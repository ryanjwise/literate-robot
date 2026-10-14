require "rails_helper"

RSpec.describe "Finance categories and expenses", type: :request do
  let(:headers) { auth_headers }

  it "creates a category and an expense in it" do
    post "/finance/categories", headers: headers, params: { category: { name: "Utilities", desired_source: "Everyday" } }
    expect(response).to have_http_status(:created)
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
end
