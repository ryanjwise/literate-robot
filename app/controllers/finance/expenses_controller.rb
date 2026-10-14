module Finance
  class ExpensesController < ResourceController
    private

    def model = Expense
    def permitted = params.expect(expense: %i[name frequency expense_category_id])
  end
end
