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
- `accounts`, `categories`, `expenses`, `transactions`: standard JSON CRUD under `/finance`
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

## Dev helpers
- `bin/rails dev:sample_data` adds sample pulled records (source `bank:sample`) to try the reconcile UI; safe to re-run.
- `bin/rails dev:clear_sample_data` removes them.
- The console accepts deep links: `/#reconcile`, `/#accounts`, `/#detail:<transaction id>`.

## Notes
Production logging defaults to `fatal` (credentials may pass through headers). Intended to sit behind Tailscale/WireGuard.
