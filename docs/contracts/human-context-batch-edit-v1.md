# Human-context atomic batch edit v1

TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A5/A6 and P3-A4.
This is explicit human compare-and-append, not semantic resolution, observed truth,
authorization, conflict links or automatic ordering/resolution of user changes.
Existing single-note APIs and JSON remain unchanged. No schema/dependency change.

## Closed interface (AI-01)

Core exposes typed `ContextBatchEdit` / `ContextBatchAction`,
`ContextBatchEdit::parse` / `validate`, and
`Store::edit_context_batch_bound(project, ContextReadBinding, request, cancel,
progress)`. The finite observer reports only `AppendStaged(1..8)` and
`ReadyToCommit`; it never publishes a receipt or content. Daemon adds
`EditContextBatchBound(project, request, root, identity, incarnation)`.

`context batch-edit PROJECT --expected-root ROOT --expected-root-identity IDENTITY
--expected-incarnation TOKEN` requires every flag exactly once in that order.
Validate this grammar and binding before bounded stdin. Read exactly one UTF-8
JSON document, at most 65536 encoded bytes; reject trailing documents, duplicate
or unknown fields, NUL, and invalid UTF-8. No partial receipt or streaming frames.

Document: `{"version":"human-context-batch-edit-v1","actions":[...]}`.
Each action is exactly either
`{"operation":"update","id":"a","expected_revision":1,"kind":"note","text":"new"}`
or `{"operation":"retire","id":"b","expected_revision":1}`.
There are 2..8 distinct existing IDs, all implicitly in PROJECT; no add, namespace,
per-action project, missing-ID fallback or extra fields. Revisions are JSON integer
tokens 1..32 (no strings, signs, fractions, exponents or leading zeroes).
Kinds use the existing closed human vocabulary. Text is nonempty, NUL-free,
at most 4096 UTF-8 bytes each and 32768 aggregate. Typed core/daemon repeat all
applicable validation, including canonical encoded request size, before storage.

## Atomicity and scope (AI-02–AI-05)

Existing store only; no creation or implicit upgrade. V3/v4 registration required.
One IMMEDIATE transaction checks exact UTF-8 root/identity/incarnation before any
human SQL, then validates every selected complete history, suppression, expected
latest revision, 32-revision/note and whole-plan 4096-row/project budgets before
any append. Retire copies kind/text from that compared latest row. Append exactly
once per target in submitted order; no loop through public single-note writers.
Fresh Update may reactivate retired history exactly as existing CAS; Forget cannot
be bypassed. Source policy/snapshot and source filesystem are not consulted.
Other histories/projects, suppression, evidence and source bytes are untouched.

Cancel at preflight, validation, each staged append and ready-to-commit rolls back
everything. Commit errors retain existing uncertainty semantics; no postcommit
cancel may pretend rollback. SQLite durability/killed-worker recovery is the
existing CAS transaction model. Dependency/capacity failure rejects the whole plan.
Mismatch is existing content-free ScopeMismatch, not a conflict receipt.

## Receipt and evidence (AI-06–AI-08)

Success only: `version`, `project`, `count`, `actions` sorted by ID, each containing
`id`, `operation`, `old_revision`, `new_revision`. At most 8192 encoded bytes including
newline; no text, paths, binding metadata or content-bearing errors. Sorting is
receipt metadata only, not semantic processing. Human declarations remain human.
AI-06 covers closed CLI/admission and content-free errors; AI-07 regression and
preservation; AI-08 staged SQL/cancel/process-death recovery and fresh reuse.
Actual evidence and exclusions belong in `docs/progress/unit-ai-atomic-human-edit-batch.md`.
