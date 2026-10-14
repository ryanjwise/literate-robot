require "rails_helper"

RSpec.describe "Finance cross-bank transfers", type: :request do
  let(:headers) { auth_headers }
  let(:up) { make_account(name: "UP Spending", opening_balance_cents: 100_000) }
  let(:other_bank) { make_account(name: "Manual Debit") }
  let(:groceries) { Finance::Category.create!(name: "Groceries") }

  # The UP half arrives as an ordinary pulled expense; the manual half is typed in by hand.
  let!(:up_leg) do
    Finance::Transaction.create!(source: "bank:up", external_id: "up-1", account: up, date: "2026-10-12",
                                 amount_cents: -30_000, description: "Transfer to other bank", raw_text: "TRANSFER")
  end
  let!(:manual_leg) do
    Finance::Transaction.create!(source: "MAN", account: other_bank, kind: "income", date: "2026-10-13",
                                 amount_cents: 30_000, status: "confirmed", description: "from UP")
  end

  def link(txn, **params) = post("/finance/transactions/#{txn.id}/link_transfer", headers: headers, params: params)

  describe "linking an existing counterpart" do
    it "turns both into one confirmed transfer and keeps the bank leg intact" do
      link(up_leg, counterpart_id: manual_leg.id)
      expect(response).to have_http_status(:ok)

      up_leg.reload
      manual_leg.reload
      expect([up_leg, manual_leg].map(&:kind)).to eq(%w[transfer transfer])
      expect(up_leg.transfer_group_id).to eq(manual_leg.transfer_group_id)
      expect([up_leg.status, manual_leg.status]).to eq(%w[confirmed confirmed])
      expect(up_leg).to have_attributes(source: "bank:up", amount_cents: -30_000, date: Date.new(2026, 10, 12), raw_text: "TRANSFER")
      expect(manual_leg).to have_attributes(source: "MAN", date: Date.new(2026, 10, 13))
    end

    it "clears any category or expense, leaves balances alone, and removes it from the queue" do
      up_leg.update!(category: groceries, status: "matched")
      before = up.reload.balance_cents
      link(up_leg, counterpart_id: manual_leg.id)
      expect(up_leg.reload).to have_attributes(category_id: nil, auto_assigned: false)
      expect(up.reload.balance_cents).to eq(before)

      get "/finance/transactions", headers: headers, params: { status: "pulled" }
      expect(json).to be_empty
    end

    it "shows up in the transfers list as a paired transfer that cannot be deleted" do
      link(up_leg, counterpart_id: manual_leg.id)
      get "/finance/transfers", headers: headers
      expect(json.first).to include("from_account_id" => up.id, "to_account_id" => other_bank.id, "paired" => true,
                                    "deletable" => false, "amount_cents" => 30_000)
      delete "/finance/transfers/#{up_leg.reload.transfer_group_id}", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "works from the manual side too" do
      link(manual_leg, counterpart_id: up_leg.id)
      expect(response).to have_http_status(:ok)
      expect(up_leg.reload.kind).to eq("transfer")
    end
  end

  describe "creating the missing half" do
    it "adds a manual leg on the other account with the opposite amount and the same date" do
      expect { link(up_leg, counterpart_account_id: other_bank.id) }.to change { Finance::Transaction.count }.by(1)
      created = Finance::Transaction.order(:id).last
      expect(created).to have_attributes(source: "MAN", account_id: other_bank.id, kind: "transfer", amount_cents: 30_000,
                                         date: Date.new(2026, 10, 12), status: "confirmed", description: "Transfer from UP Spending")
      expect(Finance::Transaction.where(transfer_group_id: created.transfer_group_id).sum(:amount_cents)).to eq(0)
    end
  end

  describe "validation" do
    it "needs exactly one counterpart" do
      link(up_leg)
      expect(response).to have_http_status(:unprocessable_content)
      link(up_leg, counterpart_id: manual_leg.id, counterpart_account_id: other_bank.id)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects the same account, a mismatched amount, and an existing transfer" do
      same = Finance::Transaction.create!(source: "MAN", account: up, kind: "income", date: "2026-10-13", amount_cents: 30_000,
                                          status: "confirmed")
      link(up_leg, counterpart_id: same.id)
      expect(response).to have_http_status(:unprocessable_content)

      manual_leg.update!(amount_cents: 29_900)
      link(up_leg, counterpart_id: manual_leg.id)
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to match(/equal and opposite/)

      link(up_leg, counterpart_account_id: up.id)
      expect(response).to have_http_status(:unprocessable_content)

      link(up_leg, counterpart_account_id: other_bank.id)
      link(up_leg, counterpart_account_id: other_bank.id)
      expect(json["error"]).to match(/already part of a transfer/)
    end

    it "404s an unknown counterpart" do
      link(up_leg, counterpart_id: 99_999)
      expect(response).to have_http_status(:not_found)
    end

    it "changes nothing when it fails" do
      manual_leg.update!(amount_cents: 1)
      link(up_leg, counterpart_id: manual_leg.id)
      expect(up_leg.reload.kind).to eq("expense")
    end
  end

  describe "candidates" do
    it "lists opposite-amount transactions on other accounts, nearest date first" do
      far = Finance::Transaction.create!(source: "MAN", account: other_bank, kind: "income", date: "2026-09-01",
                                         amount_cents: 30_000, status: "confirmed")
      get "/finance/transactions/#{up_leg.id}/transfer_candidates", headers: headers
      expect(json.map { _1["id"] }).to eq([manual_leg.id, far.id])
    end
  end

  describe "unlinking" do
    it "returns both legs to income/expense in the queue" do
      link(up_leg, counterpart_id: manual_leg.id)
      group = up_leg.reload.transfer_group_id
      post "/finance/transfers/#{group}/unlink", headers: headers
      expect(response).to have_http_status(:ok)
      expect(up_leg.reload).to have_attributes(kind: "expense", transfer_group_id: nil, status: "pulled", amount_cents: -30_000)
      expect(manual_leg.reload).to have_attributes(kind: "income", transfer_group_id: nil, status: "pulled")
    end

    it "refuses a fully manual transfer and an unknown group" do
      Finance::Transfer.new(from_account_id: up.id, to_account_id: other_bank.id, amount_cents: 5, date: "2026-10-01").tap(&:save)
      group = Finance::Transaction.where(kind: "transfer").first.transfer_group_id
      post "/finance/transfers/#{group}/unlink", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      post "/finance/transfers/nope/unlink", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  it "survives a later UP pull: the link is not undone" do
    travel_to Date.new(2026, 10, 14)
    link(up_leg, counterpart_id: manual_leg.id)
    account = up.tap { _1.update!(external_source: "bank:up", external_id: "acc-spend") }
    client = UpFixtures::FakeUpClient.new(
      accounts: [up_account("acc-spend", "UP Spending", account.balance_cents)],
      transactions: [up_txn("up-1", account: "acc-spend", cents: -30_000, desc: "Transfer to other bank", raw: "TRANSFER",
                            at: "2026-10-12T09:30:00+11:00")]
    )
    allow(Finance::Up::Client).to receive(:new).and_return(client)
    post "/finance/pull/up", headers: headers.merge("X-Bank-Token" => "t")
    expect(response).to have_http_status(:ok)
    expect(up_leg.reload).to have_attributes(kind: "transfer", status: "confirmed")
  end

  it "requires auth" do
    post "/finance/transactions/#{up_leg.id}/link_transfer"
    expect(response).to have_http_status(:unauthorized)
  end
end
