require "rails_helper"

RSpec.describe "Finance auth", type: :request do
  it "rejects requests with no key" do
    get "/finance/transactions"
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a bad key" do
    get "/finance/transactions", headers: { "Authorization" => "Bearer nope" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a key scoped to another namespace" do
    get "/finance/transactions", headers: auth_headers(namespace: "other")
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a revoked key but accepts a second active one" do
    old, old_key = ApiKey.issue(namespace: "finance", name: "old")
    _, new_key = ApiKey.issue(namespace: "finance", name: "new")
    old.revoke!

    get "/finance/transactions", headers: { "Authorization" => "Bearer #{old_key}" }
    expect(response).to have_http_status(:unauthorized)
    get "/finance/transactions", headers: { "Authorization" => "Bearer #{new_key}" }
    expect(response).to have_http_status(:ok)
  end

  it "stores only a digest" do
    key, plaintext = ApiKey.issue(namespace: "finance", name: "x")
    expect(key.digest).not_to include(plaintext)
  end
end
