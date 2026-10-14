require "rails_helper"

RSpec.describe Finance::MerchantKey do
  it "treats repeat merchants as the same key" do
    keys = ["WOOLWORTHS 1234 NEWTOWN", "Woolworths 5678 Newtown", "woolworths  newtown "].map { described_class.normalize(_1) }
    expect(keys.uniq).to eq(["WOOLWORTHS NEWTOWN"])
  end

  it "drops punctuation, digit tokens and generic words" do
    expect(described_class.normalize("EFTPOS PURCHASE NETFLIX.COM 4455")).to eq("NETFLIX COM")
  end

  it "is nil when nothing is left" do
    expect(described_class.normalize("1234 5678")).to be_nil
    expect(described_class.normalize(nil)).to be_nil
  end
end
