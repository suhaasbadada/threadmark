# Unit AH — native explicit incremental lexical Build

## Primary integration and independent review

Primary committed only thirteen owned files as `df82934` and applied cleanly as
**`71c1fa7d6d0a857072fd7053dc0e4e9bb1193841`**, exact integrated tested runtime.
The twelve-file payload fingerprint was reverified after integration, identical
to `42c72d9caf2502c406aa954dd0feafff49299662d4f5f4caa64b44daa2e4566b`.
No baseline/site merge history replay and no manual source conflict resolution.

Joffrey independently reviewed **CLEAR**, reproduced the payload before/after,
rebuilt offline CLI and SDK-isolated incremental C fixture, passed 105 strict
Debug tests/22 suites with actual CLI/C fixtures, all six API gates and whitespace.
He did not rerun full Rust/Release/deny/secrets/bundle or GUI/older Swift/remote CI.

Primary full workspace **368 Rust tests + two doctests PASS**; strict serial
actual-CLI/all-C-fixture full Debug and Release each **272 tests/43 suites PASS**;
all six API gates, offline locked deny, staged secrets/whitespace, release bundle
and Info.plist **PASS**. Two unchanged long deadlines ignored. Existing Full Build
and automatic-refresh routes remain unchanged; SQL row reuse is not source I/O,
lexical CPU, AST or benchmarked performance avoidance. Publication CI remains later.

Atomic note backend PR #83 passed all five checks at
`2abe58f28f908c90e256255ae42fe4787746a60f` (CI `43592830895`, integrated
`43592830855`); fresh exact-head/main/check/review/approval/discussion/rules gates
preceded merge `8ca233f076ca030b985bdfdb90be56362f8b95dd`. Separate exact
post-merge CI remains unverified. #82 exact post-merge runs `43592319046`/
`43592319072`, both targeting `9c84f6a826d73b9e51f83151b4e6567e05de9753`, **PASS**.
Nine inherited progress edits/worktrees/parent reminders preserved. No GUI/AX,
live-quality, host delivery, deployment or phase closure claim.

Implementation sub-agent Bob. Requirements **TM-01–TM-04, TM-07, TM-10**;
partial **P2-A1/A2/A3/A4/A5/A6** and **P3-A3/A4/A5/A6**. Phase 2/3 remain open.
Uses reviewed [AG v1](../contracts/incremental-lexical-index-v1.md) unchanged;
read Phase 2/3 and AG/AF/AE progress, manual Build, owned registry and mutation
uncertainty before implementation. This is SQL evidence-row reuse, not skipped
source I/O, skipped lexical computation, AST/semantic coverage or measured speedup.

## Full baseline and integration boundary

