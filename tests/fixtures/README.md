# Synthetic fixture inventory

All inputs are invented and contain no personal source or credentials.

- `scopes.tsv`: two projects with similar identity shape, a second worktree and
  a changed revision. Only the locally selected exact scope is admitted.
- `contracts.rs`: conflicting scope, malformed version, partial and oversized
  extraction, unavailable worker, cancellation before invocation, fresh-run
  recovery, injected clock, inference and host capability ports.
- `repository/`: two similarly named projects with conflicting rules and a
  revision manifest for rename/deletion/exclusion. These are **future worker
  input fixtures**, not evidence that indexing or deletion works today.
- The test-gate failure and scanner-secret input are generated only in temporary
  directories by `scripts/check.py` and `scripts/secrets.py`. Neither mutates
  production code or suppresses the normal test/scanner result.

The recovery test proves fresh in-memory execution after a failure, not durable
job recovery. Phase 2 must test transactions, interruption and re-import against
real storage. Scope checks are not transport authentication.
