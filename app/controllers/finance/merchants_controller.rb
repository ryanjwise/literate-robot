module Finance
  class MerchantsController < ResourceController
    private

    def model = Merchant
    def permitted = params.expect(merchant: %i[key category_id expense_id auto_assign])
  end
end
