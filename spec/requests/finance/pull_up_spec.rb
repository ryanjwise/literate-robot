require "rails_helper"

RSpec.describe "Finance UP pull", type: :request do
  let(:headers) { auth_headers.merge("X-Bank-Token" => "up:yeah:secret-token") }
  let(:accounts) { [up_account("acc-spend", "Spending", 100_000), up_account("acc-save", "Savings", 500_000, type: "SAVER")] }
  let(:transactions) do
    [up_txn("t-groc", account: "acc-spend", cents: -8_715, desc: "Woolworths", raw: "WOOLWORTHS 1234", category: "groceries"),
     up_txn("t-pay", account: "acc-spend", cents: 245_000, desc: "Acme Pty Ltd", at: "2026-10-10T08:00:00+11:00"),
     up_txn("t-out", account: "acc-spend", cents: -20_000, desc: "Transfer to Savings", transfer: "acc-save",
            at: "2026-10-11T10:00:00+11:00"),
     up_txn("t-in", account: "acc-save", cents: 20_000, desc: "Transfer from Spending", transfer: "acc-spend",
            at: "2026-10-11T10:00:01+11:00")]
  end
  let(:client) { UpFixtures::FakeUpClient.new(accounts:, transactions:) }

  before do
    travel_to Date.new(2026, 10, 14)
    allow(Finance::Up::Client).to receive(:new).and_return(client)
  end

  def pull(**params) = post("/finance/pull/up", headers: headers, params: params)

  it "creates accounts, signed transactions and kinds" do
    pull
    expect(response).to have_http_status(:ok)
    expect(json["transactions"]).to include("created" => 4, "updated" => 0, "unchanged" => 0)

    groc = Finance::Transaction.find_by!(external_id: "t-groc")
    expect(groc).to have_attributes(source: "bank:up", kind: "expense", amount_cents: -8_715, status: "pulled",
                                    description: "Woolworths", raw_text: "WOOLWORTHS 1234", bank_status: "settled",
                                    bank_category: "groceries", merchant_key: "WOOLWORTHS", date: Date.new(2026, 10, 12))
    expect(Finance::Transaction.find_by!(external_id: "t-pay")).to have_attributes(kind: "income", status: "pulled")
  end

  it "sets opening balances so computed balances match UP, and reports no drift" do
    pull
    expect(json["accounts"].map { _1["drift_cents"] }).to eq([0, 0])
    spend = Finance::Account.find_by!(external_id: "acc-spend")
    expect(spend).to have_attributes(kind: "debit", external_source: "bank:up")
    expect(spend.balance_cents).to eq(100_000)
    expect(Finance::Account.find_by!(external_id: "acc-save").balance_cents).to eq(500_000)
  end

  it "maps account types to kinds" do
    accounts << up_account("acc-loan", "Home loan", -40_000_000, type: "HOME_LOAN")
    pull
    expect(Finance::Account.find_by!(external_id: "acc-loan")).to have_attributes(kind: "credit")
  end

  it "pairs the two legs of a transfer, confirmed, with one shared group" do
    pull
    legs = Finance::Transaction.where(kind: "transfer").order(:id)
    expect(legs.map(&:external_id)).to contain_exactly("t-out", "t-in")
    expect(legs.map(&:transfer_group_id).uniq.size).to eq(1)
    expect(legs.map(&:status).uniq).to eq(["confirmed"])
    expect(legs.sum(:amount_cents)).to eq(0)
    expect(json["unpaired_transfers"]).to eq(0)
  end

  it "reports a lone transfer leg as unpaired" do
    transactions.pop
    pull
    expect(json["unpaired_transfers"]).to eq(1)
    expect(Finance::Transaction.find_by!(external_id: "t-out").transfer_group_id).to be_present
  end

  it "counts a lone Round Up leg separately from genuinely unpaired transfers" do
    transactions << up_txn("t-round", account: "acc-save", cents: 7, desc: "Round Up", transfer: "acc-spend",
                           at: "2026-10-12T09:30:05+11:00")
    pull
    expect(json).to include("round_up_transfers" => 1, "unpaired_transfers" => 0)
    expect(Finance::Transaction.find_by!(external_id: "t-round")).to have_attributes(kind: "transfer", status: "confirmed")
  end

  it "is idempotent: a second pull creates nothing" do
    pull
    expect { pull }.not_to change { Finance::Transaction.count }
    expect(json["transactions"]).to include("created" => 0, "unchanged" => 4)
    expect(Finance::Account.count).to eq(2)
  end

  it "refreshes bank fields (held -> settled) without touching review fields" do
    transactions[0] = up_txn("t-groc", account: "acc-spend", cents: -8_000, desc: "Woolworths", status: "HELD")
    pull
    groc = Finance::Transaction.find_by!(external_id: "t-groc")
    category = Finance::Category.create!(name: "Groceries")
    groc.update!(category:, notes: "weekly", status: "confirmed")

    transactions[0] = up_txn("t-groc", account: "acc-spend", cents: -8_715, desc: "Woolworths")
    pull
    expect(json["transactions"]["updated"]).to eq(1)
    expect(json["changed_after_review"]).to eq([groc.id])
    expect(groc.reload).to have_attributes(amount_cents: -8_715, bank_status: "settled", category_id: category.id,
                                           notes: "weekly", status: "confirmed")
  end

  it "reports drift when the balances disagree" do
    pull
    accounts[0] = up_account("acc-spend", "Spending", 101_000)
    pull
    expect(json["accounts"].find { _1["external_id"] == "acc-spend" }["drift_cents"]).to eq(1_000)
  end

  it "applies merchant memory to newly pulled records" do
    category = Finance::Category.create!(name: "Groceries")
    Finance::Merchant.create!(key: "WOOLWORTHS", category:)
    pull
    expect(Finance::Transaction.find_by!(external_id: "t-groc")).to have_attributes(status: "matched", auto_assigned: true,
                                                                                    category_id: category.id)
  end

  it "writes nothing on a dry run" do
    pull(dry_run: "true")
    expect(json).to include("dry_run" => true)
    expect(json["transactions"]["created"]).to eq(4)
    expect(Finance::Transaction.count).to eq(0)
    expect(Finance::Account.count).to eq(0)
  end

  it "honours dry_run sent as a JSON boolean, as clients do" do
    post "/finance/pull/up", headers: headers.merge("Content-Type" => "application/json"),
         params: { since: "2026-10-01", dry_run: true }.to_json
    expect(json["dry_run"]).to be(true)
    expect(Finance::Transaction.count).to eq(0)
    expect(Finance::Account.count).to eq(0)
  end

  it "defaults to the last 30 days, and rejects a future date" do
    pull
    expect(json["since"]).to eq("2026-09-14")
    pull(since: "2026-10-20")
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "keeps a manually named account from clashing" do
    make_account(name: "Spending")
    pull
    expect(Finance::Account.find_by!(external_id: "acc-spend").name).to eq("Spending (UP)")
  end

  describe "failures" do
    it "requires the token header" do
      post "/finance/pull/up", headers: auth_headers
      expect(response).to have_http_status(:bad_request)
    end

    it "requires our own key" do
      post "/finance/pull/up", headers: { "X-Bank-Token" => "x" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "maps an UP rejection to 502 and never echoes the token" do
      allow(client).to receive(:paginate).and_raise(Finance::Up::Error.new("UP rejected the token", status: 401))
      pull
      expect(response).to have_http_status(:bad_gateway)
      expect(response.body).not_to include("secret-token")
    end

    it "passes UP rate limiting through as 429" do
      allow(client).to receive(:paginate).and_raise(Finance::Up::Error.new("UP rate limit reached", status: 429))
      pull
      expect(response).to have_http_status(:too_many_requests)
    end

    it "rolls back everything if a write fails midway" do
      allow(Finance::Transaction).to receive(:create!).and_wrap_original do |m, *args|
        raise ActiveRecord::RecordInvalid, Finance::Transaction.new if args.first[:external_id] == "t-in"
        m.call(*args)
      end
      pull
      expect(response).to have_http_status(:unprocessable_content)
      expect(Finance::Transaction.count).to eq(0)
      expect(Finance::Account.count).to eq(0)
    end
  end
end
