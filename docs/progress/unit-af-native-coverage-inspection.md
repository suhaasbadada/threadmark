# Unit AF — native explicit coverage/freshness inspection

## Baseline, ownership and integration boundary

Implementation sub-agent: Bob product unit AF. Requirements **TM-01–TM-04,
TM-07, TM-10**; partial **P2-A1/A2/A3/A4/A6** and **P3-A3/A4/A5/A6**.
Uses the reviewed [AD contract](../contracts/coverage-report-v1.md) unchanged,
including AD's repaired raw-byte line budget. Phase 2/3 remain open.

Assigned branch `t3/266cee11`, initially clean prepared HEAD
`661bdb3e11118efe979cc7adf06c39db723bf133`. Authorized normal
`git merge --no-edit 26a2efa02e8f315885ee25573d6971ed00fa6f51` produced the
sole new commit, full baseline **`3ad593706470c2213647d6a3c7b6b3e49e1b9037`**,
with those two parents in that order. Prepared/site history is preserved.
No reset, branch switch, extra worktree or implementation commit/push/PR.

**Primary must take only the owned diff against that baseline, not replay the
merge/site history.** Implementation remains uncommitted. New files are staged
only for tracked-file secret scanning; use `git diff HEAD` for the whole patch.
The tested implementation is baseline HEAD plus the fingerprinted diff, not HEAD
alone. Independent review, integrated SHA and exact-head CI run/URL are
**not run/not created by this sub-agent** and remain primary-owned gates.

### Owned inventory

Twelve fingerprinted implementation/test/CI paths plus this document:

| Path | Owned change |
| --- | --- |
| `.github/workflows/ci.yml` | Add coverage C fixture build/env and fourth ordinary-import API gate |
| `apps/companion/Sources/CompanionKit/Coverage.swift` | Full-bound request, immutable metadata document, strict whole-document decoder |
| `apps/companion/Sources/CompanionKit/CoverageView.swift` | Explicit button and read-only per-file metadata/counts/currentness labels |
| `apps/companion/Sources/CompanionKit/CompanionModel.swift` | Coverage state/action, private fences, registry cancellation/join and narrow lifecycle invalidation |
| `apps/companion/Sources/CompanionKit/Contract.swift` | Additive typed operation/reply |
| `apps/companion/Sources/CompanionKit/ProcessService.swift` | Closed AD argv, stdin EOF, 65536-byte cap and strict response adoption |
| `apps/companion/Sources/ThreadmarkCompanion/main.swift` | Mount coverage controls in actual selected Projects details |
| `apps/companion/Tests/CompanionKitTests/CompanionTests.swift` | One exhaustive fake switch arm; no inherited test waiver |
| `apps/companion/Tests/CompanionKitTests/CoverageTests.swift` | Explicit-only, preservation, owner lifecycle, serialization and hostile document tests |
| `apps/companion/Tests/CompanionKitTests/CoverageLiveTests.swift` | Actual CLI/SQLite journeys and hostile process response tests |
| `apps/companion/Tests/CoverageFixtures/coverage.c` | Complete ordered 64-source argv/EOF verification and response fixture |
| `apps/companion/Tests/CoverageFixtures/check-api.sh` | Ordinary-import positive full-bound action and negative private/publication/unbound/decoder probes |

Tested SHA-256 fingerprint:
**`193ecdd3f983ba49628cf5aeafbeb5716770a43ce32dea4d2ec3176ccb2f7465`**.
Algorithm: sort the twelve relative paths above lexicographically, hash each UTF-8
path + NUL + raw file bytes + NUL. Exclude this document to avoid recursion.

## Delivered product and trust boundaries

The actual Projects details mount **Inspect coverage**. This is an ordinary
explicit full-bound AD read, not a consent capability, unused adapter, source
authorization or discovery action. Init, selection, appearance, radius edits,
file events and background refresh do not call coverage. No provider, inference,
host, recursive traversal or implicit Build is added. Existing Build remains an
independent explicit manual action. Coverage never grants Query/Inspect-source
eligibility, copies/sends/opens/edits files, enables automatic refresh or rebases
human edits.

Before owned dispatch, the action freezes the exact cached Project root bytes,
root identity, incarnation, ordered complete policy and snapshot (including
explicit none), plus private immutable model owner, generation, configuration
generation and scope revision. Existing owned-operation cancellation/join precedes
successor service/spawn; refresh-driver shutdown is joined too. Publication
revalidates both the action fences and the complete response against that capture.
No current-ID adoption, unbound reload, precheck-then-ID-read or replacement
registration adoption is introduced.

