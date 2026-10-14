class BankSyncFields < ActiveRecord::Migration[8.1]
  def up
    # Link a local account to the bank's account so pulls can find it again.
    add_column :finance_accounts, :external_source, :string
    add_column :finance_accounts, :external_id, :string
    add_index :finance_accounts, %i[external_source external_id], unique: true
    add_check_constraint :finance_accounts, "(external_source IS NULL) = (external_id IS NULL)",
                         name: "finance_accounts_external_pair_check"

    # What UP reports that we keep (fixed for bank records, refreshed by pulls).
    add_column :finance_transactions, :bank_status, :string   # held / settled
    add_column :finance_transactions, :settled_at, :datetime
    add_column :finance_transactions, :bank_category, :string # the bank's own category id; a hint, not trusted
    add_column :finance_transactions, :raw_text, :string
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
