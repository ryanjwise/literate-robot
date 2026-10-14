module Finance
  class TransactionsController < ResourceController
    TRANSFER_ERROR = "transfers are managed via /finance/transfers".freeze
    BANK_DELETE_ERROR = "bank records cannot be deleted; ignore them instead".freeze

    # Manual entries are created directly; pulled records enter as "pulled"
    # and are reconciled via the member actions below.
    def create
      return render_error(TRANSFER_ERROR) if transfer_requested?
      super
    end

    def update
      return render_error(TRANSFER_ERROR) if transfer_requested?
      super
    end

    def destroy
      return render_error(TRANSFER_ERROR) if record.transfer?
      return render_error(BANK_DELETE_ERROR) unless record.manual?
      super
    end

    # Assign a category and/or a recurring expense (which implies its category).
    def reconcile
      attrs = params.permit(:category_id, :expense_id).to_h.compact_blank
      return render_error("category_id or expense_id is required") if attrs.empty?
      return render_error("only pulled or matched records can be reconciled") unless %w[pulled matched].include?(record.status)

      record.update!(attrs.merge(status: "matched"))
      render json: record
    end

    def confirm
      record.update!(status: "confirmed")
      render json: record
    end

    def ignore
      record.update!(status: "ignored")
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
    # Which fields may actually change on a bank record is enforced by the model.
    def permitted
      fields = %i[source external_id date amount_cents description notes expense_id category_id status account_id kind]
      fields = %i[description notes] if @record&.transfer?
      params.expect(transaction: fields)
    end

    def transfer_requested?
      params.dig(:transaction, :kind) == "transfer"
    end

    def render_error(message)
      render json: { error: message }, status: :unprocessable_content
    end
  end
end
