require "rails_helper"

# Plain CRUD paths; the contract hook checks every response against openapi/finance.yaml.
RSpec.describe "Finance CRUD", type: :request do
  let(:headers) { auth_headers }
  let(:account) { make_account }
  let(:category) { Finance::Category.create!(name: "Utilities", desired_account: account) }
  let(:expense) { Finance::Expense.create!(name: "Power", frequency: "monthly", category:, account:, anchor_date: "2026-11-01") }

  it "lists and reads accounts" do
    account
    get "/finance/accounts", headers: headers
    expect(json.first).to include("name" => "Everyday", "balance_cents" => 0)
  end

  it "lists, reads and updates categories" do
    category
    get "/finance/categories", headers: headers
    expect(json.map { _1["name"] }).to eq(["Utilities"])
    get "/finance/categories/#{category.id}", headers: headers
    expect(json["desired_account_id"]).to eq(account.id)
    patch "/finance/categories/#{category.id}", headers: headers, params: { category: { name: "Bills" } }
    expect(json["name"]).to eq("Bills")
  end

  it "lists, reads, updates and deletes expenses" do
    expense
    get "/finance/expenses", headers: headers
    expect(json.first).to include("name" => "Power", "amount_mode" => "variable")
    get "/finance/expenses/#{expense.id}", headers: headers
    expect(json["anchor_date"]).to eq("2026-11-01")
    patch "/finance/expenses/#{expense.id}", headers: headers, params: { expense: { frequency: "quarterly" } }
    expect(json["frequency"]).to eq("quarterly")
    delete "/finance/expenses/#{expense.id}", headers: headers
    expect(response).to have_http_status(:no_content)
  end

  it "reads one merchant rule" do
    merchant = Finance::Merchant.create!(key: "WOOLWORTHS", category:)
    get "/finance/merchants/#{merchant.id}", headers: headers
    expect(json).to include("key" => "WOOLWORTHS", "auto_assign" => true)
  end
end
