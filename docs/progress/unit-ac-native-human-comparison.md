# Unit AC — native explicit human revision comparison

Requirements: TM-01–TM-04, TM-07, TM-10; partial **P2-A1/A3/A5/A6,
P3-A4/A6**. [Phase 2](../spec/phase-2-knowledge-core.md) and
[Phase 3](../spec/phase-3-background-experience.md) remain open.
Contracts: [AA comparison](../contracts/human-context-comparison-v1.md),
[human read binding](../contracts/human-context-read-binding-v1.md),
[expected revision](../contracts/human-context-revision-v1.md).
Reviewed backend/editor/read boundaries remain [AA](unit-aa-human-revision-comparison.md),
[T](unit-t-native-human-revision.md), [V](unit-v-native-bound-human-reads.md).

## Baseline and integration boundary

- Initial assigned worktree was clean at
  `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Authorized normal `git merge --no-edit 5edac1aae22ca4b33b66111278c323195d400028`
  created merge-only baseline **`d4ca56a02b3237438b195071d643bff0c264e7f0`**.
  Its parents are the initial head and required SHA, respectively. Prepared
  baseline/site history was preserved. No reset, branch switch or new worktree.
- Implementation is **uncommitted**. Baseline SHA alone is not the tested
  implementation. Primary must take only the owned diff below, never replay the
  baseline/site merge. This worktree is left intact.
- Independent review, integrated commit/head and exact remote CI run/URL: **not
  run**. No implementation commit, push, PR, merge to main, release or deployment.

## Owned inventory

Paths below are relative to `apps/companion/`:

- `Sources/CompanionKit/Comparison.swift`: immutable same-history captured pair;
  comparison-only duplicate-rejecting closed JSON parser; independent exact byte
  reconstruction and longest logical-line prefix/nonoverlapping suffix validator.
- `Sources/CompanionKit/ComparisonView.swift`: public read-only management/history
  component with native labeled pickers/buttons, explicit Compare and Cancel,
  textual metadata/change flags and all four labeled delta segments.
- `Sources/CompanionKit/Contract.swift`: only the new typed operation/reply cases.
- `Sources/CompanionKit/ProcessService.swift`: only comparison closed argv,
  empty stdin, 65536-byte stdout cap and strict response decoder arm.
- `Sources/CompanionKit/CompanionModel.swift`: comparison state/actions, owned
  serialized task, checked-human-read whitelist entry, history-replacement and
  human-mutation clearing, narrow shared cancellation/clearing hooks.
- `Sources/ThreadmarkCompanion/main.swift`: one comparison component mount in the
  existing Context/history pane. Parent editor state/actions remain unchanged.
- `Sources/CompanionTestProcess/ComparisonFixture.swift` and one dispatch line in
  its `main.swift`: synthetic exact-argv/empty-stdin response/timeout fixtures.
- `Tests/CompanionKitTests/ComparisonTests.swift`, `ComparisonModelTests.swift`,
  `ComparisonLiveTests.swift`, `ComparisonProcessTests.swift`: new contract,
  lifetime, real CLI and adapter tests.
- `Tests/CompanionKitTests/CompanionTests.swift`: one exhaustive fake switch arm
  rejects the new operation; no inherited assertions changed or waived.
- `Tests/ComparisonAPIFixtures/ComparisonPublic.swift`, `ComparisonPrivate.swift`:
  ordinary-import positive/intentional-negative typecheck fixtures, never run.
- This progress document is outside the runtime fingerprint.

No query/results, refine, source-inspection actions/types/registry hooks, Rust,
backend/CLI, schema, dependencies, lockfiles, site, providers, retained review,
export or suppression-marker semantics changed. AB's independent source-inspection
lane is not integrated or claimed tested by this unit.

## Stable acceptance and actual evidence

- **AC-01 — explicit usable history review:** mounted after a note is explicitly
  inspected. Opening, appearance and pair choices perform zero service I/O.
  Choices come only from that loaded, validated, same-note history; no latest
  substitution, ID entry, two-history-call comparison or unbound fallback. Both
  revisions must exist in 1..32, FROM <= TO; equality is valid. The view labels
  FROM/TO kind and active/retired metadata, text/kind/retirement changes, common
  prefix, removed, added, suffix, byte counts and empty segments without relying
  on color. Native controls have textual keyboard/accessibility labels. No GUI
  or assistive-technology walkthrough is claimed.
- **AC-02 — preserve drafts and stale CAS:** the real CLI journey creates a note,
  captures edit revision 1, appends peer revision 2, rejects stale save, and then
  compares equal loaded revisions while preserving the failed CAS error/status,
  original request, loaded history, context-editor revision and captured base.
  Explicit history reload reveals revision 2 but does not change view-owned draft
  or edit binding. Comparison of revisions 1/2 still leaves the old edit base
  stale; it cannot save. Only explicit Edit-equivalent fresh capture permits a
  guarded append. Actual kind/text-equal append, retirement, reactivation and
  equality comparisons check truthful flags. The editor text and binding remain
  parent view-local state; comparison neither receives nor rewrites them. Model
  preservation plus unchanged parent editor wiring is evidence, not a GUI test.
- **AC-03 — strict transport and byte semantics:** exact AA flag order, explicit
  pair and empty stdin are asserted by an actual subprocess fixture. Decoder
  caps the complete stdout frame at 65536 bytes including required final LF;
  exact-boundary whitespace frame succeeds and one-byte overflow fails whole.
  Duplicate decoded/escaped keys, nested duplicates, extra keys/frames, partial
  JSON, missing newline, wrong project/note/pair/kind/retirement/provenance/
  authority/algorithm/delta/flags and boolean-number confusion reject. Both
  captured history texts must reconstruct byte-for-byte, not merely agree with
  response metadata. Tests distinguish canonical Unicode bytes, CRLF vs LF,
  blank lines, final newline, unchanged text, kind/retirement-only transitions,
  equality and a nonminimal differing middle. A separately valid typed result for
  another captured text pair is rejected again at model adoption.
- **AC-04 — owned lifetime and recovery:** registry cancellation/join precedes
  successor metadata/service/spawn. Fake service ignores cancellation until an
  event-driven release; cancel, choice change, history reload/replacement, note
  change, configuration invalidation, Quit, mutation and successor Compare drop stale
  callbacks. Forget after cancel joins the predecessor before removing history;
  no late comparison resurrects it. Generation, configuration generation,
  history generation, current note, exact human namespace and selected pair fence
  publication. Unknown same-namespace failure/timeout/invalid response retains
  loaded human state and existing CAS conflict. Authoritative replacement uses
  the unchanged namespace-clearing policy; replacement is never adopted.
- **AC-05 — actual registration admission and human-only boundary:** real CLI
  peer replaces same ID immediately at comparison dispatch, after native
  precheck, with same-root/new-nonce or different root. Actual bound core rejects
  both: replacement delivery counter 0, unbound fallback counter 0; no B text
  reaches native adoption. Native pre/post checks use V's exact UTF-8 human binding;
  actual AA core admission, not those metadata probes, gates human SQL. AA's JSON
  contains no registration fields: native validates the captured request binding
  plus these registration checks, not invented wire fields. Actual source Forget
  preserves the completed human comparison, history, original and CAS base. A
  peer snapshot change and missing source root still permit comparison with zero
  native source operation calls. Context Forget removes comparison/history and
  old bound compare plus recreation both fail. This native counter is not new
  OS syscall instrumentation; AA's core source-access tests remain separate.
- **AC-06 — limits and verification:** inherited V/T/Forget, retained/export and
  all other native suites remain enabled. Local gate results and reproducible
  commands follow; no phase completion follows from them.

Comparison is human-authored context, not source truth, permission, semantic or
minimal diff, conflict resolution or automatic recovery. No Apply, auto-edit,
overwrite, retry, provider, host, send, import, file output or transport-consent
authority is introduced. Reading never refreshes/rebases a CAS edit base. Loaded
history and read results are current-at-read, not a revocation lease. No automatic
fetch/retry, source filesystem lookup or widened source authorization.

## Verification record

All fixtures synthetic. No subagents, credentials, external egress, spending,
GUI/host launch, Docker, polling, reminders or global configuration changes.
Existing fixture-local loopback provider tests remained enabled; they are not
live-model or external provider tests. The unchanged ignored 300-second process
and 30-second provider deadline fixtures were not rerun.

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, format, locked
  workspace build, warnings-denied Clippy, **294 Rust tests + two doctests**,
  rustdoc, diagnostics/smoke, local documentation links and intentional-negative
  gate. Two inherited long-deadline tests ignored. No Rust code changed.
- `CARGO_NET_OFFLINE=true cargo deny --offline --locked check`: **PASS**,
  advisories/bans/licenses/sources using cached offline policy data.
- C fixtures: **PASS**, rebuilt both retained and export C executables with CI's
  SDK-isolated `xcrun clang -std=c11 -Wall -Wextra -Werror -nostdinc` plus resource
  and macOS SDK include flags; all ten retained modes copied under ignored target.
- Full strict serial Debug with explicit actual CLI/retained/export fixture
  environment: **PASS**, **229 tests / 34 suites**, no suites skipped.
- Comparison-only strict Debug: **PASS**, **15 tests / four suites**, including
  parameterized invalid-frame, registration, lifecycle and exact-budget cases.
- Strict serial Release, bundle/plist, final staged secrets and whitespace results
  are recorded in the final verification addendum below.
- `sh apps/companion/scripts/check-retained-api.sh`: **PASS**, inherited ordinary
  import public model and negative controller/export-authority gates unchanged.
- New ordinary-import comparison API: **PASS**, positive model read controls
  compile; negative fixture is rejected specifically for private `comparisonActive`,
  private `ownedOperations` and internal `HumanComparisonRequest` initializer.
  Task/capture authority remains module-owned, not an externally writable store.

Debug command (Release uses the same flags and adds `--configuration release`):

```sh
THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" \
THREADMARK_RETAINED_FIXTURES="$PWD/target/retained-fixtures" \
THREADMARK_EXPORT_FIXTURE="$PWD/target/export-fixtures/export" \
sh apps/companion/scripts/swift.sh test --no-parallel --disable-xctest \
  --enable-swift-testing -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors
