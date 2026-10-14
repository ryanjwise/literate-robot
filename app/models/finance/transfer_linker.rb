module Finance
  # Turns an ordinary transaction into one half of a transfer. For transfers that
  # span banks (e.g. UP -> another bank), where one half is a bank record and the other
  # is entered by hand, so nothing pairs them automatically.
  #
  # A bank leg keeps its source, date and amount; only its kind changes, and only here.
  class TransferLinker
    class Error < StandardError; end

    # Pair `transaction` with an existing transaction (counterpart_id), or create the
    # missing manual half on another account (counterpart_account_id).
    def self.link!(transaction, counterpart_id: nil, counterpart_account_id: nil)
      raise Error, "give exactly one of counterpart_id or counterpart_account_id" if counterpart_id.present? == counterpart_account_id.present?
      raise Error, "already part of a transfer" if transaction.transfer?

      Transaction.transaction do
        group = SecureRandom.uuid
        other = counterpart_id.present? ? existing_half(transaction, counterpart_id) : new_half(transaction, counterpart_account_id, group)
        [transaction, other].each { make_leg(_1, group) }
        [transaction.reload, other.reload]
      end
    end

    # Undo a link (or a bank-detected pairing): both legs return to income/expense and
    # to the reconcile queue. A manual half that was created by linking is not deleted;
    # delete it yourself if it should not exist.
    def self.unlink!(group_id)
      legs = Transaction.where(kind: "transfer", transfer_group_id: group_id).to_a
      raise ActiveRecord::RecordNotFound if legs.empty?
      raise Error, "only transfers involving a bank record can be unlinked; delete a manual transfer instead" if legs.all?(&:manual?)

      Transaction.transaction do
        legs.each do |leg|
          leg.bank_sync = true
          leg.update!(kind: leg.amount_cents.positive? ? "income" : "expense", transfer_group_id: nil, status: "pulled")
        end
      end
      legs
    end

    # Likely counterparts: other accounts, opposite amount, nearest dates first.
    def self.candidates(transaction)
      Transaction.where(amount_cents: -transaction.amount_cents).where.not(account_id: transaction.account_id)
                 .where.not(kind: "transfer").where.not(id: transaction.id)
                 .sort_by { (_1.date - transaction.date).abs }.first(20)
    end

    def self.existing_half(transaction, id)
      other = Transaction.find(id)
      raise Error, "counterpart is already part of a transfer" if other.transfer?
      raise Error, "counterpart must be on a different account" if other.account_id == transaction.account_id
      raise Error, "counterpart amount must be equal and opposite" unless other.amount_cents == -transaction.amount_cents
      other
    end

    def self.new_half(transaction, account_id, group)
      account = Account.find_by(id: account_id) or raise Error, "counterpart account does not exist"
      raise Error, "counterpart must be on a different account" if account.id == transaction.account_id
      direction = transaction.amount_cents.negative? ? "from" : "to"
      Transaction.create!(source: Transaction::MANUAL_SOURCE, account:, kind: "transfer", transfer_group_id: group, status: "confirmed",
                          date: transaction.date, amount_cents: -transaction.amount_cents,
                          description: "Transfer #{direction} #{transaction.account.name}")
    end

    def self.make_leg(leg, group)
      return if leg.transfer? && leg.transfer_group_id == group # the newly created half
      leg.bank_sync = true
      leg.update!(kind: "transfer", transfer_group_id: group, status: "confirmed",
                  category_id: nil, expense_id: nil, auto_assigned: false)
    end

    private_class_method :existing_half, :new_half, :make_leg
  end
end
