module Finance
  class Transaction < ApplicationRecord
    MANUAL_SOURCE = "MAN".freeze
    STATUSES = %w[pulled matched confirmed].freeze

    belongs_to :expense, optional: true

    before_validation :assign_manual_external_id, on: :create

    validates :source, :external_id, :date, presence: true
    validates :amount_cents, numericality: { only_integer: true }
    validates :status, inclusion: { in: STATUSES }
    validates :external_id, uniqueness: { scope: :source }
    validates :expense, presence: true, unless: -> { status == "pulled" }

    private

    # Manual entries get a generated ID; pulled records carry the bank's own.
    def assign_manual_external_id
      self.external_id ||= SecureRandom.uuid if source == MANUAL_SOURCE
    end
  end
end
