module ApiHelpers
  def auth_headers(namespace: "finance")
    _, key = ApiKey.issue(namespace:, name: "spec")
    { "Authorization" => "Bearer #{key}" }
  end

  def json = JSON.parse(response.body)

  def make_account(name: "Everyday", kind: "debit", **attrs)
    Finance::Account.create!(name:, kind:, **attrs)
  end
end

RSpec.configure { |c| c.include ApiHelpers }
