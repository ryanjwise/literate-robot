require "rails_helper"

RSpec.describe "Finance merchant memory", type: :request do
  let(:headers) { auth_headers }
  let(:account) { make_account }
  let(:groceries) { Finance::Category.create!(name: "Groceries") }
  let(:utilities) { Finance::Category.create!(name: "Utilities") }
  let(:power) { Finance::Expense.create!(name: "Power", frequency: "monthly", category: utilities) }

  def pulled(external_id, description = "WOOLWORTHS 1234 NEWTOWN", **attrs)
    Finance::Transaction.create!({ source: "bank:up", external_id:, account:, date: "2026-10-02",
                                   amount_cents: -1_000, description: }.merge(attrs))
  end

  def reconcile(txn, **params)
    post "/finance/transactions/#{txn.id}/reconcile", headers: headers, params: params
  end

  it "learns the merchant on reconcile and pre-matches the other waiting records" do
    first = pulled("a")
    second = pulled("b", "Woolworths 5678 Newtown")
    other = pulled("c", "NETFLIX.COM")

    reconcile(first, category_id: groceries.id)
    expect(json["auto_matched"]).to eq(1)

    expect(second.reload).to have_attributes(status: "matched", category_id: groceries.id, auto_assigned: true)
    expect(other.reload.status).to eq("pulled")
    expect(Finance::Merchant.find_by(key: "WOOLWORTHS NEWTOWN")).to have_attributes(category_id: groceries.id)
  end

  it "pre-matches new records as they are created" do
    reconcile(pulled("a"), category_id: groceries.id)
    later = pulled("z", "WOOLWORTHS 9999 NEWTOWN")
    expect(later).to have_attributes(status: "matched", category_id: groceries.id, auto_assigned: true)
  end

  it "remembers a recurring expense too" do
    reconcile(pulled("a", "ORIGIN ENERGY 2891"), expense_id: power.id)
    later = pulled("b", "ORIGIN ENERGY 7777")
    expect(later).to have_attributes(expense_id: power.id, category_id: utilities.id, status: "matched")
  end

  it "does not touch manual records, income, or merchants with auto_assign off" do
    reconcile(pulled("a"), category_id: groceries.id)
    Finance::Merchant.find_by!(key: "WOOLWORTHS NEWTOWN").update!(auto_assign: false)

    manual = Finance::Transaction.create!(source: "MAN", account:, date: "2026-10-03", amount_cents: -5,
                                          description: "WOOLWORTHS NEWTOWN")
    off = pulled("n")
    expect(manual.status).to eq("pulled")
    expect(off.status).to eq("pulled")
  end

  it "a manual reconcile clears the auto flag and relearns" do
    reconcile(pulled("a"), category_id: groceries.id)
    auto = pulled("b")
    expect(auto.auto_assigned).to be(true)

    reconcile(auto, category_id: utilities.id)
    expect(auto.reload).to have_attributes(auto_assigned: false, category_id: utilities.id)
    expect(Finance::Merchant.find_by!(key: "WOOLWORTHS NEWTOWN").category_id).to eq(utilities.id)
  end

  it "confirms every untouched auto-matched record in one call" do
    reconcile(pulled("a"), category_id: groceries.id) # manual: matched, not auto
    auto1 = pulled("b")
    auto2 = pulled("c")
    manual_matched = Finance::Transaction.find_by!(external_id: "a")

    post "/finance/transactions/confirm_auto", headers: headers
    expect(json["confirmed"]).to eq(2)
    expect([auto1, auto2].map { _1.reload.status }).to eq(%w[confirmed confirmed])
    expect(manual_matched.reload.status).to eq("matched")
  end

  it "lists, edits and deletes merchant rules" do
    reconcile(pulled("a"), category_id: groceries.id)
    merchant = Finance::Merchant.first

    get "/finance/merchants", headers: headers
    expect(json.first["key"]).to eq("WOOLWORTHS NEWTOWN")

    patch "/finance/merchants/#{merchant.id}", headers: headers, params: { merchant: { auto_assign: false } }
    expect(json["auto_assign"]).to be(false)

    delete "/finance/merchants/#{merchant.id}", headers: headers
    expect(response).to have_http_status(:no_content)
  end

  it "rejects a rule with no category or expense" do
    post "/finance/merchants", headers: headers, params: { merchant: { key: "X" } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
