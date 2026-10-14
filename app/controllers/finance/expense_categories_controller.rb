module Finance
  class ExpenseCategoriesController < ResourceController
    private

    def model = ExpenseCategory
    def permitted = params.expect(expense_category: %i[name desired_source])
  end
end
