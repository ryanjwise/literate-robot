module Finance
  class TransactionsController < ResourceController
    # Manual entries are created directly; pulled records enter as "pulled"
    # and are reconciled via the member actions below.
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
      params[:status] ? Transaction.where(status: params[:status]) : Transaction.all
    end

    def permitted
      params.expect(transaction: %i[source external_id date amount_cents description notes expense_id status])
    end
  end
end
