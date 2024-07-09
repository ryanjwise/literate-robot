class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|
      t.date :date
      t.integer :dollars
      t.integer :cents
      t.string :source
      t.text :notes

      t.timestamps
    end
  end
end
