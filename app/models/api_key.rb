class ApiKey < ApplicationRecord
  validates :namespace, :name, :digest, presence: true

  scope :active, -> { where(revoked_at: nil) }

  # Returns [record, plaintext]. The plaintext is shown once and never stored.
  def self.issue(namespace:, name:)
    plaintext = SecureRandom.urlsafe_base64(32)
    [create!(namespace:, name:, digest: digest_for(plaintext)), plaintext]
  end

  def self.digest_for(plaintext) = Digest::SHA256.hexdigest(plaintext)

  # Keys are high-entropy random strings, so a fast hash plus an indexed
  # lookup is sufficient; the final comparison is constant-time.
  def self.authenticate(plaintext, namespace:)
    return if plaintext.blank?
    digest = digest_for(plaintext)
    key = active.find_by(digest:, namespace:)
    key if key && ActiveSupport::SecurityUtils.secure_compare(key.digest, digest)
  end

  def revoke! = update!(revoked_at: Time.current)
end
