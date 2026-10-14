module Finance
  class TransfersController < BaseController
    def index
      render json: Transfer.all
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
                                    include_forecast: params[:include_forecast] != "false")
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
