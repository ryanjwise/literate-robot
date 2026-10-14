# Builds payloads shaped like UP's API (https://developer.up.com.au) for specs.
module UpFixtures
  def up_money(cents) = { "currencyCode" => "AUD", "value" => format("%.2f", cents / 100.0), "valueInBaseUnits" => cents }

  def up_account(id, name, balance, type: "TRANSACTIONAL")
    { "type" => "accounts", "id" => id,
      "attributes" => { "displayName" => name, "accountType" => type, "ownershipType" => "INDIVIDUAL",
                        "balance" => up_money(balance), "createdAt" => "2024-01-01T00:00:00+11:00" } }
  end

  def up_txn(id, account:, cents:, desc:, at: "2026-10-12T09:30:00+11:00", status: "SETTLED", transfer: nil, category: nil, raw: nil)
    { "type" => "transactions", "id" => id,
      "attributes" => { "status" => status, "rawText" => raw, "description" => desc, "message" => nil,
                        "amount" => up_money(cents), "createdAt" => at, "settledAt" => status == "SETTLED" ? at : nil,
                        "transactionType" => nil },
      "relationships" => { "account" => { "data" => { "type" => "accounts", "id" => account } },
                           "transferAccount" => { "data" => transfer && { "type" => "accounts", "id" => transfer } },
                           "category" => { "data" => category && { "type" => "categories", "id" => category } } } }
  end

  # Stands in for Finance::Up::Client: serves canned lists by path.
  class FakeUpClient
    attr_reader :calls

    def initialize(accounts:, transactions:)
      @data = { "/accounts" => accounts, "/transactions" => transactions }
      @calls = []
    end

    def paginate(path, params = {})
      @calls << [path, params]
      @data.fetch(path)
    end
  end
end

RSpec.configure { |c| c.include UpFixtures }
