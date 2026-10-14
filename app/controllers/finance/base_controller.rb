module Finance
  class BaseController < ApplicationController
    include ApiKeyAuthentication
    self.api_namespace = :finance

    rescue_from Date::Error do
      render json: { error: "invalid date" }, status: :bad_request
    end

    # An id that points at nothing (or at something still in use) is a client error, not a 500.
    rescue_from ActiveRecord::InvalidForeignKey do
      render json: { error: "references a record that does not exist" }, status: :unprocessable_content
    end

    rescue_from ActiveRecord::RecordNotFound do
      head :not_found
    end
    rescue_from ActiveRecord::RecordInvalid do |e|
      render json: { errors: e.record.errors }, status: :unprocessable_content
    end
    rescue_from ActionController::ParameterMissing do |e|
      render json: { error: e.message }, status: :bad_request
    end
  
    private

    def date_param(name, default)
      params[name].present? ? Date.iso8601(params[name]) : default
    end
  end
end
