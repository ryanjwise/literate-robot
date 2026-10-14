module Finance
  class Expense < ApplicationRecord
    FREQUENCIES = %w[daily weekly fortnightly monthly quarterly biannually annually].freeze
    AMOUNT_MODES = %w[fixed variable].freeze
    # Whole-month steps for the month-based frequencies; day steps for the rest.
    MONTH_STEPS = { "monthly" => 1, "quarterly" => 3, "biannually" => 6, "annually" => 12 }.freeze
    DAY_STEPS = { "daily" => 1, "weekly" => 7, "fortnightly" => 14 }.freeze
    ESTIMATE_SAMPLES = 4

    belongs_to :category
    belongs_to :account, optional: true # where this bill is normally paid from
    has_many :transactions, dependent: :restrict_with_error

    validates :name, presence: true
    validates :frequency, inclusion: { in: FREQUENCIES }
    validates :amount_mode, inclusion: { in: AMOUNT_MODES }
    validates :expected_amount_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :expected_amount_cents, presence: true, if: -> { amount_mode == "fixed" }

    # Due dates in [from, to]. Each is computed from the anchor (not by repeated
    # addition) so a bill due on the 31st returns to the 31st after a short month.
    def due_dates(from, to)
      return [] unless anchor_date
      last = ends_on ? [to, ends_on].min : to
      dates = []
      (0..).each do |n|
        date = occurrence(n)
        break if date > last
        dates << date if date >= from
      end
      dates
    end

    # Cost in cents (positive) and how it was derived: fixed amount, the average of
    # the last few assigned transactions, or the expected amount as a fallback.
    def estimate
      return [expected_amount_cents, "fixed"] if amount_mode == "fixed"

      recent = transactions.where(status: %w[matched confirmed]).order(date: :desc, id: :desc).limit(ESTIMATE_SAMPLES).pluck(:amount_cents)
      return [(-recent.sum.fdiv(recent.size)).round, "average of #{recent.size}"] if recent.any?
      return [expected_amount_cents, "expected"] if expected_amount_cents
      [nil, "no history"]
    end

    private

    def occurrence(n)
      if MONTH_STEPS.key?(frequency)
        anchor_date >> (MONTH_STEPS[frequency] * n)
      else
        anchor_date + (DAY_STEPS.fetch(frequency) * n)
      end
    end
  end
end
