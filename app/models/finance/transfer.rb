module Finance
  # A transfer is two linked transactions: money out of one account, in to another.
  class Transfer
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :from_account_id, :integer
    attribute :to_account_id, :integer
    attribute :amount_cents, :integer
    attribute :date, :date
    attribute :description, :string
    attribute :notes, :string
    attr_reader :transfer_group_id

    validates :from_account_id, :to_account_id, :date, presence: true
    validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
    validate :accounts_exist_and_differ

    # Groups the legs of every transfer into one hash per transfer.
    def self.all
      Transaction.where(kind: "transfer").order(:date, :id).group_by(&:transfer_group_id).map do |group, legs|
        from, to = legs.partition { _1.amount_cents.negative? }.map(&:first)
        { transfer_group_id: group, date: from.date, amount_cents: to.amount_cents,
          from_account_id: from.account_id, to_account_id: to.account_id,
          description: from.description, notes: from.notes, legs: legs.map(&:id) }
      end
    end

    def self.destroy_group!(group_id)
      legs = Transaction.where(kind: "transfer", transfer_group_id: group_id)
      raise ActiveRecord::RecordNotFound if legs.none?
      legs.destroy_all
    end

    def save
      return false unless valid?
      group = SecureRandom.uuid
      Transaction.transaction do
        { from_account_id => -amount_cents, to_account_id => amount_cents }.each do |account_id, cents|
          Transaction.create!(source: Transaction::MANUAL_SOURCE, account_id:, amount_cents: cents, kind: "transfer",
                              transfer_group_id: group, date:, description:, notes:, status: "confirmed")
        end
      end
      @transfer_group_id = group
      true
    end

    private

    def accounts_exist_and_differ
      errors.add(:to_account_id, "must differ from from_account_id") if from_account_id == to_account_id
      [:from_account_id, :to_account_id].each do |attr|
        id = public_send(attr)
        errors.add(attr, "does not exist") if id && !Account.exists?(id)
      end
    end
  end
end
