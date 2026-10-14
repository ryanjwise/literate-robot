class ScheduleExpenses < ActiveRecord::Migration[8.1]
  def up
    # expected_amount_cents is a positive cost; forecasts report it as negative (money out).
    add_column :finance_expenses, :expected_amount_cents, :integer
    add_column :finance_expenses, :amount_mode, :string, null: false, default: "variable"
    add_column :finance_expenses, :anchor_date, :date
    add_column :finance_expenses, :ends_on, :date
    add_reference :finance_expenses, :account, foreign_key: { to_table: :finance_accounts }

    add_check_constraint :finance_expenses, "amount_mode IN ('fixed','variable')",
                         name: "finance_expenses_amount_mode_check"
    add_check_constraint :finance_expenses, "expected_amount_cents IS NULL OR expected_amount_cents > 0",
                         name: "finance_expenses_expected_positive_check"
    add_check_constraint :finance_expenses, "amount_mode <> 'fixed' OR expected_amount_cents IS NOT NULL",
                         name: "finance_expenses_fixed_has_amount_check"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
