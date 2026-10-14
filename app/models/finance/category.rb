module Finance
  class Category < ApplicationRecord
    # The account spending in this category should normally come out of.
    belongs_to :desired_account, class_name: "Finance::Account", optional: true
    has_many :expenses, dependent: :restrict_with_error
    has_many :transactions, dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: true
  end
end
