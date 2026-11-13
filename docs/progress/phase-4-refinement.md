# Phase 4 — Provider-neutral Rust refinement/review engine

## Status and revision

Partial implementation, not phase closure. Requirements: **TM-04–TM-07, TM-10**;
acceptance: **P4-A1–P4-A4** have local structural/failure-fixture evidence only;
**P4-A5 remains open**. Phase 1 live authorization/host/inference gates remain open.
The sequencing exception changes ordering, not scope or authority.

- Frozen integration base: `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Exact locally tested implementation SHA:
  `c71a04149520a19ca5f5ba1b50971028802a638c`.
- This follow-up evidence record is documentation-only; the final handoff also
  identifies and tests its resulting head. No implementation changes follow the
  implementation SHA above in this lane.
- CI run/URL/head: **not run**; no remote push, PR, merge, deployment or release.
- Independent review: **not run**; coordinator owns independent review and exact
  integrated-head CI. Local implementation self-inspection is not that gate.

Specification: [Phase 4](../spec/phase-4-refinement.md).
Integration contract: [client v1](../contracts/client-v1.md).

## Delivered scope

`crates/refinement` is an actual dependency-free, safe Rust 2024 library, explicit
version `0.1.0`, with unsafe code forbidden and missing documentation denied.
It contains immutable bounded captures, provider-neutral structured briefs,
cooperative preparation, preview/edit/review and revalidated handoff **values**.
No Python demo, RPC layer, database, signed receipt or custom hash was added.

- Request freezes original, exact ordered constraint IDs/text, attachment
  references/metadata, destination, project/snapshot, mode and selected evidence.
  Original is bounded to 4 KiB UTF-8; selection to eight items; the entire escaped
  request and conservative full escaped handoff envelope to 8 KiB. Stricter caller
  budgets apply. Overflow rejects the whole value, never truncates or drops data.
- `EvidenceAuthority` is a **trusted core port**, not a caller-ID authorization
  mechanism. It must actually validate registered-root authorization and freshness.
  Exact project, snapshot, selection, provenance and currentness are compared on
  preparation and again on approval/handoff. No request root is opened or trusted.
- Context appends explicitly quoted evidence/coverage without rewriting original;
  Bypass returns exact original. Neither invokes inference, even if provider access
  was supplied. Empty/unindexed context has visible limitations, not fake expertise.
- Refine requires explicit host-supplied consent binding the exact request/data,
  profile/model/endpoint/locality, data scope, deadline and call/output budgets.
  Missing trusted core authorization fails visibly before provider invocation;
  missing/mismatched inference consent is `needs-input`, never an implicit fallback.
  The only data scope is bounded request/selected evidence/attachment **metadata**;
  no attachment contents or whole-project upload is available.
- `Provider` receives frozen request, conservative seed, cooperative control and
  effective output budget. No concrete production or fake provider is shipped in
  the library. Deterministic providers and independent core views are test-only.
- Brief retains exact original/constraints/evidence IDs, candidate objective,
  exact attributed source quotes, proposed decisions, unknowns/questions, proposed
  evidence-backed risks (mechanism/applicability/uncertainty/prevention/check) and
  output expectations. No completed-test or independently verified-claim field is
  provided. Source quotes must exactly match selected current evidence.
- Source strings are escaped plain-text quotations, never top-level instructions,
  permission grants or HTML. Source-origin consent claims grant nothing.
- Material questions and flagged conflicting decisions block prepared approval.
  Empty evidence/unavailable snapshot blocks Refine prepared approval but does not
  turn independent Context into fake inference or fake project expertise.
- Preview exposes exact original, full proposed plain text and a changed indicator:
  a compact side-by-side/whole-replacement diff seam, not a mandatory workbench.
- Review uses private exact typed equality bindings over immutable request, brief,
  trusted evidence view, revision, choice and operation control identity. Any edit
  attempt/retry invalidates earlier approval, including a reverted/rejected edit.
  Destination/attachment/scope/evidence changes cannot reuse approval. A canceled
  operation's approval cannot be revived in an identical fresh engine.
- Explicit use-original can recover after provider failure or an unusable provider
  output budget, preserving exact original and attachments under the request budget.
  Cancel/supersede are terminal for that operation; late results are discarded.
- Delivery is always `not-attempted`. There is no send, clipboard, host transport,
  native launch, network, credential discovery/reuse, content logging, persistence,
  global configuration, background inference or execution capability.

## Coordinator API/integration

1. Convert authorized core query selection to the public v1-shaped evidence DTOs;
   freeze a `RequestData` with `Request::new`. Implement `EvidenceAuthority` using
   actual core authorization/currentness, **not** an echo of untrusted request IDs.
2. Create a monotonic `Control` deadline and `Engine::new(request, control.clone())`.
3. Context/Bypass: `engine.prepare(&core, None)`. Refine: supply explicit
   `ProviderAccess { provider, consent }`; consent includes `request.clone()` and
   the disclosed identity/data/call/output/deadline settings.
4. Show `preview()` and any `brief().questions`/limitations. For Refine edits use
   `edit(brief)` and review again. Treat text as escaped plain text in the UI.
5. After an explicit user choice, call `approve(UsePrepared | UseOriginal, &core)`;
   then `handoff(&approval, &core)` revalidates the exact binding/current evidence.
   Returned `Handoff` is a value only, never delivery or downstream success.
6. `cancel()`/`Control::cancel()` never send. Before starting a replacement, call
   `old_control.supersede()`; use a fresh request/control for new scope.

A compiling context integration example is in `crates/refinement/src/lib.rs`.
Coordinator must remove the temporary nested `[workspace]`, add the crate to root
workspace membership and regenerate the shared lockfile. Nested Cargo.lock/target
artifacts are ignored and **not committed**. Root manifest, root lock, CLI, shared
contract, README, core/store and shell were not changed by this lane.

## Local evidence

All fixtures are synthetic, offline and in-process. On the exact implementation
SHA above, the independent crate commands passed:

```text
cargo fmt --manifest-path crates/refinement/Cargo.toml --check
cargo test --offline --manifest-path crates/refinement/Cargo.toml
  25 integration behavior tests passed; 1 compiling doctest passed