- Initial clean prepared HEAD: `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Required **local** reviewed stack: `cfba6b107b518af58d73e716fbaaf49c2164332d`.
  No assumption that PR 82 or its parent 81 was merged.
- Authorized normal `git merge --no-edit` produced sole merge-only baseline
  **`4e9b5b715eecfe143804ca64a483e0eaf8d1d687`**. Parents, in order, are the two
  complete SHAs above. Prepared baseline and site history retained; no reset,
  branch switch, extra worktree, implementation commit, push or PR.
- Tested implementation is that full baseline **plus uncommitted owned files**,
  not the baseline SHA alone. Primary must integrate only this owned diff, never
  replay the baseline/site merge or changes already in the reviewed stack.
- Independent review, integrated tested SHA, exact publication CI run/head/URL
  and Swift 6.1.2 CI are **not run/not available** in this implementation child.
  Primary owns those gates; no phase closure follows from local tests.

### Owned inventory

Twelve payload files plus this progress record:

| Path | Change |
| --- | --- |
| `.github/workflows/ci.yml` | Build/enable new C fixture and sixth API gate |
| `apps/companion/Sources/CompanionKit/CompanionModel.swift` | Explicit action/result, private immutable action fences, mutation-start uncertainty and narrow lifecycle hooks |
| `apps/companion/Sources/CompanionKit/Contract.swift` | Additive typed request/reply cases |
| `apps/companion/Sources/CompanionKit/ProcessService.swift` | Closed AG argv, stdin EOF, 64 KiB complete-frame bound and decoder |
| `apps/companion/Sources/CompanionKit/IncrementalBuild.swift` | Full captured Project request; closed duplicate/type/count/snapshot/no-op validation; exact post-write metadata adoption |
| `apps/companion/Sources/CompanionKit/IncrementalBuildView.swift` | Explicit optional Build alternative and conservative SQL accounting |
| `apps/companion/Sources/ThreadmarkCompanion/main.swift` | Mount in actual selected Projects details, beside unchanged Full Build |
| `apps/companion/Tests/CompanionKitTests/CompanionTests.swift` | Single exhaustive fake rejection arm |
| `apps/companion/Tests/CompanionKitTests/IncrementalBuildTests.swift` | Closed decoder and explicit/model/registry/lifecycle tests |
| `apps/companion/Tests/CompanionKitTests/IncrementalBuildLiveTests.swift` | Real core/daemon/CLI and genuine postcommit lost-receipt/peer/cancel journeys |
| `apps/companion/Tests/IncrementalBuildFixtures/incremental.c` | Exact ordered 64-source capture and EOF; hostile stdout fixture |
| `apps/companion/Tests/IncrementalBuildFixtures/check-api.sh` | Ordinary-import positive action and negative publication/lifecycle/controller/ID-only/decoder probes |

No Rust/backend, AG report, schema, dependency, lockfile, site, provider,
refinement, retained/export/filter semantics or independent atomic-note-batch
lane was edited. The independent Rust lane was not investigated or duplicated.

## Product and boundaries

Projects mounts **Incremental lexical Build (SQL row reuse)** as a separate
explicit alternative. Original Full Build button, eligibility and route remain
unchanged; default automatic refresh remains off/session-only and its existing
full-index route is unchanged. No new automatic mode or preference is introduced.
Selection, appearance, source inspection/coverage, filter/query changes and file
events never dispatch incremental indexing. This explicit action stops/joins
automatic producers; it grants no subsequent automatic consent.

Before owned dispatch, capture the **complete immutable Project**: exact root
bytes, root identity, incarnation, ordered complete policy (0–64) and snapshot,
including none. Private model generation, configuration and scope revision fence
the action. Existing registry cancels and joins all predecessors **before any
successor service/spawn/mutation**; refresh-driver shutdown is joined as well.
There is no project-show precheck followed by ID-only Build, diagnostic fallback,
Full Build fallback, corrective Build, implicit retry or provider/host/network call.

Core AG performs its unchanged full bounded reads and lexical checks, including
zero-write no-ops. After a whole valid receipt, and only then, native requests fresh
project metadata. It may adopt the old registration/policy with **exactly the
receipt's new snapshot**, but never another root/identity/incarnation/policy or a
racing unrelated snapshot. Model publication independently redecodes the retained
wire frame and rechecks both action fences and fresh metadata. AG does not echo
root/nonce/policy in its report: native does not invent those wire fields or claim
the receipt alone authenticates them. Transactional AG binding and exact post-write
metadata corroboration are separate checks, not an external filesystem lease.

Human history/editor revision/original/edit CAS base and completed comparison
state follow existing manual Build preservation. No human follow-up read is
needed by the new action; existing human reads retain V's exact-registration bound
route. Neither a source snapshot change nor a metadata receipt rebases a draft.
Source evidence/query/inspection/coverage caches are discarded, not renewed by row
reuse. Reused rows and coverage are never new source authorization.

Cancel, policy/scope/configuration/selection changes, Quit, opening Forget/source
Forget/removal, and explicit successors fence late output. Once mutation dispatch
begins, any CLI/decode/metadata failure, cancel or post-write adoption failure is
**unknown persisted outcome** and requires explicit metadata refresh; never “no
effect” or “rolled back.” No post-failure diagnostic command is issued. Cancellation
while still joining an older worker, before mutation starts, does not falsely set
mutation uncertainty. A legitimate explicit successor still joins first and must
independently satisfy AG's old-snapshot binding; success is not inferred from an
older callback. Cancellation is cooperative, and commit I/O can be uncertain.

UI reports files reused/reindexed; anchor SQL rows reused/deleted/inserted; total
anchors; persistent-write boolean, snapshot-changed boolean, snapshot hash and
validated no-op. Labels explicitly require full source freshness reads and lexical
computation, disavow AST/semantic/CPU/performance claims, and never mark Ready or
complete understanding. Buttons/text compile; no GUI or assistive-technology
walkthrough was performed.

## Stable acceptance and actual evidence

| ID | Local evidence |
| --- | --- |
| **AH-A1 / AG-A1, P2-A1/A6** | Immutable complete typed capture including none/empty/64 policy; C fixture verifies ordered argv/root/identity/nonce/snapshot and stdin EOF. Real old-snapshot/policy/nonce/root captures fail with source removed and exact DB bytes unchanged. Retained AG core hook tests separately verify mismatch before filesystem access; native tests do not claim independent syscall instrumentation. |
| **AH-A2 / AG-A2/A3, P2-A2/A4** | Actual native unindexed initial Build, query, unchanged zero persistent writes with byte-identical DB; one-file edit reuses one other file/anchor and reports one delete/two inserts; same-content new inode reindexes one file. Actual 64 empty files, empty policy initial/no-op; strict coverage/provenance/count/snapshot/no-op fields. Complete frame including final LF <=65536; exact boundary accepted and overflow rejected. |
| **AH-A3 / P2-A3, P3-A3/A5** | Delayed cancellation-ignoring fake against Cancel, policy, config, Quit, human/source Forget and selection. Query predecessor and explicit incremental successors cannot overlap. Queued canceled Build never starts mutation. Real successful commit followed by lost receipt, cancellation, or peer snapshot/policy/nonce/root replacement retains old native metadata and marks outcome unknown; never adopts B or falls back. |
| **AH-A4 / AG-A5, P2-A5, P3-A4** | Actual source Forget invalidates old capture; explicit fresh-none rebuild omits revoked source; source bytes and saved human note survive. Native human history/original/editor revision/CAS base and completed comparison remain through successful Build; fake stale-CAS conflict remains stale, no rebasing. Existing full Build fake still takes its original route; old refresh tests run unchanged. |
| **AH-A5 / P3-A6** | Decoder rejects wrong project/provenance, required/extra/escaped-duplicate fields, types/decimals/overflow, count contradictions, old/new snapshot and no-op contradictions, truncated/extra/missing-LF frames and 65537 bytes. Ordinary imports can request complete-bound Build but cannot set publication, access private registry/tickets/generations or internal retained controller, call decoder or submit an ID-only action. |

## Reproduction and verification

All fixtures synthetic. Runtime sources frozen before final full native gates.
Use the command-scoped SDK wrapper, not host header/SDK modifications.

```sh
cargo build --offline --locked -p threadmark-cli
# Compile all existing retained/export/inspection/coverage C fixtures as in CI,
# plus IncrementalBuildFixtures/incremental.c -> target/incremental-fixture:
# xcrun clang -std=c11 -Wall -Wextra -Werror -nostdinc \
#   -isystem "$(xcrun clang -print-resource-dir)/include" \
#   -isystem "$(xcrun --sdk macosx --show-sdk-path)/usr/include" \
#   -isysroot "$(xcrun --sdk macosx --show-sdk-path)" INPUT -o OUTPUT
THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" \
THREADMARK_RETAINED_FIXTURES="$PWD/target/retained-fixtures" \
THREADMARK_EXPORT_FIXTURE="$PWD/target/export-fixtures/export" \
THREADMARK_SOURCE_INSPECTION_FIXTURE_BINARY="$PWD/target/source-inspection-fixtures/inspection" \
THREADMARK_COVERAGE_FIXTURE_BINARY="$PWD/target/coverage-fixture" \
THREADMARK_INCREMENTAL_FIXTURE_BINARY="$PWD/target/incremental-fixture" \
sh apps/companion/scripts/swift.sh test --no-parallel --disable-xctest \
  --enable-swift-testing -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
