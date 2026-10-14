module Finance
  class ExpensesController < ResourceController
    private

    def model = Expense
    def permitted = params.expect(expense: %i[name frequency category_id])
  end
end
