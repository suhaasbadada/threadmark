# Unit X — explicit scoped native local project export

## Integrated acceptance and publication preparation

Primary committed the repaired 13-file unit as `ea05bfa` and applied only owned
changes as `1b3a57f`, retaining V/Y bound human/marker cases in three textual
conflicts. The export fake now validates bound LIST rather than an unbound fake
case. The actual-CLI test starts each independent replacement probe by explicit
selection, not cached Refresh (which V correctly refuses after nonce replacement).
No stale-consent assertion or production guard was relaxed. CI now rebuilds and
enables the export C fixture instead of silently skipping its transport test.

Exact integrated tested SHA **`54ce7124b76a22a5667efe6372ec0586f4cfa322`**:
full workspace check **265 Rust tests + two doctests**, strict serial Debug
**214 tests/30 suites**, strict overlap Release **25 tests/four suites**, ordinary-
import API gate, offline locked deny, staged secrets/whitespace, bundle build and
Info.plist validation **PASS**. Actual CLI and retained/export C fixtures enabled.
The unchanged long deadline cases remain ignored in normal checks. No GUI launch.
Initial combined Debug caught the test's incompatible cached-Refresh assumption;
that failed run is not passing evidence. Full rerun passed after the narrow fix.

Joffrey independently cleared the integration at that exact SHA, passed 25 overlap
tests/four suites with actual CLI/C fixtures, API gate, C warnings-as-errors syntax
and whitespace. Reviewed Swift 6.1 compatibility, but executed installed Swift 6.4
only; remote CI remains its separate gate. Private writer/document controls and
V/Y lifecycle boundaries remain intact. No source/store cleanup or user export.

PR #73 passed all five checks at `8285ebbe3426caf42106c821d306823d939536c8`
(CI `43580072928`, integrated `43580072931`); fresh exact-head/main/check/review/
approval/discussion/rules gates preceded merge `11a56089b61560f0120f585dead00c667f4e5923`.
Merged main normally without replaying lane baseline/site history. Separate #73
post-merge CI and this unit's remote publication gates remain pending. All nine
inherited progress edits/worktrees/parent reminders preserved; no phase closure.

## Primary repair after independent review

Joffrey found High pending-confirmation transport bypass and Medium `/` root
containment defects. Initial review was **not clear**. Primary repaired these in
this completed lane; the original fingerprint below describes pre-repair source.

`Operation.exportProjectBound` now takes opaque public `ProjectExportExecution`,
not the public pending disclosure. Its constructor/claim/revoke and confirmation
are module-internal. NSLock protects one-use claim/revocation; the owned model
task mints only after destination/registered-root validation, synchronously revokes
on task cancellation and revokes on completion/error. Reply validation uses the
captured scope without reclaiming execution. This API fence is not authentication
against arbitrary in-module/in-process malicious code or an external scope lease.

Destination containment handles `/` explicitly; descriptor identity/local-mount
validation includes the initial `/` descriptor as well as every traversed parent.
Validation-only selected-root/other-registered-root `/` tests create no export.
Tests also cover claim replay, pre-claim revocation, completed/canceled model
execution replay and delayed transport claim after owned cancellation. Ordinary-
import compile gates reject pending disclosure dispatch and execution construction,
while public model confirmation/selection remains usable. No controls removed.

Primary rebuilt actual CLI/retained/export C fixtures; strict Debug **201 tests /
28 suites**, Release export **13 tests / 2 suites**, API gate, full workspace
check (255 Rust + two doctests), offline locked deny, staged-new-file secrets and
whitespace **PASS**. Logs `target/export-X-repair-{debug,release,check}.log` ignored.
No GUI, real-user export, live provider or host launch. Joffrey independently
rechecked the repairs **CLEAR**, passed 13 export tests/two suites with existing
actual CLI/C binaries and ordinary-import compiler gates. He noted `/dev/..`
normalizes to `/`, so that test does not isolate initial descriptor identity;
the validation itself was verified in code. Exact integrated-head CI remains
outstanding; no publication claimed.

Implementation sub-agent: Bob product unit X. TM-01–TM-04, TM-07, TM-10;
partial P2-A1/A3/A4/A5/A6, P3-A3/A5/A6. No phase or host-delivery claim.
Uses the reviewed W backend and unchanged
[export v1](../contracts/project-export-v1.md) /
[captured binding](../contracts/project-export-binding-v1.md) contracts.

## Baseline and owned integration inventory

Initial status clean at `661bdb3e11118efe979cc7adf06c39db723bf133`.
Authorized normal `git merge --no-edit bbacab839171d144cba8cce4e66ea3d59de7d320`
created merge-only baseline **`a66aaf8e8f45873c9541663179779cc1b62c63cc`**, tree
`40ff04cfa4021f99fe4aa7a8a0418d04cfbab458`. Both full parents are retained,
including the prepared contract/site history. No reset, branch switch, new
worktree, implementation commit, push or PR. Primary should integrate only the
owned diff below, not replay the merge/site history.

Tested source = that full baseline **plus uncommitted** twelve-file inventory:

