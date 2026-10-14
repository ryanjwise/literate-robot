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

      record.update!(attrs.merge(status: "matched", auto_assigned: false))
      merchant = Merchant.learn(record)
      auto_matched = merchant ? merchant.apply_to_pending : 0
      render json: record.as_json.merge("auto_matched" => auto_matched)
    end

    # Confirm everything the merchant memory matched that you have not touched.
    def confirm_auto
      count = Transaction.where(status: "matched", auto_assigned: true).update_all(status: "confirmed", updated_at: Time.current)
      render json: { confirmed: count }
    end

    def confirm
      record.update!(status: "confirmed")
      render json: record
    end

    def ignore
      record.update!(status: "ignored")
      render json: record
    end

    # Make this the half of a transfer: pair it with `counterpart_id`, or create the
    # missing manual half on `counterpart_account_id`.
    def link_transfer
      legs = TransferLinker.link!(record, counterpart_id: params[:counterpart_id], counterpart_account_id: params[:counterpart_account_id])
      render json: legs
    rescue TransferLinker::Error => e
      render_error(e.message)
    end

    def transfer_candidates
      render json: TransferLinker.candidates(record)
    end

    private

    def model = Transaction

    # Filters: status, account_id, category_id, expense_id, kind, from/to (dates),
    # and q (case-insensitive text match on description, notes and merchant).
    def scope
      scoped = Transaction.all
      %i[status account_id category_id expense_id kind].each { scoped = scoped.where(_1 => params[_1]) if params[_1].present? }
      scoped = scoped.where(date: date_param(:from, nil)..) if params[:from].present?
      scoped = scoped.where(date: ..date_param(:to, nil)) if params[:to].present?
      if params[:q].present?
        like = "%#{Transaction.sanitize_sql_like(params[:q])}%"
        scoped = scoped.where("description LIKE :q ESCAPE '\\' OR notes LIKE :q ESCAPE '\\' OR merchant_key LIKE :q ESCAPE '\\'", q: like)
      end
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
