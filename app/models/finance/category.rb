module Finance
  class Category < ApplicationRecord
    has_many :expenses, dependent: :restrict_with_error
    has_many :transactions, dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: true
  end
end
