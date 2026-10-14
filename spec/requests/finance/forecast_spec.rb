require "rails_helper"

RSpec.describe "Finance forecast and transfers needed", type: :request do
  let(:headers) { auth_headers }
  before { travel_to Date.new(2026, 10, 14) }
  let(:category) { Finance::Category.create!(name: "Bills") }
  let(:savings) { make_account(name: "Savings", opening_balance_cents: 500_000) }
  let(:debit) { make_account(name: "Debit", opening_balance_cents: 20_000, funded_by: savings) }
  let(:card) { make_account(name: "Card", kind: "credit", funded_by: debit) }

  def bill(name, cents, anchor, account:, frequency: "monthly")
    Finance::Expense.create!(name:, frequency:, category:, account:, amount_mode: "fixed",
                             expected_amount_cents: cents, anchor_date: anchor)
  end

  describe "GET /finance/forecast" do
    it "lists dated outflows, totals per account and unscheduled expenses" do
      bill("Power", 15_000, "2026-10-20", account: debit)
      bill("Netflix", 2_299, "2026-10-25", account: card)
      Finance::Expense.create!(name: "Rego", frequency: "annually", category:)
      Finance::Expense.create!(name: "Dentist", frequency: "ad_hoc", category:) # ad hoc: not "unscheduled"

      get "/finance/forecast", headers: headers, params: { from: "2026-10-14", to: "2026-11-30" }
      expect(json["occurrences"].map { [_1["date"], _1["expense_name"], _1["amount_cents"]] }).to eq(
        [["2026-10-20", "Power", -15_000], ["2026-10-25", "Netflix", -2_299],
         ["2026-11-20", "Power", -15_000], ["2026-11-25", "Netflix", -2_299]]
      )
      expect(json["total_cents"]).to eq(-34_598)
      expect(json["totals_by_account"]).to eq(debit.id.to_s => -30_000, card.id.to_s => -4_598)
      expect(json["unscheduled"].map { _1["expense_name"] }).to eq(["Rego"])
    end

    it "validates the range and requires auth" do
      get "/finance/forecast", headers: headers, params: { from: "2026-10-14", to: "2028-10-14" }
      expect(response).to have_http_status(:unprocessable_content)
      get "/finance/forecast", headers: headers, params: { from: "nope" }
      expect(response).to have_http_status(:bad_request)
      get "/finance/forecast"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /finance/transfers/needed" do
    before do
      Finance::Transaction.create!(source: "bank:up", external_id: "spend", account: card, date: "2026-10-01", amount_cents: -30_000)
      bill("Netflix", 2_000, "2026-10-20", account: card)
      bill("Power", 15_000, "2026-10-22", account: debit)
    end

    it "covers what the card owes now when forecast is off" do
      get "/finance/transfers/needed", headers: headers, params: { to: "2026-10-31", include_forecast: "false" }
      expect(json["transfers"]).to include(
        { "from_account_id" => debit.id, "to_account_id" => card.id, "amount_cents" => 30_000 }
      )
    end

    it "chains savings -> debit -> card and includes upcoming bills" do
      get "/finance/transfers/needed", headers: headers, params: { to: "2026-10-31" }
      by_pair = json["transfers"].to_h { [[_1["from_account_id"], _1["to_account_id"]], _1["amount_cents"]] }
      # card: owes 300.00 + 20.00 bill = 320.00 from debit
      expect(by_pair[[debit.id, card.id]]).to eq(32_000)
      # debit: 200.00 - 150.00 power - 320.00 sent to card = -270.00, so savings sends 270.00
      expect(by_pair[[savings.id, debit.id]]).to eq(27_000)
      savings_row = json["accounts"].find { _1["account_id"] == savings.id }
      expect(savings_row).to include("outgoing_cents" => 27_000, "shortfall_cents" => 0)
    end

    it "reports a shortfall at the top of the chain" do
      savings.update!(opening_balance_cents: 10_000)
      get "/finance/transfers/needed", headers: headers, params: { to: "2026-10-31" }
      expect(json["accounts"].find { _1["account_id"] == savings.id }["shortfall_cents"]).to eq(17_000)
    end

    it "sends nothing when everything is covered" do
      Finance::Transaction.create!(source: "MAN", account: card, kind: "income", date: "2026-10-02", amount_cents: 30_000,
                                   status: "confirmed")
      get "/finance/transfers/needed", headers: headers, params: { to: "2026-10-31", include_forecast: "false" }
      expect(json["transfers"].none? { _1["to_account_id"] == card.id }).to be(true)
    end
  end

  it "rejects a funding loop" do
    a = make_account(name: "A")
    b = make_account(name: "B", funded_by: a)
    patch "/finance/accounts/#{a.id}", headers: headers, params: { account: { funded_by_id: b.id } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
