require "rails_helper"

RSpec.describe "Dev console", type: :request do
  around do |ex|
    old = ENV["FINANCE_API_KEY"]
    ex.run
  ensure
    ENV["FINANCE_API_KEY"] = old
  end

  it "injects the env key as an escaped JSON string" do
    ENV["FINANCE_API_KEY"] = %(a"</script>b)
    get "/"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("</script>b")
    expect(response.body).to include('a\\"\\u003c/script\\u003eb')
  end

  it "serves with an empty key when unset" do
    ENV.delete("FINANCE_API_KEY")
    get "/"
    expect(response.body).to include('const INJECTED_KEY = ""')
  end
end
