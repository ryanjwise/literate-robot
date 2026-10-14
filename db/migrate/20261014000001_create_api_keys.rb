class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.string :namespace, null: false
      t.string :name, null: false
      t.string :digest, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_keys, :digest, unique: true
    add_index :api_keys, :namespace
  end
end
