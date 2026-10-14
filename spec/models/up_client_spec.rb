require "rails_helper"

RSpec.describe Finance::Up::Client do
  subject(:client) { described_class.new("secret", base_url: "https://api.up.example/api/v1") }

  it "refuses to follow a link to another host, before any request is made" do
    expect(Net::HTTP).not_to receive(:new)
    expect { client.get_url("https://evil.example/api/v1/transactions") }
      .to raise_error(Finance::Up::Error, /another host/)
  end

  it "refuses a downgraded scheme or different port on the same host" do
    expect { client.get_url("http://api.up.example/api/v1/accounts") }.to raise_error(Finance::Up::Error, /another host/)
    expect { client.get_url("https://api.up.example:8443/api/v1/accounts") }.to raise_error(Finance::Up::Error, /another host/)
  end

  it "follows next links across pages and stops when next is null" do
    pages = [{ "data" => [1, 2], "links" => { "next" => "https://api.up.example/api/v1/x?page=2" } },
             { "data" => [3], "links" => { "next" => nil } }]
    allow(client).to receive(:get_url) { pages.shift }
    expect(client.paginate("/x")).to eq([1, 2, 3])
  end

  it "gives up rather than loop forever" do
    allow(client).to receive(:get_url).and_return({ "data" => [], "links" => { "next" => "https://api.up.example/api/v1/x" } })
    expect { client.paginate("/x") }.to raise_error(Finance::Up::Error, /more than/)
  end
end
