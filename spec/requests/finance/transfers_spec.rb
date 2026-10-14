require "rails_helper"

RSpec.describe "Finance transfers", type: :request do
  let(:headers) { auth_headers }
  let(:debit) { make_account(name: "Debit", opening_balance_cents: 100_000) }
  let(:card) { make_account(name: "Card", kind: "credit", funded_by: debit) }

  def transfer!(amount: 30_000)
    post "/finance/transfers", headers: headers,
         params: { transfer: { from_account_id: debit.id, to_account_id: card.id, amount_cents: amount,
                               date: "2026-10-10", description: "card payment" } }
  end

  it "creates two linked legs that net to zero and move both balances" do
    Finance::Transaction.create!(source: "bank:x", external_id: "spend", account: card, date: "2026-10-02", amount_cents: -30_000)

    transfer!
    expect(response).to have_http_status(:created)
    group = json["transfer_group_id"]

    legs = Finance::Transaction.where(transfer_group_id: group)
    expect(legs.pluck(:amount_cents).sum).to eq(0)
    expect(debit.reload.balance_cents).to eq(70_000)
    expect(card.reload.balance_cents).to eq(0) # spent 300, paid 300
  end

  it "lists transfers as single records" do
    transfer!
    get "/finance/transfers", headers: headers
    expect(json.size).to eq(1)
    expect(json.first).to include("from_account_id" => debit.id, "to_account_id" => card.id, "amount_cents" => 30_000)
  end

  it "validates amount and accounts" do
    transfer!(amount: 0)
    expect(response).to have_http_status(:unprocessable_content)

    post "/finance/transfers", headers: headers,
         params: { transfer: { from_account_id: debit.id, to_account_id: debit.id, amount_cents: 5, date: "2026-10-10" } }
    expect(response).to have_http_status(:unprocessable_content)

    post "/finance/transfers", headers: headers,
         params: { transfer: { from_account_id: debit.id, to_account_id: 9999, amount_cents: 5, date: "2026-10-10" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "deletes both legs together and blocks deleting or reshaping one leg" do
    transfer!
    group = json["transfer_group_id"]
    leg = Finance::Transaction.find_by(transfer_group_id: group, account: debit)

    delete "/finance/transactions/#{leg.id}", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    patch "/finance/transactions/#{leg.id}", headers: headers, params: { transaction: { amount_cents: -1, description: "edited" } }
    expect(leg.reload.amount_cents).to eq(-30_000)
    expect(leg.description).to eq("edited") # free text is still editable

    delete "/finance/transfers/#{group}", headers: headers
    expect(response).to have_http_status(:no_content)
    expect(Finance::Transaction.where(transfer_group_id: group)).to be_empty
  end

  it "requires auth" do
    get "/finance/transfers"
    expect(response).to have_http_status(:unauthorized)
  end
end
