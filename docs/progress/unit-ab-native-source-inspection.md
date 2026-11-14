# Unit AB — native explicit source-anchor inspection

## Primary integration and independent review

Primary committed only the twelve owned files as `39159e5` and applied without
conflicts as `8ace8ee`. CI now rebuilds/enables the inspection C fixture and runs
its ordinary-import API gate. Exact combined tested runtime:
**`789945f1d8bacd1ebd4955d92816b05423f7d32f`**. No lane baseline/site history replay.

Joffrey independently reproduced the fingerprint and reviewed **CLEAR**. Rebuilt
CLI and SDK-isolated inspection C fixture; strict Debug and Release inspection
suites each **10 tests/two suites PASS**, including actual CLI and WAL database-
byte/directory preservation. API compiler gates and whitespace **PASS**. He did
not rerun full regression/lint/deny/secrets or GUI/AX/Swift 6.1 execution.

Primary full workspace gate **PASS**, 294 Rust tests + two doctests; strict serial
actual-CLI/retained/export/inspection-C Debug **224 tests/32 suites PASS**; targeted
Release **10 tests/two suites PASS**. Both ordinary-import API gates, offline locked
deny, staged secrets/whitespace, release bundle and Info.plist validation **PASS**.
Long-deadline fixtures remained ignored. Exact publication-head CI remains later.

PR #76 exact post-merge runs `43583739007` and `43583739026`, both targeting
`099d54714c2d43a38cd6528a3a37f0efe135f357`, completed **PASS**. Native human-note
comparison continues independently. Nine inherited progress edits, all worktrees
and parent-owned reminders preserved. V1 short-right-window EOF attestation limit
below remains explicit; no GUI/AX, live model, host delivery or phase closure claim.

Requirements: **TM-01–TM-04, TM-07, TM-10**; partial **P2-A1/A3/A4/A6** and
**P3-A3/A4/A5/A6**, building on **Z-A1–Z-A5** in the reviewed
[source inspection contract](../contracts/source-anchor-inspection-v1.md).
Phase 2 and Phase 3 remain open. This is an occasional management read, not a
companion listener, source authorization, editor, semantic search or inference.

## Baseline and ownership

