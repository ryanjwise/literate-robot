require "rails_helper"

RSpec.describe "expense_categories/new", type: :view do
  before(:each) do
    assign(:expense_category, ExpenseCategory.new(
      desired_source: "MyString",
    ))
  end

  it "renders new expense_category form" do
    render

    assert_select "form[action=?][method=?]", expense_categories_path, "post" do
      assert_select "input[name=?]", "expense_category[desired_source]"
    end
  end
end
