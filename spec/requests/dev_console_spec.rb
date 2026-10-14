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

RSpec.describe "Dev console UP token", type: :request do
  around do |ex|
    old = ENV["UP_API_TOKEN"]
    ex.run
  ensure
    ENV["UP_API_TOKEN"] = old
  end

  it "injects the UP token as an escaped JSON string, empty when unset" do
    ENV["UP_API_TOKEN"] = %(up:"</script>)
    get "/"
    expect(response.body).not_to include("</script>\"")
    expect(response.body).to include('const INJECTED_UP_TOKEN = "up:\\"\\u003c/script\\u003e"')

    ENV.delete("UP_API_TOKEN")
    get "/"
    expect(response.body).to include('const INJECTED_UP_TOKEN = ""')
  end
end
