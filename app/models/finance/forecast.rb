module Finance
  # Read-only projection of recurring bills over a date range. Nothing is stored.
  # Limitation: it does not check whether a bill has already been paid early.
  class Forecast
    MAX_DAYS = 366

    attr_reader :from, :to

    def initialize(from:, to:)
      @from = from
      @to = to
    end

    def valid?
      from <= to && (to - from).to_i <= MAX_DAYS
    end

    def occurrences
      @occurrences ||= Expense.includes(:category).order(:id).flat_map do |expense|
        cost, basis = expense.estimate
        expense.due_dates(from, to).map do |date|
          { date:, expense_id: expense.id, expense_name: expense.name, category_id: expense.category_id,
            account_id: expense.account_id, amount_cents: cost && -cost, basis: }
        end
      end.sort_by { [_1[:date], _1[:expense_id]] }
    end

    def unscheduled
      Expense.where(anchor_date: nil).pluck(:id, :name).map { |id, name| { expense_id: id, expense_name: name } }
    end

    # Sum of forecast outflows per account (negative cents); nil key = no account set.
    def totals_by_account
      occurrences.group_by { _1[:account_id] }.transform_values { |list| list.sum { _1[:amount_cents].to_i } }
    end

    def as_json(*)
      { from:, to:, occurrences:, total_cents: occurrences.sum { _1[:amount_cents].to_i },
        totals_by_account: totals_by_account.transform_keys(&:to_s),
        unscheduled:, unestimated: occurrences.count { _1[:amount_cents].nil? } }
    end
  end
end
