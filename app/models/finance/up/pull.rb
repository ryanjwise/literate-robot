require "time"

module Finance
  module Up
    # Imports accounts and transactions from UP. Everything is fetched first and
    # written in one DB transaction, so a failed pull changes nothing.
    # Re-pulling is safe: identity is (source, UP transaction id).
    class Pull
      SOURCE = "bank:up".freeze
      PAIR_WINDOW_SECONDS = 60
      ACCOUNT_KINDS = { "TRANSACTIONAL" => "debit", "SAVER" => "debit", "HOME_LOAN" => "credit" }.freeze
      ZONE = ActiveSupport::TimeZone["Australia/Sydney"]

      def initialize(client:, since:, dry_run: false)
        @client = client
        @since = since
        @dry_run = dry_run
      end

      def call
        up_accounts = @client.paginate("/accounts", "page[size]" => 100)
        up_txns = @client.paginate("/transactions", "page[size]" => 100, "filter[since]" => ZONE.local(@since.year, @since.month, @since.day).iso8601)
        result = nil
        ActiveRecord::Base.transaction do
          result = write(up_accounts, up_txns)
          raise ActiveRecord::Rollback if @dry_run
        end
        result.merge(dry_run: @dry_run)
      end

      private

      def write(up_accounts, up_txns)
        by_account = up_txns.group_by { rel_id(_1, "account") }
        linked = up_accounts.to_h { [_1["id"], link_account(_1, by_account.fetch(_1["id"], []))] }
        groups = pair_transfers(up_txns)
        existing = Transaction.where(source: SOURCE, external_id: up_txns.map { _1["id"] }).index_by(&:external_id)

        counts = { created: 0, updated: 0, unchanged: 0 }
        changed_after_review = []
        up_txns.each do |t|
          account = linked[rel_id(t, "account")]&.first
          next unless account
          record = existing[t["id"]]
          if record
            outcome = sync_existing(record, t)
            counts[outcome] += 1
            changed_after_review << record.id if outcome == :updated && record.status != "pulled"
          else
            create_new(t, account, groups[t["id"]])
            counts[:created] += 1
          end
        end

        legs_per_group = groups.values.tally
        lone = up_txns.select { groups.key?(_1["id"]) && legs_per_group[groups[_1["id"]]] == 1 }
        round_ups = lone.count { round_up?(_1) }
        { since: @since, transactions: counts, changed_after_review:,
          round_up_transfers: round_ups, unpaired_transfers: lone.size - round_ups,
          accounts: linked.map { |up_id, (account, created)| account_summary(up_accounts, up_id, account, created) } }
      end

      # Find the local account for an UP account, or create it. A new account's opening
      # balance is set so its computed balance matches UP's at the time of the pull.
      def link_account(up, txns)
        existing = Account.find_by(external_source: SOURCE, external_id: up["id"])
        return [existing, false] if existing

        pulled_total = txns.sum { cents(_1) }
        name = up.dig("attributes", "displayName")
        name = "#{name} (UP)" if Account.exists?(name:)
        account = Account.create!(name:, kind: ACCOUNT_KINDS.fetch(up.dig("attributes", "accountType"), "debit"),
                                  external_source: SOURCE, external_id: up["id"],
                                  opening_balance_cents: up.dig("attributes", "balance", "valueInBaseUnits") - pulled_total,
                                  opening_balance_on: @since)
        [account, true]
      end

      def account_summary(up_accounts, up_id, account, created)
        up_balance = up_accounts.find { _1["id"] == up_id }.dig("attributes", "balance", "valueInBaseUnits")
        { account_id: account.id, external_id: up_id, name: account.name, created:, up_balance_cents: up_balance,
          computed_balance_cents: account.balance_cents, drift_cents: up_balance - account.balance_cents }
      end

      def create_new(t, account, group_id)
        transfer = group_id.present?
        Transaction.create!(
          { source: SOURCE, external_id: t["id"], account:, kind: kind_for(t, transfer),
            transfer_group_id: group_id, status: transfer ? "confirmed" : "pulled" }.merge(bank_attributes(t))
        )
      end

      # Bank fields follow the bank; review fields (category, notes, status...) are never touched.
      def sync_existing(record, t)
        record.bank_sync = true
        record.assign_attributes(bank_attributes(t))
        return :unchanged unless record.changed?
        record.save!
        :updated
      end

      def bank_attributes(t)
        a = t["attributes"]
        { date: Time.iso8601(a["createdAt"]).to_date, amount_cents: cents(t), description: a["description"],
          raw_text: a["rawText"], bank_status: a["status"]&.downcase,
          settled_at: a["settledAt"] && Time.iso8601(a["settledAt"]), bank_category: rel_id(t, "category") }
      end

      def kind_for(t, transfer)
        return "transfer" if transfer
        cents(t).positive? ? "income" : "expense"
      end

      # UP shows a transfer between your accounts as two transactions, one per account.
      # Pair them (opposite amounts, mirrored accounts, created together) so they share a group.
      def pair_transfers(txns)
        transfers = txns.select { rel_id(_1, "transferAccount") }
        groups = {}
        transfers.each do |t|
          next if groups.key?(t["id"])
          partner = transfers.find { |u| u["id"] != t["id"] && !groups.key?(u["id"]) && counterpart?(t, u) }
          group = "up-#{[t["id"], partner&.dig("id")].compact.sort.join("-")}"
          groups[t["id"]] = group
          groups[partner["id"]] = group if partner
        end
        groups
      end

      def counterpart?(t, u)
        rel_id(u, "account") == rel_id(t, "transferAccount") && rel_id(u, "transferAccount") == rel_id(t, "account") &&
          cents(u) == -cents(t) && (created_at(t) - created_at(u)).abs <= PAIR_WINDOW_SECONDS
      end

      # UP shows a Round Up as only the saver's incoming transfer; the outgoing side is
      # part of the purchase, so a lone "Round Up" leg is expected, not a missing pair.
      def round_up?(t) = t.dig("attributes", "description").to_s.casecmp?(Transfer::ROUND_UP_DESCRIPTION)

      def cents(t) = t.dig("attributes", "amount", "valueInBaseUnits")
      def created_at(t) = Time.iso8601(t.dig("attributes", "createdAt"))
      def rel_id(t, name) = t.dig("relationships", name, "data", "id")
    end
  end
end
