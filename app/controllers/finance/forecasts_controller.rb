module Finance
  class ForecastsController < BaseController
    # GET /finance/forecast?from=YYYY-MM-DD&to=YYYY-MM-DD (default: next 30 days)
    def show
      forecast = Forecast.new(from: date_param(:from, Date.current), to: date_param(:to, 30.days.from_now.to_date))
      return render json: { error: "range must be ordered and at most #{Forecast::MAX_DAYS} days" }, status: :unprocessable_content unless forecast.valid?
      render json: forecast
    end
  end
end
