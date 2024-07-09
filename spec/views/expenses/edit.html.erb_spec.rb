require "rails_helper"

RSpec.describe "expenses/edit", type: :view do
  let(:expense_category) {
    ExpenseCategory.create!(
      name: "MyExpense",
      desired_source: "MyDesiredSource",
    )
  }
  let(:expense) {
    Expense.create!(
      name: "MyString",
      frequency: "monthly",
      expense_category_id: expense_category.id,
    )
  }

  before(:each) do
    assign(:expense_category, expense_category)
    assign(:expense, expense)
  end

  it "renders the edit expense form" do
    render

    assert_select "form[action=?][method=?]", expense_path(expense), "post" do
      assert_select "input[name=?]", "expense[name]"

      assert_select "select[name=?]", "expense[frequency]"
    end
  end
end
