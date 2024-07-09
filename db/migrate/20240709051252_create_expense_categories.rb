class CreateExpenseCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :expense_categories do |t|
      t.string :name
      t.string :desired_source

      t.timestamps
    end
  end
end
