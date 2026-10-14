require "rails_helper"

RSpec.describe Finance::Expense do
  let(:category) { Finance::Category.create!(name: "Bills") }
  let(:account) { Finance::Account.create!(name: "Everyday", kind: "debit") }

  def expense(frequency: "monthly", anchor: "2026-01-31", **attrs)
    described_class.create!({ name: "E#{SecureRandom.hex(3)}", frequency:, category:, anchor_date: anchor }.merge(attrs))
  end

  def d(s) = Date.iso8601(s)

  describe "#due_dates" do
    it "returns the 31st again after a short month" do
      dates = expense.due_dates(d("2026-01-01"), d("2026-05-31"))
      expect(dates).to eq(%w[2026-01-31 2026-02-28 2026-03-31 2026-04-30 2026-05-31].map { d(_1) })
    end

    it "steps weekly, fortnightly, quarterly and annually" do
      expect(expense(frequency: "weekly", anchor: "2026-10-01").due_dates(d("2026-10-01"), d("2026-10-22")).size).to eq(4)
      expect(expense(frequency: "fortnightly", anchor: "2026-10-01").due_dates(d("2026-10-02"), d("2026-11-30")).map(&:to_s))
        .to eq(%w[2026-10-15 2026-10-29 2026-11-12 2026-11-26])
      expect(expense(frequency: "quarterly", anchor: "2026-01-15").due_dates(d("2026-02-01"), d("2026-12-31")).map(&:to_s))
        .to eq(%w[2026-04-15 2026-07-15 2026-10-15])
      expect(expense(frequency: "annually", anchor: "2024-03-01").due_dates(d("2026-01-01"), d("2027-12-31")).map(&:to_s))
        .to eq(%w[2026-03-01 2027-03-01])
    end

    it "treats ad hoc as a single planned bill, or nothing without a date" do
      one_off = expense(frequency: "ad_hoc", anchor: "2026-11-10")
      expect(one_off.due_dates(d("2026-11-01"), d("2026-12-31"))).to eq([d("2026-11-10")])
      expect(one_off.due_dates(d("2026-11-11"), d("2026-12-31"))).to eq([])
      expect(expense(frequency: "ad_hoc", anchor: nil).due_dates(d("2026-01-01"), d("2026-12-31"))).to eq([])
    end

    it "respects the range start, the end date, and a missing anchor" do
      e = expense(anchor: "2026-01-10", ends_on: "2026-03-10")
      expect(e.due_dates(d("2026-02-01"), d("2026-12-31")).map(&:to_s)).to eq(%w[2026-02-10 2026-03-10])
      expect(expense(anchor: nil).due_dates(d("2026-01-01"), d("2026-12-31"))).to eq([])
    end
  end

  describe "#estimate" do
    def paid(exp, cents, day)
      Finance::Transaction.create!(source: "bank:up", external_id: SecureRandom.uuid, account:, date: day,
                                   amount_cents: -cents, expense: exp, category:, status: "confirmed")
    end

    it "uses the fixed amount" do
      expect(expense(amount_mode: "fixed", expected_amount_cents: 2_299).estimate).to eq([2_299, "fixed"])
    end

    it "averages the last four assigned transactions, using fewer if fewer exist" do
      e = expense
      expect(e.estimate).to eq([nil, "no history"])
      paid(e, 10_000, "2026-06-01")
      paid(e, 20_000, "2026-07-01")
      expect(e.estimate).to eq([15_000, "average of 2"])
      paid(e, 30_000, "2026-08-01")
      paid(e, 40_000, "2026-09-01")
      paid(e, 90_000, "2026-10-01")
      expect(e.estimate).to eq([45_000, "average of 4"]) # 20k, 30k, 40k, 90k
    end

    it "ignores pulled and ignored records and falls back to the expected amount" do
      e = expense(expected_amount_cents: 5_000)
      Finance::Transaction.create!(source: "bank:up", external_id: "p", account:, date: "2026-10-01", amount_cents: -99_999,
                                   expense: e, category:, status: "ignored")
      expect(e.estimate).to eq([5_000, "expected"])
    end

    it "requires an amount for fixed expenses and enforces it in the database" do
      e = described_class.new(name: "F", frequency: "monthly", category:, amount_mode: "fixed")
      expect(e).not_to be_valid
      expect { e.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
