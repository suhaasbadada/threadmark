# Bounded local project export

Requirements: TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A4/P2-A5/P2-A6.
Exact tested integration: `051f2e45f9fbde6f80f175890fcf94bde065f4e8`, based
on PR #43 merge `de5cb679a6ffe22edabd304c7e6ea794878745fe`. The ancestry
merge changed no tree content. Bob implemented; the coordinator owns publication.

## Contract and product capability

[Export v1](../contracts/project-export-v1.md) was independently reviewed before
implementation. Joffrey identified ambiguous selection/serialization and the
overlap between unavailable content and lost authorization. The coordinator fixed
the wire table, all-record ordering, empty-snapshot semantics and authorization
precedence; Joffrey re-reviewed and cleared both contract findings.

`project export PROJECT --confirm-export-local-content` exports from an existing
recognized private store only. Exact confirmation is required before store open;
export never creates a store, indexes sources, writes a file or sends data. The
complete document is emitted to stdout only on success. Sharing/redirection is
the caller's explicit responsibility; sensitive source/note content is not
automatically safe to share. No credential discovery or actual private export was
performed during this work.

One coherent read transaction binds registration, evidence and complete human
revision history. All eligible anchors are ordered by relative path/line, not the
query's eight-result prefix. Human revisions retain separate authorship and
non-authority provenance. No absolute root/store metadata, environment, provider,
host configuration or request/preview history is included. Complete manifest,
snapshot and exact current source anchors are revalidated. Authorized stale-file
content suppresses all factual excerpts with an explicit limitation; root/store
authorization loss fails. Mid-current-export source changes fail the operation.

Incremental escaped-row accounting bounds the full JSON plus newline at 1 MiB;
overflow rejects the entire archive, never truncates records or emits a prefix.
Cancellation and corruption fail with bounded content-free errors. Read-lock
contention fails without retries or mixed writer/removal state. Project policy,
sources, notes and evidence are not mutated. This is inspection/provenance, not
import/restore or a replacement for Forget/suppression.

## Verification and independent review

Fourteen new synthetic tests cover complete selection/history, isolation,
current/unindexed/stale/empty states, root/store revocation, malformed/foreign
anchors and history, escaped inclusive budgets/overflow, cancellation, source
changes, concurrent writes/removal and no partial stdout. Actual CLI processes
cover confirmation, no implicit store creation, reopen and preservation.

Joffrey independently reviewed implementation conformance with no substantive
findings, ran eleven core export tests and three real CLI export tests, and passed
diff checks. The coordinator's full check pipeline passed on the exact integrated
head: 80 Rust tests plus two doctests, formatting, strict lint, docs, smoke, links
and negative gate. All 43 strict Swift tests passed against the rebuilt actual
core. Dependency policy, staged secrets and whitespace checks passed.

No database schema, third-party dependency, lockfile, GUI or live integration
changed. Remote exact-head CI/PR outcome remains a subsequent gate. GUI/runtime,
Forget, automatic watching, live provider/host acceptance and phase closure remain
open. All worktrees and inherited progress appends were preserved.

## Publication outcome

PR [#44](https://github.com/suhaasbadada/threadmark/pull/44) passed all five
checks on `b410dac367e5afd6505936d7ade58642953152b4`: CI
[43522245973](https://github.com/suhaasbadada/threadmark/actions/runs/43522245973)
and integrated [43522245900](https://github.com/suhaasbadada/threadmark/actions/runs/43522245900).
Fresh exact-head/main/discussion/rules checks found no blocker; independent review
and acceptance above applied. It merged at `2026-11-13T22:53:43Z` as
`7f6e2a248c0ec18b75bd814d1e910b62c8a15fb2`; the PR watch was removed.
Post-merge CI [43522953736](https://github.com/suhaasbadada/threadmark/actions/runs/43522953736)
and integrated [43522953654](https://github.com/suhaasbadada/threadmark/actions/runs/43522953654)
both passed on that exact merge. Export is not inference, delivery or phase closure.