cargo clippy --offline --manifest-path crates/refinement/Cargo.toml --all-targets -- -D warnings
RUSTDOCFLAGS='-D warnings' cargo doc --offline --manifest-path crates/refinement/Cargo.toml --no-deps
cargo deny --offline --locked --manifest-path crates/refinement/Cargo.toml check
  advisories, bans, licenses and sources passed; zero third-party dependencies
```

Repository `python3 scripts/check.py` passed (root workspace foundation checks,
documentation links and intentional failing-test gate). It does **not** include
this temporarily isolated crate: independent commands above are essential.
`cargo deny --offline --locked check` passed for root as well. Offline mode avoids
implicit advisory/source fetching. `python3 scripts/secrets.py` passed after
staging the crate; tracked/history scans passed and the synthetic sentinel was
correctly rejected. Documentation-only head checks are repeated before handoff.

| Acceptance | Local evidence and remaining gate |
| --- | --- |
| P4-A1 | Unicode/negation and immutable intent/constraint/reference checks; unsupported source quotations reject. Free prose semantic quality is not proven. |
| P4-A2 | Exact independently supplied authorized selection, project/snapshot/provenance/currentness checks; stale/unresolvable inputs reject; empty context and flagged contradictory decisions remain visible. Real core authorization integration remains open. |
| P4-A3 | Context/Bypass no-call, explicit consent, provider failure/retry, pre-call budgets/deadline, overflow, material questions, cancel and late/superseded returns; no engine delivery capability. No live provider/host evidence. |
| P4-A4 | Edit/revert/rejected-edit/retry, scope/destination/attachment/evidence/coverage changes, authority revocation and canceled-operation approval reuse reject; handoff revalidates. Integrated host review remains open. |
| P4-A5 | **Open**: no held-out controlled quality evaluation, scoring thresholds, raw comparative results or AI-quality improvement claim. Deterministic fixture calls are not inference quality evidence. |

## Honest limitations and exclusions

Structural validation is not NLP: arbitrary generated objective/risk/expectation
prose remains explicitly **unverified** and human-review-required. The engine does
not guarantee semantic fidelity, detect every contradiction, establish permission
from text, prove a claim true, or assert that proposed checks ran/passed. Providers
and hosts must surface material ambiguity; local fixtures test known flags and
structural rejection, not universal hallucination prevention.

Provider execution is synchronous and **cooperative**. Cancellation/deadline are
supplied; budgets are consumed before invocation and late returns reject. The
engine does not forcibly stop an arbitrary blocking/noncooperative implementation,
bound its allocations, or claim bounded wall time for it. Such implementations need
a host-owned isolated execution boundary. Trusted core calls are likewise supplied
by the host. A freshness check is current-at-read, not an atomic lease on future
host delivery. No real core adapter or inference authorization is fabricated here.

Phase 4 remains partial pending real core/provider authorization integration,
qualified independent review, exact integrated-head CI, host review interaction
and controlled evaluation. Phase 1 live host/inference, daemon listener, storage,
certified host support, hands-free execution, deployment and release are not
established or authorized by this work.
