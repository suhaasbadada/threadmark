# AP — native opt-in ranked human-note search

## Primary integration and independent review

### Older-compiler binding repair

PR #91 head `f1a8a6e92b129a2c04cd1dadfe422e52931c919d`, CI `43606990554`,
macOS job `132483653491` **failed** during Swift 6.1.2 IR generation for
`HumanContextSearchView.swift`: signal 6, "SmallVector unable to grow", in the
compiler-generated String setter thunk. This is not a passing or retried run.
The new direct `Binding` setter method reference was the narrowly identified
trigger candidate; it is replaced with an explicit closure calling the same
byte-exact `setQuery` implementation. No cancellation, input, matching, UI scope
or test assertion is removed. The repair checkout normally merged the publication
head and verified exact full-tree equality before the one-line runtime patch.
Local Swift 6.4 checks cannot prove the 6.1.2 workaround; only a new exact-head
CI run can verify that. Both suites, all fixtures/APIs and bundle remain mandatory.

Owned implementation committed as `0c0320e`, then applied on AN as
**`1fbb169e9238756cadfcc587200a622827886b8c`**, exact integrated tested runtime.
Shared conflicts retain both AN and AP cancellation/history/CAS hooks and both
fixtures/API gates. Added two cross-feature successor cases and extended AP's
local verification script to build/enable AN as well. No baseline merge replay.
The integrated payload intentionally differs from the isolated child.

Joffrey independently reviewed isolated AP **CLEAR**, reproduced its fingerprint,
ran full strict Debug **309 tests/49 suites**, targeted AP **13 tests**, all nine
then-existing API gates and whitespace. A separate fresh integration review was
**CLEAR**, checking conflict unions and both new successor cases; independent
existing-build AP/AN model/decoder tests passed, as did the AP hostile-frame case
with its fixture explicitly enabled. No remote CI or GUI proof was claimed.

Primary full offline workspace **419 tests/doctests PASS**; strict serial full
Debug and Release each **323 tests/52 suites PASS**, actual CLI and all nine C
families enabled, all ten ordinary-import API gates, bundle/plist, offline locked
deny, secrets and whitespace **PASS**. Runtime did not change after these tests.
Two inherited deadline fixtures remain ignored. Nine inherited progress edits
and earlier local receipts remain unstaged/preserved; no worktree cleanup.

AN's diagnosed CI deadline repair was normally merged as
`04bfb4adcb3f51965ec50732d5e39f2255ea4a7e`. Exact diff from the tested runtime in
`apps/companion` is empty; only CI's macOS timeout changes from 12 to 20 minutes
(Linux stays 12), with all gates retained. Integrated AP non-progress binary-diff
fingerprint relative to repaired AN `4754e9723abe36c1db55348814bf2e931413d61b`:
**`4d83a935327ad487f214b0ecd594634e5f3f3c576964f98210359c0ec63cbb51`**
(`git diff --binary BASE HEAD -- .github/workflows/ci.yml apps/companion`).
Repaired AN runs `43606742532`/`43606742538` were confirmed at that repaired head,
initially running; the old canceled 12-minute job is not green evidence. AP's
publication CI is separate. Swift 6.1.2 whole-CI completion, GUI/AX/live quality/
host delivery/phase closure remain open.

## Frozen scope and acceptance (before implementation)

Requirements TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A4/A5/A6,
P3-A4/A5/A6. AO binding/ranking is human-note authority only, not source
authorization, semantic quality, inference or phase completion.

- **AP-01:** mounted explicit Literal default / Ranked any terms, zero-I/O
  choices, explicit Search notes dispatch; preserve AE routing and empty-filter
  disabling. Explain caps, distinct-before-frequency, provenance and omissions.
- **AP-02:** immutable full human binding/raw query/normalized first-seen terms/
  canonical kinds; exact closed AO CLI, stdin EOF, no source permission preflight.
- **AP-03:** distinct duplicate-rejecting bounded closed reply; exact provenance,
  terms, kinds, score/order/counts; retain frame and reparse exact projection on
  adoption; forged typed values cannot grant Inspect eligibility.
- **AP-04:** existing owned cancel/join/generation/config/scope fences; no late
  publication, no namespace fallback, history/original/Edit base/CAS and AJ
  unknown-outcome preservation; genuine explicit bound Inspect only.
- **AP-05:** synthetic real CLI ordering/Unicode/quoted data/latest/kinds/Forget/
  replacement/source independence and preservation; real C malformed-frame and
  ordinary-import API boundary tests; additive CI.
- **AP-06:** strict serial Debug/Release, existing fixture/API regression gates,
  offline workspace/deny/staged secrets/whitespace/bundle evidence and inventory.

Exclusions: AN FileContext implementation, Rust/backend/schema/dependencies/
lockfiles/site/provider/export/Refine/retained semantics. No GUI, host startup,
network egress, Docker, implementation commit, push or PR. Baseline merge only.

## Baseline

