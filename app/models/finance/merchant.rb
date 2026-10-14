module Finance
  # What to do with a merchant's future transactions, learned from reconciling.
  class Merchant < ApplicationRecord
    belongs_to :category, optional: true
    belongs_to :expense, optional: true

    validates :key, presence: true, uniqueness: true
    validate :has_a_default

    scope :auto, -> { where(auto_assign: true) }

    # Remember the choice made on a reconciled transaction.
    def self.learn(transaction)
      return unless transaction.kind == "expense" && transaction.merchant_key.present?
      merchant = find_or_initialize_by(key: transaction.merchant_key)
      merchant.update!(category_id: transaction.category_id, expense_id: transaction.expense_id)
      merchant
    end

    # Pre-assign every other waiting record from this merchant. Returns the count.
    def apply_to_pending
      return 0 unless auto_assign
      pending = Transaction.where(merchant_key: key, status: "pulled", kind: "expense").where.not(source: Transaction::MANUAL_SOURCE)
      pending.each { _1.update!(category_id:, expense_id:, status: "matched", auto_assigned: true) }.size
    end

    private

    def has_a_default
      errors.add(:base, "needs a category or an expense") if category_id.nil? && expense_id.nil?
    end
  end
end
