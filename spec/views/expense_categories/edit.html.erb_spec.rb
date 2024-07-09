require "rails_helper"

RSpec.describe "expense_categories/edit", type: :view do
  let(:expense_category) {
    ExpenseCategory.create!(
      desired_source: "MyString",
    )
  }

  before(:each) do
    assign(:expense_category, expense_category)
  end

  it "renders the edit expense_category form" do
    render

    assert_select "form[action=?][method=?]", expense_category_path(expense_category), "post" do
      assert_select "input[name=?]", "expense_category[desired_source]"
    end
  end
end