Original HEAD `661bdb3e11118efe979cc7adf06c39db723bf133` (clean).
Required AO local base `28e09180c5af7c974e8c49b2a46d0e7bbd3da083`.
Normal `git merge --no-edit` produced
`56f3f929d51f9e52f58b0a3db9b0014c14ed5f5c`, preserving both parents.
No implementation commits authorized. Remote CI/review not run by this unit.

## Evidence

### Implemented boundaries

- The existing Context mount (`HumanContextSearchView`, mounted by the native
  app) adds an independent Literal / Ranked any terms picker. Only Search notes
  dispatches. No appearance, typing, kind or mode selection starts a read.
  Literal off-filter remains the old bound operation; AE selected-kind route and
  decoder stay distinct. Ranked off-filter captures all five canonical kinds;
  an empty explicit filter disables without fallback.
  The query TextField uses a byte-exact local Binding setter rather than Swift
  String-equivalence onChange, so composed/decomposed edits also cancel captures.
- `RankedHumanSearchRequest` captures full byte-exact human binding, raw query,
  first-seen normalized terms and canonical kinds. The strict new process route
  is AO `context search-terms` with full binding, explicit kind list and EOF.
  No reduced Project, source preflight, implicit create/upgrade or ID fallback.
- The distinct AO decoder rejects duplicate decoded keys, unknown/missing keys,
  malformed integers, wrong provenance/terms/kinds/bindings, score forgery,
  incorrect byte-substring matches, row order, counts and truncation. It retains
  the whole <=8192-byte LF frame. Model adoption independently reparses and
  compares exact encoded typed projection. Existing AE/literal decoding remains
  unchanged. No public result initializer, decoder or mutable lifecycle state.
- Existing operation registry cancellation/join fences successors before
  metadata or spawn. Capture freezes owner, model/search/config generations,
  project namespace, mode and kinds. Source policy/currentness is not AO human
  authority; conservative model invalidation still discards old captures.
- Same-namespace errors/cancel preserve history, original, editor and captured
  CAS base/conflict. Namespace replacement uses existing clearing. Mode changes
  also cancel old literal/AE operations. Search choices revoke AJ review through
  existing guards; dispatched-batch unknown outcome/intent remain independent.
- Ranked Inspect requires the currently adopted read identity, current mode,
  namespace and row membership, then uses the full existing bound history read.
  Old rendered result handles cannot reopen a new generation; no edit base is
  installed. Literal Inspect keeps its old entry point.
- Shared lifecycle edits are narrow human-search hooks in removal/Forget/
  source Forget/Build/policy cancellation, plus the existing history loader's
  private independent-human-read path. Primary must reconcile these with AN;
  this unit did not inspect, duplicate or modify AN's FileContext work.

### Reproduction

All fixtures synthetic; no Docker, GUI, AX, host launch or provider used.

```sh
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --offline --locked check
sh apps/companion/Tests/RankedHumanSearchFixtures/verify-local.sh
git add apps/companion/Sources/CompanionKit/RankedHumanSearch*.swift \
  apps/companion/Tests/CompanionKitTests/RankedHumanSearch*.swift \
  apps/companion/Tests/RankedHumanSearchFixtures/* \
  docs/progress/unit-ap-native-ranked-human-note-search.md
python3 scripts/secrets.py
git diff --check
git diff --cached --check
```

The native reproduction compiles all seven existing C fixture families plus AP,
sets their original environment hooks plus `THREADMARK_RANKED_HUMAN_FIXTURE_BINARY`,
then runs full serial strict Debug and Release, all eight existing API gates plus
AP's ordinary-import positive/negative gate, bundle build and plist lint. It uses
the documented command-scoped SDK/header isolation wrapper; no global SDK edits.
Two inherited long deadline tests remain disabled, not re-run by AP.

### Verification status

- Final offline `python3 scripts/check.py`: passed (workspace build/fmt/clippy/
  tests/docs/smoke, documentation links, intentional test-failure negative gate).
  Rust summaries: 419 passed, zero failed, two inherited ignored production
  300-second idle / 30-second provider deadline fixtures; neither run explicitly.
- `cargo deny --offline --locked check`: passed advisories/bans/licenses/sources.
- Staged-new-file `python3 scripts/secrets.py`: passed history/tracked scan and
  synthetic failure gate; repeated after final evidence edits.
- Initial targeted strict Swift and actual rebuilt CLI AP tests: passed.
- First full native reproduction: passed Debug 306 tests / 49 suites, Release
  308 tests / 49 suites (additional tests were added between those builds), all
  nine API gates, bundle and plist. This is intermediate evidence only.
- **Final unchanged non-progress payload:** full strict serial Debug **309 tests
  in 49 suites passed**, full strict serial Release **309 tests in 49 suites
  passed**. Actual rebuilt CLI and all eight C fixture families were enabled,
  including AP exact all-five-kind argv/raw query bytes/nonce/EOF/hostile-frame
  test. All nine ordinary-import API gates passed. Bundle build and plist lint
  passed without GUI launch. Whitespace checks passed staged and unstaged.
