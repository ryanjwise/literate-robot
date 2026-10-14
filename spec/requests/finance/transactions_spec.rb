require "rails_helper"

RSpec.describe "Finance transactions", type: :request do
  let(:headers) { auth_headers }
  let(:account) { make_account }
  let(:category) { Finance::Category.create!(name: "Utilities") }
  let(:expense) { Finance::Expense.create!(name: "Power", frequency: "monthly", category: category) }

  it "creates a manual transaction with a generated external id" do
    post "/finance/transactions", headers: headers,
         params: { transaction: { source: "MAN", account_id: account.id, date: "2026-10-01", amount_cents: -12_345,
                                  expense_id: expense.id, status: "confirmed" } }
    expect(response).to have_http_status(:created)
    expect(json["external_id"]).to be_present
    expect(json).to include("amount_cents" => -12_345, "kind" => "expense")
  end

  it "requires an account and a non-zero amount" do
    post "/finance/transactions", headers: headers,
         params: { transaction: { source: "MAN", date: "2026-10-01", amount_cents: 0 } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"].keys).to include("account", "amount_cents")
  end

  it "requires income to be positive" do
    post "/finance/transactions", headers: headers,
         params: { transaction: { source: "MAN", account_id: account.id, date: "2026-10-01", amount_cents: -5,
                                  kind: "income", status: "confirmed" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "does not require an expense for confirmed income" do
    post "/finance/transactions", headers: headers,
         params: { transaction: { source: "MAN", account_id: account.id, date: "2026-10-01", amount_cents: 5000,
                                  kind: "income", status: "confirmed" } }
    expect(response).to have_http_status(:created)
  end

  it "rejects a duplicate (source, external_id)" do
    attrs = { source: "bank:abc", external_id: "t1", account_id: account.id, date: "2026-10-01", amount_cents: -100 }
    post("/finance/transactions", headers: headers, params: { transaction: attrs })
    post("/finance/transactions", headers: headers, params: { transaction: attrs })
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects an unknown status and enforces the DB checks too" do
    post "/finance/transactions", headers: headers,
         params: { transaction: { source: "MAN", account_id: account.id, date: "2026-10-01", amount_cents: -1, status: "bogus" } }
    expect(response).to have_http_status(:unprocessable_content)

    t = Finance::Transaction.new(source: "MAN", external_id: "x", account:, date: Date.today, amount_cents: -1, status: "bogus")
    expect { t.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    t = Finance::Transaction.new(source: "MAN", external_id: "y", account:, date: Date.today, amount_cents: 0)
    expect { t.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "reconciles a pulled record, then confirms it" do
    t = Finance::Transaction.create!(source: "bank:abc", external_id: "t2", account:, date: "2026-10-02", amount_cents: -500)
    expect(t.status).to eq("pulled")

    post "/finance/transactions/#{t.id}/reconcile", headers: headers, params: { expense_id: expense.id }
    expect(json).to include("status" => "matched", "expense_id" => expense.id, "category_id" => category.id)

    post "/finance/transactions/#{t.id}/confirm", headers: headers
    expect(json["status"]).to eq("confirmed")
  end

  it "filters by status and account" do
    other = make_account(name: "Savings")
    Finance::Transaction.create!(source: "bank:abc", external_id: "a", account:, date: "2026-10-02", amount_cents: -1)
    Finance::Transaction.create!(source: "bank:abc", external_id: "b", account: other, date: "2026-10-02", amount_cents: -1,
                                 status: "matched", expense:)
    get "/finance/transactions", headers: headers, params: { status: "pulled" }
    expect(rows.map { _1["external_id"] }).to eq(["a"])
    get "/finance/transactions", headers: headers, params: { account_id: other.id }
    expect(rows.map { _1["external_id"] }).to eq(["b"])
  end

  it "refuses to create a transfer leg directly" do
    post "/finance/transactions", headers: headers,
         params: { transaction: { source: "MAN", account_id: account.id, date: "2026-10-01", amount_cents: -1, kind: "transfer" } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end

RSpec.describe "Finance transaction search", type: :request do
  let(:headers) { auth_headers }
  let(:account) { make_account }

  before do
    [["a", "2026-09-01", "WOOLWORTHS NEWTOWN", "weekly shop"], ["b", "2026-10-01", "NETFLIX.COM", nil],
     ["c", "2026-10-10", "100% PURE JUICE", nil]].each do |id, date, desc, notes|
      Finance::Transaction.create!(source: "bank:up", external_id: id, account:, date:, amount_cents: -100, description: desc, notes:)
    end
  end

  def ids(**params)
    get "/finance/transactions", headers: headers, params: params
    rows.map { _1["external_id"] }.sort
  end

  it "searches description, notes and merchant case-insensitively" do
    expect(ids(q: "woolworths")).to eq(%w[a])
    expect(ids(q: "weekly")).to eq(%w[a])
    expect(ids(q: "NETFLIX COM")).to eq(%w[b])
  end

  it "treats % and _ literally" do
    expect(ids(q: "100%")).to eq(%w[c])
    expect(ids(q: "%")).to eq(%w[c])
  end

  it "filters by date range and combines filters" do
    expect(ids(from: "2026-10-01")).to eq(%w[b c])
    expect(ids(from: "2026-09-15", to: "2026-10-05")).to eq(%w[b])
    expect(ids(q: "pure", from: "2026-10-01", kind: "expense")).to eq(%w[c])
  end

  it "rejects a bad date" do
    get "/finance/transactions", headers: headers, params: { from: "yesterday" }
    expect(response).to have_http_status(:bad_request)
  end
end