- Assigned branch: `t3/native-source-anchor-inspection-ui`; initially clean HEAD
  `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Authorized normal `git merge --no-edit` of required local base
  `b2f86f4fbf91002eac769488057078956bf7fd6a` produced the sole new commit,
  **`5d19308393a220ec2377e5118ca1084692eed1e7`**, with those two parents in order.
  Prepared baseline/site history is preserved. No reset, branch switch or new
  worktree was used. **Primary must take only the owned diff against this merge.**
- Implementation remains **uncommitted**. There is no implementation commit SHA,
  PR, push, remote CI run/head, independent review or integration SHA for AB.
  Full tested local HEAD is the baseline merge above plus the fingerprinted diff.
- New files are staged solely for tracked-file secret scanning. Existing modified
  files remain unstaged. Use `git diff HEAD`, not only `git diff`, for integration.

Owned inventory (eleven fingerprinted implementation/test paths plus this document):

| Path below `apps/companion/` | Change |
| --- | --- |
| `Sources/CompanionKit/CompanionModel.swift` | Private immutable owner/generation/configuration/scope capture, query membership, explicit read and invalidation; reuse owned cancellation/join registry; scoped failure preservation |
| `Sources/CompanionKit/Contract.swift` | Additive typed bound operation and reply |
| `Sources/CompanionKit/ProcessService.swift` | Exact Z argv, no stdin, 8192-byte stdout ceiling and strict document decoding |
| `Sources/CompanionKit/SourceInspection.swift` | Full typed registration/anchor request and whole-document closed duplicate-rejecting parser |
| `Sources/CompanionKit/SourceInspectionView.swift` | Explicit radius control and read-only numbered whole-line/provenance display |
| `Sources/ThreadmarkCompanion/main.swift` | Mount Inspect source on each existing literal/ranked result; query-text invalidation |
| `Tests/CompanionKitTests/CompanionTests.swift` | One exhaustive fake-service switch arm; dedicated inspection tests own behavior |
| `Tests/CompanionKitTests/SourceInspectionTests.swift` | Deterministic fake-service lifecycle, membership, preservation and decoder tests |
| `Tests/CompanionKitTests/LiveSourceInspectionTests.swift` | Actual CLI 64-source queries/windows, forged bindings, source mutation, Forget/rebuild and hostile process responses |
| `Tests/SourceInspectionFixtures/inspection.c` | Closed 84-argument/64-policy/EOF-stdin and hostile stdout fixture |
| `Tests/SourceInspectionFixtures/check-api.sh` | Ordinary-importer positive model/full-bound-read and negative private-state/publication/unbound-read compiler probes |

Implementation/test fingerprint (SHA-256):
**`9091f7e508a2072c796a004c272ad0a5d555c24ab7bcbc719eb224a1ad8a82c5`**.
Algorithm: sort the eleven paths above with the `apps/companion/` prefix;
hash each relative UTF-8 path + NUL + raw file bytes + NUL in sequence.
Exclude this progress document to avoid recursion.

## Product and lifecycle boundaries

Each real Query/QueryTerms row has an **Inspect source** button. Radius is 0..3,
default 2. A radius change only clears the previous display; no selection,
appearance or radius callback fetches content. Explicit inspection turns off
automatic refresh rather than manufacturing new refresh authorization. It does
not copy/send, edit, launch a host, call a provider, or change retained/refinement,
export, marker, source-query or edit-CAS contracts.

The request captures the exact cached Project (root bytes/identity, nonce, ordered
policy and non-null snapshot), exact selected row (path/coordinate/hash/text/
producer/kind/currentness), and a private immutable model owner/generation/
configuration/scope action. Membership uses encoded exact bytes, not canonically
equivalent Swift string equality. Every displayed retrieved row is eligible;
invented coordinates/text/producer are not. No ID-only or project-show-then-old-
unbound inspection exists. No normal `project show` is used before/after inspection
or to diagnose failure: its writable store opener could normalize rejected WAL.
The native WAL regression asserts unchanged database bytes and directory entries.
Core still owns authorization and membership before
source traversal; native UI evidence is not authority. The reviewed Z command
transmits its specified path/line/hash selector and complete Project binding;
native decoding additionally requires the exact captured text and producer.

Work is owned by the existing model registry. Successors cancel and join prior
operations before service/spawn; existing shutdown joins all owned work and the
refresh producer. Task cancellation plus generation/owner/configuration/scope
guards reject late results. Query edits/new query, mode/settings/configuration,
policy, selection, Build, Forget, Cancel and Quit invalidate old inspection
eligibility/display. A failed/canceled inspection requires explicit fresh Query
then Inspect; changing radius after a successful idle inspection may explicitly
inspect the same still-eligible query again. No task controller or publication
authority is public.

Same-namespace unknown/dependency/decoder failures and cancellation preserve the
existing query, human history, editor revision and original. Authoritatively
reported policy/snapshot mismatch follows existing source-refresh invalidation;
authoritatively reported namespace replacement follows existing clearing
(including editor/original). CLI nonzero exits are opaque failures, not authority
to classify a replacement: native retains old displayed values, disables their
inspection eligibility and requires explicit fresh Query, without any diagnostic
metadata read or replacement adoption. A later explicit normal Query/Refresh uses
its existing namespace/policy checking and clearing semantics.
No replacement registration or new snapshot is silently adopted. No note Save,
edit binding or human-history behavior was broadened.

The display attaches exact relative path, hash, snapshot, indexed-center producer,
current-at-read and lexical-only labels. Every full line retains its number;
the center is indexed, neighbors (including blank lines) are observed text, not
additional indexed claims. Native buttons/picker have accessibility labels, blank
lines have spoken labels and all status is text, not color. No GUI/AX walkthrough
or host accessibility certification was performed.

## Stable acceptance and evidence

| ID | Local synthetic evidence |
| --- | --- |
| **AB-A1 / Z-A1/A5** | Typed transport requires complete binding, lower-hex hashes/snapshot, non-null nonce, ordered <=64-file policy and admitted path/line/radius. Actual CLI rejects wrong root/identity/nonce/snapshot/policy/hash/coordinate; missing metadata fails request construction. Wrong selected text/producer fails response validation. C fixture verifies all 84 arguments, ordered 64 sources and EOF stdin. |
| **AB-A2 / Z-A2, P3-A6** | Both actual literal and ranked query results can each be explicitly inspected for radii 0..3 with 64 sources, Unicode, escaped text, blank neighbors and naturally bounded windows. Fake service proves zero inspection I/O until explicit action and rejects invented row membership. Actual mounted controls and labels compile in the app. |
| **AB-A3 / Z-A3/A4** | Actual source edits, new snapshots, revoked policy, same-ID same/other-root reincarnation, source Forget plus omitted-source rebuild and failed Build reject the old request with no inspection adoption. Opaque CLI failures preserve old query/human history/original/editor without replacement adoption or renewed inspection eligibility. Authoritative typed namespace errors clear through the unchanged policy. Explicit restoration/requery recovers; deleted/recreated file requires explicit successful Build because file identity changed. Native WAL rejection leaves database bytes and directory entries unchanged. |
| **AB-A4 / P2-A3, P3-A3/A4/A5** | Delayed cancellation-ignoring fake service proves Cancel, successor Query/Build, radius/query changes, settings/configuration, policy, project selection and Quit cannot adopt late output; successors do not overtake prior active work. Full regression suite covers existing human edit-CAS/history/original, retained review, export, cancellation and process-reaping paths. |
| **AB-A5 / Z-A5** | Strict parser rejects unknown/duplicate keys (including escaped aliases and line-object duplicates), wrong scalar types/scope/anchor/text/producer/kind/currentness/radius, gaps, duplicate/out-of-window coordinates, missing center/empty/oversized arrays, numeric overflow, truncated JSON, trailing documents, embedded newline and whole encoded overflow. Exact 8192 bytes including final newline succeeds; 8192 bytes without its required newline reservation fails. Hostile C process verifies no prefix adoption. Ordinary-importer API gates reject private lifecycle/publication access and row-only transport. |

### Important v1 observability limitation

Z v1 returns no EOF/total-line-count metadata. Native validates the exact left
boundary, consecutive coordinates, one exact center, maximum radius/count and
right bound; it accepts a shorter right edge only as the contract's natural EOF
case. It **cannot independently distinguish** a well-formed child falsely claiming
an early right EOF from a genuine short file. Truncated JSON and windows missing
the center are rejected; stronger EOF attestation would require a separately
reviewed backend/wire change, explicitly excluded from AB. Current-at-read also
does not promise future filesystem freshness. No additional source read is used
to invent either guarantee.

## Verification and reproduction

Use the documented command-scoped SDK wrapper, never change global SDK/headers.
Build the synthetic C fixtures with SDK-isolated `clang` (`-nostdinc`, resource
include, SDK `usr/include` and Frameworks); the ordinary host include path contains
incompatible headers. Build `inspection.c` and existing `export.c`; build existing
`retained.c` once with `retained-{malformed,duplicate,oversize,unknown,partial,eof,
pipeclose,idle,hold,deinit}` executable aliases. Paths below are ignored artifacts.

```sh
cargo build --offline --locked -p threadmark-cli
THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" \
THREADMARK_SOURCE_INSPECTION_FIXTURE_BINARY="$PWD/target/unit-ab-inspection-fixture" \
THREADMARK_EXPORT_FIXTURE="$PWD/target/unit-ab-export-fixture" \
THREADMARK_RETAINED_FIXTURES="$PWD/target/unit-ab-retained-fixtures" \
sh apps/companion/scripts/swift.sh test --no-parallel \
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
sh apps/companion/scripts/check-retained-api.sh
sh apps/companion/Tests/SourceInspectionFixtures/check-api.sh
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --locked --offline check
python3 scripts/secrets.py
git diff --check
git diff --cached --check
```

- **PASS:** offline full workspace `check.py`: formatting/build/warnings-as-errors
  Clippy, 282 Rust tests + two doctests, docs/local links, finite CLI/daemon smoke
  and intentional failing-test gate; ignored log `target/unit-ab-check-final.log`.
- **PASS:** offline locked deny, advisories/bans/licenses/sources. Advisory
  freshness is limited to the existing offline cache.
- **PASS:** existing retained/export API boundary and new inspection ordinary-
  importer API positive/negative gates.
- **PASS:** final full strict serial debug Swift with rebuilt actual CLI and all
  three C-fixture groups: **224 tests / 32 suites**, 55.165 seconds;
  `target/unit-ab-swift-full-final.log`. Native WAL regression passed explicitly.
- **PASS:** relevant strict serial release Swift with actual CLI and inspection C
  fixture: **10 tests / two suites**, 3.134 seconds;
  `target/unit-ab-swift-release-final.log`.
- **PASS:** release app bundle built/package-only, executable is arm64 Mach-O,
  executable bit present and `Info.plist` lint passed. Artifact is ignored
  `apps/companion/dist/Threadmark.app`; it was not launched/installed/signed.
- **PASS:** staged-new-file tracked/history secret scan and its intentionally
  rejected synthetic-secret probe; staged and unstaged whitespace checks.
- Unchanged production 300/30-second deadline fixtures were **not rerun**; their
  ignored status remains prior evidence, not a new acceptance claim.
- Local compiler is Swift **6.4**; closures use explicit portable call forms.
  CI's Swift 6.1.2 has **not run** on AB; exact integrated-head CI is primary-owned.

Validation iterations found and repaired an availability-sensitive SwiftUI
`onChange` overload (now an older-SDK-compatible Binding setter), a recovery test
that needed explicit Build after file inode replacement, and Build's active-
inspection supersession guard. Implementation-agent self-review additionally found
the normal metadata opener risk; the final implementation removes all inspection
metadata calls and adds the actual WAL/database-byte preservation regression.
Final passing evidence supersedes the initial failing local iteration logs.

All fixtures are synthetic. No real store/source, real provider/inference, network
egress, credentials, GUI picker/host launch, Docker, spending, deployment, delegate,
implementation commit/push/PR, polling or reminders were used. Initial T3 `Plum`
read returned `thread_not_found`; no coordination or automatic follow-up is claimed.
Inherited full-suite tests include synthetic loopback transport fixtures, not
external providers. Primary owns independent review, integration and exact
integration-head CI.
