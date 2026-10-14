module Finance
  class TransfersController < BaseController
    SORTS = %w[date amount_cents].freeze

    # Filters: from/to (dates), round_up (true/false), paired (true/false). Newest first.
    def index
      items = Transfer.all
      items = items.select { _1[:date] >= date_param(:from, nil) } if params[:from].present?
      items = items.select { _1[:date] <= date_param(:to, nil) } if params[:to].present?
      %i[round_up paired].each do |flag|
        items = items.select { _1[flag] == ActiveModel::Type::Boolean.new.cast(params[flag]) } if params[flag].present?
      end
      render json: paginate_array(items, sorts: SORTS, default_sort: "date", tie: :transfer_group_id)
    end

    def create
      transfer = Transfer.new(params.expect(transfer: %i[from_account_id to_account_id amount_cents date description notes]))
      if transfer.save
        render json: { transfer_group_id: transfer.transfer_group_id }, status: :created
      else
        render json: { errors: transfer.errors }, status: :unprocessable_content
      end
    end

    # GET /finance/transfers/needed?to=YYYY-MM-DD&include_forecast=true
    def needed
      planner = TransferPlanner.new(to: date_param(:to, 30.days.from_now.to_date),
                                    include_forecast: ActiveModel::Type::Boolean.new.cast(params.fetch(:include_forecast, true)))
      return render json: { error: "range must be at most #{Forecast::MAX_DAYS} days" }, status: :unprocessable_content unless planner.valid?
      render json: planner
    end

    def unlink
      render json: TransferLinker.unlink!(params[:id])
    rescue TransferLinker::Error => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def destroy
      Transfer.destroy_group!(params[:id])
      head :no_content
    rescue Transfer::NotDeletable => e
      render json: { error: e.message }, status: :unprocessable_content
    end
  end
end
