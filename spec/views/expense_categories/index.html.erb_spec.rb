require "rails_helper"

RSpec.describe "expense_categories/index", type: :view do
  before(:each) do
    assign(:expense_categories, [
      ExpenseCategory.create!(
        desired_source: "Desired Source",
      ),
      ExpenseCategory.create!(
        desired_source: "Desired Source",
      ),
    ])
  end

  it "renders a list of expense_categories" do
    render
    cell_selector = Rails::VERSION::STRING >= "7" ? "div>p" : "tr>td"
    assert_select cell_selector, text: Regexp.new("Desired Source".to_s), count: 2
  end
end
