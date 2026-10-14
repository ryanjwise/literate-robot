require "rails_helper"

RSpec.describe "Finance pagination", type: :request do
  let(:headers) { auth_headers }
  let(:account) { make_account }

  def txn(external_id, date, cents = -100, **attrs)
    Finance::Transaction.create!({ source: "bank:up", external_id:, account:, date:, amount_cents: cents }.merge(attrs))
  end

  def list(path, **params)
    get path, headers: headers, params: params
    json
  end

  # Follow next_cursor until null, returning every page's ids.
  def walk(path, **params)
    pages = []
    cursor = nil
    loop do
      body = list(path, **params, cursor:)
      pages << body["data"].map { _1["external_id"] || _1["id"] || _1["transfer_group_id"] }
      cursor = body["next_cursor"]
      break unless cursor
      raise "cursor never ended" if pages.size > 50
    end
    pages
  end

  describe "transactions" do
    # 7 records over 3 dates, with ties on date (the tie-break is id).
    before do
      %w[a b c].each { txn(_1, "2026-10-01") }
      %w[d e].each { txn(_1, "2026-10-05") }
      %w[f g].each { txn(_1, "2026-10-09") }
    end

    it "returns the most recent first, then by newest id" do
      expect(list("/finance/transactions")["data"].map { _1["external_id"] }).to eq(%w[g f e d c b a])
    end

    it "wraps results in an envelope with no cursor when everything fits" do
      body = list("/finance/transactions")
      expect(body.keys).to match_array(%w[data next_cursor])
      expect(body["next_cursor"]).to be_nil
    end

    it "walks every page exactly once, with no gaps or duplicates" do
      pages = walk("/finance/transactions", limit: 3)
      expect(pages).to eq([%w[g f e], %w[d c b], %w[a]])
      expect(pages.flatten.uniq.size).to eq(7)
    end

    it "walks ascending too" do
      expect(walk("/finance/transactions", limit: 3, dir: "asc").flatten).to eq(%w[a b c d e f g])
    end

    it "sorts by amount, signed, and walks through ties" do
      Finance::Transaction.find_by!(external_id: "a").update_columns(amount_cents: -5_000)
      Finance::Transaction.find_by!(external_id: "g").update_columns(amount_cents: 900)
      desc = walk("/finance/transactions", sort: "amount_cents", limit: 2).flatten
      expect(desc.first).to eq("g")
      expect(desc.last).to eq("a")
      expect(desc.size).to eq(7)
      expect(walk("/finance/transactions", sort: "amount_cents", dir: "asc", limit: 2).flatten.first).to eq("a")
    end

    it "walks by created_at" do
      expect(walk("/finance/transactions", sort: "created_at", limit: 3).flatten.size).to eq(7)
    end

    it "does not repeat or skip rows when newer records arrive between pages" do
      first = list("/finance/transactions", limit: 3)
      txn("newest", "2026-10-20")
      second = list("/finance/transactions", limit: 3, cursor: first["next_cursor"])
      expect(second["data"].map { _1["external_id"] }).to eq(%w[d c b])
      expect(second["data"].map { _1["external_id"] } & first["data"].map { _1["external_id"] }).to be_empty
    end

    it "combines with filters" do
      txn("big", "2026-10-02", -9_000)
      txn("income", "2026-10-03", 20_000, kind: "income")
      expect(walk("/finance/transactions", min_amount_cents: 5_000, limit: 1).flatten).to eq(%w[income big])
      expect(list("/finance/transactions", max_amount_cents: 100)["data"].size).to eq(7)
      expect(list("/finance/transactions", min_amount_cents: 5_000, max_amount_cents: 10_000)["data"].map { _1["external_id"] }).to eq(%w[big])
      expect(walk("/finance/transactions", from: "2026-10-05", to: "2026-10-09", limit: 2).flatten).to eq(%w[g f e d])
    end

    it "caps limit at the maximum" do
      stub_const("FinancePagination::MAX_LIMIT", 2)
      expect(list("/finance/transactions", limit: 100)["data"].size).to eq(2)
    end

    describe "bad input" do
      it "rejects an unknown sort, direction, or limit" do
        { sort: "description", dir: "sideways", limit: 0 }.each do |key, value|
          get "/finance/transactions", headers: headers, params: { key => value }
          expect(response).to have_http_status(:bad_request), "#{key}=#{value}"
        end
        get "/finance/transactions", headers: headers, params: { limit: "many" }
        expect(response).to have_http_status(:bad_request)
        get "/finance/transactions", headers: headers, params: { min_amount_cents: "lots" }
        expect(response).to have_http_status(:bad_request)
      end

      it "rejects a garbage cursor, and a cursor used with a different sort or direction" do
        get "/finance/transactions", headers: headers, params: { cursor: "not-a-cursor" }
        expect(response).to have_http_status(:bad_request)

        cursor = list("/finance/transactions", limit: 2)["next_cursor"]
        get "/finance/transactions", headers: headers, params: { cursor:, sort: "amount_cents" }
        expect(response).to have_http_status(:bad_request)
        get "/finance/transactions", headers: headers, params: { cursor:, dir: "asc" }
        expect(response).to have_http_status(:bad_request)
        expect(json["error"]).to match(/different sort or direction/)
      end
    end
  end

  describe "reference lists" do
    it "paginates accounts, categories, expenses and merchants newest first, and sorts by name" do
      %w[Charlie Alpha Bravo].each { make_account(name: _1) }
      page = list("/finance/accounts", limit: 2)
      expect(page["data"].map { _1["name"] }).to eq(%w[Bravo Alpha])
      expect(list("/finance/accounts", limit: 2, cursor: page["next_cursor"])["data"].map { _1["name"] }).to eq(%w[Charlie])
      expect(list("/finance/accounts", sort: "name", dir: "asc")["data"].map { _1["name"] }).to eq(%w[Alpha Bravo Charlie])

      cats = %w[Z Y X].map { Finance::Category.create!(name: _1) }
      expect(walk("/finance/categories", limit: 1).flatten).to eq(cats.reverse.map(&:id))

      expenses = %w[One Two].map { Finance::Expense.create!(name: _1, frequency: "monthly", category: cats.first) }
      expect(walk("/finance/expenses", limit: 1).flatten).to eq(expenses.reverse.map(&:id))

      merchants = %w[AAA BBB].map { Finance::Merchant.create!(key: _1, category: cats.first) }
      expect(walk("/finance/merchants", limit: 1).flatten).to eq(merchants.reverse.map(&:id))
      expect(list("/finance/merchants", sort: "key", dir: "asc")["data"].map { _1["key"] }).to eq(%w[AAA BBB])
    end

    it "rejects a sort column that is not on the allowlist" do
      get "/finance/accounts", headers: headers, params: { sort: "opening_balance_on" }
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "transfers" do
    let(:other) { make_account(name: "Other") }

    before do
      [["2026-10-01", 100], ["2026-10-03", 300], ["2026-10-02", 200], ["2026-10-04", 400]].each do |date, cents|
        Finance::Transfer.new(from_account_id: account.id, to_account_id: other.id, amount_cents: cents, date:).save
      end
      Finance::Transaction.create!(source: "bank:up", external_id: "ru", account: other, kind: "transfer", transfer_group_id: "up-ru",
                                   status: "confirmed", date: "2026-10-05", amount_cents: 7, description: "Round Up")
    end

    it "is newest first and walks without gaps or duplicates" do
      pages = walk("/finance/transfers", limit: 2)
      expect(pages.flatten.size).to eq(5)
      expect(pages.flatten.uniq.size).to eq(5)
      expect(list("/finance/transfers")["data"].map { _1["date"] }).to eq(%w[2026-10-05 2026-10-04 2026-10-03 2026-10-02 2026-10-01])
      expect(list("/finance/transfers", dir: "asc")["data"].first["date"]).to eq("2026-10-01")
    end

    it "sorts by amount and filters by round_up, paired and date range" do
      expect(list("/finance/transfers", sort: "amount_cents", dir: "asc")["data"].map { _1["amount_cents"] }).to eq([7, 100, 200, 300, 400])
      expect(list("/finance/transfers", round_up: "false")["data"].size).to eq(4)
      expect(list("/finance/transfers", round_up: "true")["data"].map { _1["transfer_group_id"] }).to eq(["up-ru"])
      expect(list("/finance/transfers", paired: "false")["data"].size).to eq(1)
      expect(list("/finance/transfers", from: "2026-10-02", to: "2026-10-03")["data"].size).to eq(2)
    end

    it "enforces cursor rules the same way" do
      cursor = list("/finance/transfers", limit: 2)["next_cursor"]
      get "/finance/transfers", headers: headers, params: { cursor:, sort: "amount_cents" }
      expect(response).to have_http_status(:bad_request)
      get "/finance/transfers", headers: headers, params: { cursor: "garbage" }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
