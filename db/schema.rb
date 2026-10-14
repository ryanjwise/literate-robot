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

ActiveRecord::Schema[8.1].define(version: 2026_10_14_000007) do
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

  create_table "finance_accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", null: false
    t.integer "funded_by_id"
    t.integer "opening_balance_cents", default: 0, null: false
    t.date "opening_balance_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["funded_by_id"], name: "index_finance_accounts_on_funded_by_id"
    t.index ["name"], name: "index_finance_accounts_on_name", unique: true
    t.check_constraint "kind IN ('debit','credit','cash')", name: "finance_accounts_kind_check"
  end

  create_table "finance_categories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "desired_account_id"
    t.index ["desired_account_id"], name: "index_finance_categories_on_desired_account_id"
    t.index ["name"], name: "index_finance_categories_on_name", unique: true
  end

  create_table "finance_expenses", force: :cascade do |t|
    t.string "name", null: false
    t.string "frequency", null: false
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "expected_amount_cents"
    t.string "amount_mode", default: "variable", null: false
    t.date "anchor_date"
    t.date "ends_on"
    t.integer "account_id"
    t.index ["account_id"], name: "index_finance_expenses_on_account_id"
    t.index ["category_id"], name: "index_finance_expenses_on_category_id"
    t.check_constraint "amount_mode <> 'fixed' OR expected_amount_cents IS NOT NULL", name: "finance_expenses_fixed_has_amount_check"
    t.check_constraint "amount_mode IN ('fixed','variable')", name: "finance_expenses_amount_mode_check"
    t.check_constraint "expected_amount_cents IS NULL OR expected_amount_cents > 0", name: "finance_expenses_expected_positive_check"
    t.check_constraint "frequency IN ('daily','weekly','fortnightly','monthly','quarterly','biannually','annually','ad_hoc')", name: "finance_expenses_frequency_check"
  end

  create_table "finance_merchants", force: :cascade do |t|
    t.string "key", null: false
    t.integer "category_id"
    t.integer "expense_id"
    t.boolean "auto_assign", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_finance_merchants_on_category_id"
    t.index ["expense_id"], name: "index_finance_merchants_on_expense_id"
    t.index ["key"], name: "index_finance_merchants_on_key", unique: true
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
    t.integer "account_id", null: false
    t.string "kind", default: "expense", null: false
    t.string "transfer_group_id"
    t.integer "category_id"
    t.string "merchant_key"
    t.boolean "auto_assigned", default: false, null: false
    t.index ["account_id"], name: "index_finance_transactions_on_account_id"
    t.index ["category_id"], name: "index_finance_transactions_on_category_id"
    t.index ["expense_id"], name: "index_finance_transactions_on_expense_id"
    t.index ["merchant_key"], name: "index_finance_transactions_on_merchant_key"
    t.index ["source", "external_id"], name: "index_finance_transactions_on_source_and_external_id", unique: true
    t.index ["status"], name: "index_finance_transactions_on_status"
    t.check_constraint "(kind = 'transfer') = (transfer_group_id IS NOT NULL)", name: "finance_transactions_transfer_group_check"
    t.check_constraint "amount_cents <> 0", name: "finance_transactions_amount_nonzero_check"
    t.check_constraint "kind IN ('expense','income','transfer')", name: "finance_transactions_kind_check"
    t.check_constraint "status IN ('pulled','ignored') OR category_id IS NOT NULL OR kind <> 'expense'", name: "finance_transactions_reconciled_has_category_check"
    t.check_constraint "status IN ('pulled','matched','confirmed','ignored')", name: "finance_transactions_status_check"
  end

  add_foreign_key "finance_accounts", "finance_accounts", column: "funded_by_id"
  add_foreign_key "finance_categories", "finance_accounts", column: "desired_account_id"
  add_foreign_key "finance_expenses", "finance_accounts", column: "account_id"
  add_foreign_key "finance_expenses", "finance_categories", column: "category_id"
  add_foreign_key "finance_merchants", "finance_categories", column: "category_id"
  add_foreign_key "finance_merchants", "finance_expenses", column: "expense_id"
  add_foreign_key "finance_transactions", "finance_accounts", column: "account_id"
  add_foreign_key "finance_transactions", "finance_categories", column: "category_id"
  add_foreign_key "finance_transactions", "finance_expenses", column: "expense_id"
end
