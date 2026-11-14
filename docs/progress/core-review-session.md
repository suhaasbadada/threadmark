# Core-backed retained refinement review

TM-04–TM-07/TM-10; bounded P2-A1/A6 and P4-A1–A4 integration evidence, not
phase closure, semantic quality evaluation or host-delivery certification.

The coordinator's product unit adds `preparation::ReviewSession` over the actual
SQLite core and existing provider-neutral engine. Capture accepts user intent,
never caller-provided evidence/snapshot; core supplies the current bounded
selection. A frozen request is exposed for exact profile/model/endpoint/data/
budget consent. Refine requires explicit `ProviderAccess`; no discovery, network
client, credential reuse or implicit consent is added here. Context/Bypass remain
provider-free. The engine is retained for retry, preview, user edits, exact review
approval and revalidated handoff values; nothing is sent or persisted.

Registration root/identity/incarnation and exact source policy are captured once
and bracket every subsequent authority read. Preview also refreshes authority
before publication. Replacing a same-ID registration even at the same root and
snapshot cannot revive old consent/review. Legacy stores without incarnations
fail closed without automatic migration. Material source changes/revocation,
cancellation, supersession and deadline invalidate use; the original remains in
memory. Query work is core-bounded with operation checkpoints before/after, not
a promise of mid-query interruption. Providers still require their own bounded
execution boundary and cooperative cancellation; this API is synchronous.

Actual SQLite plus synthetic provider fixtures cover explicit consent/no-call
without it, bounded retry budget, editable retained review, invalidated approval,
explicit original after failure, late canceled results, changed sources during
inference, forged capture, unknown project, source policy revocation, same-root
registration reuse, supersession and expired capture. Fixtures remove only their
owned synthetic directories. No user store, provider service or host is touched.

Provider configuration/transport and companion runtime/UX are concurrent separate
owned lanes. Native wiring, remote inference authorization, secure credential
entry, actual GUI/AX proof, quality evaluation, host draft APIs and phase closure
remain separate gates. Publication/review/exact-head CI evidence is pending.

## Local review and integration evidence

Joffrey independently reviewed the actual-core session and post-provider freshness
check, found no substantive issues, and passed six SQLite integration tests,
25 engine tests and the refinement doctest. The coordinator passed the full
workspace gate (143 Rust tests plus two doctests), dependency policy, secrets,
whitespace and all 105 strict Swift tests against the rebuilt actual CLI. The
source-change-during-inference regression initially exposed the missing final
authority read; the engine now revalidates before accepting the brief, and the
regression passes. No live provider or host was used. Exact publication head and
remote CI remain pending, not inferred from these local results.

## PR #52 publication outcome

PR [#52](https://github.com/suhaasbadada/threadmark/pull/52) passed all five checks
on exact head `e56623a0b68af71657908bbcb085ff6c282c76b8`: CI
[43549487017](https://github.com/suhaasbadada/threadmark/actions/runs/43549487017)
and integrated [43549487004](https://github.com/suhaasbadada/threadmark/actions/runs/43549487004).
Fresh exact-head/main/rules/discussion checks found no blocker; recorded independent
review and acceptance applied. It merged at `2026-11-14T03:15:59Z` as
`8e46da24ecf14422c580a4c3ef93219d5d8a8bf9`; the PR watch was removed. Separate
post-merge CI [43550727189](https://github.com/suhaasbadada/threadmark/actions/runs/43550727189)
and integrated [43550727139](https://github.com/suhaasbadada/threadmark/actions/runs/43550727139)
both passed on that exact merge. Provider and native integrations are later units,
not retroactively covered by those checks.
