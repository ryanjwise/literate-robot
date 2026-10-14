class CreateFinanceTables < ActiveRecord::Migration[8.1]
  def change
    create_table :finance_expense_categories do |t|
      t.string :name, null: false
      t.string :desired_source
      t.timestamps
    end
    add_index :finance_expense_categories, :name, unique: true

    create_table :finance_expenses do |t|
      t.string :name, null: false
      t.string :frequency, null: false
      t.references :expense_category, null: false,
                   foreign_key: { to_table: :finance_expense_categories }
      t.timestamps
      t.check_constraint(
        "frequency IN ('daily','weekly','fortnightly','monthly','quarterly','biannually','annually')",
        name: "finance_expenses_frequency_check"
      )
    end

    # expense_id is nullable: pulled records are unreconciled until matched.
    create_table :finance_transactions do |t|
      t.string :source, null: false
      t.string :external_id, null: false
      t.date :date, null: false
      t.integer :amount_cents, null: false
      t.string :description
      t.text :notes
      t.string :status, null: false, default: "pulled"
      t.references :expense, foreign_key: { to_table: :finance_expenses }
      t.timestamps
      t.check_constraint "status IN ('pulled','matched','confirmed')",
                         name: "finance_transactions_status_check"
      t.check_constraint "status = 'pulled' OR expense_id IS NOT NULL",
                         name: "finance_transactions_reconciled_has_expense_check"
    end
    add_index :finance_transactions, %i[source external_id], unique: true
    add_index :finance_transactions, :status
  end
end
