class CategoriesOnTransactions < ActiveRecord::Migration[8.1]
  def up
    rename_table :finance_expense_categories, :finance_categories
    rename_column :finance_expenses, :expense_category_id, :category_id

    add_reference :finance_transactions, :category, foreign_key: { to_table: :finance_categories }
    execute <<~SQL
      UPDATE finance_transactions
      SET category_id = (SELECT category_id FROM finance_expenses WHERE finance_expenses.id = finance_transactions.expense_id)
      WHERE expense_id IS NOT NULL
    SQL

    # A reconciled expense needs a category (an expense link is now optional).
    remove_check_constraint :finance_transactions, name: "finance_transactions_reconciled_has_expense_check"
    add_check_constraint :finance_transactions,
                         "status IN ('pulled','ignored') OR category_id IS NOT NULL OR kind <> 'expense'",
                         name: "finance_transactions_reconciled_has_category_check"

    remove_check_constraint :finance_transactions, name: "finance_transactions_status_check"
    add_check_constraint :finance_transactions, "status IN ('pulled','matched','confirmed','ignored')",
                         name: "finance_transactions_status_check"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
