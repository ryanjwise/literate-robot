module Finance
  class CategoriesController < ResourceController
    SORTS = %w[id name created_at].freeze

    private

    def model = Category
    def permitted = params.expect(category: %i[name desired_account_id])
  end
end
