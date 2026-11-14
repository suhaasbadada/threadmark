# Unit AN — mounted native file-scoped Context

## Primary integration and independent review

### macOS CI deadline repair

Publication head `db4c1cbf390d66236e02793ff04482f006b1a854`, CI `43604701177`,
macOS job `132476724243` concluded canceled with the authoritative annotation
**"The job has exceeded the maximum execution time of 12m0s"**. It is a blocker,
not green or a transient failure being blindly retried. The retained job trace
shows strict Debug **309 tests PASS**, strict Release **309 tests PASS**, all nine
API gates PASS, and the final bundle product linked before the outer deadline;
final bundle/plist completion was not certified. Linux and security passed;
integrated run `43604701219` passed separately at that head.

The AN checkout normally merged its publication head; exact full-tree equality
with that head was verified before this repair. Runtime/test payload is unchanged.
Only the macOS matrix timeout is raised to a bounded **20 minutes**; Linux stays
at 12. Debug, Release, every fixture/API gate, bundle and plist remain mandatory.
No explicit operator cancellation was overridden or job retried. A new push/run
must be verified at its new full head before any success or merge claim.

Owned child implementation committed as `c5c3d25`, then cleanly applied on
merged AO as **`5f0ad07c5087de62cd7bcc3a1db958abc10771da`**, exact integrated tested
runtime. Only the owned diff was applied; no baseline/site merge replay, conflict
repair or unrelated edit was included. Fifteen-file payload fingerprint reproduced
after integration, identical to
**`236e37961fe87cd959d4b478fcb4c9642d880b4f00300449d863fa87aae6c423`**.

Joffrey independently reviewed **CLEAR**, verified baseline/inventory/fingerprint,
and checked independent Query/Context/Refine scopes, exact full binding, strict
wire/adoption validation, joined lifecycle, human preservation and batch uncertainty.
He reran strict targeted Debug **60 tests** (one batch C test skipped without its
variable), targeted Release **59 tests with none skipped**, new API and whitespace.
No full Rust/native/security/bundle/remote/GUI proof was claimed by that review.

Primary full offline workspace gate **419 tests/doctests PASS** against merged AO;
strict serial full Debug and Release each **309 tests/50 suites PASS**, actual CLI
and all eight C-fixture families enabled. All nine ordinary-import API gates,
offline locked deny, secrets/whitespace and bundle/Info.plist **PASS**. No runtime
changes were made after these tests; publication-head CI remains separate.
Two inherited long-deadline fixtures remain ignored. Swift 6.1.2 CI, GUI/AX,
live inference, host delivery and phase closure remain unverified by local runs.

AO #89 exact post-merge integrated run `43603445495` passed at
`1a6b8387074240261bcefacbe8343ad24e01ff31`; CI `43603445471` was still running at
the initial integration read, not claimed green. AP native ranked-note search
continues independently. Nine inherited progress edits, earlier local merge
receipts, worktrees and parent continuation reminders are preserved.

## Predeclared scope and acceptance

TM-01–TM-07, TM-10; partial P2-A1–A6, P3-A3/A4/A5/A6, P4-A1/A2/A3.
Phase 2/3/4 remain open. Read their specifications, AM/AK contracts, AL complete
binding/decoder/lifetime and AJ revocation/uncertainty boundaries before design.

- **AN-A1:** mounted Context-only opt-in over current registered sources; old
  default route unchanged; empty disables Prepare, inert choices, independent
  Query (including empty subset), Refine and retained consent.
- **AN-A2:** immutable full-bound request, exact original <=4096 UTF-8 stdin,
  closed AM argv, shape admission before spawn; no metadata probe or wide fallback.
- **AN-A3:** distinct closed duplicate-rejecting <=8192 including LF frame;
  exact scope/mode/original, honest state/counts/coverage/truncation, bounded
  selected provenance; raw frame reparsed independently at adoption.
