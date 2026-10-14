module Finance
  class Expense < ApplicationRecord
    FREQUENCIES = %w[daily weekly fortnightly monthly quarterly biannually annually].freeze

    belongs_to :category
    has_many :transactions, dependent: :restrict_with_error

    validates :name, presence: true
    validates :frequency, inclusion: { in: FREQUENCIES }
  end
end
