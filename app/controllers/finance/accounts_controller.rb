module Finance
  class AccountsController < ResourceController
    private

    def model = Account
    def permitted
      params.expect(account: %i[name kind funded_by_id opening_balance_cents opening_balance_on external_source external_id])
    end
  end
end