- `apps/companion/Sources/CompanionKit/CompanionModel.swift`
- `apps/companion/Sources/CompanionKit/Contract.swift`
- `apps/companion/Sources/CompanionKit/ProcessService.swift`
- `apps/companion/Sources/CompanionKit/ProjectExport.swift` (new)
- `apps/companion/Sources/CompanionKit/ProjectExportFile.swift` (new)
- `apps/companion/Sources/CompanionKit/ProjectExportView.swift` (new)
- `apps/companion/Sources/ThreadmarkCompanion/main.swift`
- `apps/companion/Tests/CompanionKitTests/CompanionTests.swift` (one exhaustive fixture case)
- `apps/companion/Tests/CompanionKitTests/LiveProjectExportTests.swift` (new)
- `apps/companion/Tests/CompanionKitTests/ProjectExportTests.swift` (new)
- `apps/companion/Tests/ProjectExportFixtures/export.c` (new)
- `apps/companion/scripts/check-retained-api.sh`

SHA-256 **`6a76869f439578131a3ad06a6a4b426f754dd3a64feab218f7f3549264fb5b51`**:
lexically sort those paths; concatenate UTF-8 path, NUL, raw bytes, NUL for each,
then hash. This thirteenth owned progress file excludes itself. New files are
staged for the tracked-file secrets gate; existing edits remain unstaged. There
is deliberately no tested implementation commit SHA or remote CI head yet.

## Product flow and stable acceptance evidence

- **X-EXPORT-CONSENT / P2-A1/A5/A6, P3-A3/A6:** Projects and Privacy mount the
  same explicit Export control. Opening confirmation does no service or file
  access. It captures exact Project/root/identity/incarnation/ordered source
  policy/snapshot, model generation, scope revision and core configuration
  generation. The sheet discloses source excerpts/relative paths/root identity,
  all saved human history (earlier edits and retired revisions), sensitivity,
  sync/backup/retention and no forensic/isolation certification. Cancel is the
  default. Explicit current confirmation yields a one-use save-picker token;
  an OS save destination must be selected before even destination validation or
  export access. There is no appearance fetch, automatic export or fallback.
- **X-EXPORT-OWNERSHIP / P2-A3/A6, P3-A5:** Export is registered in the existing
  model-owned operation registry. It cancels and joins all predecessors and the
  refresh driver before service calls or writing. A detached filesystem worker
  is cancellation-linked and joined by its registered owner, not fire-and-forget.
  Scope/policy/build/config/provider-setting/pause/quit invalidation fences old
  picker callbacks and late bytes. Replayed/old callbacks cannot consume a newer
  picker. Settings enablement never authorizes export. Tests deliberately hold
  a service that ignores cancellation; successors cannot overtake it, and late
  data creates no file. The ordinary-import API gate preserves the retained
  controller negative test and rejects direct export destination-authority access.
- **X-EXPORT-WIRE / P2-A1/A4/A5/A6:** Typed `exportProjectBound` always passes
  the existing mandatory core confirmation flag and the complete captured W
  binding. No preflight followed by unbound ID export exists. The whole stdout
  cap remains 1 MiB including newline/whitespace. A bounded-depth parser rejects
  duplicate keys including escaped aliases before permissive decoding, and a
  closed envelope/nested schema validates exact consent scope, snapshot,
  coverage/currentness, record bounds/order, source/human provenance and complete
  sequential human revisions. Only validated original raw bytes are written.
  The C hostile-stdout fixture checks exact bound argv, empty stdin, complete
  limit success and one-byte overflow rejection; malformed, duplicate,
  additional-document and wrong-scope frames fail. Model failure fixtures prove
  no destination file is published for malformed/duplicate/wrong-scope/overflow
  replies, or for unsafe destinations (which reject before export dispatch).
- **X-EXPORT-FILE / P2-A3/A5/A6:** Destination is exclusively the user-chosen
  NEW name in an existing owned 0700 local directory without ACLs. No parent
  creation, symlink traversal, overwrite, source-root/descendant or store-root/
  descendant destination. After choice, registered project metadata is explicitly
  listed to reject other registered source roots too. Directory descriptors and
  device/inode checks bind traversal; each ancestor filesystem must report
  MNT_LOCAL. Temporary files use exclusive creation and mode 0600. Bounded short
  writes, file sync and exclusive atomic rename publish a complete file; final
  destination/ancestry validation and directory identity checks precede rename.
  Only the matching owned temporary inode is cleaned up. Existing files and
  unrelated similarly named files stay intact. Simulated partial write/ENOSPC,
  sync failure and cooperative mid-write cancellation leave no orphan temps.
  A post-publication directory sync failure retains the complete new user file
  and reports uncertainty, never deletes it. Cancellation/write failure status
  conservatively warns that a new file may exist; no OS-kernel I/O deadline or
  guaranteed cancellation rollback is promised. A separate content-free export
  outcome remains visible even if a later settings/status update replaces the
  general operation status; it retains neither filename nor exported content.
