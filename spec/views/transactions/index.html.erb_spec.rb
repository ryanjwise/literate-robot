require "rails_helper"

RSpec.describe "transactions/index", type: :view do
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
    assign(:transactions, [
      Transaction.create!(
        dollars: 2,
        cents: 3,
        expense_id: expense.id,
        source: "Source",
        notes: "MyText",
      ),
      Transaction.create!(
        dollars: 2,
        cents: 3,
        expense_id: expense.id,
        source: "Source",
        notes: "MyText",
      ),
    ])
  end

  it "renders a list of transactions" do
    render
    cell_selector = Rails::VERSION::STRING >= "7" ? "div>p" : "tr>td"
    assert_select cell_selector, text: Regexp.new(2.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(3.to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Source".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
  end
end
