require "rails_helper"

RSpec.describe "transactions/show", type: :view do
  let(:expense) {
    Expense.create!(
      name: "MyString",
      frequency: "monthly",
    )
  }
  before(:each) do
    assign(:transaction, Transaction.create!(
      dollars: 2,
      cents: 3,
      expense_id: expense.id,
      source: "Source",
      notes: "MyText",
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/2/)
    expect(rendered).to match(/3/)
    expect(rendered).to match(/MyString/)
    expect(rendered).to match(/Source/)
    expect(rendered).to match(/MyText/)
  end
end
