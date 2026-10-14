module Finance
  class Account < ApplicationRecord
    KINDS = %w[debit credit cash].freeze

    belongs_to :funded_by, class_name: "Finance::Account", optional: true
    has_many :transactions, dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: true
    validates :kind, inclusion: { in: KINDS }
    validates :opening_balance_cents, numericality: { only_integer: true }
    validate :not_funded_by_itself
    validate :funding_chain_has_no_cycle

    # Running balance: opening balance plus every transaction on or after the
    # opening date. Credit accounts go negative as money is owed.
    def balance_cents
      scope = opening_balance_on ? transactions.where(date: opening_balance_on..) : transactions
      opening_balance_cents + scope.sum(:amount_cents)
    end

    def as_json(options = nil) = super.merge("balance_cents" => balance_cents)

    private

    def funding_chain_has_no_cycle
      seen = [id]
      current = funded_by
      while current
        return errors.add(:funded_by_id, "would create a funding loop") if seen.include?(current.id)
        seen << current.id
        current = current.funded_by
      end
    end

    def not_funded_by_itself
      errors.add(:funded_by_id, "cannot be the account itself") if funded_by_id && funded_by_id == id
    end
  end
end
