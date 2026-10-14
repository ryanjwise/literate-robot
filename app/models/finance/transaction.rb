module Finance
  class Transaction < ApplicationRecord
    MANUAL_SOURCE = "MAN".freeze
    STATUSES = %w[pulled matched confirmed].freeze
    KINDS = %w[expense income transfer].freeze

    # amount_cents is signed from the account's point of view:
    # negative = money out, positive = money in.
    belongs_to :account
    belongs_to :expense, optional: true

    before_validation :assign_manual_external_id, on: :create

    validates :source, :external_id, :date, presence: true
    validates :amount_cents, numericality: { only_integer: true, other_than: 0 }
    validates :status, inclusion: { in: STATUSES }
    validates :kind, inclusion: { in: KINDS }
    validates :external_id, uniqueness: { scope: :source }
    validates :expense, presence: true, if: -> { kind == "expense" && status != "pulled" }
    validates :amount_cents, numericality: { greater_than: 0 }, if: -> { kind == "income" }
    validate :transfer_group_matches_kind

    def transfer? = kind == "transfer"

    private

    # Manual entries get a generated ID; pulled records carry the bank's own.
    def assign_manual_external_id
      self.external_id ||= SecureRandom.uuid if source == MANUAL_SOURCE
    end

    def transfer_group_matches_kind
      return if transfer? == transfer_group_id.present?
      errors.add(:transfer_group_id, transfer? ? "is required for transfers" : "is only for transfers")
    end
  end
end
