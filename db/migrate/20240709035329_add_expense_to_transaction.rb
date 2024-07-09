class AddExpenseToTransaction < ActiveRecord::Migration[7.1]
  def change
    add_reference :transactions, :expense, null: false, foreign_key: true
  end
end
