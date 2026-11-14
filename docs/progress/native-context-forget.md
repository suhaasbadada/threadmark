# Native human-context Forget

Requirements: TM-01–TM-04, TM-07, TM-10; partial P2-A3/P2-A5 and
P3-A3/P3-A4/P3-A5. Exact tested integration:
`4de114023ff49a31510385894f194ceda0d06564`, based on PR #47 merge
`ddaaac5ad17db063ab133f2ac3258746c1b1eda8`. Ancestry integration changed no
reviewed tree content. Bob implemented; the coordinator owns publication.

The native Context view now offers a separate immutable Forget confirmation with
Cancel as default. Approval identifies project/root identity, registration
incarnation, target context ID and complete displayed latest revision. All four
bindings reach the actual core transaction before suppression or deletion. A new
revision, absent/marked target or same-root re-registration fails without touching
replacement history. The explicit unbound CLI remains idempotent; native bound
approval never falls back to that path. No database schema change is introduced.

Canceling the prompt performs no core operation or unsaved editor deletion.
Confirmation dispatch clears displayed stored history and the human editor, and
invalidates dependent previews, while preserving the unrelated original request.
Automatic owned work is stopped/preempted with existing serialized teardown. Stale
confirmations, repeated confirmation and late results cannot affect a new selection.

Receipts require exact target/count/fixed limits, bounded at 1 KiB; marker listing
is typed, ordered, unique and bounded at 1 MiB. Success requires the target absent
from fresh context state and present in suppression markers. Project inspection
before and after follow-up reads rechecks the same incarnation so replacement
data is not displayed. Errors/cancellation require Refresh, not an assertion of
rollback after commit. Marker inspection is explicit, non-content and no restore.

The warning explains loss of every local human revision and same-scope suppression,
never source-file deletion or forensic erasure. Previous exports/backups/displayed
copies may retain bytes. V1/v2 native cached actions require the documented explicit
v3 CLI upgrade and legacy-worker-stop attestation; the app neither migrates nor
invents tokens automatically. No real user Forget, migration or private export ran.

Joffrey independently reviewed implementation with no substantive findings; 33
model/adapter tests and actual SQLite Forget integration passed using existing
builds through the documented wrapper. The coordinator then rebuilt and verified
the exact integrated tree: 118 Rust tests plus two doctests, full formatting/lint/
docs/smoke/links/negative gate, and all 69 strict Swift tests against the actual
rebuilt CLI. Bob's release bundle/plist passed. Dependency policy, staged secrets
and whitespace checks passed. No dependency or generated lock changed.

Synthetic fixtures cover confirmation/cancel/stale editor/scope/revision/absence,
same-root reuse, SQL/cancel rollback, malformed receipt/markers, uncertain follow-up
and source/other-project preservation across rebuild/reopen. Remote exact-head CI
and PR outcome remain subsequent gates. GUI/accessibility runtime, source-derived
Forget, native upgrade UI, event watching, live providers/hosts and full phase
closure remain open. Inherited appends, user work, worktrees and reminders remain.

## Publication outcome

PR [#48](https://github.com/suhaasbadada/threadmark/pull/48) passed all five
checks on `ad1052f0ca5bb9c357adee2f750fccd0463f5997`: CI
[43535434885](https://github.com/suhaasbadada/threadmark/actions/runs/43535434885)
and integrated [43535434911](https://github.com/suhaasbadada/threadmark/actions/runs/43535434911).
Fresh exact-head/main/discussion/rules checks found no blocker; independent review
and exact-binding acceptance above applied. It merged at
`2026-11-14T00:43:11Z` as `399f0c8d472c6dc7669f0247182dff3de5bb7b47`;
the PR watch was removed. Post-merge CI
[43536068601](https://github.com/suhaasbadada/threadmark/actions/runs/43536068601)
and integrated [43536068641](https://github.com/suhaasbadada/threadmark/actions/runs/43536068641)
both passed on that exact merge. No real human context was forgotten during testing.