```

For the comparison API fixtures, use `xcrun swiftc -typecheck` with the same SDK
and include isolation as `scripts/check-retained-api.sh`, debug Modules include
path, `-strict-concurrency=complete -warnings-as-errors`. Positive fixture must
succeed, negative must fail with the three protection-level errors above.

Copyable API gate from the repository root (no fixture is executed):

```sh
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
check_comparison_api() {
  "$compiler" -typecheck -strict-concurrency=complete -warnings-as-errors \
    -sdk "$sdk" -I apps/companion/.build/debug/Modules -F "$developer" \
    -Xcc -nostdinc -Xcc -isystem -Xcc "$resource" \
    -Xcc -isystem -Xcc "$sdk/usr/include" \
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" "$1"
}
check_comparison_api apps/companion/Tests/ComparisonAPIFixtures/ComparisonPublic.swift
# Must exit nonzero with the three protection-level errors; do not treat as success.
check_comparison_api apps/companion/Tests/ComparisonAPIFixtures/ComparisonPrivate.swift
```

Manual product repro for primary's later GUI gate (not performed here): open
management Context, explicitly inspect a saved note, choose Edit loaded revision
and type an unsaved draft. Use a separate trusted operator CLI to append a newer
revision, then attempt the stale save. Open Compare saved revisions: choices show
only the loaded history and no read occurs until Compare. An equality read must
retain the conflict. Explicit Reload history (keep editor) reveals the newer
revision without replacing the draft/base; choose FROM/TO and Compare. Inspect
all four textual segments and independent metadata flags. Cancel keeps the draft,
loaded history and stale edit base. Only explicit Edit loaded revision replaces
the editor and captures the fresh base. Comparison offers no Apply or resolution.

Local toolchain is Apple Swift **6.4**, not CI's older **6.1.2**. New picker
closures are explicit, with no initializer-reference inference dependency; local
compilation is **not** proof of older-toolchain CI. The existing native-build-system
deprecation and Testing.framework deployment-target linker warnings are not
suppressed; no compiler warning/strict-concurrency checks were relaxed.

Artifact SHA-256:

```text
8bd305547ebe819ca9b9be2377490264b5ad9ed50566e519a050676934d572c2  target/debug/threadmark
b8e6de85b292c4ae8a0132a76fec5d26c20514f9d93baa51aed9d03d96ba99ed  target/retained-fixtures/retained
483f33c196fab70e07984d192c992479595546cefd71dd14b4e6b5fcf8ca7e6e  target/export-fixtures/export
```

Local logs (not CI): `unit-ac-check.log`, `unit-ac-deny.log`,
`unit-ac-comparison-final.log`, `unit-ac-debug-verified.log`, `unit-ac-release-verified.log`,
`unit-ac-api.log`, `unit-ac-comparison-api-negative.log` in the session's approved
temporary directory. Early development compile failures (exhaustive fake switch
and actor property access in an assertion) were fixed, not waived. The final
passing full Debug run includes those fixes and all comparison process fixtures.
Final self-review also found a mutation-during-comparison ordering edge: clearing
the comparison-active flag before `start` could bypass history-preserving
cancellation. Clearing now follows `start`, after it has canceled/join-fenced the
active read; a new timeout-mutation successor case asserts history/base/original
preservation. Both complete strict suites passed again for this correction;
earlier green runs are not substituted for its final evidence.

## Remaining gates

Primary owns independent review of the exact inventory/fingerprint, owned-diff
integration, final integrated SHA, exact CI head/run and any separately authorized
publication. No CI URL/head exists for this uncommitted unit. GUI/AX, certified
host/OS support, live-model quality, host delivery, background companion completion,
forensic erasure and phase closure remain unverified/unclaimed.

## Final verification addendum

- Full strict serial **Release PASS: 229 tests / 34 suites**, no suites skipped,
  actual CLI/retained/export C-fixture environment and the same strict wrapper
  flags as Debug. This is the full inherited suite, not merely a focused subset.
- `sh apps/companion/scripts/bundle.sh`: **PASS**, release bundle built/package
  only, never launched/installed. `plutil -lint
  apps/companion/dist/Threadmark.app/Contents/Info.plist`: **PASS**.
- `python3 scripts/secrets.py`: **PASS** after staging only the ten owned new
  files (including this progress record); tracked-file scan and intentionally
  failing synthetic-secret probe both verified. Six modified existing files
  remain unstaged; all implementation remains uncommitted.
- Final `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS** again on the
  corrected implementation, same 294 Rust/two-doctest totals and two unchanged
  ignored deadline fixtures. Final `git diff --check HEAD` and
  `git diff --cached --check`: **PASS**. Local additional logs: `unit-ac-bundle-verified.log`,
  `unit-ac-secrets.log`, `unit-ac-check-final.log`.

Exact tested baseline is `d4ca56a02b3237438b195071d643bff0c264e7f0` **plus the
owned uncommitted implementation**. Runtime diff fingerprint (including staged
new files, excluding this document): SHA-256 of
`git diff --binary HEAD -- apps/companion`:
**`772ab0ada16d317e7b2609efdd2747fbd3a7292c7b3d41741df7d7df0bc83692`**.

Whole-owned-runtime-file aggregate SHA-256:
`a5b23e36d4f2ab67754531a72414a98dedbc362f57a646981cd4a477330a2c3e`.
Reproduce with standard-library Python `hashlib.sha256`: sort the fifteen paths
from `git diff --name-only HEAD -- apps/companion`; for each, hash UTF-8 relative
path, NUL, exact file bytes, NUL. This record is deliberately excluded to avoid
self-reference. API fixtures are typechecked separately; they do not participate
in the runtime test target. Final Debug, Release, ordinary-import API checks and
bundle rebuild all ran on the corrected runtime implementation. No implementation
commit or exact-head CI is represented by either fingerprint.