# Same environment for Release, adding -c release --filter
# 'Incremental|Coverage|SourceInspection|Comparison|HumanRevision|Forget|FileEvent|BoundHuman'
sh apps/companion/scripts/check-retained-api.sh
sh apps/companion/Tests/SourceInspectionFixtures/check-api.sh
sh apps/companion/Tests/ComparisonAPIFixtures/check-api.sh
sh apps/companion/Tests/HumanSearchFilterAPIFixtures/check-api.sh
sh apps/companion/Tests/CoverageFixtures/check-api.sh
sh apps/companion/Tests/IncrementalBuildFixtures/check-api.sh
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --offline --locked check
python3 scripts/secrets.py
git diff --check
git diff --cached --check
sh apps/companion/scripts/bundle.sh
plutil -lint apps/companion/dist/Threadmark.app/Contents/Info.plist
```

- **PASS:** full offline check.py, **348 Rust tests + two doctests**, format,
  locked build, all-target warning-denied Clippy, rustdoc, finite diagnostics,
  local documentation links and intentional failing-test gate. Existing 300/30
  deadline fixtures stayed ignored, not explicitly rerun. `target/unit-ah-check.log`.
- **PASS:** offline locked cargo-deny, cached advisory data only;
  `target/unit-ah-deny.log`. No dependency/lockfile changes or egress.
- **PASS:** targeted strict serial actual CLI/new C fixture, **12 tests / three
  suites**, including parameterized race/hostile cases. `target/unit-ah-targeted.log`.
- **PASS:** all five inherited ordinary-import API gates plus new sixth gate.
- Full Debug, relevant Release, bundle/plist, staged-new-file secrets and final
  whitespace/documentation gates: final results appended below, not inferred here.

Initial local iterations caught actor-await/autoclosure test spelling, a fixture
using the existing nonce instead of a new one, and an assertion expecting a word
not in the existing uncertainty message. Fixed tests and added explicit unknown
outcome cancellation disclosure; no inherited tests were waived or edited except
the required exhaustive fake arm. The required-base repaired stdin fixture is
unchanged. Local Swift **6.4** is not CI Swift **6.1.2** evidence; closures remain
explicit/portable. Existing wrapper/linker warnings were not suppressed.

No delegates, implementation commit/push/PR, credentials, external egress, spend,
deployment, GUI/host launch, Docker, polling or reminders. T3 Plum read returned
`thread_not_found`; no cross-agent coordination occurred. Inherited test-local
loopback transports are not live external provider tests. Worktree remains intact.

## Final receipt

- **PASS:** final full strict serial Debug, **272 tests / 43 suites**, all real
  CLI and all five C fixture families enabled, no tests skipped;
  `target/unit-ah-debug.log` (63.906 seconds).
- **PASS:** staged-new-file secret scan and synthetic-secret negative gate,
  `target/unit-ah-secrets.log`; working/staged whitespace and local docs links.
- **PASS:** relevant strict serial Release, **105 tests / 22 suites**, actual
  CLI/all C fixtures enabled, no selected test skipped; incremental, coverage,
  inspection, comparison, revision, Forget, file-event and bound-human families.
  `target/unit-ah-release.log` (25.482 seconds).
- **PASS:** release bundle/package, arm64 Mach-O executable and Info.plist lint;
  `target/unit-ah-bundle.log`. Bundle was **not launched**, installed, signed or
  deployed. Primary review/integration/exact-head CI remain separate gates.

Twelve-file payload fingerprint (excludes this self-referential progress file):
**`42c72d9caf2502c406aa954dd0feafff49299662d4f5f4caa64b44daa2e4566b`**.
Algorithm: sort the twelve relative payload paths lexicographically, SHA-256
successive UTF-8 path + NUL + exact complete file bytes + NUL. Reproduction:

```sh
python3 - <<'PY'
import hashlib, pathlib, subprocess
paths = sorted(subprocess.check_output(
    ['git', 'diff', '--name-only', 'HEAD'], text=True).splitlines())
h = hashlib.sha256()
for p in paths:
    if p.startswith('docs/progress/'):
        continue
    h.update(p.encode()); h.update(b'\0')
    h.update(pathlib.Path(p).read_bytes()); h.update(b'\0')
print(h.hexdigest())
PY
```

This covers staged new files and unstaged existing-file edits with `git diff
HEAD`. Do not use plain `git diff` as the complete integration patch. Baseline
HEAD alone does not contain these bytes. Primary should fingerprint the owned
files before independent review and again after integrating the intended diff.
