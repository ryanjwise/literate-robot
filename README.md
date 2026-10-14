# literate-robot

API-only Rails app hosting small personal tools as route namespaces in one process.
Currently: `/finance` (expense tracking: manual entry now, bank pulls + reconciliation later).

## Dev
    bundle install && bin/rails db:prepare
    bundle exec rspec
    bin/rails server

## Keys (per-namespace bearer tokens; only a SHA-256 digest is stored)
    bin/rails "keys:create[finance,laptop]"   # prints the key once
    bin/rails keys:list
    bin/rails "keys:revoke[ID]"
Roll a key: create the new one, move clients over, revoke the old one.

## Finance API (`Authorization: Bearer <key>`)
- `accounts`, `categories` (each may name a `desired_account_id`), `expenses`, `transactions`: standard JSON CRUD under `/finance`
- Accounts have a `kind` (`debit`/`credit`/`cash`), an optional `funded_by_id` (the account that pays a card) and an
  opening balance; `balance_cents` is computed (opening + transactions on/after the opening date). Credit accounts go negative.
- `amount_cents` is signed from the account's view: negative = money out, positive = money in. Transaction `kind`
  is `expense`, `income` (must be positive) or `transfer`.
- `/finance/transfers` (`index`, `create`, `destroy` by group id) manages transfers as two linked legs that net to zero.
  Transfer legs cannot be created, deleted or reshaped through `/finance/transactions` (only description/notes).
- `POST /finance/transactions/:id/reconcile` with `category_id` and/or `expense_id` -> status `matched`.
  Choosing a recurring expense implies its category unless one is given. Income and transfers need neither.
- `POST /finance/transactions/:id/confirm` -> `confirmed` (an expense must have a category by then)
- `POST /finance/transactions/:id/ignore` -> `ignored` (for records that are not real spending)
- Bank-origin records (source other than `MAN`): only `notes`, `category_id`, `expense_id` and `status` can change;
  they cannot be deleted (ignore them instead). Manual records can change everything except `source`/`external_id`.
- `GET /finance/transactions?status=pulled` lists unreconciled records
- Transactions are unique on `(source, external_id)`; manual entries use source `MAN` with a generated id.
- Amounts are integer `amount_cents`. States and frequencies are enforced by DB CHECK constraints.

## Merchant memory
Each transaction gets a `merchant_key` (normalized description). Reconciling an expense-kind record saves a
`merchants` rule (key -> category and/or expense) and pre-matches every other waiting record from that merchant
(`auto_assigned: true`). New bank records from a known merchant arrive pre-matched. `POST /finance/transactions/confirm_auto`
confirms all untouched auto-matched records. Rules are managed at `/finance/merchants` (turn `auto_assign` off to stop one).

## Forecast and transfers
- Expenses can carry `anchor_date` (a due date), `frequency` (including `ad_hoc`: one planned bill on the anchor date, or never forecast without one), optional `ends_on`, `amount_mode` (`fixed` needs
  `expected_amount_cents`; `variable` uses the average of the last 4 matched/confirmed transactions), and `account_id`.
- `GET /finance/forecast?from=&to=` (max 366 days) lists dated outflows (negative cents), totals per account, and
  expenses with no anchor. It does not check whether a bill was already paid early.
- `GET /finance/transfers/needed?to=&include_forecast=true` returns the transfers that cover each account along
  the `funded_by` chain: `max(0, -(balance + upcoming bills - what it sends on))`. The top of a chain reports a shortfall.
- `GET /finance/transactions` filters: `status`, `account_id`, `category_id`, `expense_id`, `kind`, `from`, `to`, `q`.

## UP bank pull
`POST /finance/pull/up` with headers `Authorization: Bearer <our key>` and `X-Bank-Token: <UP personal access token>`;
params `since` (YYYY-MM-DD, default 30 days ago) and `dry_run=true` to preview. The token is used for that request only and
is never stored or logged; errors from UP come back as 502 (429 if rate limited).
- Accounts are created from UP's (`external_source: bank:up`, `external_id`), with an opening balance chosen so the computed
  balance equals UP's at pull time. Each response reports per-account `drift_cents` (UP minus ours).
- Transactions are identified by (`bank:up`, UP id), so re-pulling never duplicates. Bank fields refresh (e.g. held -> settled);
  your category, notes and status are never touched. Records you had already reviewed that the bank then changed are listed in
  `changed_after_review`.
- Positive amounts are `income`, negative `expense`; transfers between your UP accounts are paired into one transfer (confirmed).
- UP's category is kept in `bank_category` as a hint only; new bank records still go through merchant memory.
- To link a manual account to an UP account instead of creating a new one, set its `external_source` (`bank:up`) and `external_id`.

## Dev helpers
- `bin/rails dev:sample_data` adds sample pulled records (source `bank:sample`) to try the reconcile UI; safe to re-run.
- `bin/rails dev:clear_sample_data` removes them.
- The console accepts deep links: `/#reconcile`, `/#accounts`, `/#detail:<transaction id>`.

## Notes
Production logging defaults to `fatal` (credentials may pass through headers). Intended to sit behind Tailscale/WireGuard.
