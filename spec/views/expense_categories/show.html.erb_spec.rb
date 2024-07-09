require "rails_helper"

RSpec.describe "expense_categories/show", type: :view do
  before(:each) do
    assign(:expense_category, ExpenseCategory.create!(
      desired_source: "Desired Source",
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Desired Source/)
  end
end
