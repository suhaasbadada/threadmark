# Explicit local project removal

Requirements: TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A3/P2-A5 and
P3-A3/P3-A4 evidence. Phase 2 lifecycle is not complete. Exact locally tested
integration: `b0726d9f9669768107ddf80b8648ff92d3578779`, based on PR #41 merge
`6ae0dd82d674358ff124a8221d9f87d0fec04a00`. The ancestry merge changed no tree
content. Bob implemented the operation; the coordinator repaired the review
finding and owns publication.

## Operation contract

`project remove PROJECT --confirm-remove-local-data` requires exact explicit
confirmation before opening or creating storage. Inside the existing authorized
private store, an immediate SQLite transaction removes only the selected
registration, source evidence and all human-note revisions. No source root or
file is opened for deletion, changed or removed. Other projects remain intact.
The non-content receipt identifies the local project and retention limitations.
Cancellation at each deletion stage rolls back; cancellation is checked just
before commit. The commit boundary is authoritative for completed removal.

This is not Forget/suppression or forensic erasure. SQLite free pages, sidecars,
backups and exports may retain historical bytes. Explicit re-registration and
reindexing can import approved sources again but cannot restore deleted human
history. There is no schema migration, dependency or lockfile change, no listener,
no UI removal control, and no product inference or external content egress.

## Concurrency, recovery and review

Tests cover reopen/re-registration, two-project isolation, source preservation,
invalid/unknown IDs, missing confirmation without store creation, staged cancel,
SQL-abort rollback after child-table deletion, and held indexing during removal
or different-root replacement. Index publication rechecks root identity and exact
source policy transactionally so an old worker cannot populate a replacement root.

Joffrey's initial independent review found a medium race: a pending note write
checked registration presence but could cross a remove/re-register boundary into
a different root. The coordinator added transaction-time exact captured-root and
root-identity validation to note writes, source-policy changes, retirement and
removal. A deterministic four-operation test splits the actual production
preflight/transaction continuations using a second connection, replaces the root,
and proves every pending operation rejects without changing replacement policy,
snapshot, evidence or history. Joffrey independently re-reviewed these paths,
cleared the finding and ran all 24 knowledge tests successfully.

The coordinator's full check pipeline passed on the exact integration revision:
63 Rust tests and two doctests, strict formatting/lint/docs/smoke/negative gate.
All 34 strict Swift tests passed against its rebuilt real core. Dependency policy,
staged secrets and whitespace checks passed. Remote exact-head CI and PR outcome
remain subsequent gates. GUI/accessibility runtime, Forget, export, automatic
watching, live provider/host acceptance and phase closure remain open. Inherited
progress appends and worktrees were preserved; no real user project was removed.

## Publication outcome

PR [#42](https://github.com/suhaasbadada/threadmark/pull/42) passed all five
checks on `8806ce1da1c98abcb3d5cd45aa95d4326220ceb9`: CI
[43512825689](https://github.com/suhaasbadada/threadmark/actions/runs/43512825689)
and integrated [43512825781](https://github.com/suhaasbadada/threadmark/actions/runs/43512825781).
Fresh exact-head/main/discussion/rules checks found no blocker; independent
review and the repaired replacement-root race acceptance above applied. It merged
at `2026-11-13T21:44:51Z` as `90a9cce830f2d284edf5f9097a78dcf0fd026b9e`;
the PR watch was removed. Post-merge CI
[43513420854](https://github.com/suhaasbadada/threadmark/actions/runs/43513420854)
and integrated [43513420917](https://github.com/suhaasbadada/threadmark/actions/runs/43513420917)
both passed on that exact merge. No deployment or real user-data deletion occurred.
