class Expense < ApplicationRecord
  belongs_to :expense_category
  has_many :transactions

  enum frequency: {
         daily: "daily",
         weekly: "weekly",
         fourtnightly: "fourtnightly",
         monthly: "monthly",
         quarterly: "quarterly",
         biannually: "biannually",
         annually: "annually",
       }
end
