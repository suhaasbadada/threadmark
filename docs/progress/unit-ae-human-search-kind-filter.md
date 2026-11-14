# Unit AE — explicit kind-filtered saved human context search

## Required CI failure and deterministic fixture repair

PR #80 first head `d8010cc3c6d978ad86fda442c1838b15913013ee` failed CI
[`43588766553`](https://github.com/suhaasbadada/threadmark/actions/runs/43588766553),
Ubuntu job `132428811737`: existing knowledge regression
`rejected_child_may_close_stdin_before_the_fixture_writes` required `BrokenPipe`
after waiting for one rejected child, but the nine-byte write returned `Ok(())`.
Primary retained/read its complete job trace in ignored
`target/unit-ae-ci-ubuntu-failure.log`. Inspected every job: this was the only
failed job; macOS/security and integrated run `43588766554` passed at that old
head. They are not evidence for the repair head. No retry or failure waiver.

Sherlock independently established the test's insufficient synchronization:
waiting for one child does not establish that every pipe-reader reference closed.
Transient reader inheritance by concurrently spawning processes is credible, not
proven by the trace; no Linux descriptor reproduction is claimed from macOS.

Primary repaired only the private fixture/test: default `finish` still performs
real writes; shared `finish_with_writer` retains the original Ok/BrokenPipe/error
classification, drops stdin before waiting, and permits BrokenPipe only for a
failed child. Real argument-rejection/empty-stdout/no-store behavior remains
tested. Injection deterministically exercises BrokenPipe with a real failed child;
a real successful `--version` child must trigger the specific early-close guard.
No sleep, polling, retry, global serialization or runtime behavior changed.

Repair tested runtime **`c82473e76c55e3072b22e02987931fa62a2b5c7f`**:
21 knowledge integration cases **PASS**, full workspace **328 Rust tests + two
doctests PASS**, offline locked deny, secrets and whitespace **PASS**. Prior native
source is unchanged; no fresh native run is inferred from this test-only repair.
Joffrey independently reviewed **CLEAR**, ran all 21 knowledge tests/whitespace;
did not rerun full pipeline or CI. Fresh pushed-head CI remains required.

## Primary integration and independent review

The preliminary child handoff explicitly had native verification still running;
primary did not treat that as a pass or restart the invocation. Native completion
then delivered the frozen-source final receipt below. Primary read the settled
child result and only then requested independent review. No duplicate worker.

Joffrey independently reproduced both fingerprints, reviewed all 21 owned files
**CLEAR**, and passed six Rust core, four actual CLI, six strict Swift tests/two
suites (fake/live adapter), filter API gate and whitespace. Full pipeline/bundle
results at that point remained lane-reported; no GUI/Swift 6.1 or CI claim.

Primary committed only owned files as `3817c6d` and applied cleanly as `bba91e3`,
reconciling AD's shared core/daemon/CLI additions without textual conflicts or
baseline/site history replay. CI now invokes the fourth, filter API compiler gate.
Exact integrated tested runtime **`14adb52d710fdc1245130d7a75d1622ad56a3584`**:
full workspace **327 Rust tests + two doctests PASS**; strict serial actual-CLI/
all-C-fixture Debug and full Release each **245 tests/38 suites PASS**; all four
API gates, offline locked deny, staged secrets/whitespace, release bundle/plist
**PASS**. Two unchanged long deadlines ignored. Publication CI remains separate.

PR #79 passed all five checks at `26a2efa02e8f315885ee25573d6971ed00fa6f51`
(CI `43587483663`, integrated `43587483669`), fresh exact-head/main/check/review/
approval/discussion/rules gates preceded merge
`e26aea6ec00fabb0e56ba259fa858f61ce2d758e`. Watch removed. Its exact post-merge
runs `43588017452` and `43588017421`, both targeting that merge, **PASS**.
Native coverage inspection remains independently active. Nine inherited progress
edits, worktrees and parent reminders preserved. No GUI/AX/live-quality/host-
delivery/phase closure inferred from any local/CI/merge gate.

Requirements TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A4/A5/A6,
P3-A4/A6. [Phase 2](../spec/phase-2-knowledge-core.md) and
[Phase 3](../spec/phase-3-background-experience.md) remain open.
The versioned [contract and stable AE-01–AE-07 acceptance IDs](../contracts/human-search-kind-filter-v1.md)
were written before runtime implementation. This is human-only literal lexical
search, not semantic retrieval, source truth, authentication or conflict resolution.

## Baseline and ownership

- Initial assigned checkout clean at `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Authorized normal `git merge --no-edit 4de4b4a2bd844cc850e5ecfd050019cf3616221e`
  produced merge-only baseline **`a432f34f82ba169a5f08fa0c8bad8e4366d5c1e3`**,
  preserving both prepared baseline/site history and the required local base.
- Runtime is **uncommitted**; the baseline SHA alone is not the implementation.
  Primary must take only the owned diff, not replay baseline/site merge history.
  No reset/switch/new worktree, implementation commit, push, PR or deployment.

Owned inventory (paths relative to repository root):

- `crates/core/src/knowledge/human_search.rs`: validated immutable canonical
  `HumanSearchKinds`, mandatory-bound API, minimal optional-kind factoring of the
  existing pipeline. Old API keeps its old envelope. All nonsuppressed latest-row
  validation and 4096 scoped history budget precede kind filtering; ranking and
  selection follow it. New metadata is included before whole-frame budgeting.
- `crates/core/src/knowledge.rs`: only the typed selector export.
- `crates/core/src/knowledge/human_search/tests.rs`: only new test-module mount;
  `crates/core/src/knowledge/human_search/tests/kind_filter.rs`: actual SQLite tests.
- `crates/daemon/src/knowledge.rs`: only filtered command/preflight/existing-store
  admission/dispatch arm; no lifecycle/source logic change.
- `crates/cli/src/main.rs`: only closed `--kinds` branch and help text.
- `crates/cli/tests/human_search.rs`: only module mount;
  `crates/cli/tests/human_search/kind_filter.rs`: real CLI tests.
- `apps/companion/Sources/CompanionKit/HumanSearchKindFilter.swift`: immutable
  captured request and distinct strict duplicate-rejecting response contract.
  Original bounded frame is retained and independently revalidated at adoption;
  forged typed projections cannot substitute another result for that frame.
- `apps/companion/Sources/CompanionKit/Contract.swift`: only operation/reply cases.
- `apps/companion/Sources/CompanionKit/ProcessService.swift`: only explicit filtered
  argv, empty stdin, 8192-byte cap and strict filtered decode arm.
- `apps/companion/Sources/CompanionKit/CompanionModel.swift`: human-search-only
  filter/display state, generation/capture/actions, bound-read whitelist and narrow
  search-ticket/CAS-conflict preservation hooks. Existing owned worker registry
  cancels/joins predecessors before any successor metadata/service/spawn.
- `apps/companion/Sources/CompanionKit/HumanContextSearchView.swift`: opt-in toggle,
  labeled kind checkboxes, disabled empty-choice Search, captured-kind disclosure.
  Existing application mount remains; no GUI launch or AX claim.
- `apps/companion/Tests/CompanionKitTests/CompanionTests.swift`: one new exhaustive
  rejecting fake arm, no inherited assertions changed or waived.
- `apps/companion/Tests/CompanionKitTests/HumanSearchKindFilterTests.swift` and
  `LiveHumanSearchKindFilterTests.swift`: new strict/fake/real adapter tests.
- `apps/companion/Tests/HumanSearchFilterAPIFixtures/FilterPublic.swift`,
  `FilterPrivate.swift`, `check-api.sh`: ordinary-import public action and negative
  capture/generation/registry/publication-authority probes.
- Contract above and this progress record.

The independent AD source-coverage module/low-level read helper was not inspected,
duplicated or changed. No source-inspection/comparison methods, generic lifecycle
refactor, schema/dependency/lock, site, provider, retained/export/marker semantics
were changed. Shared-file edits are intentionally narrow for primary integration.

## Acceptance evidence

- **AE-01:** twelve higher-score unwanted pitfall rows cannot displace wanted
  notes; wanted rows still score-sort and ID-tie-sort. Filtered counts/omission/
  truncation are recomputed after selection. Escaped overbudget text is omitted
  whole and later smaller entries fit. Aggregate Unicode bytes and exact complete
  8192-byte envelopes including LF are tested. All-five-kind small fixture equals
  old result bytes after removing only new version/filter metadata; old bound and
  trusted CLI stdout bytes match. At a byte boundary the additional metadata can
  legitimately reduce filtered-mode capacity; old envelopes are unchanged.
- **AE-02:** kind-only revision moves eligibility, latest retirement suppresses
  history, reactivation returns only the new latest kind, Forget suppresses all
  kinds and prevents same-ID recreation. Malformed unselected latest text and
  4097 scoped rows reject rather than return a filtered prefix.
- **AE-03:** mandatory `read_human_bound` admits exact root/identity/nonce before
  human SQL. Dropped context/Forget tables still yield scope mismatch for wrong
  bindings, including canonically equivalent but byte-distinct Unicode metadata.
  Actual WAL peer edit retains snapshot A; actual registration replacement rejects
  publication and never returns B text. Pre-cancellation rejects. Missing root and
  source-policy-only changes preserve human results with zero source access.
- **AE-04:** actual CLI canonicalizes order, rejects empty/duplicate/unknown/extra/
  partial/reordered/oversized forms with stdin held open and no store creation.
  A valid filtered request to missing storage creates nothing. A genuine schema-2
  fixture fails without creating registration objects or changing schema version.
  Typed daemon preflight repeats shape validation before storage admission.
- **AE-05:** mounting/choosing filters performs zero service I/O. A fake ignoring
  cancellation holds A while B waits on owned teardown, then only immutable B can
  publish. Cancel/selection/configuration/Quit reject late callbacks. Actual CLI
  same-root/new-nonce and different-root replacement occurs at filtered dispatch
  after native precheck: rejected=1, delivered-B=0, unbound fallback=0.
- **AE-06:** decoder rejects wrong captured filter, unselected result kind, missing/
  extra/decoded-duplicate top/nested keys, partial/extra frames, missing LF and
  8193-byte response. Exact 8192-byte frame accepted. Model independently rejects
  a valid typed response captured for another filter. Fake failure/unknown response
  and filter edits retain human history, original, editor revision and captured CAS
  base; actual stale CAS remains stale after success, opaque failure and canceled
  filtered reads, including filter edits while an ignoring peer is held. Default
  opt-out still uses old bound route. Native controls expose textual keyboard/
  accessibility labels; no rendered GUI or assistive-technology test was run.

## Reproduction and remaining gates

Synthetic local example: add notes/decisions through existing explicit context
commands, capture project root/identity/incarnation, then run the new closed form
from the contract. In native Context search opt in, choose kinds, then Search;
choice alone must not load anything. Inspect history, retain an unsaved draft,
append a peer revision, attempt stale save, then filter/search: history/editor/base
and conflict remain unchanged. Explicit history/edit refresh is still required;
search offers no automatic rebase/resolution. These are primary GUI repro steps,
not a claim of GUI execution here.

All fixtures synthetic. No subagents, external egress, credentials, spending,
GUI/host launch, Docker, reminders/polling, source modification or global config.
Inherited fixture-local provider loopback checks are not external live-provider
tests. Unchanged ignored 300/30-second deadline fixtures were not rerun.
Local Apple Swift 6.4 is not CI's Swift 6.1.2: closures are explicit and portable,
but only exact older-toolchain CI can prove that gate. Existing wrapper/linker
warnings are not suppressed. No phase, certified host, revocation lease, forensic
erasure, background daemon/listener or live-model quality claim follows.

Primary owns independent review, owned-diff integration and exact integrated-head
CI. No PR/CI run URL or tested implementation commit exists for this uncommitted
unit. Local checks, integration, CI, publication and GUI/AX remain separate gates.

## Local verification record

Tested baseline is `a432f34f82ba169a5f08fa0c8bad8e4366d5c1e3` plus the owned
uncommitted bytes. Runtime/contract diff SHA-256 (excluding this evidence file):
**`0e5ed493431e88f7acdb2e6f9bd3948f00a512438588755dca4546f967704356`**.
Reproduce by taking `git diff --name-only HEAD`, excluding `docs/progress/`, then
SHA-256 of `git diff --binary HEAD --` those paths. This includes staged new files
and latest working-tree modifications. Whole-file aggregate for those same twenty
sorted paths: hash relative UTF-8 path, NUL, exact file bytes, NUL, successively:
**`7838ecf37e8435fa45bdb016239a26ee962d036927b26e61da418a108bdeee26`**.

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS** on final Rust
  sources/tests, **304 Rust tests + two doctests**, two inherited deadlines ignored.
  Format, locked workspace build, warnings-denied Clippy, rustdoc, diagnostics,
  local links and intentionally failing test gate all pass.
- `CARGO_NET_OFFLINE=true cargo deny --offline --locked check`: **PASS**;
  advisories/bans/licenses/sources using cached policy data, no refresh/egress.
- Staged-new-file `python3 scripts/secrets.py`: **PASS**, tracked scan and
  synthetic negative scanner probe. New-file changes remain staged solely to make
  them visible to the scanner; existing files remain unstaged, no commit.
- Rebuilt all retained modes, export and inspection C fixtures with CI's
  `xcrun clang -std=c11 -Wall -Wextra -Werror -nostdinc`, resource/macOS SDK
  include isolation. No C fixture source changed.
- Initial full strict serial Debug and Release each passed **245 tests / 38
  suites**. Subsequent final-only changes add explicit configuration capture,
  slash-safe projected JSON and actual conflict-failure/cancellation assertions;
  final rerun results are recorded below, not inferred from these earlier runs.
- All three inherited API gates and the new filter ordinary-import gate passed;
  final rerun accompanies final native verification below.
- Early development failures were fixed: CLI test module mount, peer opening
  before WAL admission, Swift actor assertions and a wrong-filter fake accidentally
  returning its expected filter. A bundle attempt failed because the source was
  being edited during compilation; no bundle success is inferred from that attempt.
  Runtime sources were then frozen for serialized final Debug/Release/bundle checks.

Reproduce strict native runs from repository root (Release adds
`--configuration release`):

```sh
THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" \
THREADMARK_RETAINED_FIXTURES="$PWD/target/retained-fixtures" \
THREADMARK_EXPORT_FIXTURE="$PWD/target/export-fixtures/export" \
THREADMARK_SOURCE_INSPECTION_FIXTURE_BINARY="$PWD/target/source-inspection-fixtures/inspection" \
sh apps/companion/scripts/swift.sh test --no-parallel --disable-xctest \
  --enable-swift-testing -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors
```

API commands: `sh apps/companion/scripts/check-retained-api.sh`, then
`sh apps/companion/Tests/SourceInspectionFixtures/check-api.sh`,
`sh apps/companion/Tests/ComparisonAPIFixtures/check-api.sh`,
`sh apps/companion/Tests/HumanSearchFilterAPIFixtures/check-api.sh`.
Build only: `sh apps/companion/scripts/bundle.sh`, then
`plutil -lint apps/companion/dist/Threadmark.app/Contents/Info.plist`.

Tested artifacts (SHA-256):

```text
d789970e7c43d3bb70915aa79ca0d62325bc0714ad7da1de90ecbb5d84a4f8ac  target/debug/threadmark
b8e6de85b292c4ae8a0132a76fec5d26c20514f9d93baa51aed9d03d96ba99ed  target/retained-fixtures/retained
483f33c196fab70e07984d192c992479595546cefd71dd14b4e6b5fcf8ca7e6e  target/export-fixtures/export
e37ea269805625b26de08dab0f4b426611d48b60ff6c16bcf95001c15447bee2  target/source-inspection-fixtures/inspection
```

Local logs are in the session-approved temporary directory, prefixed `ae-`:
`ae-check-complete.log`, `ae-deny.log`, `ae-secrets.log`,
`ae-swift-debug-final.log`, `ae-swift-release-final.log`, `ae-bundle-final.log`.
These are local evidence, not integrated exact-head CI or independent review.

### Final frozen-runtime verification

- Full strict serial **Debug PASS: 245 tests / 38 suites**, no suites skipped,
  actual rebuilt CLI plus retained/export/inspection C fixtures explicitly set.
- Full strict serial **Release PASS: 245 tests / 38 suites**, same explicit
  fixture environment and strict flags. This includes the final slash-heavy
  decoder, captured-configuration and real stale-CAS failure/cancel tests.
- All **four ordinary-import API gates PASS** after final Debug/Release:
  retained, source inspection, comparison, new filtered human search. Positive
  controls compile and intended private/internal/publication bypasses reject.
- Release bundle build/package **PASS**; `Info.plist` lint **PASS**. Never
  launched, installed, signed or deployed. The earlier build-during-edit failure
  was repaired by freezing sources and rerunning the complete serial gate.
- Final offline locked dependency check, staged-new-file secrets/synthetic-negative
  probe, documentation links and staged/working-tree whitespace **PASS**.
- Runtime/contract fingerprint above reverified unchanged after the final runs.
  Only this evidence record was appended afterward; the worktree remains intact,
  uncommitted, with exactly the owned inventory listed above.

Primary independent review, integrated full SHA, exact CI run/head/URL,
Swift 6.1.2 CI and GUI/AX acceptance remain **NOT RUN**. No publication occurred.