**There is no normal project-show pre/postflight or diagnostic call.** Those
normal openers can normalize WAL. AD alone performs its existing-only READ_ONLY
read and containment checks. Opaque process/decoder/dependency failures retain
existing Project/query/human history/editor revision/edit base/original and CAS
conflict, discard the report and source-inspection eligibility, and require an
explicit fresh metadata action before another coverage attempt. No writable
diagnostic probe or automatic retry follows. Typed authoritative namespace errors
use unchanged namespace-clearing behavior; typed source-refresh errors retain
their existing invalidation semantics.

Cancel, Quit, settings/configuration, selection/policy, query supersession, Build,
and opening Forget invalidate active coverage. Old cancellation-ignoring results
cannot publish, and successors join rather than overlap. General source-inspection,
comparison, retained, export, human search, CAS and Forget semantics remain their
own lanes; generic changes are limited to the coverage-preserving read option,
coverage clearing and lifecycle flags.

### Conservative display/decoder

The closed duplicate-rejecting parser validates the entire document, including
escaped duplicate keys, no trailing document, all required/unknown fields, exact
version/format/registration/snapshot/policy ordering, <=64 exact captured relative
paths, numerical bounds, nullable metadata, each status, hashes, anchor record
counts and recomputed summary/needs-build/currentness consistency. Byte/line totals
are bounded; a matching baseline cannot claim more stored anchor records than
current lines. Missing baseline cannot carry stored records or current matches.
Empty current observations require the empty SHA-256 hash. Whole JSON plus a final
LF reservation must fit 65536 bytes; malformed/partial/overflow responses fail
wholly, never prefix adoption.

Display is explicitly **lexical-only**, semantic completeness **not assessed**,
current-at-read **not a future filesystem lease**. Unavailable-or-unsafe metadata
remains unknown, with no permission/missing diagnosis. Nullable `needs_build` is
shown as unknown. Baseline snapshot is labeled historical; admitted observed file
hashes are current-at-read observations, not a claim that a changed file matches
its baseline. Stored anchors are **record counts**, not semantic evidence. Mixed
files do not make a project current, and empty policy is not completeness. No
absolute root/store path, OS details or source/human content enters the coverage
document/status. UI has textual statuses and a native keyboard-operable Button
with accessibility label/identifier; no GUI/AX walkthrough is claimed.

## Stable acceptance and actual evidence

| ID | Evidence |
| --- | --- |
| **AF-A1 / AD-A1** | Full typed capture including none; C fixture checks all 78 argv entries, ordered 64-source policy and EOF stdin. Real old captures reject after Build, policy change and same-ID nonce/root replacement without adopting B metadata. No additional metadata calls in fake success/error paths. Ordinary-import API gate allows full-bound direct reads but rejects ID-only reads and private state/publication/decoder access. |
| **AF-A2 / AD-A2, P3-A6** | Real CLI register 64 unindexed files, explicit mounted model coverage action, explicit Build, recaptured current report. Actual changed/replaced (same hash/new inode), missing/symlink-unsafe, mixed, readable-empty before/after baseline, blank zero-anchor and empty-policy before/after Build states. Unknown-only unreadability yields null needs-build. UI mounts/compiles with metadata-only text labels. |
| **AF-A3 / AD-A3/A4** | Actual repaired 4096 LF plus NUL/invalid UTF-8 suffix fails native adoption wholly (4097 logical lines); 4095 LF plus suffix stays unavailable-or-unsafe. Database bytes preserved. C hostile responses and decoder matrix reject malformed/partial/overflow/duplicate/extra/wrong types, scope/snapshot/order/path/count/status/hash/currentness and baseline inconsistencies; exact final-newline size boundary tested. |
| **AF-A4 / P2-A3, P3-A3/A4/A5** | Delayed cancellation-ignoring fake coverage versus Cancel, Query/query-edit, settings/config, selection, policy, Build, Forget, source Forget, Quit and successor coverage. Older active Query is canceled/joined before coverage; no overlapping service work. CAS conflict, human history, editor/base/original and existing query preserved through success/unknown error/cancel. Typed namespace error follows existing clearing. |
| **AF-A5 / AD-A4/A5** | Native WAL-header refusal checks exact unchanged DB bytes and directory entries; no normal diagnostics. Actual source Forget invalidates old capture; rebuild/report omits forgotten source while exact source bytes and saved human note survive. Coverage success/failure preserves usable baseline/store bytes. Inherited AB/AC/T/V/Forget and other regressions run without waivers. |

