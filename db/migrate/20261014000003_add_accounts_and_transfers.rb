class AddAccountsAndTransfers < ActiveRecord::Migration[8.1]
  def up
    create_table :finance_accounts do |t|
      t.string :name, null: false
      t.string :kind, null: false
      t.references :funded_by, foreign_key: { to_table: :finance_accounts }
      t.integer :opening_balance_cents, null: false, default: 0
      t.date :opening_balance_on
      t.timestamps
      t.check_constraint "kind IN ('debit','credit','cash')", name: "finance_accounts_kind_check"
    end
    add_index :finance_accounts, :name, unique: true

    add_reference :finance_transactions, :account, foreign_key: { to_table: :finance_accounts }
    add_column :finance_transactions, :kind, :string, null: false, default: "expense"
    add_column :finance_transactions, :transfer_group_id, :string

    # Existing rows predate accounts and stored outflows as positive amounts.
    if select_value("SELECT COUNT(*) FROM finance_transactions").to_i.positive?
      execute "INSERT INTO finance_accounts (name, kind, opening_balance_cents, created_at, updated_at) " \
              "VALUES ('Unassigned', 'debit', 0, datetime('now'), datetime('now'))"
      execute "UPDATE finance_transactions SET amount_cents = -amount_cents, " \
              "account_id = (SELECT id FROM finance_accounts WHERE name = 'Unassigned')"
    end
    change_column_null :finance_transactions, :account_id, false

    add_check_constraint :finance_transactions, "kind IN ('expense','income','transfer')",
                         name: "finance_transactions_kind_check"
    add_check_constraint :finance_transactions, "amount_cents <> 0",
                         name: "finance_transactions_amount_nonzero_check"
    add_check_constraint :finance_transactions, "(kind = 'transfer') = (transfer_group_id IS NOT NULL)",
                         name: "finance_transactions_transfer_group_check"

    # Only expenses need an expense once reconciled (income/transfers do not).
    remove_check_constraint :finance_transactions, name: "finance_transactions_reconciled_has_expense_check"
    add_check_constraint :finance_transactions,
                         "status = 'pulled' OR expense_id IS NOT NULL OR kind <> 'expense'",
                         name: "finance_transactions_reconciled_has_expense_check"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
