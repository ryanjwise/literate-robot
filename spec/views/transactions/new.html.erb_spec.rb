require "rails_helper"

RSpec.describe "transactions/new", type: :view do
  before(:each) do
    assign(:transaction, Transaction.new(
      dollars: 1,
      cents: 1,
      source: "MyString",
      notes: "MyText",
    ))
  end

  it "renders new transaction form" do
    render

    assert_select "form[action=?][method=?]", transactions_path, "post" do
      assert_select "input[name=?]", "transaction[dollars]"

      assert_select "input[name=?]", "transaction[cents]"

      assert_select "input[name=?]", "transaction[source]"

      assert_select "textarea[name=?]", "transaction[notes]"
    end
  end
end