- **AN-A4:** owned registry cancel/join before successors; capture owner,
  generation/configuration/scope/original revision; all relevant edits revoke
  delayed output, preserve drafts/history/Edit base/CAS and batch uncertainty.
- **AN-A5:** actual CLI 64+64 and late selected anchor, full-policy stale/unsafe,
  root/nonce/policy/snapshot and Forget rejection without resurrection or B text;
  source and human notes preserved. Native claims no atomic source lease.
- **AN-A6:** strict serial Debug/Release, actual CLI and fixture families, all
  eight existing plus additive API gate, full offline check/deny/secrets,
  whitespace and bundle/plist; honest version/CI/review limitations.

## Baseline / ownership

Initial clean HEAD `661bdb3e11118efe979cc7adf06c39db723bf133`. Authorized normal
`git merge --no-edit 8873b267b099efcc5545508a54ff8d46ee0be874` produced sole baseline
merge `597b1891bdfde7e5821ebb08346a2c78ed4e7da2` (those parents in order).
Prepared baseline/site ancestry preserved. No reset, switch or new worktree.
Primary integrates only owned uncommitted diff, never this baseline merge.

Excludes Rust/backend/schema/client-v1/Refine profile or consent architecture,
dependencies/locks/site, provider/host execution, external network, GUI/AX,
credentials, commits (except baseline), pushes/PRs/deployment/Docker/subagents.
No remote CI or independent review exists for this uncommitted payload.

Baseline tree: `4d5a7b81d65245d0b52ec3e9c4a5764cc40d7911`.
Full tested identity is **`597b1891bdfde7e5821ebb08346a2c78ed4e7da2` plus the
uncommitted payload**, not HEAD alone. Fifteen-file payload SHA-256:
**`236e37961fe87cd959d4b478fcb4c9642d880b4f00300449d863fa87aae6c423`**.
Hash the following inventory in lexical relative-path order: UTF-8 path + NUL +
exact working-tree bytes + NUL. Exclude this progress document (self-reference).

## Owned inventory

1. `.github/workflows/ci.yml`: build/enable additive Context C fixture; retain
   original seven C families and all eight existing API gates; add ninth gate
   and explicit serial strict Release tests alongside strict Debug.
2. `apps/companion/Sources/CompanionKit/FileContext.swift`: immutable full-bound
   request, distinct closed AM decoder, retained frame and independent adoption.
3. `apps/companion/Sources/CompanionKit/FileContextView.swift`: inert native
   Context-only registered-policy controls and scope/freshness disclosures.
4. `apps/companion/Sources/CompanionKit/CompanionModel.swift`: narrow captures,
   registry-owned direct operation, adoption, lifecycle and preservation hooks.
5. `apps/companion/Sources/CompanionKit/Contract.swift`: additive operation/reply.
6. `apps/companion/Sources/CompanionKit/ProcessService.swift`: AM closed argv,
   exact bounded stdin/EOF, whole stdout cap and distinct decoder.
7. `apps/companion/Sources/CompanionKit/QueryFilter.swift`: only make AL's
   syntax-only parser and nonoverlap counting helper module-internal for reuse;
   no duplicate Query implementation or Query wire/behavior change.
8. `apps/companion/Sources/CompanionKit/QueryFilterView.swift`: accurate independent
   Context scope disclosure, no inherited Query subset.
9. `apps/companion/Sources/CompanionKit/RefinementPreviewView.swift`: one eligibility
   binding now uses the unchanged full-scope predicate, not Context's new subset
   predicate. No Refine profile, consent, serialization, transport or architecture
   change. Empty Context selection cannot disable explicit Refine inspection.
10. `apps/companion/Sources/ThreadmarkCompanion/main.swift`: actual preparation mount.
11. `apps/companion/Tests/CompanionKitTests/FileContextTests.swift`: closed frame,
    exact bytes, inert choices, fake-service lifecycle/preservation/batch tests.
