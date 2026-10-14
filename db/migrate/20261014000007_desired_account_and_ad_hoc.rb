class DesiredAccountAndAdHoc < ActiveRecord::Migration[8.1]
  def up
    add_reference :finance_categories, :desired_account, foreign_key: { to_table: :finance_accounts }
    # Free text becomes a link to an account; text that names no account is dropped.
    execute <<~SQL
      UPDATE finance_categories
      SET desired_account_id = (SELECT id FROM finance_accounts WHERE lower(name) = lower(finance_categories.desired_source))
      WHERE desired_source IS NOT NULL
    SQL
    remove_column :finance_categories, :desired_source

    remove_check_constraint :finance_expenses, name: "finance_expenses_frequency_check"
    add_check_constraint :finance_expenses,
                         "frequency IN ('daily','weekly','fortnightly','monthly','quarterly','biannually','annually','ad_hoc')",
                         name: "finance_expenses_frequency_check"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
