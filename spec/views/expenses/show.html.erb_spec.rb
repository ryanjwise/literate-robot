require "rails_helper"

RSpec.describe "expenses/show", type: :view do
  let(:expense_category) {
    ExpenseCategory.create!(
      name: "MyExpense",
      desired_source: "MyDesiredSource",
    )
  }

  before(:each) do
    assign(:expense, Expense.create!(
      name: "Name",
      frequency: "monthly",
      expense_category_id: expense_category.id,
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/Frequency/)
  end
end
