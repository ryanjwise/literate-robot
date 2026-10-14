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
- `expense_categories`, `expenses`, `transactions`: standard JSON CRUD under `/finance`
- `POST /finance/transactions/:id/reconcile` (`expense_id`) -> status `matched`
- `POST /finance/transactions/:id/confirm` -> status `confirmed`
- `GET /finance/transactions?status=pulled` lists unreconciled records
- Transactions are unique on `(source, external_id)`; manual entries use source `MAN` with a generated id.
- Amounts are integer `amount_cents`. States and frequencies are enforced by DB CHECK constraints.

## Notes
Production logging defaults to `fatal` (credentials may pass through headers). Intended to sit behind Tailscale/WireGuard.