## Verification and reproduction

All fixtures are synthetic. Use command-scoped SDK wrapper (no global SDK/header
changes). C fixtures were compiled with `xcrun clang -std=c11 -Wall -Wextra
-Werror -nostdinc`, its resource include, selected SDK `usr/include` and `-isysroot`.
CI now builds/enables coverage alongside existing retained/export/inspection C
fixtures and runs its API gate. Local ignored artifacts use the same paths as CI.

```sh
cargo build --offline --locked -p threadmark-cli
THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" \
THREADMARK_COVERAGE_FIXTURE_BINARY="$PWD/target/coverage-fixture" \
THREADMARK_SOURCE_INSPECTION_FIXTURE_BINARY="$PWD/target/source-inspection-fixtures/inspection" \
THREADMARK_EXPORT_FIXTURE="$PWD/target/export-fixtures/export" \
THREADMARK_RETAINED_FIXTURES="$PWD/target/retained-fixtures" \
sh apps/companion/scripts/swift.sh test --no-parallel \
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
# Same fixture environment for relevant Release:
# test -c release --no-parallel --filter 'Coverage|SourceInspection|Comparison'
sh apps/companion/scripts/check-retained-api.sh
sh apps/companion/Tests/SourceInspectionFixtures/check-api.sh
sh apps/companion/Tests/ComparisonAPIFixtures/check-api.sh
sh apps/companion/Tests/CoverageFixtures/check-api.sh
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --offline --locked check
python3 scripts/secrets.py
git diff --check
git diff --cached --check
sh apps/companion/scripts/bundle.sh
plutil -lint apps/companion/dist/Threadmark.app/Contents/Info.plist
```

- **PASS:** full offline `check.py`: format/build/warnings-denied Clippy/rustdoc,
  **317 Rust tests + two doctests** (319 passing), CLI/daemon finite smoke,
  local documentation links and intentional failing-test rejection. Two unchanged
  300/30-second deadline fixtures remained ignored, **not rerun**.
  Log: ignored `target/unit-af-check.log`.
- **PASS:** strict full serial Debug, all actual CLI/C fixture groups enabled:
  **254 tests / 38 suites**, 58.668 seconds; `target/unit-af-swift-full.log`.
- **PASS:** relevant strict serial Release coverage/source-inspection/comparison,
  same actual CLI/C fixture environment: **41 tests / nine suites**, 7.401 seconds;
  `target/unit-af-swift-release.log`.
- **PASS:** all four ordinary-import API gates (retained/export, inspection,
  comparison, new coverage); no public lifecycle/publication bypass.
- **PASS:** offline locked deny (advisories/bans/licenses/sources); freshness is
  limited to the existing local advisory cache. Log: `target/unit-af-deny.log`.
- **PASS:** release package/bundle build, arm64 Mach-O executable, Info.plist lint;
  ignored `apps/companion/dist/Threadmark.app`, **not launched**.
- **PASS:** `python3 scripts/secrets.py` with all seven new files staged (tracked
  scan and synthetic-secret rejection), staged/unstaged whitespace, and final
  `python3 scripts/check.py docs` with this document present. Secret log:
  `target/unit-af-secrets.log`.

Local compiler is **Swift 6.4**. Explicit portable closures are retained; local
success is **not Swift 6.1.2 CI evidence**. No new dependencies/lock/schema or Rust,
backend, CLI, source inspection, comparison, refine, retained, export, human-search
kind-filter or site implementation changes. No delegates, GUI, host launch,
credentials, external egress, Docker, spend, deployment, reminders or polling.
T3 `Plum` read returned `thread_not_found`; no coordination was performed.
Inherited full tests include synthetic loopback transports, not external providers.

Initial local iterations caught the required exhaustive fake switch arm, a Swift
test await/autoclosure spelling and nil-vs-null optional test expectation; fixed
without waivers before the final passing full gates above.

## Limitations and primary handoff

AD v1 is the full metadata response, not independent source/hash verification by
the native client. Its transaction/cooperative two-scan checks do not constitute
a hard kernel deadline, external filesystem lease, future freshness, or detection
of an unobservable change-and-restore. The native decoder does not invent a
stronger wire EOF/FS guarantee. No added filesystem reads attempt to do so.
No GUI/AX certification, remote Swift 6.1.2 run, independent review, CI publication
head/run, phase closure, deployment or semantic-completeness claim. Primary must
review/integrate only this owned diff and record the exact integrated tested SHA,
remote CI URL/run/head, required checks and independent review separately.
