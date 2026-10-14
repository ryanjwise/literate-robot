module Finance
  class PullsController < BaseController
    # POST /finance/pull/up   header: X-Bank-Token   params: since (YYYY-MM-DD, default 30 days ago), dry_run
    # The UP token is used for this request only; it is never stored or logged.
    def up
      token = request.headers["X-Bank-Token"].to_s
      return render json: { error: "X-Bank-Token header is required" }, status: :bad_request if token.blank?

      since = date_param(:since, 30.days.ago.to_date)
      return render json: { error: "since cannot be in the future" }, status: :unprocessable_content if since > Date.current

      pull = Up::Pull.new(client: Up::Client.new(token), since:, dry_run: ActiveModel::Type::Boolean.new.cast(params[:dry_run]) || false)
      render json: pull.call
    rescue Up::Error => e
      # 502 (not 401) so clients can tell "UP said no" from "our key is wrong".
      status = e.status == 429 ? :too_many_requests : :bad_gateway
      render json: { error: e.message }, status:
    end
  end
end
