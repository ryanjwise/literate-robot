module ApiKeyAuthentication
  extend ActiveSupport::Concern

  included do
    class_attribute :api_namespace
    before_action :authenticate_api_key!
  end

  private

  def authenticate_api_key!
    token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
    @current_api_key = ApiKey.authenticate(token, namespace: api_namespace.to_s)
    head :unauthorized unless @current_api_key
  end
end
