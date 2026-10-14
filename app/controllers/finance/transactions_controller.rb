module Finance
  class TransactionsController < ResourceController
    TRANSFER_ERROR = "transfers are managed via /finance/transfers".freeze

    # Manual entries are created directly; pulled records enter as "pulled"
    # and are reconciled via the member actions below.
    def create
      return render_transfer_error if transfer_requested?
      super
    end

    def update
      return render_transfer_error if transfer_requested?
      super
    end

    def destroy
      return render_transfer_error if record.transfer?
      super
    end

    def reconcile
      record.update!(expense_id: params.require(:expense_id), status: "matched")
      render json: record
    end

    def confirm
      record.update!(status: "confirmed")
      render json: record
    end

    private

    def model = Transaction

    def scope
      scoped = Transaction.all
      scoped = scoped.where(status: params[:status]) if params[:status]
      scoped = scoped.where(account_id: params[:account_id]) if params[:account_id]
      scoped
    end

    # Transfer legs only allow free-text edits; amounts and accounts must stay paired.
    def permitted
      fields = %i[source external_id date amount_cents description notes expense_id status account_id kind]
      fields = %i[description notes] if @record&.transfer?
      params.expect(transaction: fields)
    end

    def transfer_requested?
      params.dig(:transaction, :kind) == "transfer"
    end

    def render_transfer_error
      render json: { error: TRANSFER_ERROR }, status: :unprocessable_content
    end
  end
end