- Tooling: Rust 1.97.1, cargo-deny 0.20.2 (cached offline advisory data), Gitleaks
  8.30.1, Apple Swift 6.4, macOS SDK 27.0. SDK wrapper's inherited native-build
  deprecation warning and macOS 13 target / newer Testing.framework linker
  warning remain; strict Swift compiler warnings-as-errors passed.

Local evidence logs retained in the harness-approved temporary directory:
`ap-check-final.log`, `ap-deny.log`, `ap-secrets.log`, and
`ap-native-verified.log`. They are not public payload (compiler logs contain
local paths); reproduction above is authoritative for primary integration.

### Stable acceptance evidence

| ID | Local evidence | Result / limits |
| --- | --- | --- |
| AP-01 | `ap01ZeroIOAndOldRoutes`, empty selection/no fallback, mounted SwiftUI controls and byte-exact query binding | Passed code/unit gate; GUI/AX not run |
| AP-02 | `ap02LimitsUnicodeByteIdentity`, `ap05CArgvEOFAndHostileFrames`, actual CLI suites | Passed full binding, canonical all-five args, exact raw query and EOF |
| AP-03 | `ap03WholeFrameAndForgedProjection`, C hostile frames, fake forged model adoption, order/overlap/count/type/duplicate/LF tests | Passed; independent reparse and exact projection comparison |
| AP-04 | `ap04IgnoringCancelJoinsBeforeSuccessorAndPreservesHistory`, `ap04Lifecycle`, `ap04ModeChangeCancelsOldLiteralAndAEPreservingCAS`, `ap04SameNamespaceFailuresPreserveHumanState`, `ap04AJReviewRevokedAndUnknownOutcomeSurvivesReadonlySuccess` | Passed ignoring-cancel join, no stale Inspect handles, history/original/CAS preservation and AJ warning |
| AP-05 | `ap05RankGainKindsUnicodeLatestAndBudgets`, `ap04CASHistoryInspectSourceIndependenceAndNoWrites`, `ap05ReplacementAfterPrecheckRejectsOldBinding`, `ap05UnindexedStaleAndAbsentSourceRootAreNotHumanAuthority` | Passed native plus actual CLI rank/filter/latest/retire/Forget/rebuild/nonce/source independence; additive CI not remotely run |
| AP-06 | Final 309-test Debug and Release runs; nine API gates; all eight C families; offline workspace/deny/secrets; whitespace; bundle/plist | Passed locally; Swift 6.1.2, independent review and exact integrated CI remain primary gates |

### Owned inventory and payload identity

Tested working tree = baseline merge SHA
`56f3f929d51f9e52f58b0a3db9b0014c14ed5f5c` plus the uncommitted AP payload.
No implementation SHA exists. Non-progress payload SHA-256 is
`a4672da8e8f9ecee1f5c6263c89397988364600f33a0a493093a0cbabc73fd82`,
computed over `git diff --binary HEAD -- .github/workflows/ci.yml apps/companion`
after staging AP new files. This excludes this self-describing progress file and
ignored local build products. Do not cherry-pick the baseline merge as AP payload;
primary takes only the owned diff, reconciling shared hooks with AN independently.

Owned paths (and no other implementation paths):

```text
.github/workflows/ci.yml
apps/companion/Sources/CompanionKit/CompanionModel.swift
apps/companion/Sources/CompanionKit/Contract.swift
apps/companion/Sources/CompanionKit/HumanContextSearchView.swift
apps/companion/Sources/CompanionKit/ProcessService.swift
apps/companion/Sources/CompanionKit/RankedHumanSearch.swift
apps/companion/Sources/CompanionKit/RankedHumanSearchView.swift
apps/companion/Tests/CompanionKitTests/CompanionTests.swift
apps/companion/Tests/CompanionKitTests/RankedHumanSearchLiveTests.swift
apps/companion/Tests/CompanionKitTests/RankedHumanSearchTests.swift
apps/companion/Tests/RankedHumanSearchFixtures/check-api.sh
apps/companion/Tests/RankedHumanSearchFixtures/ranked-human.c
apps/companion/Tests/RankedHumanSearchFixtures/verify-local.sh
docs/progress/unit-ap-native-ranked-human-note-search.md
```

The one-line existing test fake addition handles the new enum case; no existing
literal/source/Refine/retained fixture semantics were rewritten. CI retains its
eight API gates and seven C fixture families and adds AP's ninth gate/eighth
family; primary must union AN's independent CI additions rather than overwrite.

### Limitations and separate gates

Local compiler is Apple Swift 6.4, not Swift 6.1.2 CI proof. Native GUI/AX was not
launched. Independent review, exact integrated-head remote CI, merge, release,
performance and whole-phase closure are not established. AO's source independence
does not grant source access or an atomic external revocation lease. This native
unit does not change backend ranking, schema, persistence, forensic retention,
host permissions or inference. No implementation commit/push/PR was made.