- **X-EXPORT-REAL-CLI / P2-A1/A5:** Synthetic actual-CLI native journey exports
  full indexed source evidence plus all three human revisions (including retire),
  preserves source bytes, and contains no absolute root path. Missing/default
  native confirmation and canceled picker perform no export I/O. Actual external
  snapshot change, ordered-policy change, same-root nonce replacement and
  different-root replacement after picker approval all fail without a file.
  W's actual CLI missing-consent/closed-flag/pre-storage tests also pass in the
  workspace gate. No real user data was exported.

## Verification and reproduction

- Rebuilt CLI: `CARGO_NET_OFFLINE=true cargo build --locked -p threadmark-cli`.
- Rebuilt retained and export C fixtures with the documented command-scoped SDK
  isolation; no ambient headers, settings or dependencies changed:

```sh
mkdir -p target/retained-fixtures target/export-fixtures
sdk=$(xcrun --sdk macosx --show-sdk-path)
resource=$(xcrun clang -print-resource-dir)
xcrun clang -std=c11 -Wall -Wextra -Werror -nostdinc \
  -isystem "$resource/include" -isystem "$sdk/usr/include" -isysroot "$sdk" \
  apps/companion/Tests/RetainedReviewFixtures/retained.c \
  -o target/retained-fixtures/retained
for mode in malformed duplicate oversize unknown partial eof pipeclose idle hold deinit; do
  cp target/retained-fixtures/retained "target/retained-fixtures/retained-$mode"
done
xcrun clang -std=c11 -Wall -Wextra -Werror -nostdinc \
  -isystem "$resource/include" -isystem "$sdk/usr/include" -isysroot "$sdk" \
  apps/companion/Tests/ProjectExportFixtures/export.c -o target/export-fixtures/export
THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" \
THREADMARK_RETAINED_FIXTURES="$PWD/target/retained-fixtures" \
THREADMARK_EXPORT_FIXTURE="$PWD/target/export-fixtures/export" \
  sh apps/companion/scripts/swift.sh test --disable-xctest --enable-swift-testing \
    -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors --no-parallel
# Same environment/wrapper: test -c release ... --no-parallel --filter ProjectExport
sh apps/companion/scripts/check-retained-api.sh
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --offline --locked check
python3 scripts/secrets.py
git diff --check
git diff --cached --check
```

- **PASS final strict full serial debug:** 198 tests / 28 suites in 46.568s,
  with actual CLI, retained C and new export C fixtures enabled; zero skips.
  Log: ignored `target/export-X-native-debug-final.log`.
- **PASS strict release export scope:** 10 tests / two suites in 0.494s, same
  explicit actual-CLI/C-fixture environment; `target/export-X-native-release.log`.
- **PASS ordinary-import model API compiler gate**, including existing retained
  negative gate and added export authority negative gate.
- **PASS `scripts/check.py`:** formatting, locked workspace build, all-target
  strict Clippy, 255 Rust tests plus two doctests, docs, CLI/daemon smoke, docs
  links and intentional failure probe. Its two unchanged 300s/30s ignored Rust
  deadline fixtures were not separately rerun. `target/export-X-check.log`.
- **PASS dependency policy:** advisories/bans/licenses/sources, offline/locked.
- **PASS staged-new-file secrets and staged/unstaged whitespace checks.**

Initial compiler passes caught the necessary new exhaustive fake-service enum
case and an ambiguous Foundation Operation name in the new tests; both fixed
without altering existing behavior. One 120-second debug attempt, concurrent
with the release build, was terminated by the tool timeout before a final result;
it is not counted as a pass. A subsequent process check found no surviving test
or C-fixture processes, and the final standalone full serial rerun passed above.
The cause of that capped attempt was not established. Existing SwiftPM native
backend deprecation and macOS-13/Testing-14 linker warnings remain; no source
warnings were waived. Plain Swift was never used.

## Primary review gates and limitations

Independent review, implementation commit, exact-head remote CI run/URL, PR,
merge and rollout are **not run/not created** and belong to primary integration.
No delegates, reminders, polling, GUI picker invocation, app/host launch,
permissions prompt, credentials, external egress, live provider, network upload,
Docker resource, deployment or real-user file export. Existing unrelated site,
Rust, providers, consent/refinement, retained/diff, schema/dependency/lock and
concurrent human-read implementation are untouched. The R explicit Swift setter
closures and retained API boundary are preserved.

GUI/keyboard/AX/runtime acceptance is not inferred from compilation. Nonlocal
filesystem rejection is covered by the MNT_LOCAL policy unit test and remote-host
URL rejection, not by mounting a real remote filesystem. Disk faults use injected
local write/sync failures, not a real full disk. Mode/ACL and local mount checks
are deliberately narrow controls, not cloud, backup, retention or isolation
certification. Same-user external filesystem mutations and kernel I/O cannot be
leased or given a hard cancellation deadline by cooperative Task cancellation.
The backend's coherent read/currentness/authorization/Forget semantics remain
W-owned; exports are current only at read, not semantic completeness or import.
Plum read was attempted; linked environment was unreachable. No coordination
message, follow-up or reminder was sent.
