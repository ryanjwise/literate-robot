namespace :dev do
  SAMPLE_SOURCE = "bank:sample".freeze

  desc "Add sample pulled records to the dev DB for trying the reconcile UI (idempotent)"
  task sample_data: :environment do
    abort "dev:sample_data only runs in development" unless Rails.env.development?

    everyday = Finance::Account.find_or_create_by!(name: "Everyday") { _1.kind = "debit" }
    visa = Finance::Account.find_or_create_by!(name: "Visa") { |a| a.kind = "credit"; a.funded_by = everyday }

    utilities = Finance::Category.find_or_create_by!(name: "Utilities")
    groceries = Finance::Category.find_or_create_by!(name: "Groceries")
    entertainment = Finance::Category.find_or_create_by!(name: "Entertainment")
    Finance::Expense.find_or_create_by!(name: "Power") { |e| e.frequency = "monthly"; e.category = utilities }
    Finance::Expense.find_or_create_by!(name: "Netflix") { |e| e.frequency = "monthly"; e.category = entertainment }

    today = Date.current
    samples = [
      { id: "s1", account: everyday, days: 1, cents: -18_240, desc: "ORIGIN ENERGY 2891 MELBOURNE" },
      { id: "s2", account: visa, days: 2, cents: -8_715, desc: "WOOLWORTHS 1234 NEWTOWN" },
      { id: "s3", account: visa, days: 3, cents: -2_299, desc: "NETFLIX.COM" },
      { id: "s4", account: everyday, days: 4, cents: 245_000, desc: "SALARY ACME PTY LTD", kind: "income" },
      { id: "s5", account: visa, days: 5, cents: -3_450, desc: "AMAZON AU *<b>MKTPLACE</b>" }, # checks HTML is shown as text
      { id: "s6", account: visa, days: 6, cents: -6_120, desc: "WOOLWORTHS 1234 NEWTOWN", category: groceries, status: "matched" },
    ]
    samples.each do |s|
      Finance::Transaction.find_or_create_by!(source: SAMPLE_SOURCE, external_id: s[:id]) do |t|
        t.account = s[:account]
        t.date = today - s[:days]
        t.amount_cents = s[:cents]
        t.description = s[:desc]
        t.kind = s[:kind] || "expense"
        t.category = s[:category]
        t.status = s[:status] || "pulled"
      end
    end
    puts "Sample data ready: #{Finance::Transaction.where(source: SAMPLE_SOURCE).count} records in #{SAMPLE_SOURCE}"
  end

  desc "Remove the sample pulled records"
  task clear_sample_data: :environment do
    abort "dev:clear_sample_data only runs in development" unless Rails.env.development?
    puts "Removed #{Finance::Transaction.where(source: SAMPLE_SOURCE).destroy_all.size} sample records"
  end
end
