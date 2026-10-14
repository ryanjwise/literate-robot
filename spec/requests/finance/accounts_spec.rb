require "rails_helper"

RSpec.describe "Finance accounts", type: :request do
  let(:headers) { auth_headers }

  it "creates an account that is funded by another" do
    debit = make_account
    post "/finance/accounts", headers: headers,
         params: { account: { name: "Visa", kind: "credit", funded_by_id: debit.id } }
    expect(response).to have_http_status(:created)
    expect(json).to include("kind" => "credit", "funded_by_id" => debit.id, "balance_cents" => 0)
  end

  it "rejects an unknown kind, a duplicate name, and self-funding" do
    post "/finance/accounts", headers: headers, params: { account: { name: "X", kind: "crypto" } }
    expect(response).to have_http_status(:unprocessable_content)

    make_account(name: "Dup")
    post "/finance/accounts", headers: headers, params: { account: { name: "Dup", kind: "debit" } }
    expect(response).to have_http_status(:unprocessable_content)

    a = make_account(name: "Solo")
    patch "/finance/accounts/#{a.id}", headers: headers, params: { account: { funded_by_id: a.id } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "computes balance from the opening balance plus transactions on or after its date" do
    a = make_account(opening_balance_cents: 100_000, opening_balance_on: "2026-10-01")
    Finance::Transaction.create!(source: "MAN", account: a, kind: "income", date: "2026-10-05", amount_cents: 50_000, status: "confirmed")
    Finance::Transaction.create!(source: "MAN", account: a, kind: "income", date: "2026-09-01", amount_cents: 999, status: "confirmed")
    Finance::Transaction.create!(source: "bank:x", external_id: "e", account: a, date: "2026-10-06", amount_cents: -12_000)

    get "/finance/accounts/#{a.id}", headers: headers
    expect(json["balance_cents"]).to eq(100_000 + 50_000 - 12_000)
  end

  it "will not delete an account that has transactions" do
    a = make_account
    Finance::Transaction.create!(source: "bank:x", external_id: "e", account: a, date: "2026-10-06", amount_cents: -1)
    delete "/finance/accounts/#{a.id}", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
  end
end
