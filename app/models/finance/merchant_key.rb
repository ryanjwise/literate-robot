module Finance
  # Reduces a bank description to a stable key so repeat merchants match:
  # "WOOLWORTHS 1234 NEWTOWN" and "Woolworths 5678 Newtown" share a key.
  # Replaced by the bank's own merchant field when a source provides one.
  module MerchantKey
    NOISE = %w[PURCHASE EFTPOS VISA CARD DEBIT PAYMENT].freeze

    def self.normalize(description)
      tokens = description.to_s.upcase.gsub(/[^A-Z0-9 ]/, " ").split
      tokens = tokens.reject { |t| t.match?(/\d/) || NOISE.include?(t) }
      tokens.join(" ").presence
    end
  end
end
