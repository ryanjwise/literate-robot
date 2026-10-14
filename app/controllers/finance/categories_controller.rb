module Finance
  class CategoriesController < ResourceController
    private

    def model = Category
    def permitted = params.expect(category: %i[name desired_account_id])
  end
end
