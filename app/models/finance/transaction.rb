module Finance
  class Transaction < ApplicationRecord
    MANUAL_SOURCE = "MAN".freeze
    STATUSES = %w[pulled matched confirmed ignored].freeze
    KINDS = %w[expense income transfer].freeze

    # Identity never changes. Records that came from a bank are otherwise
    # fixed: only these review fields may be edited. Manual records are
    # editable apart from their identity.
    IDENTITY_FIELDS = %w[source external_id].freeze
    BANK_EDITABLE_FIELDS = %w[notes category_id expense_id status auto_assigned].freeze

    # amount_cents is signed from the account's point of view:
    # negative = money out, positive = money in.
    belongs_to :account
    belongs_to :category, optional: true
    belongs_to :expense, optional: true

    before_validation :assign_manual_external_id, on: :create
    before_validation :assign_merchant_key
    before_validation :apply_merchant_default, on: :create
    before_validation :default_category_from_expense

    validates :source, :external_id, :date, presence: true
    validates :amount_cents, numericality: { only_integer: true, other_than: 0 }
    validates :status, inclusion: { in: STATUSES }
    validates :kind, inclusion: { in: KINDS }
    validates :external_id, uniqueness: { scope: :source }
    validates :category, presence: true, if: -> { kind == "expense" && !%w[pulled ignored].include?(status) }
    validates :amount_cents, numericality: { greater_than: 0 }, if: -> { kind == "income" }
    validate :transfer_group_matches_kind
    validate :protected_fields_unchanged, on: :update

    def transfer? = kind == "transfer"
    def manual? = source == MANUAL_SOURCE

    private

    # Manual entries get a generated ID; pulled records carry the bank's own.
    def assign_manual_external_id
      self.external_id ||= SecureRandom.uuid if source == MANUAL_SOURCE
    end

    def assign_merchant_key
      self.merchant_key = MerchantKey.normalize(description) if merchant_key.blank? || description_changed?
    end

    # A new bank record from a merchant we have seen arrives pre-matched.
    def apply_merchant_default
      return unless status == "pulled" && kind == "expense" && !manual? && category_id.nil? && expense_id.nil?
      merchant = merchant_key && Merchant.auto.find_by(key: merchant_key)
      return unless merchant
      assign_attributes(category_id: merchant.category_id, expense_id: merchant.expense_id, status: "matched", auto_assigned: true)
    end

    # Picking a recurring expense implies its category unless one is already set.
    def default_category_from_expense
      self.category ||= expense&.category
    end

    def transfer_group_matches_kind
      return if transfer? == transfer_group_id.present?
      errors.add(:transfer_group_id, transfer? ? "is required for transfers" : "is only for transfers")
    end

    def protected_fields_unchanged
      editable = source_was == MANUAL_SOURCE ? attribute_names - IDENTITY_FIELDS : BANK_EDITABLE_FIELDS
      (changed - editable).each do |attr|
        errors.add(attr, source_was == MANUAL_SOURCE ? "cannot be changed" : "cannot be changed on a bank record")
      end
    end
  end
end
