# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_14_000002) do
  create_table "api_keys", force: :cascade do |t|
    t.string "namespace", null: false
    t.string "name", null: false
    t.string "digest", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["digest"], name: "index_api_keys_on_digest", unique: true
    t.index ["namespace"], name: "index_api_keys_on_namespace"
  end

  create_table "finance_expense_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "desired_source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_finance_expense_categories_on_name", unique: true
  end

  create_table "finance_expenses", force: :cascade do |t|
    t.string "name", null: false
    t.string "frequency", null: false
    t.integer "expense_category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_category_id"], name: "index_finance_expenses_on_expense_category_id"
    t.check_constraint "frequency IN ('daily','weekly','fortnightly','monthly','quarterly','biannually','annually')", name: "finance_expenses_frequency_check"
  end

  create_table "finance_transactions", force: :cascade do |t|
    t.string "source", null: false
    t.string "external_id", null: false
    t.date "date", null: false
    t.integer "amount_cents", null: false
    t.string "description"
    t.text "notes"
    t.string "status", default: "pulled", null: false
    t.integer "expense_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id"], name: "index_finance_transactions_on_expense_id"
    t.index ["source", "external_id"], name: "index_finance_transactions_on_source_and_external_id", unique: true
    t.index ["status"], name: "index_finance_transactions_on_status"
    t.check_constraint "status = 'pulled' OR expense_id IS NOT NULL", name: "finance_transactions_reconciled_has_expense_check"
    t.check_constraint "status IN ('pulled','matched','confirmed')", name: "finance_transactions_status_check"
  end

  add_foreign_key "finance_expenses", "finance_expense_categories", column: "expense_category_id"
  add_foreign_key "finance_transactions", "finance_expenses", column: "expense_id"
end
