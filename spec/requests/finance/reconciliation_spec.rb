require "rails_helper"

RSpec.describe "Finance reconciliation and record rules", type: :request do
  let(:headers) { auth_headers }
  let(:account) { make_account }
  let(:groceries) { Finance::Category.create!(name: "Groceries") }
  let(:utilities) { Finance::Category.create!(name: "Utilities") }
  let(:power) { Finance::Expense.create!(name: "Power", frequency: "monthly", category: utilities) }

  def pulled(external_id: "p1", **attrs)
    Finance::Transaction.create!({ source: "bank:up", external_id:, account:, date: "2026-10-02",
                                   amount_cents: -8_715, description: "WOOLWORTHS 1234" }.merge(attrs))
  end

  describe "reconcile" do
    it "matches by category alone, with no expense" do
      t = pulled
      post "/finance/transactions/#{t.id}/reconcile", headers: headers, params: { category_id: groceries.id }
      expect(json).to include("status" => "matched", "category_id" => groceries.id, "expense_id" => nil)
    end

    it "derives the category from a recurring expense" do
      t = pulled
      post "/finance/transactions/#{t.id}/reconcile", headers: headers, params: { expense_id: power.id }
      expect(json).to include("status" => "matched", "expense_id" => power.id, "category_id" => utilities.id)
    end

    it "keeps an explicitly chosen category over the expense's" do
      t = pulled
      post "/finance/transactions/#{t.id}/reconcile", headers: headers, params: { expense_id: power.id, category_id: groceries.id }
      expect(json["category_id"]).to eq(groceries.id)
    end

    it "requires a category or an expense" do
      t = pulled
      post "/finance/transactions/#{t.id}/reconcile", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "will not reconcile a confirmed record" do
      t = pulled(status: "confirmed", category: groceries)
      post "/finance/transactions/#{t.id}/reconcile", headers: headers, params: { category_id: utilities.id }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "cannot confirm an expense that has no category" do
      t = pulled
      post "/finance/transactions/#{t.id}/confirm", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("category")
    end

    it "ignores a record without needing a category" do
      t = pulled
      post "/finance/transactions/#{t.id}/ignore", headers: headers
      expect(json["status"]).to eq("ignored")
    end

    it "enforces the category requirement in the database too" do
      t = pulled
      t.assign_attributes(status: "confirmed")
      expect { t.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "does not require a category for income" do
      t = pulled(amount_cents: 245_000, kind: "income")
      post "/finance/transactions/#{t.id}/confirm", headers: headers
      expect(json["status"]).to eq("confirmed")
    end
  end

  describe "bank-origin records" do
    it "allows only the review fields to change" do
      t = pulled
      patch "/finance/transactions/#{t.id}", headers: headers,
            params: { transaction: { notes: "weekly shop", category_id: groceries.id, status: "matched" } }
      expect(response).to have_http_status(:ok)
      expect(t.reload).to have_attributes(notes: "weekly shop", category_id: groceries.id)
    end

    %w[amount_cents date description account_id kind].each do |field|
      it "rejects changing #{field}" do
        t = pulled
        other = make_account(name: "Other")
        value = { "amount_cents" => -1, "date" => "2020-01-01", "description" => "changed",
                  "account_id" => other.id, "kind" => "income" }[field]
        patch "/finance/transactions/#{t.id}", headers: headers, params: { transaction: { field => value } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json["errors"]).to have_key(field)
      end
    end

    it "cannot be deleted" do
      t = pulled
      delete "/finance/transactions/#{t.id}", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(Finance::Transaction.exists?(t.id)).to be(true)
    end
  end

  describe "manual records" do
    let(:manual) do
      Finance::Transaction.create!(source: "MAN", account:, date: "2026-10-01", amount_cents: -1_000,
                                   category: groceries, status: "confirmed")
    end

    it "allows editing any field except identity" do
      patch "/finance/transactions/#{manual.id}", headers: headers,
            params: { transaction: { amount_cents: -2_500, description: "fixed", date: "2026-10-03" } }
      expect(response).to have_http_status(:ok)
      expect(manual.reload).to have_attributes(amount_cents: -2_500, description: "fixed")
    end

    it "never allows changing source or external_id" do
      patch "/finance/transactions/#{manual.id}", headers: headers, params: { transaction: { external_id: "new" } }
      expect(response).to have_http_status(:unprocessable_content)
      patch "/finance/transactions/#{manual.id}", headers: headers, params: { transaction: { source: "bank:up" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "can be deleted" do
      delete "/finance/transactions/#{manual.id}", headers: headers
      expect(response).to have_http_status(:no_content)
    end
  end

  it "shows every stored field on a single transaction" do
    t = pulled
    get "/finance/transactions/#{t.id}", headers: headers
    expect(json.keys).to include("id", "source", "external_id", "account_id", "kind", "date", "amount_cents",
                                 "description", "notes", "status", "category_id", "expense_id", "created_at", "updated_at")
  end
end