12. `apps/companion/Tests/CompanionKitTests/FileContextLiveTests.swift`: actual CLI
    scope/freshness/Forget/races/store failures, exact process transport and bounds.
13. `apps/companion/Tests/CompanionKitTests/CompanionTests.swift`: additive exhaustive
    fake rejection arm only; no inherited assertions changed or waived.
14. `apps/companion/Tests/FileContextFixtures/context.c`: exact 146 argv elements
    excluding executable (argc 147), staged expected argv/raw stdin/whole response.
15. `apps/companion/Tests/FileContextFixtures/check-api.sh`: ordinary-import positive
    explicit request/control/action plus negative mutation/lifetime/publication/
    unbound request/frame constructor/decoder probes.

Plus this progress document. All other baseline bytes are untouched. New files
are staged solely for the tracked-file secrets scanner; existing modifications
remain unstaged. Primary must integrate **`git diff HEAD`**, not only index or
unstaged diff. No implementation commit, push, PR, CI run/head/URL or independent
review exists in this child. Primary owns those distinct gates.

## Product / authority boundary

Mounted only in the existing occasional Context preparation surface. Default
remains all approved sources using the old bound literal/ranked Context route.
Opt-in starts with an explicit empty selection: Prepare is disabled with guidance,
never all-files fallback. Choices come only from current registered Project.sources,
not policy drafts, discovery or a filesystem picker, and canonicalize to captured
full-policy order. Unknown/duplicate paths are rejected. Choices and radius/mode
changes never prepare, perform service I/O or call a provider. Appearance merely
renders native controls. No GUI/AX walkthrough or host launch was performed.

Query choices, including an empty Query subset, never change Context candidates.
Context choices never change Query candidates. The existing shared Source Query/
Context algorithm picker remains accurately labeled. Refine and retained review
keep independent full-scope retrieval/consent, with no automatic preparation,
provider coupling, widening or transmission. AL's mounted disclosure now explicitly
states Context has its own independent file scope. Refine's prior eligibility was
shared with Prepare Context; only that predicate was split to avoid new coupling.

The immutable FileContextRequest freezes full Project root bytes/identity/non-null
incarnation/ordered FULL policy/nullable snapshot, raw query, raw original, explicit
algorithm and canonical nonempty subset. Private model action adds owner, generation,
configuration generation, scope revision and original/query revision. Process shape
admission precedes executable filesystem inspection/spawn; original is nonempty,
<=4096 UTF-8 bytes, no NUL, passed only as exact stdin, never argv or trimmed.
Direct `context prepare-files` uses AM's closed two-list grammar. No project-show
precheck, unbound reload, reduced Project, writable diagnostic, recovery probe,
automatic retry, shortened scope or wide fallback exists in this route.

AM's actual response has no root or nonce echoes: none invented. Entire JSON plus
LF must fit <=8192. Exact closed keys/types at every level, version/project/mode/
subset/original, state/provider/approval/delivery, snapshot/coverage/selection/
truncation/count consistency, bounded selected-and-approved evidence, lowercase
64-hex hashes, bounded producer identity, coordinates, sequential engine IDs,
lexical match/order and duplicate-anchor rejection are enforced. Scores are not
AM wire fields and are rejected as extras; ranked ordering is independently
checked with AL's existing term/nonoverlap helpers. Decoded/escaped duplicate keys,
fractional/exponent/Boolean integers and additional/partial frames are rejected.
The raw whole frame is retained and reparsed against the immutable request at
adoption, then byte-compared to all typed display projections. A forged projection
cannot publish. Context evidence does not grant Query Inspect membership.

Existing preview rendering shows verbatim original/proposed data; no composer,
normalization, regenerated original or hand-built brief. The engine's quoted
untrusted-source header is required for ready output; source instructions grant
no execution or permission. Missing/stale/unindexed/no-selected-evidence results
are honestly needs-input, unchanged original and changed=false. Selected scope
is shown separately; no semantic-quality or fabricated readiness claim.

