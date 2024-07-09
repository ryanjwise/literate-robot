require "rails_helper"

RSpec.describe "transactions/edit", type: :view do
  let(:expense) {
    Expense.create!(
      name: "MyString",
      frequency: "monthly",
    )
  }
  let(:transaction) {
    Transaction.create!(
      dollars: 1,
      cents: 1,
      expense_id: expense.id,
      source: "MyString",
      notes: "MyText",
    )
  }

  before(:each) do
    assign(:expense, expense)
    assign(:transaction, transaction)
  end

  it "renders the edit transaction form" do
    render

    assert_select "form[action=?][method=?]", transaction_path(transaction), "post" do
      assert_select "input[name=?]", "transaction[dollars]"

      assert_select "input[name=?]", "transaction[cents]"

      assert_select "input[name=?]", "transaction[source]"

      assert_select "textarea[name=?]", "transaction[notes]"
    end
  end
end
