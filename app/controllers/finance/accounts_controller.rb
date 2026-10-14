module Finance
  class AccountsController < ResourceController
    SORTS = %w[id name created_at].freeze

    private

    def model = Account
    def permitted
      params.expect(account: %i[name kind funded_by_id opening_balance_cents opening_balance_on external_source external_id])
    end
  end
end