The existing registry joins all predecessors and refresh-driver shutdown before
successor service/spawn. Query/original/mode/Context subset/Query subset/policy/
Build/Forget/Cancel/settings/configuration/project/Quit changes revoke old captures
and drop delayed output. Deliberate successors alone may fetch/adopt metadata after
join; Context never adopts response-selected metadata. Same-namespace failures,
invalid/empty input and cancellation preserve editor revision, loaded history,
old Edit base, original and CAS conflict. Existing explicit project/configuration
changes and authoritative namespace replacement retain their prior clearing rules.
No failure is reclassified by a diagnostic probe. Existing uncertain mutation
errors remain visible when Prepare is denied. Pending batch review is invalidated
without execution; dispatched batch cancellation synchronously revokes execution,
joins it and retains staged intent and its separate persisted-outcome-unknown warning.

Subset scope restricts **output candidates only**. ALL approved sources still
receive freshness reads; an unselected changed/unsafe file can stale the entire
snapshot. Native does not prove an atomic source lease; AM owns the frozen binding
and repeated source-freshness checks across engine reads. No permissions/privacy,
I/O avoidance, AST/semantic coverage, filesystem-lock or performance gain is claimed.
Retained/export/inspection/coverage/incremental/human-search/Query semantics and old
Context/Refine transports/serialization are unchanged.

## Actual acceptance evidence

| ID | Evidence |
| --- | --- |
| AN-A1 | Both algorithms: default uses old full-bound route; empty Context disables Prepare with zero calls; canonical registered sources, unknown path rejection, Query-empty independence, explicit separate Refine inspection and zero provider calls. Mounted native view compiles. Empty Context does not disable Refine inspection. |
| AN-A2 | Actual CLI 64 approved + 64 selected, with both no-match and genuine late-file evidence. C fixture checks all 146 arguments and exact Unicode/decomposed Unicode/quotes/backslash/CRLF stdin and EOF in both modes. Max 128-byte ID, 4096-byte root, 128-byte identity, 64 x 240-byte paths in both lists, 256-byte query and 4096-byte original traverse fixture; decode error (not child failure) proves accepted exact transport. Actual CLI rejects oversized scope whole without store creation. |
| AN-A3 | Both modes: missing/extra/duplicate/escaped-duplicate keys, wrong types/fields/state/snapshot/scope/selection/counts, forged scores, wrong/nonselected/duplicate anchors, hashes/producers/coordinates, literal/ranked matching, canonical order, exact original normalization/trim/NUL mismatch, truthful stale/no-evidence original, positive truncation, typed projection forgery and exact 8192 including LF accepted / +1 rejected. Real CLI rejects an unfit 4096-byte original frame without publishing preview; C hostile outputs fail whole. |
| AN-A4 | Cancellation-ignoring A across subset/query/original/Query subset/Query text/mode/radius/settings/policy/project/Build/incremental/Forget/source-Forget/Cancel/configuration/Quit/invalid input. Successor calls cannot overtake teardown; B publishes only its own original/scope; beta adoption is intentional after join, no A preview. CAS/base/editor/history/original preservation, no failure diagnostic calls, and both undispatched batch review invalidation and dispatched preclaim revocation/join with persistent uncertainty/staged intent are asserted. |
| AN-A5 | Actual CLI: 63 earlier stronger unselected matches never enter selected z.rs preview; full 64-file scope with a late-only match retains z.rs. Unselected edit and symlink produce honest needs-input/unchanged original; peer root/identity/nonce/policy/snapshot changes reject old captures with no B result. Source Forget rejects old capture and new forgotten subset; rebuild does not resurrect z.rs; source bytes and independent human note preserved. Missing/invalid stores fail without creation/repair. AM's existing three-boundary Rust race tests pass in full offline workspace check. |
| AN-A6 | Gates below. No provider-live/host/GUI/AX run, external network, production deployment or phase closure. |

