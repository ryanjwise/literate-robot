module ApiHelpers
  def auth_headers(namespace: "finance")
    _, key = ApiKey.issue(namespace:, name: "spec")
    { "Authorization" => "Bearer #{key}" }
  end
end

RSpec.configure { |c| c.include ApiHelpers }
