module Finance
  class BaseController < ApplicationController
    include ApiKeyAuthentication
    self.api_namespace = :finance

    rescue_from ActiveRecord::RecordNotFound do
      head :not_found
    end
    rescue_from ActiveRecord::RecordInvalid do |e|
      render json: { errors: e.record.errors }, status: :unprocessable_content
    end
    rescue_from ActionController::ParameterMissing do |e|
      render json: { error: e.message }, status: :bad_request
    end
  end
end
