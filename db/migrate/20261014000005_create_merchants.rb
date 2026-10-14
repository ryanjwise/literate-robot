class CreateMerchants < ActiveRecord::Migration[8.1]
  def up
    create_table :finance_merchants do |t|
      t.string :key, null: false
      t.references :category, foreign_key: { to_table: :finance_categories }
      t.references :expense, foreign_key: { to_table: :finance_expenses }
      t.boolean :auto_assign, null: false, default: true
      t.timestamps
    end
    add_index :finance_merchants, :key, unique: true

    add_column :finance_transactions, :merchant_key, :string
    add_column :finance_transactions, :auto_assigned, :boolean, null: false, default: false
    add_index :finance_transactions, :merchant_key
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
