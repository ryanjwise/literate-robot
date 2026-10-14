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
    expect(rows.size).to eq(1)
    expect(rows.first).to include("from_account_id" => debit.id, "to_account_id" => card.id, "amount_cents" => 30_000,
                                  "paired" => true, "deletable" => true)
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

RSpec.describe "Finance transfers from a bank pull", type: :request do
  let(:headers) { auth_headers }
  let(:account) { make_account }

  def bank_leg(external_id, cents, group)
    Finance::Transaction.create!(source: "bank:up", external_id:, account:, kind: "transfer", transfer_group_id: group,
                                 status: "confirmed", date: "2026-10-11", amount_cents: cents, description: "Transfer")
  end

  it "lists a lone leg (partner outside the pulled range) instead of crashing" do
    bank_leg("lone-out", -20_000, "up-lone")
    bank_leg("lone-in", 5_000, "up-lone-in")

    get "/finance/transfers", headers: headers
    expect(response).to have_http_status(:ok)
    by_group = rows.index_by { _1["transfer_group_id"] }
    expect(by_group["up-lone"]).to include("from_account_id" => account.id, "to_account_id" => nil,
                                           "amount_cents" => 20_000, "paired" => false, "deletable" => false)
    expect(by_group["up-lone-in"]).to include("from_account_id" => nil, "to_account_id" => account.id, "paired" => false)
  end

  it "flags Round Ups" do
    Finance::Transaction.create!(source: "bank:up", external_id: "r", account:, kind: "transfer", transfer_group_id: "up-r",
                                 status: "confirmed", date: "2026-10-11", amount_cents: 7, description: "Round Up")
    bank_leg("o", -20_000, "up-other")
    get "/finance/transfers", headers: headers
    flags = rows.to_h { [_1["transfer_group_id"], _1["round_up"]] }
    expect(flags).to eq("up-r" => true, "up-other" => false)
  end

  it "will not delete a transfer that came from the bank" do
    bank_leg("a", -100, "up-pair")
    bank_leg("b", 100, "up-pair")
    delete "/finance/transfers/up-pair", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(Finance::Transaction.where(transfer_group_id: "up-pair").count).to eq(2)
  end
end
