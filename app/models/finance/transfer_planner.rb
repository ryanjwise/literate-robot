module Finance
  # Works out what to move between accounts so each funded account can cover
  # what it owes (credit) or will pay out (forecast bills), following the
  # `funded_by` chain, e.g. savings -> debit -> credit card.
  #
  #   transfer in = max(0, -(balance + forecast - transfers out of this account))
  #
  # Accounts at the top of a chain have no funder; any shortfall there is reported.
  class TransferPlanner
    def initialize(to:, include_forecast: true, from: Date.current)
      @forecast = include_forecast ? Forecast.new(from:, to:) : nil
      @to = to
    end

    def valid? = @forecast.nil? || @forecast.valid?

    def accounts
      @accounts ||= Account.order(:id).to_a
    end

    def as_json(*)
      rows = accounts.map { row_for(_1) }
      { to: @to, include_forecast: !@forecast.nil?,
        transfers: rows.select { _1[:funded_by_id] && _1[:transfer_in_cents].positive? }
                       .map { { from_account_id: _1[:funded_by_id], to_account_id: _1[:account_id], amount_cents: _1[:transfer_in_cents] } },
        unassigned_forecast_cents: @forecast ? @forecast.totals_by_account.fetch(nil, 0) : 0,
        accounts: rows }
    end

    private

    def row_for(account)
      forecast = forecast_for(account)
      out = outgoing(account)
      need = transfer_in(account)
      { account_id: account.id, name: account.name, funded_by_id: account.funded_by_id,
        balance_cents: account.balance_cents, forecast_cents: forecast, outgoing_cents: out,
        transfer_in_cents: account.funded_by_id ? need : 0,
        shortfall_cents: account.funded_by_id ? 0 : need }
    end

    def forecast_for(account)
      @forecast ? @forecast.totals_by_account.fetch(account.id, 0) : 0
    end

    # What this account must send on to the accounts it funds.
    def outgoing(account)
      @outgoing ||= {}
      @outgoing[account.id] ||= accounts.select { _1.funded_by_id == account.id }.sum { transfer_in(_1) }
    end

    def transfer_in(account)
      @transfer_in ||= {}
      @transfer_in[account.id] ||= [0, -(account.balance_cents + forecast_for(account) - outgoing(account))].max
    end
  end
end
