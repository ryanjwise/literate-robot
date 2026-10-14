require "rails_helper"

RSpec.describe "Finance categories and expenses", type: :request do
  let(:headers) { auth_headers }

  it "creates a category and an expense in it" do
    account = make_account
    post "/finance/categories", headers: headers, params: { category: { name: "Utilities", desired_account_id: account.id } }
    expect(response).to have_http_status(:created)
    expect(json["desired_account_id"]).to eq(account.id)
    cat_id = json["id"]

    post "/finance/expenses", headers: headers, params: { expense: { name: "Power", frequency: "monthly", category_id: cat_id } }
    expect(response).to have_http_status(:created)
    expect(json).to include("category_id" => cat_id)
  end

  it "rejects an unknown frequency and a duplicate category name" do
    cat = Finance::Category.create!(name: "Dup")
    post "/finance/expenses", headers: headers, params: { expense: { name: "X", frequency: "hourly", category_id: cat.id } }
    expect(response).to have_http_status(:unprocessable_content)
    post "/finance/categories", headers: headers, params: { category: { name: "Dup" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "will not delete a category in use" do
    cat = Finance::Category.create!(name: "Used")
    Finance::Expense.create!(name: "E", frequency: "daily", category: cat)
    delete "/finance/categories/#{cat.id}", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "maps a category to an account that exists" do
    post "/finance/categories", headers: headers, params: { category: { name: "X", desired_account_id: 9999 } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "will not delete an account that a category or expense points at" do
    account = make_account
    cat = Finance::Category.create!(name: "C", desired_account: account)
    delete "/finance/accounts/#{account.id}", headers: headers
    expect(response).to have_http_status(:unprocessable_content)

    cat.update!(desired_account: nil)
    Finance::Expense.create!(name: "E", frequency: "daily", category: cat, account:)
    delete "/finance/accounts/#{account.id}", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "accepts an ad hoc expense" do
    cat = Finance::Category.create!(name: "C")
    post "/finance/expenses", headers: headers, params: { expense: { name: "Dentist", frequency: "ad_hoc", category_id: cat.id } }
    expect(response).to have_http_status(:created)
  end
end

RSpec.describe "Finance dangling references", type: :request do
  let(:headers) { auth_headers }

  it "returns 422, not 500, for ids that point at nothing" do
    account = make_account
    post "/finance/transactions", headers: headers,
         params: { transaction: { source: "MAN", account_id: account.id, date: "2026-10-01", amount_cents: -1,
                                  kind: "income", expense_id: 9999 } }
    expect(response).to have_http_status(:unprocessable_content)

    post "/finance/accounts", headers: headers, params: { account: { name: "Z", kind: "debit", funded_by_id: 9999 } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
