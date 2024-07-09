class AddExpenseCategoryToExpense < ActiveRecord::Migration[7.1]
  def change
    add_reference :expenses, :expense_category, null: false, foreign_key: true
  end
end