## Verification / reproduction

All final gates **PASS**:

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **403 Rust tests + two
  doctests**, formatting/build/all-target clippy/rustdoc, finite diagnostics,
  offline local doc links and intentional failing-test rejection sentinel. The two
  inherited 300/30-second deadline tests remain ignored and were **not rerun**.
- `cargo deny --offline --locked check`: advisories/bans/licenses/sources pass
  using locally cached advisory data; no advisory-refresh claim.
- Documented SDK-isolated wrapper, strict concurrency/warnings-as-errors,
  `--no-parallel --disable-xctest --enable-swift-testing`: full Debug **309 tests /
  50 suites** (65.760s), then full Release **309 / 50** (70.544s). Actual CLI and all
  eight C families enabled in both, including the original seven unchanged families.
- All **nine** ordinary-import API gates; original eight retained: retained,
  source inspection, comparison, human-kind filter, coverage, incremental, batch,
  Query filter, plus new FileContext gate.
- New files staged then `python3 scripts/secrets.py`: tracked-file scan and
  synthetic secret rejection pass; staged/unstaged whitespace checks pass.
- `sh apps/companion/scripts/bundle.sh` and
  `plutil -lint apps/companion/dist/Threadmark.app/Contents/Info.plist`: pass, not launched.

Local compiler is **Apple Swift 6.4**, target arm64 macOS. Hostile/mixed arrays have
explicit element types to avoid known older-compiler inference problems, but this
is **not Swift 6.1.2 CI proof**. No remote exact-head CI exists for this uncommitted
payload; CI wiring is prepared, not claimed run. Independent review was not run.

Logs (ignored/local-only; may contain local paths, not public artifacts):
`target/unit-an-check.log`, `unit-an-deny.log`, `unit-an-full-debug.log`,
`unit-an-full-release.log`, `unit-an-api.log`, `unit-an-secrets.log`,
`unit-an-bundle.log`. Earlier targeted logs are also retained; final full runs above
are acceptance evidence. Self-inspection found and repaired local invalid-input
CAS/uncertainty masking before the final full Debug/Release runs; no waiver.

From repository root, run the Rust/deny commands above, build all eight C fixtures
with the exact SDK-isolated clang commands in `.github/workflows/ci.yml` (including
retained mode copies), and export its native-step environment variables using
absolute paths under this checkout. `THREADMARK_CORE_TEST_BINARY` must target the
actual `target/debug/threadmark`; each fixture variable must point at its compiled
family (including `THREADMARK_FILE_CONTEXT_FIXTURE_BINARY`). Then:

```sh
sh apps/companion/scripts/swift.sh test --no-parallel --disable-xctest --enable-swift-testing -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
sh apps/companion/scripts/swift.sh test -c release --no-parallel --disable-xctest --enable-swift-testing -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
sh apps/companion/scripts/check-retained-api.sh
sh apps/companion/Tests/SourceInspectionFixtures/check-api.sh
sh apps/companion/Tests/ComparisonAPIFixtures/check-api.sh
sh apps/companion/Tests/HumanSearchFilterAPIFixtures/check-api.sh
sh apps/companion/Tests/CoverageFixtures/check-api.sh
sh apps/companion/Tests/IncrementalBuildFixtures/check-api.sh
sh apps/companion/Tests/BatchEditAPIFixtures/check-api.sh
sh apps/companion/Tests/QueryFilterFixtures/check-api.sh
sh apps/companion/Tests/FileContextFixtures/check-api.sh
sh apps/companion/scripts/bundle.sh
plutil -lint apps/companion/dist/Threadmark.app/Contents/Info.plist
```

Stage the new inventory files and this document before the secrets command;
`git diff --check` and `git diff --cached --check` must both pass. Leave all work
uncommitted and intact for primary integration of only this unit's owned diff.
