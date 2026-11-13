# Native project-removal confirmation

Requirements: TM-01–TM-03, TM-07, TM-10; partial P2-A1/P2-A5 and
P3-A3/P3-A4/P3-A5 evidence. Exact tested integration:
`48f1cb98a7af59d97fcd5b0e63a9a1cc224b1d3c`, based on PR #42 merge
`90a9cce830f2d284edf5f9097a78dcf0fd026b9e`. The ancestry merge changed no tree
content. Bob implemented; the coordinator owns integration and publication.

The Projects view offers a separate removal confirmation showing immutable
project ID, root and root identity. Cancel is the default action and dispatches
nothing. The destructive action explains loss of all local notes/history and
evidence, source preservation and retention limitations. Source/project/config
changes invalidate pending confirmation; repeat/stale confirmation cannot dispatch.

The shell always supplies exact expected root and root identity through the CLI
`--expected-root ROOT --expected-root-identity IDENTITY` pair, in addition to
`--confirm-remove-local-data`. Core compares the captured registration with the
approval and rechecks under its deletion transaction. A reused local ID cannot
redirect the confirmed removal to a different root. These values are stale-approval
guards, not authenticated credentials or permission to read new sources. Invalid
binding shapes fail before store creation. Existing explicit unbound CLI removal
remains available, but is never used by the GUI adapter.

The adapter requires an exact typed, content-free receipt with at most 1 KiB of
output. No generic acknowledgement is success. Model success additionally requires
a fresh project listing with the removed ID absent. Pending/running removal clears
dependent selection/previews/drafts; canceled or uncertain outcomes require Refresh
and never claim rollback after commit. Owned-operation serialization and late-result
suppression are preserved. No automatic selection or source deletion follows.

Local full Rust checks passed: 68 tests including two doctests, formatting, lint,
documentation, smoke, links and negative gate. All 43 strict Swift tests passed
against the rebuilt actual core, including synthetic SQLite removal, mismatched
replacement-root rejection and preservation of sources/other-project notes. Bob's
release bundle/plist passed. Joffrey independently cleared all 14 app/crate files,
ran three targeted Rust tests, rebuilt the CLI and passed all 43 Swift tests.
The coordinator repeated full Rust and actual-core Swift verification on the exact
integration head. Dependency policy, staged secrets and whitespace checks passed.

No schema, third-party dependency or generated lock changed. No real user data was
removed. Remote exact-head CI remains a subsequent gate. GUI launch/accessibility
runtime, Forget/suppression, export, background watching, live provider/host gates
and full phase closure remain open. Worktrees and unrelated appends were preserved.

## Publication outcome

PR [#43](https://github.com/suhaasbadada/threadmark/pull/43) passed all five
checks on `25e2a26bf5a764eaa7e55de5dfdafe79d5492d9e`: CI
[43515049339](https://github.com/suhaasbadada/threadmark/actions/runs/43515049339)
and integrated [43515049263](https://github.com/suhaasbadada/threadmark/actions/runs/43515049263).
Fresh exact-head/main/discussion/rules checks found no blocker; independent review
and scoped acceptance above applied. It merged at `2026-11-13T22:01:08Z` as
`de5cb679a6ffe22edabd304c7e6ea794878745fe`; the PR watch was removed.
Post-merge CI [43515723262](https://github.com/suhaasbadada/threadmark/actions/runs/43515723262)
and integrated [43515723037](https://github.com/suhaasbadada/threadmark/actions/runs/43515723037)
both passed on that exact merge. GUI/provider/host gates remain separate.
