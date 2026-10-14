require "rails_helper"

RSpec.describe "Finance transactions", type: :request do
  let(:headers) { auth_headers }
  let(:category) { Finance::ExpenseCategory.create!(name: "Utilities") }
  let(:expense) { Finance::Expense.create!(name: "Power", frequency: "monthly", expense_category: category) }

  def json = JSON.parse(response.body)

  it "creates a manual transaction with a generated external id" do
    post "/finance/transactions", headers:,
         params: { transaction: { source: "MAN", date: "2026-10-01", amount_cents: 12_345, expense_id: expense.id, status: "confirmed" } }
    expect(response).to have_http_status(:created)
    expect(json["external_id"]).to be_present
    expect(json["amount_cents"]).to eq(12_345)
  end

  it "rejects a duplicate (source, external_id)" do
    attrs = { source: "bank:abc", external_id: "t1", date: "2026-10-01", amount_cents: 100 }
    post("/finance/transactions", headers:, params: { transaction: attrs })
    post("/finance/transactions", headers:, params: { transaction: attrs })
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects an unknown status and enforces the DB check too" do
    post "/finance/transactions", headers:,
         params: { transaction: { source: "MAN", date: "2026-10-01", amount_cents: 1, status: "bogus" } }
    expect(response).to have_http_status(:unprocessable_content)

    t = Finance::Transaction.new(source: "MAN", external_id: "x", date: Date.today, amount_cents: 1, status: "bogus")
    expect { t.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "reconciles a pulled record, then confirms it" do
    t = Finance::Transaction.create!(source: "bank:abc", external_id: "t2", date: "2026-10-02", amount_cents: 500)
    expect(t.status).to eq("pulled")

    post "/finance/transactions/#{t.id}/reconcile", headers:, params: { expense_id: expense.id }
    expect(json).to include("status" => "matched", "expense_id" => expense.id)

    post "/finance/transactions/#{t.id}/confirm", headers: headers
    expect(json["status"]).to eq("confirmed")
  end

  it "filters by status" do
    Finance::Transaction.create!(source: "bank:abc", external_id: "a", date: "2026-10-02", amount_cents: 1)
    Finance::Transaction.create!(source: "bank:abc", external_id: "b", date: "2026-10-02", amount_cents: 1,
                                 status: "matched", expense:)
    get "/finance/transactions", headers:, params: { status: "pulled" }
    expect(json.map { _1["external_id"] }).to eq(["a"])
  end
end
