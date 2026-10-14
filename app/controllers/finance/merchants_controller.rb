module Finance
  class MerchantsController < ResourceController
    SORTS = %w[id key created_at updated_at].freeze

    private

    def model = Merchant
    def permitted = params.expect(merchant: %i[key category_id expense_id auto_assign])
  end
end
