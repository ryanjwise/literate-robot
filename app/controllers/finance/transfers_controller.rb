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

    def destroy
      Transfer.destroy_group!(params[:id])
      head :no_content
    end
  end
end
