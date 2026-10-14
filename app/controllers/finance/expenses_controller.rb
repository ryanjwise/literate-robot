module Finance
  class ExpensesController < ResourceController
    SORTS = %w[id name created_at].freeze

    private

    def model = Expense
    def permitted = params.expect(expense: %i[name frequency category_id expected_amount_cents amount_mode anchor_date ends_on account_id])
  end
end
