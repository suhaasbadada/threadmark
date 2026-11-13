# Phase 1 — Release-pinned OpenCode native bridge prerequisite

## Exact compiler path-fix review and primary execution decision

Joffrey independently reviewed regenerated candidate SHA-256
`7fb64794f4dd856ddcec40afda792538be67742beba411ca49d6ebd70f3da2b8`:
no substantive findings; authentic archive both pins, all 112 files / 107 libraries,
93 reachable default libraries, complete metadata/notices and embedded measured
Node candidate revalidated. Actual compiler normalization/diagnostic/listFiles
paths, fixed configuration, path rejection, quoting and retained cleanup reviewed.
143 pure/static native tests passed, including 32 compiler tests. No target ran.

Primary now authorizes **one exact `run_guard` invocation** on that reviewed
candidate digest for fixed version/positive/negative compiler-only measurement,
under existing unchanged bounds/policy. No automatic retries, permission expansion,
SDK/host execution, new acquisition, provider or binary deployment is authorized.
Failure must retain evidence and be diagnosed before a new reviewed decision.
This is not SDK closure, certification or phase closure; P1-A2/P1-A5 remain partial.

The single authorized real attempt returned BLOCKED: fixed version check observed
TypeScript `6.0.3`; positive semantic check did not receive acceptance and negative
remained NOT_RUN. Target launch occurred; host did not launch. Reported program
closure is NOT established. Cleanup reported verified-or-not-launched. No retry
or sandbox permission change followed. The wrapper preserved only sanitized guard
evidence, not the discarded raw compiler output or precise blocked reason, so the
positive failure's root cause cannot honestly be inferred from this attempt.
Before further authorization, add bounded private diagnostic retention and safe
failure-stage evidence, pure tests and regenerated independent candidate review.

Joffrey's retention review found a medium finalization-evidence inconsistency:
close/fsync failure could return BLOCKED while the immutable record said PASS.
Primary repaired this by persisting only explicitly provisional success and
returning a record/review-bound receipt only after write/close succeeds. Existing
close-failure regression now checks retained bytes; a new post-rename failure test
also proves no terminal success record or receipt survives. All 48 compiler pure
tests pass. Fresh inert candidate digest
`baed387bb15e809d031e9f24a5c43457526ce450b856165c91eb7f6dc8603530`
is UNAPPROVED pending new independent review; no additional target ran.

Fresh Joffrey recheck confirmed the provisional-record repair, 48 pure tests and
actual exact candidate/runtime validation, with no substantive findings. Primary
authorizes one **instrumented diagnostic invocation** on that exact
`baed387bb15e809d031e9f24a5c43457526ce450b856165c91eb7f6dc8603530`
candidate to retain the first failure cause privately under unchanged policy and
bounds. This is a new reviewed observability experiment, not a blind retry or
waiver; no automatic retries or SDK/host execution follows it.

Instrumented invocation BLOCKED with version 6.0.3 PASS, positive exit 1/stderr,
negative NOT_RUN. Before/after validation and owner cleanup passed for both
attempts; owned execution artifacts removed. Raw output retained privately under
the approved private parent. Sanitized diagnosis: `EPERM` / `uv_cwd`, stack
`process.wrappedCwd` -> `Object.getCurrentDirectory` -> compiler CLI. Stdout was
empty. This identifies cwd access as the observed blocker, not a semantic result.

Primary adds only literal `file-read*` on the owned workspace directory itself,
not recursive access, to test that diagnosis. Pure policy tests reject unknown
descendants, host directories and workspace writes. No private/recursive host
grant or measured shared Node/C source change. This candidate needs fresh review
and explicit decision before a third real experiment; no retry has occurred.

Joffrey independently corroborated retained `uv_cwd` failure, exact literal grant,
unchanged fixed oracles/bounds and revalidated candidate
`aea72b77d1cacbcd2daf30aa5b555f6b52b94e8e7c336d3970b8235702039caf`.
No substantive findings. Primary authorizes one diagnostic/compiler-only invocation
of that exact candidate to measure the reviewed owned-cwd-read correction. No
additional grant/retry/SDK or host execution is included in this decision.

The corrected exact invocation PASSED: version 6.0.3/exit 0, positive semantic
success/exit 0/no diagnostics, negative exactly TS2322/exit 2. Each semantic run
reported precisely the expected 93 authentic libraries plus its owned fixture,
hash/role bound to the reviewed inventory. Every before/after validation and
retained-owner cleanup passed; owned execution artifacts removed. Private raw
outputs/attempt records remain retained, outside target access. Successful-call
receipt binds review digest above and provisional record SHA-256
`e969a38afdb040eac3919f2da44c0ef10d2afa12db7810586eb87a4ba909f5eb`.
No second success run or new permission followed. Preserve both earlier failed
attempts and the unavailable-first-diagnostic limitation. `listFiles` binds
reported program-file closure, not all metadata/system reads or SDK closure.
Native compatibility, dependency provenance and P1-A2/P1-A5 remain incomplete.

Primary final local verification: 471 Python tests (including five CI-interpreter
tests and 49 compiler tests) plus 80 Node offline tests = **551 PASS**. Foundation
check and offline cargo-deny PASS. No authentic artifact acquisition or live
compiler execution was added to CI. Staged secrets/whitespace follow final staging;
exact tested commit and remote CI are separate PR gates, not claimed here.

Published separately as PR #26:
https://github.com/suhaasbadada/threadmark/pull/26. Full tested/pushed head
`1d8b3d3c1633494afa8421218ec5c14504da1ac9`, with merged main/site PR #25
integrated without changing measured compiler/runtime sources. All 551 offline
tests and foundation/site checks reran successfully at that exact head. CI
`43353895237`, integrated `43353895253` and offline OpenCode `43353895601`
target that head; initially two offline jobs passed and five jobs remained running.
No CI success, merge or phase closure is claimed before fresh final inspection.
This local append retains exact-head tracking for the notification continuation.

## PR #26 qualified merge and next authentic declaration gate

Fresh exact-head inspection verified all seven jobs SUCCESS on
`1d8b3d3c1633494afa8421218ec5c14504da1ac9`, main target, CLEAN/MERGEABLE,
no draft/comments/unresolved threads or additional approval/protection/ruleset
gate. Independent reviews and actual bounded compiler acceptance above remain
the acceptance evidence; no forge approval was invented. Under standing qualified
merge authorization, PR #26 merged as `1590450e2c40684080fe67ac5c07d1aa87134af1`;
tree equals tested `2df32e199e3d7d5c9816bb3d3051cfe96af3591e`. Watch stopped.
Post-merge offline OpenCode `43354230483`, integrated `43354230530` and CI
`43354230775` all succeeded on that exact merge SHA. No native deployment followed.

Sherlock independently inspected all 345 owned archives, checking compressed
hashes, and confirmed a new declaration dependency: plugin promise entrypoint ->
plugin declarations -> aisdk declarations -> `@ai-sdk/provider@3.0.8` ->
`json-schema` types. Owned json-schema@0.4.0 has no declarations; the provider's
authentic metadata pins dev dependency `@types/json-schema@7.0.15`, absent from
the lock/archive set. Existing Emscripten bytes do not define EmscriptenModule;
the web-tree-sitter surface's optional peer is needed if explicitly consumed,
but ordinary plugin/TUI reachability has not been established for that surface.

Primary reviewed public exact-version registry metadata only for
`@types/json-schema@7.0.15` and candidate `@types/emscripten@1.40.0`: both MIT,
declaration entry `index.d.ts`, empty dependencies/scripts. JSON Schema integrity
`sha512-5+fP8P8MFNC+AyZCDxrB2pkZFPGzqQWUzpSeuuVLvm8VMcorNYavBqoFcxK8bQz4Qsbn4oUEEem4wDLfcysGHA==`;
Emscripten integrity
`sha512-MD2JJ25S4tnjnhjWyalMS6K6p0h+zQV6+Ylm+aGbiS8tSn/aHLSGNzBgduj6FB4zH0ax2GRMGYi/8G1uOxhXWA==`.
These are metadata pins, not acquired-byte/license/semantic certification.
Next unit may add these exact declaration-only prerequisites through generated
lock-only npm and bounded inert acquisition of only those two public registry
archives, with actual notices/dependency inspection and independent review.
No install scripts, runtime import, compiler/SDK execution, new credentials or
waiver of the remaining runtime provenance/engine/type-closure gates is authorized.

Primary final verification also reran all 80 Node offline contract tests: PASS,
bringing this unit to 478 Python + 80 Node = **558 offline tests PASS**.
Joffrey independently verified both authentic archives/pins, all eight selected
file hashes/sizes and MIT notice bytes, generated lock's two-entry-only delta,
unchanged existing notices and qualified closure limitations. No substantive
findings; 175 native tests and whitespace passed independently. Final staged
secrets and whitespace checks PASS. No compiler/SDK execution followed acquisition.

Declaration prerequisite unit published as PR #27:
https://github.com/suhaasbadada/threadmark/pull/27, exact pushed/tested-source head
`693fa8a4d394da29e18788ea188b13d47785b6c0`. CI `43356241295`, integrated
`43356241342` and offline OpenCode `43356241337` target that exact head; all seven
jobs initially running. This local tracking append is not part of that head.
No remote success or merge is claimed pending fresh exact-head verification.

## PR #27 qualified merge

Fresh inspection verified all seven exact-head jobs SUCCESS on
`693fa8a4d394da29e18788ea188b13d47785b6c0` (CI `43356241295`, integrated
`43356241342`, offline OpenCode `43356241337`), main target, CLEAN/MERGEABLE,
no draft/comments/unresolved review threads, and no additional approval,
protection or ruleset gate. Joffrey's independent actual-artifact review and
prerequisite acceptance remain recorded above; no forge approval was invented.
Under standing qualified-merge authorization PR #27 squash merged as
`33bc8b010879d3bf0b846b154c736e4aa4c700b1`. Merge tree equals tested tree
`0435d46a2eefd4e79c73eb0e8a0fd472a951366a`. PR watch stopped. Post-merge
CI remains a separate gate until inspected; no runtime/binary deployment followed.

Next agreed gate: explicit authentic SDK declaration selection and a separate
fixed SDK compiler candidate. The successful standalone guard must remain fixed;
adding missing archive bytes does not establish consumed SDK type closure.
Resolve actual selected-root notice mappings and declaration needs without
stubs/suppressions or automatic ambient types, then independently review the
candidate before any SDK compiler execution. Runtime provenance/engine mismatch,
native-host acceptance and Phase 1 remain open. Worktree and local evidence kept.

All post-merge PR #27 workflows subsequently passed on exact merge
`33bc8b010879d3bf0b846b154c736e4aa4c700b1`: CI `43356685088`, integrated
`43356685052`, offline OpenCode `43356685092`.

Final independent SDK-selection/notice review by Joffrey: no substantive findings;
193 native tests passed, including 18 new selection/notice tests. Actual nine
archives/pins, 338 declaration identities, excluded implementation sources,
three retained registry verification outputs/certificate identities, complete
source tree/blob/notice scope, appended MIT bytes and closed candidate gates were
cross-checked. Cryptographic verification was performed by primary, not rerun by
the reviewer; no such independent execution is claimed. Total unit verification
is 496 Python + 80 Node = 576 offline tests PASS, plus foundation, cached cargo-deny,
staged secrets, documentation and whitespace PASS. No SDK projection or compiler
execution was approved by this review. Private candidate digest
`81378958e9ea8590c3300adf497561a982c3a823dee4f706c14f3911bcdba74d`
remains a planning identity, not operator authorization.

Status: **BLOCKED at dependency license/closure gate, before installation**.
TM-05/TM-08/TM-10; P1-A2 and P1-A5 remain **PARTIAL**, not newly satisfied.
Phase 1 and the full agreed product scope remain OPEN. This is not another
offline model advertised as native, and not a product bridge or certified host.

## Branch, provenance and staged state

- Assigned branch `t3/004628d1`; assigned T3 worktree retained unchanged in
  location. No second checkout, branch switch, reset or user-work cleanup.
- Initial clean base `c10e9ee5ec31569c908dab9d2a556b3c0c99a6d7`; fetched
  `origin/main`, then fast-forwarded only this branch to the exact requested base
  **`6e739637bd90beec1c65b262365ee6f7b9f57509`**. No implementation commits.
- New audit artifacts and this record are staged/uncommitted. No SHA represents
  this changed tree. Parent owns design approval, review, final tested SHA, exact
  CI run/head, commit, push, PR and any authorized merge.
- Public release/source mapping supplied by parent's Sherlock audit:
  v2.2.5 → `9bbb8ce18c80f099e0e448775f59d965ead40a21`. Not independently
  re-certified here; not a cryptographic match to the installed executable.
- Read Phase 1 specification, product requirements, ADRs 0003/0004, the original
  48-test OpenCode contract/README/progress and host-isolation limits. No graph
  existed; targeted source reads used, without building a graph or delegating.
- Fetched full public V2 plugin overview, server, TUI, RPC and JavaScript client
  documentation. Rolling documentation does not supersede pinned declarations.

## Dependency evidence and stop decision

Exact candidate direct pins: `@opencode/plugin`, `@opencode/client` and
`@opencode/theme` **2.2.5**; `@opentui/core` and `@opentui/solid` **0.8.0**;
`solid-js` **1.9.17**; compiler alias **npm:@typescript/typescript6@6.0.2**.
No embedded `@opencode/sdk` added or acquired. The npm-generated lock has 375
entries, including 11 optional records. This is a resolution candidate, **not a
fully approved closure**; nonoptional peer/type dependencies remain unresolved.

The [audit README](../../experiments/opencode/native/README.md) records the exact
blocking paths, isolation controls, compiler-wrapper distinction, engine mismatch
and decision options. The [machine-readable ledger](../../experiments/opencode/native/dependency-audit.json)
records lock SHA-256, all advertised SHA-512 values and licenses. Metadata counts:
MIT 200, ISC 76, Apache-2.0 71, BlueOak-1.0.0 17, BSD-2-Clause 4,
BSD-3-Clause 2, plus one each CC-BY-4.0, CC-BY-3.0, CC0-1.0, 0BSD,
and `(AFL-2.1 OR BSD-3-Clause)`.

Actual downloaded-byte SHA-512 matched public metadata for **five** archives:
plugin 2.2.5, client 2.2.5, TypeScript wrapper 6.0.2, caniuse-lite 1.0.30001826,
and spdx-exceptions 2.5.0. Plugin/client also match the exact integrities supplied
in the brief. Archive package manifests were read without extraction/execution;
license-file hashes are recorded where present. **370 entries have no computed
tarball check. No complete artifact/license audit passed.** Registry integrity
matching alone does not establish trustworthy provenance or host identity.

CC-BY-4.0/3.0 are outside the currently authorized license set. Stopped rather
than installing anyway. Parent must decide whether to retain the gate or approve
specific exceptions/closure and compiler pin; neither approval is assumed.
Native code implementation, strict positive/negative SDK compile and new pure
state-machine tests are **NOT RUN / NOT IMPLEMENTED**, not silently substituted.

## Verification at the exact base plus staged audit files

No existing runtime, test or workflow changed. All **381 existing integrated
tests passed**: Python selector 5, extraction 18, containment 25, corpus 10,
scoring 24, adapter 18, lexical 21, candidate 39, symbol 37, directcall 79,
runner 25, combined Node OpenCode/T3/UX 80 (including OpenCode's existing 48).
Used the repository's reviewed installed Python 3.12 selector and actual workflow
commands; Python discovery also treated ResourceWarning as error. Nothing was
downloaded to obtain Python. The bounded positive worker regressions ran without
any SDK host, model or provider startup.

- Actual local synthetic macOS guard: **passed**, Darwin kernel 27.0.0,
  `result=synthetic-only-pass`, **`host_launched=false`**.
- `python3 scripts/check.py`: **passed** format/build/Clippy/workspace tests,
  doctests/docs, finite Phase 0 CLI/daemon diagnostic smoke, local Markdown links
  and deliberate failing-assertion rejection. These finite foundation commands
  are not native OpenCode or a working Threadmark daemon service.
- `cargo deny --offline --locked check`: **passed**, advisories/bans/licenses/
  sources. Advisory freshness is limited to the cached database; no online
  freshness claim or npm advisory scan. npm audit was deliberately disabled.
- `python3 scripts/secrets.py` after staging all six files: **passed** history
  and tracked/staged-file checks; synthetic sentinel correctly rejected.
- `git diff --cached --check` and `git diff --check`: **passed**. Local Markdown
  link checks rerun after adding this record and audit README: **passed**.
- No new CI workflow or automatic download step. Remote exact-change CI and
  independent review **NOT RUN**; parent owns both.

## Still-open design and native-runtime gates

No host launch plan was executed or approved. Before any future host launch,
parent-reviewed pre-execution plan must pin exact executable/package hashes and
demonstrate config-ancestor/system discovery negative controls, restricted reads
and writes, private owned state, provider/network denial, no shared service,
no auto resume, process-group termination within two seconds, bounded stdout/
stderr and content-free evidence, then native review/real acknowledgment with
zero inference. Listenerless SDK memory mode still loads config/credentials,
watchers/recovery and is **not** isolation. Earlier version-only observations do
not satisfy this new plan. No policy allowance was widened here.

After the dependency gate, implementation must preserve the parent's full native
capture → metadata-only session-local pending selection → explicit exclusive
lease claim → rendered original/candidate and all attachment/agent/skill/delivery
bindings → fresh server scope/fidelity revalidation before and after awaits →
synchronous one-attempt latch → actual native SessionInboxUser acknowledgment.
Close/navigation/reload/disconnect/cancel/timeout revoke review; unknown admission
never retries. Native UI and RPC expose no authenticated origin-window identity
or current-composer capture; local nonce leases must not be advertised as auth
against fully trusted plugins/clients. Core revision/scope verification remains
unresolved and closed. Immutable attachment fingerprints and mention fidelity,
diff semantics, native message identity/reconciliation and hook-order effects
remain required. No text-only fallback or automatic original send.

Synthetic injectable daemon preparation is a labeled bounded test port, not real
refinement. Complete context ownership/turn/serialization handling is a separate
pending gate: no guessed currentTurn, last-user-role heuristic, forged-marker
deletion or model-option overwrite. Full context, refinement, hosts, inference,
UX and safety remain required; this stop does not narrow them to an MVP.

No native host/service, SDK executable import, listener, model, real prompt,
draft, clipboard, application DB/config, provider, credential reuse, Docker,
global install, deployment, subdelegate, scheduler or watch. All artifacts remain
staged only. T3's requested Plum/current-thread lookup returned `thread_not_found`;
no coordination message or visible thread rename was claimed.

## Parent acquisition decision — conditional development-only gate

Sherlock independently reviewed the two specific attribution-license findings and
revised acquisition options. This is a technical dependency assessment, not legal
advice or a claim that all 375 packages passed review. The original narrow license
set was imposed by the parent task, not an explicit user redistribution policy.

Parent selects the bounded development/static-check path, subject to all remaining
artifact/closure checks, with **exact-package exceptions only**:

- `spdx-exceptions@2.5.0`, CC-BY-3.0, exact integrity already recorded in the audit.
  Preserve Copyright © 2010–2015 Linux Foundation and its Contributors, Kyle E.
  Mitchell's source attribution, pinned upstream README and the CC-BY-3.0 link.
  Absence of an archive LICENSE does not make this public domain.
- `caniuse-lite@1.0.30001826`, CC-BY-4.0, exact recorded integrity. Preserve the
  archive LICENSE, README attribution to caniuse.com/Alexis Deveria, Ben Briggs'
  manifest authorship, source/license links and unmodified status. This exception
  includes its shipped helper code, not only its data; no MIT relicense is asserted.

Use is limited to private, nonredistributed development/type checking in this
isolated task. No package publishing, bundled dependency redistribution, cache/
container/artifact upload, native SDK/UI execution or production approval follows.
Any later distribution needs a separate notice/compliance review; the root MIT
license does not relicense these third-party packages. Record dedicated notices.

The remaining permissive licenses (MIT, ISC, Apache-2.0, BSD-2/3-Clause, BlueOak-1.0.0,
CC0-1.0, 0BSD, and the explicit BSD-3-Clause option of the AFL/BSD alternative)
may proceed only with their actual package-specific notices and verified artifacts.
Unknown/new license expressions or provenance gaps still stop acquisition.

Replace the floating TypeScript wrapper deliberately with exact Apache-2.0
`typescript@6.0.3`, verifying its own archive before compiler execution. Resolve
the actual mandatory type peers and regenerate the lock through npm, never by hand.
Verify every **acquired** archive before installation, with scripts/credential
reuse disabled and owned HOME/config/cache. Unacquired optional platform packages
must be explicitly excluded, not marked verified. Reject archive traversal, links
or special files; bound each archive and total acquisition/extraction. Parent
accepts this bounded audit surface (32 MiB/archive, 256 MiB compressed total,
1 GiB declared extracted total); exceeding it requires a fresh decision.

OpenTUI's engine mismatch remains a runtime blocker, not a waived engine check.
Only the independently verified compatible compiler may execute for static checks;
no SDK/TUI host import or startup. Complete real declaration checking, not ambient
SDK stubs or `skipLibCheck`, is required. Native bridge implementation proceeds
only after this conditional dependency gate actually passes. This does not reduce
the full agreed product scope or close Phase 1.

## Declaration-only alternative — implementation gate, not execution approval

The full runtime acquisition path remains blocked on package-specific notice/
provenance gaps. It has not passed because archive hashes matched. Primary ran
the previously unfinished archive tests: **18 PASS** without dependency imports.
Sherlock's prior alternative and a fresh independent Joffrey design review identify
a separate legitimate static-analysis path, **not approval of runtime closure**.

Parent authorizes implementation and pure synthetic testing of a declaration-only
projection utility/ledger now, with **no compiler execution, new download, npm
installation or SDK/TUI import**. Keep byte-identical complete package manifests,
original package-relative paths and nested dependency identities; authentic
declaration/JSX/type source bytes only, never fabricated ambient SDK types or
substitute aliases. Missing mandatory types/notices remain blockers. The eventual
pinned compiler must perform official resolution; a projection cannot claim the
full npm/runtime graph or assume excluded packages are irrelevant.

Materialization must write only selected regular bytes into a newly owned private
destination, never general tar extraction; reject effective PAX/GNU traversal,
links/sparse/special files, case-folded collisions, file/ancestor conflicts,
pre-existing destination links, malformed/oversized archives and count/total
overflow. Rehash archives and output; interrupted/incomplete projection is not
usable. Add negative tests and fix redirect prevention before any future acquisition
reuse: checking a final URL after following a redirect is too late.

Compiler execution needs a **separate subsequent reviewed launcher/plan**: verified
compiler and pinned Node; empty allowlisted environment; explicit owned config/
roots/typeRoots/types; no NODE_OPTIONS/NODE_PATH, plugins, extends, custom resolver,
watch/build, allowJs, either library-skip option or owned-source suppressions;
strict non-any positive assertions and intended-diagnostic negative fixtures.
Trace every consumed file back to approved bytes/notices; genuinely unresolved
requested modules fail. Deny network and reads outside approved types/compiler,
necessary Node/system files and owned state; prove negative controls and the
120-second/output/heap/two-second cleanup limits before execution. No existing
host containment policy may be broadened for convenience. This revision changes
only the acquisition-design gate, not product scope or native acceptance.

## Bob implementation handoff — declaration preparation only

Assigned branch `t3/004628d1`, unchanged base HEAD
`13bdeb0be2bc4f5375b46ad902c6dba876cc682c`; tested working-tree changes are
staged only, not a new committed/tested SHA. Parent owns independent review,
exact eventual committed SHA/CI run/head and later publication decisions. No CI
run for these uncommitted changes, merge, deployment or certification is claimed.

TM-04/TM-05/TM-08/TM-10, P1-A2/P1-A5 supporting dependency-boundary evidence:
`project_types.py` prepares only explicitly reviewed, hash-bound authentic files
and complete unmodified metadata in nested npm locations. It does not implement
package resolution. Its full-archive preflight is deliberately stricter than the
inert archive inspector (all duplicates reject); explicit non-`package` roots
are supported. Fresh private output uses nofollow/exclusive descriptor-relative
writes, copied-byte verification and a verified atomic ledger with an incomplete
marker until success. Failure artifacts remain owned/incomplete, not usable or
claimed cleaned. Parent path ancestors are trusted; this is not arbitrary
hostile same-UID containment. Prepared means only `prepared_not_compiled`, never
type/runtime closure. There is no actual SDK selection or projection result.

The archive inspector now denies redirects before network follow, retaining its
final-URL defense. The existing Python-3.12 workflow discovery automatically
includes new pure tests; no install/compiler/acquisition CI step was added.
Historical audit remains unchanged; regenerated package files, provisional
notices, conditional blocked ledger and source-notice evidence are retained.

Local verification on this working tree:

- Python **3.12** native discovery: **41 PASS** = 18 retained archive tests,
  2 redirect regressions and 21 projection tests. Synthetic inert byte fixtures
  cover exact metadata/exports-null/wildcard preservation, selected declarations/
  JSX/source, nested versions/nonstandard roots, approval/hash/identity/missing
  requirements, unsafe effective PAX/GNU names, special/sparse/link members,
  duplicates/case/NFC/ancestor conflicts, inclusive bounds/overflow, preexisting
  roots/links, child-link injection, interruption/copied-file/ledger corruption.
- Existing integrated suites: **381 PASS** (296 Python experiment tests,
  5 Python selection tests, 80 Node tests); thus **422** with native discovery.
- Actual macOS synthetic guard: `synthetic-only-pass`, `host_launched: false`.
- `python3 scripts/check.py`: PASS (format/build/clippy/workspace tests/docs,
  CLI/daemon offline smoke, documentation links and intentional failure probe).
- `cargo deny --locked --offline check`: PASS using cached advisory data;
  no claim of a refreshed online advisory database.
- After staging all 12 unit files, `python3 scripts/secrets.py`: PASS for
  history/tracked working-tree scan and the intentional secret rejection probe.
- `git diff --cached --check`: **FAIL (370 diagnostics)** confined to authentic
  upstream notice whitespace/CRLF and terminal blank line in the provisional
  `THIRD-PARTY-NOTICES.txt`. Legal evidence was preserved rather than silently
  reformatted. The same check excluding that single notice artifact: PASS;
  all implementation/configuration/docs/JSON files pass. No global whitespace
  rule was disabled and the full check is not represented as green.

The runtime notice/provenance gaps (agent/eastasianwidth/three AWS packages),
mandatory authentic declaration needs including `@types/emscripten`, Node/OpenTUI
engine mismatch, full type closure and all real native acceptance remain
**BLOCKED/unestablished**. Neither synthetic tests nor this utility close P1-A2,
P1-A5 or Phase 1. Separate reviewed compiler/containment plan and actual consumed-
file verification are still required. No compiler, SDK import, host, new download,
install, provider, credential reuse, model, service or Docker was used in this unit.

## Primary review and repair — prerequisite tooling only

Joffrey independently reviewed the staged projection/acquisition implementation,
tests, workflow, identities and evidence claims; his 41 native tests passed. He
found one medium acquisition defect: aggregate declared member sizes were checked,
but aggregate decompressed tar bytes (headers/padding included) were not. Primary
reproduced the boundary with real synthetic archives and repaired the inspector/
acquisition return, enforcement and evidence fields. Two regression tests check
the inclusive actual-expanded total and one-byte aggregate overflow. The primary's
Python 3.12 native discovery now passes **43 tests**. The blocked historical ledger
is retained unchanged and does **not** prove an aggregate actual-expanded bound;
no corrected acquisition, SDK projection or compiler run is asserted.

The original 370 notice whitespace diagnostics are retained above as actual
failure evidence. Primary added a narrowly scoped `.gitattributes` `-whitespace`
attribute for the single authentic upstream `THIRD-PARTY-NOTICES.txt` artifact.
No legal text was rewritten, no global check was disabled, and no other path is
exempted. Full staged whitespace validation now passes with this explicit legal-
evidence policy; the original notice blob remains byte-identical to Bob's handoff.

Primary reran foundation checks and cached offline cargo-deny successfully.
Fresh integrated verification passed **424 tests**: 344 Python tests (including
43 native tests) and 80 Node tests. The actual macOS synthetic guard returned
`synthetic-only-pass`, `host_launched: false`. Both new acquisition regressions
were also executed against the pre-fix inspector: missing expanded-byte evidence
and an incorrectly accepted overflow failed as expected. The repaired inspector
passes both. No network, compiler or dependency execution was used by these tests.
The optional no-mistakes CLI reported this repository is not initialized; no
no-mistakes pipeline, second worktree or gate configuration was created. Existing
repository checks and independent review remain the verification route.
Staged secrets, final tested commit, exact-head CI and merge acceptance will be
recorded separately; none is implied by this entry.
P1-A2/P1-A5 remain PARTIAL and Phase 1 OPEN. Full runtime acquisition, authentic
mandatory type closure, compiler containment/execution and native behavior remain
separate unpassed gates.

## Published prerequisite — exact-head CI pending

PR: <https://github.com/suhaasbadada/threadmark/pull/21>, target `main`.
Full implementation/tested head:
`3f3f1893a30b31e7530e0eb4a363b3e5d2a7f768` (tree
`3674164aea82acdea205fc7d10c87e859598ae11`). All local results above apply to
this implementation; staged secrets and full whitespace checks passed before
commit. Worktree was clean following publication; this appended evidence is a
local progress update, not an additional published head or claim of remote green.

Initial PR inspection confirmed that exact head and seven registered jobs:

- Foundation CI: <https://github.com/suhaasbadada/threadmark/actions/runs/43317833157>
  — both Rust platforms and dependencies/licenses/secrets IN_PROGRESS.
- Integrated experiments:
  <https://github.com/suhaasbadada/threadmark/actions/runs/43317832992>
  — Linux/macOS IN_PROGRESS.
- OpenCode offline contracts:
  <https://github.com/suhaasbadada/threadmark/actions/runs/43317833155>
  — Linux/macOS SUCCESS; these remain abstract offline contracts, not native proof.

No remote approval/review was present at initial inspection. Joffrey's independent
review and the primary's repair/regression evidence are recorded above. Merge
remains gated on fresh complete exact-head checks and approval/discussion/target
verification. No merge, runtime deployment, phase closure or native certification
is claimed. Plum coordination remains unavailable (`plum did not answer`); no
coordination reply was inferred or fabricated.

## PR #21 merge gate and continuation

Fresh PR inspection verified all seven exact-head checks SUCCESS for
`3f3f1893a30b31e7530e0eb4a363b3e5d2a7f768`, target `main`, MERGEABLE/CLEAN,
no unresolved review threads, no draft state, and no repository branch-protection
or ruleset approval requirement. No forge approval was invented; independent
Joffrey review plus primary repair/regression verification are recorded above.
The same three PR runs linked above completed successfully. This accepts only
the prerequisite unit, not the still-partial P1-A2/P1-A5 phase acceptance.

Under Suhaas's standing qualified-merge authorization, PR #21 was squash-merged
at `3ae73eaa7be65ce7b4c2187b72f10e8f26e06287`. Its tree is exactly
`3674164aea82acdea205fc7d10c87e859598ae11`, matching the tested implementation
tree. No binary/runtime deployment or phase closure followed. The PR watch was
stopped. Assigned task branch/worktree and local progress updates were preserved;
the exact merged main was integrated without reset, branch switch or cleanup.

Post-merge runs were freshly bound to the merge SHA: foundation CI
<https://github.com/suhaasbadada/threadmark/actions/runs/43318520271> and integrated
experiments <https://github.com/suhaasbadada/threadmark/actions/runs/43318520767>
were IN_PROGRESS at inspection; OpenCode offline contracts
<https://github.com/suhaasbadada/threadmark/actions/runs/43318520581> were SUCCESS.
No pending post-merge run is called green. Next authorized work remains a reviewed
compiler-only preflight/containment plan and pure tests, not compiler execution,
new dependency acquisition, SDK loading or native certification.

## Bob continuation — inert compiler-only preflight candidate

Assigned branch `t3/004628d1`, full local merge HEAD
`2c001f3d20ae1dda86a53b8001ea4cbd6d677e6a`; integrated main/base
`3ae73eaa7be65ce7b4c2187b72f10e8f26e06287`. The parent-owned progress text
above is preserved, with this append only. This unit is staged/uncommitted:
there is **no new tested implementation commit or exact-change CI run**. Parent
owns independent review, final tested SHA, publication and exact-head CI. The
post-merge run IDs/states above were not polled or reclassified by Bob.

TM-04/TM-05/TM-08/TM-10, supporting P1-A2/P1-A5 prerequisites only:
`compiler_plan.py` now validates an out-of-band operator-reviewed manifest digest,
reconstructs authentic selected projection bytes from already-owned archives,
requires exact prepared ledger bytes/hash and absence of incomplete/extra files,
and validates complete metadata, source/Node/compiler inventories and notices.
Canonical paths, single-link regular files, aliases, roots, hashes, source
suppressions, compiler modes and known missing requirements fail closed.
Owned fixtures retain normal node_modules ancestry without aliases. The returned
descriptor exposes per-read-file/config hashes, fixed strict no-emit config,
explicit roots/typeRoots/types, clean environment, fixed compiler argv and
independent bounds. No config is written and there is **no launch entrypoint**.

The [compiler plan](../../experiments/opencode/native/COMPILER-PLAN.md) documents
authority, exact compiler archive pin and notice/helper/lib inventory review,
Node version/hash inventory trust, same-UID parent-path assumptions, pending
macOS system/dyld/owner policy, typed policy serialization and the future measured
negative-control matrix. Compiler archive provenance is an **external reviewed
inventory attestation**, not new archive verification/projection by this builder;
Node version identity likewise cannot be proved from a hash without external
review. Synthetic fixtures are inert invented bytes, not authentic compiler/Node
proof. All actual selection/inventory approvals remain future gates.

Every descriptor says `executionApproved: false`, `containmentVerified: false`,
type/runtime closure `NOT established`. Future execution separately requires
independent plan review, explicit parent authorization, complete reviewed minimum
runtime/system inventory, launch-time revalidation and measured negative controls.
Retained process-owner/status/control semantics are required; 120 s wall,
16 MiB combined output, 1 GiB V8 old-space and 2 s cleanup proof are budgets,
not measurements. Unknown cleanup/EPERM quarantines rather than claiming success.
No system read allowance, generic process framework or host policy was added.
Actual strict non-any positive/negative diagnostics and consumed-file closure
remain unrun; unknown module problems require the future official compiler.

Verification on the uncommitted tree:

- Native discovery: **69 PASS** = retained 43 + **26 new pure synthetic tests**.
  Final native rerun used selected installed Python **3.12** and ResourceWarning
  as error. Tests inspect observable descriptor/config/environment/hash contracts;
  they do not grep implementation text or simulate compiler/type closure success.
  Source/entrypoint bytes containing dynamic process-import syntax remain inert;
  guarded process/socket/acquisition APIs were not called by the builder.
- Full existing integrated workflow suites plus new tests: **450 PASS** =
  370 Python (including the 69 native tests) + 80 existing Node offline-contract
  tests. No Node probe/compiler/SDK command was invoked. Existing bounded worker
  tests remain synthetic contracts, not native compiler containment proof.
- `python3 scripts/check.py`: **PASS**, including Rust format/build/Clippy/tests,
  docs, finite foundation diagnostics and intentional-failure rejection. Local
  Markdown links rerun after plan changes: **PASS**.
- `cargo deny --locked --offline check`: **PASS**, cached advisories only;
  no online freshness or npm audit claim.
- Initial direct `scripts/ci_python.py` invocation lacked its required CI-only
  `GITHUB_ENV` and failed; corrected by using its existing selector API without
  writing global/CI state. Reviewed installed Python 3.12 selection and its five
  tests passed; no interpreter was acquired.
- After staging the five handoff files, `python3 scripts/secrets.py`: **PASS**
  (tracked/history scan and intentional synthetic-secret rejection).
  `git diff --cached --check`, `git diff --check`, and Markdown links: **PASS**.
  No new workflow/dependency, compiler, acquisition, SDK/TUI import, native host,
  provider, credential reuse, Docker, delegate, scheduler, watch, commit, push,
  PR, merge or deployment was used. Actual macOS compiler negative controls and
  the standalone synthetic guard were **NOT RUN** in this unit.

Full runtime notice/provenance gaps, authentic mandatory types (including
`@types/emscripten`), Node/OpenTUI engine compatibility and actual SDK selection
remain blocked. Native capture/attachments, immutable fidelity, exclusive review
lease, scope/revision/admission, context ownership and full agreed product scope
remain open. P1-A2/P1-A5 remain PARTIAL; no Phase 1/native acceptance is claimed.

## Primary compiler-preflight review and encoding repair

Primary freshly verified the two pending PR #21 post-merge runs above: foundation
`43318520271` and integrated `43318520767` completed SUCCESS on exact merge head
`3ae73eaa7be65ce7b4c2187b72f10e8f26e06287`. Together with offline contracts
`43318520581`, the three recorded merge-head workflows passed. This remains
offline CI, not a deployment or native acceptance gate.

Joffrey independently reviewed the compiler-preflight unit and ran its 26 pure
tests. He requested a medium fix: raw ASCII-byte suppression scans accepted
BOM-marked UTF-16 source directives. Primary repaired the owned-source contract
to strict UTF-8 (optional UTF-8 BOM), rejecting malformed encodings and NUL before
directive checking. Authentic upstream bytes are not rewritten. Two new tests
cover both UTF-16 byte orders/all three directives, invalid UTF-8/NUL, UTF-8 BOM
directives, and valid UTF-8 with/without BOM while preserving exact byte hashes.

The encoding regression was executed against the pre-fix implementation and
failed in the six directive cases plus malformed/NUL cases, as expected. The
repaired native suite passes **71 tests** with ResourceWarning treated as error.
No compiler, Node probe, SDK import, acquisition or network was used by these
reproductions. Primary cached offline cargo-deny also passes; no advisory-refresh
claim is made. Fresh full-suite/foundation/staged checks and publication evidence
will follow separately; execution approval and measured containment remain CLOSED.

## Published compiler-preflight prerequisite — PR #22

PR: <https://github.com/suhaasbadada/threadmark/pull/22>, target `main`.
Tested implementation head `47328e24087b995c1295860c7a9010b13c66d292`, tree
`f00dd8cc330794b0a8345c543be9a6e8dc649f43`. Primary fresh integrated verification
passes **452 tests** (372 Python, including 71 native; 80 Node); actual macOS
synthetic guard passes with `host_launched: false`. Foundation checks, cached
offline cargo-deny, staged secrets and full whitespace checks pass. Joffrey's
review, sole encoding finding and primary regression repair are recorded above.

Initial exact-head PR inspection registered seven queued/in-progress jobs:

- Foundation CI: <https://github.com/suhaasbadada/threadmark/actions/runs/43321091555>
  — both Rust platforms plus dependencies/licenses/secrets.
- Integrated experiments:
  <https://github.com/suhaasbadada/threadmark/actions/runs/43321091267>
  — Linux/macOS.
- Offline OpenCode contracts:
  <https://github.com/suhaasbadada/threadmark/actions/runs/43321091590>
  — Linux/macOS.

These are pending, not green. Exact-head final checks, approvals/discussions,
target and prerequisite-only acceptance must be freshly checked before merge.
This appended local evidence is not another published implementation head.
No compiler/SDK/host, native containment measurement, type closure, product
acceptance, deployment or phase closure is claimed. The assigned worktree and
all progress text remain intact; no duplicate worker or reminder was created.

## PR #22 qualified merge

Fresh inspection verified all seven exact-head jobs SUCCESS for
`47328e24087b995c1295860c7a9010b13c66d292`, with the three PR run IDs above,
target `main`, MERGEABLE/CLEAN, no draft, no unresolved review threads and no
additional repository branch-protection/ruleset approval gate. No forge approval
was invented. Independent Joffrey review, his sole finding, and the primary's
encoding repair/pre-fix regression evidence are recorded above. This accepts only
the inert prerequisite, not compiler containment or phase acceptance.

Under standing qualified-merge authorization, PR #22 was squash-merged at
`d5e9a04cae1cad1c22e0e23032cc8131b7c98cc9`. The PR watch was stopped. The
assigned task branch integrated merged main without branch switch, reset or
cleanup; local progress updates were preserved. No compiler, SDK/TUI, provider,
binary/runtime deployment or native certification followed. Post-merge CI and
the next synthetic containment-harness gates remain separate.

## Synthetic containment implementation decision

PR #22's merge tree equals tested tree `f00dd8cc330794b0a8345c543be9a6e8dc649f43`.
Fresh post-merge verification found SUCCESS on exact merge head
`d5e9a04cae1cad1c22e0e23032cc8131b7c98cc9`: foundation CI
<https://github.com/suhaasbadada/threadmark/actions/runs/43321679364>, integrated
experiments <https://github.com/suhaasbadada/threadmark/actions/runs/43321679397>,
and offline contracts <https://github.com/suhaasbadada/threadmark/actions/runs/43321679385>.

Sherlock independently investigated the actual next executable prerequisite.
The existing C host guard permits fork and whole-state writes; it is not evidence
for compiler no-child containment. Primary selects minimal extraction of the
repaired retained-owner mechanism into a private shared helper, preserving the
extraction wrapper's 15 s/256 KiB cap and existing behavior. A separate fixed C-only
synthetic experiment may use explicit bounded budgets; no generic public command,
profile or executable launcher is authorized. The existing host guard is not
broadened or migrated. Unknown cleanup must preserve/quarantine owned state and
block reuse, not merely raise and then unconditionally delete its directory.

Implementation and pure/portable synthetic tests are authorized now. **The new
C sandbox runner itself must receive independent policy/code review before its
first measured run.** A later primary decision may authorize only that fixed C
fixture using installed Apple tools and owned synthetic canaries. System-only
`/usr/lib`/dyld baseline allowances may be implemented as a separately labeled
synthetic baseline; they are not Node's reviewed minimum inventory and may not be
silently expanded to home, repository or private trees. No network allowance or
target fork/spawn permission is authorized. Bootstrap failure is a concrete
blocker to investigate, not permission to restore fork.

No Node/compiler/SDK execution, dependency acquisition or real compiler launch
descriptor is authorized by this implementation decision. C controls cannot prove
Node loader/config/type behavior, V8 memory containment or declaration semantics.
Full type closure, runtime provenance and all native/product gates remain open.

## First C-only run authorization after independent review

Joffrey reviewed the exact eight-file staged synthetic harness/fixture/policy and
shared owner refactor, identifying no substantive blocking finding. He separately
passed 18 synthetic policy/portable owner tests and 20 extraction tests with
ResourceWarning as error, and staged whitespace validation. He verified fixed
extraction caps, private owner status/readiness, TERM/KILL-before-reap, quarantine/
artifact retention, no fork/network allowance, DAC-independent denial checks and
content-free complete observations. His review does not establish actual SBPL,
C denial outcomes or exact-change CI.

Primary authorizes **one exact fixed `--synthetic-compiler-guard` execution** after
committing the reviewed implementation, using installed Apple C tools, fresh
private owned artifacts/canaries and only owned loopback receivers. No policy
change, retry, compiler/Node/SDK execution, provider call or external egress is
authorized by this decision. Any bootstrap/parser/denial failure blocks and must
be diagnosed with evidence, not permission expansion. C results remain separate
from DNS IPC, Node loader/config, V8 memory, type closure and native certification.

## Bob — fixed C-only containment implementation, measurement NOT RUN

This append preserves the primary's entire existing progress text. Assigned
branch `t3/004628d1`, full base/local HEAD
`38707993e511219a07ef7450d8835b9f579700a0`, integrating merged main
`d5e9a04cae1cad1c22e0e23032cc8131b7c98cc9`. The implementation is staged and
uncommitted; there is **no exact-change tested commit or CI run**. The prior
merge-head runs above are not evidence for this working-tree change. Parent
independent review, final tested SHA and exact-head CI remain separate gates.

TM-04/TM-05/TM-08/TM-10; P1-A2/P1-A5 remain **PARTIAL**, Phase 1 OPEN. The
authoritative synthetic implementation decision above is preserved: no C fixture
compilation, new sandbox policy execution or new network/listening negative
control has run. The optional fixed CLI is implemented for parent use only after
independent policy/code review. No executable/profile/descriptor/budget inputs,
Node/compiler/SDK integration, installation or acquisition are introduced.

Changed files (complete unit, including this preserved parent-owned record):

- `experiments/host-isolation/_bounded_process.py`: one private repaired owner
  loop, canonical private ready/status records, independent stdout/stderr and
  elapsed result; fixed 120 s/16 MiB hard maxima and 2 s cleanup proof. No public
  command or environment override. Both final signals are attempted even after
  readiness/drain errors; no group-owner reaping before final KILL. Unknown
  status/permission/reap/FD cleanup quarantines and retains owner references.
- `experiments/extraction/run.py`: thin compatibility wrapper retains signature,
  15 s/256 KiB caps, stdout/elapsed and content-free nonzero/launch-status
  translation. Larger budgets reject before shared launch. The supervisor and
  older host guard/policy are unchanged.
- `experiments/extraction/test_harness.py`: existing portable lifecycle fault
  seams now explicitly target the actual shared module, including the fixture
  clock seam. Two added wrapper-compatibility tests prevent cap/result drift.
- `experiments/opencode/native/synthetic_containment.py`: fixed C-only action,
  typed deny-default policy and serializer, strict observations, clean six-state
  environment, private owned artifacts and quarantine on uncertain cleanup.
  Structured partial/failure evidence never emits target output/canaries/paths;
  success requires all requested controls. Future observed evidence records
  fixture/binary/policy/harness/owner/supervisor hashes and OS/kernel, not an
  inferred Node version or compiler/native certification.
- `experiments/opencode/native/containment_probe.c`: fixed synthetic filesystem,
  fork, unauthorized spawn, separate direct exec, IPv4/IPv6 TCP/UDP/bind/listen
  controls. Controlled invalid exec marker makes ENOEXEC a failure, not proof.
  Owner-writable protected controls avoid DAC-based false positives; owned
  canaries and protected hashes must remain unchanged. No private data printing.
- `experiments/opencode/native/test_synthetic_containment.py`: 18 new pure/
  portable tests, independently decoded behavioral policy tests (including quoted
  injection-shaped roots), import/CLI closure, strict partial/duplicate/malformed
  result rejection, ordinary failure/recovery, removal failure and real finite
  owner runs with injected TERM+KILL EPERM, missing/malformed status and reap
  failures. Quarantine, retained artifacts/references and no further launch are
  asserted. Injection tests deliver real cleanup before reporting synthetic
  faults; test-only removal occurs only after independent actual wait proof.
- `experiments/opencode/native/README.md`: review-before-first-run command,
  policy baseline, matrix, lifecycle ownership and explicit unsupported gates.
- `docs/progress/phase-1-opencode-native.md`: this append and preserved primary
  updates, staged together without rewriting earlier evidence.

Verification: full integrated offline suites **472 PASS** = 392 Python and 80
existing Node contract tests (retained 452 + 18 new native + 2 wrapper tests).
Python 3.12 with ResourceWarning as error: selector 5, extraction 20, native 89,
host-isolation 25, corpus 10, scoring 24, adapter 18, lexical 21, candidate 39,
symbol 37, directcall 79, evaluation runner 25. Existing extraction tests exercise
timeout, combined floods, cancellation, early EOF and retained-owner/descendant
ordering through the shared implementation; existing supervisor tests retain
parent-death coverage. `python3 scripts/check.py` passes foundation format/build/
Clippy/Rust tests/docs/finite commands/intentional-failure rejection and local
links. `cargo deny --locked --offline check` passes using cached advisories only.
Staged secrets and staged/unstaged whitespace pass; final local documentation
links pass. No online freshness, acquisition or actual C measurement is claimed.

**Actual new C guard, clang fixture compilation, policy parser/path injection,
fork/spawn/exec and network sandbox measurements: NOT RUN pending independent
review.** No new C workflow step exists. `/usr/lib` and dyld are labeled only a
SYNTHETIC C baseline, with exact ancestor metadata and no private read subtrees;
they are not Node's minimum inventory. Bootstrap failure must stop, not restore
fork or expand allowances. Group status/kill cannot prove an escaped descendant
died. DNS/resolver IPC, Node/plugin/config behavior, V8/total-memory containment,
actual type/consumed-file closure, provenance and native/product acceptance stay
unproved. No delegate, watch, scheduler, commit, push, PR, merge or deployment was
performed; the existing assigned worktree and full product scope remain intact.

## First measured C-only guard — BLOCKED, preserved as failure

The reviewed implementation was committed at
`8c1b42439f42f781e1f8e5d98a94c22baffcb903`. Its single authorized fixed run
on Darwin kernel 27.0.0 compiled the C fixture and passed both invalid-policy
parser controls, then blocked in the filesystem/bootstrap mode. The remaining
filesystem checks were `failed-or-unverified`; fork/spawn/exec, network and quoted
path acceptance were NOT_RUN. `result: blocked`, exit 1, `host_launched: false`,
`typescript_launched: false`, cleanup `verified-or-not-launched`. No policy was
relaxed or rerun for success. Ordinary verified cleanup removed only owned run
artifacts; unknown-cleanup retention was not needed in this measured attempt.

Recorded SHA-256 identities from that run:

- Fixture: `66d808157b24ced28ad7245379dcd8615573d45cdbf1749d449657c5cf67fdde`
- Harness: `e963dcba298eef8d3dbff9a27b4e2390f2b10eae378f93e1df9a53cb8d20bb57`
- Shared owner: `cea23401c8d15de10b40464d4f01d432d945efc7c90513b3335924f23a21276b`
- Supervisor: `4f88bfeee095c9d29783284b5e5d661b11723a70808419357ed4e3b3c4d75e32`
- C binary: `3bd996ff05cf332a38ae25f3b033208ef43f7a4589fd55ffd6e13cd0d63b5065`
- Policy: `aa97dce8504f17323e12d8b509542cdf9357570e32a286d3018d2a35a787741c`

The initial result omitted target exit/status detail and discarded bounded
diagnostics, preventing a precise bootstrap diagnosis. Primary added content-free
attempt summaries (fixed mode, exit status, byte counts/hash, bounded categorical
hint and only exact known observation labels); these cannot mark a partial mode
successful. The new privacy/failure-evidence regression and 18 retained targeted
tests pass. Primary authorizes one **diagnostic-only** repeat with the exact same
policy and C fixture, retaining bounded stderr privately for root-cause inspection
without printing it or publishing private paths. This is evidence collection, not
a blind success retry or permission expansion. Compiler/Node/SDK remain CLOSED.

## Bootstrap diagnosis and narrow policy candidate

The diagnostic-only repeat again blocked before any fixture observation: mode
`filesystem`, target exit **-6 (SIGABRT)**, zero stdout/stderr, empty stderr
SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
Both parser controls passed; C binary identity matched the first run. Cleanup
was verified, no Node/TypeScript/host ran, and private bounded diagnostic evidence
was retained outside the repository. No raw captured output was published.

The existing independently exercised host guard documents that dyld opens the
root directory itself. The new policy allowed root metadata but not that read.
This is a **bootstrap hypothesis, not an observed root cause**: the abort supplied
no target diagnostic. Targeted system-log inspection did not establish a usable
denial record. Unattributed crash reports were not treated as owned evidence.

Primary proposes exactly one narrow candidate change for independent review:
`file-read-data` on **literal `/` only**, retaining existing root metadata. This
can expose root directory entries, not descendant file bytes; it grants no
recursive root, private/home/repository reads, writes, fork/spawn or network.
Pure policy tests require literal root-data access and deny it for `/Users`,
`/private`, owned ancestors and sibling canaries. No further measured run is
authorized until this candidate's independent safety review and a new explicit
primary diagnostic decision. No broad permission expansion is inferred from the
failed bootstrap, and all compiler/SDK/product gates remain CLOSED.

Joffrey independently reviewed this literal-root candidate and its diagnostic
changes, found no blocking findings, and passed all 11 pure policy tests. He
confirmed exact literal SBPL scope, unchanged fork/network restrictions and that
pure operation-name matching is not actual SBPL wildcard/runtime proof. Primary
now authorizes **one exact fixed C-only diagnostic candidate run** with only that
reviewed literal root-data addition. No other relaxation or automatic retry is
authorized. The first two failures above remain evidence even if it bootstraps;
all actual denial controls must still pass before any synthetic success claim.

## Reviewed literal-root candidate — measured C-only PASS

At exact candidate commit `af95ba6619b826efa208f8e020009cb130c189bf`, the single
authorized fixed C run passed all **32** required controls on Darwin kernel 27.0.0.
The only policy change from the two blocked runs was the independently reviewed
literal root-directory data read; fork/spawn/network restrictions and the system-
only synthetic baseline were not relaxed. The successful counterfactual supports
the dyld root-directory bootstrap explanation; it does not erase either earlier
failure or turn an unattributed crash report into evidence.

Observed: approved read and six state writes; denied sibling/home/repo/config and
symlink reads; denied symlink/workspace/probe/policy/inventory writes; actual fork,
spawn and direct exec denial; IPv4/IPv6 connect/UDP/bind/listen denial; no owned
receiver traffic; both malformed-policy controls and quoted injection-shaped root.
The fixed probe required EPERM/EACCES, not generic errno. All checks were
`observed-pass`, `result: synthetic-only-pass`, cleanup
`verified-owned-artifacts-removed`, `host_launched: false`,
`typescript_launched: false`. The final target status was 0 with empty stderr.

Measured SHA-256 identities:

- Fixture: `66d808157b24ced28ad7245379dcd8615573d45cdbf1749d449657c5cf67fdde`
- C binary: `3bd996ff05cf332a38ae25f3b033208ef43f7a4589fd55ffd6e13cd0d63b5065`
- Harness: `53c4421d028edd4f0ea0d3b781016cc26a574364144e7407042009829d6371ec`
- Policy: `785ee715e177a63b69c415d496b618198b258c12449ad7d01ab1c5543e511673`
- Shared owner: `cea23401c8d15de10b40464d4f01d432d945efc7c90513b3335924f23a21276b`
- Supervisor: `4f88bfeee095c9d29783284b5e5d661b11723a70808419357ed4e3b3c4d75e32`

Primary now adds the exact reviewed fixed C action to the existing macOS
integrated guard step, after the unchanged older host guard. No install, extra
workflow, host launch or provider step is added. Remote macOS execution/CI remains
pending until its exact final head is verified. Diagnostic observation fragments
were renamed neutrally from `observed-pass-before-failure` to
`observed-pass-fragment`, since successful attempts also have summaries; no policy,
fixture or success oracle changed. Final full local verification follows.

DNS/resolver IPC, escaped-descendant proof beyond measured no-fork/spawn, Node
loader/plugins/config, V8/total memory, authentic declaration/consumed-file closure,
full runtime provenance and native capture/review/admission remain unestablished.
No Node, TypeScript, SDK/TUI or provider ran. P1-A2/P1-A5 remain PARTIAL; Phase 1
and the full agreed product scope remain OPEN.

## Published C-only prerequisite — PR #23

PR: <https://github.com/suhaasbadada/threadmark/pull/23>, target `main`.
Full final tested implementation head:
`8011b2967e49b15bdafb616941f58d60ce74e49e`, tree
`156383fe1d9c6129be2a8b295b5c1a40cf555b94`. Primary final integrated verification
passed **473 tests** (393 Python, including 90 native; 80 Node). Both actual
macOS C guards passed; the new fixed guard repeated all 32 controls with verified
owned-artifact removal, `host_launched: false`, `typescript_launched: false`.
Foundation checks, cached offline cargo-deny, staged secrets and full staged
whitespace checks passed. Joffrey independently reviewed both the core unit and
the narrow literal-root candidate before their respective measurements.

Initial PR inspection bound **12 queued/in-progress checks** to that exact head:

- Foundation CI: <https://github.com/suhaasbadada/threadmark/actions/runs/43326501894>
  — both Rust platforms and dependency/license/secret validation.
- Integrated experiments:
  <https://github.com/suhaasbadada/threadmark/actions/runs/43326501854>
  — Linux/macOS, including the new fixed C action on macOS.
- Extraction harness:
  <https://github.com/suhaasbadada/threadmark/actions/runs/43326501874>
  — Linux/macOS wrapper/owner regression coverage.
- Offline OpenCode contracts:
  <https://github.com/suhaasbadada/threadmark/actions/runs/43326501893>
  — Linux/macOS, still abstract contracts rather than native proof.
- Synthetic host isolation:
  <https://github.com/suhaasbadada/threadmark/actions/runs/43326501846>
  — two portable jobs and the unchanged older real macOS guard.

Pending checks are not green. Fresh exact-head completion, review/discussions,
target and prerequisite-only acceptance remain required before merge. This local
progress append is not an additional published head. No native/compiler or full
phase gate is closed by the local C result; all prior failed attempts are retained.

## Offline authentic inventory continuation while PR #23 is watched

Bob completed one separate bounded offline inventory unit from already-owned
archives, without changing repository source/configuration, polling CI, acquiring
dependencies or executing Node/TypeScript/SDK code. Original archives remain
untouched. All **345 archive files** were rehashed twice against SHA-256 filenames
and exact SHA-512 ledger identities, covering **364 acquired records**. Eight
selected archives passed strict full preflight. The exact lock hash is
`c37f2f29fe209654cdf21e04d2137c45289196f9dbe082d6d7841b8bce975c66`.

Private, nonredistributed candidate JSON inventories were written into a fresh
0700 owned root; they are **not approved**, installed, projected, executed or
uploaded. Primary independently rehashed and parsed the compiler/native/Node/
validation/refinement outputs against Bob's handoff identities:

- Compiler inventory:
  `0ddbaa519352d4b02cbc691a552b24936f6eb512cba9c10cd8dab6d868ad353f`.
  **112 files**, including **107** authentic default libraries, complete metadata,
  actual notices and both compiler entrypoints. Static dynamic-require/source-map
  support/compile-cache findings keep runtime/helper closure UNPROVEN. No compiler
  bytes were materialized and no compiler ran.
- Native type inventory:
  `122224a07e6ef46d74914ea1f5c1ce4e78a2d6d2cdfdeb89be35b89f5ff30a8b`.
  Seven exact native packages contain **336 declarations + 11 type sources**;
  unchanged manifest/export/peer/nested metadata and notice evidence are retained.
  This is not official module resolution or a complete SDK projection.
- Node inventory:
  `c952472a8830a3cd1fe820cb60536a3108574742f4df67b1a7d66243a0ff0ddf`.
  ARM64 regular single-link binary, mode 0555, 64,866,928 bytes, SHA-256
  `e7daf91e350dcfc19c3f67bef0a463c1269e98e084606c2e38edf2c349e3842a`.
  Version identity remains UNPROVEN; path labels do not authenticate a version.
  Static Apple-tool inspection found Homebrew library dependencies; minimum
  Node/system runtime inventory remains UNCLOSED. No Node probe was run.
- Source refinement:
  `aa5f3cb7c44302bd7170b7532663684e1b6e19eaac8ebe11a44b801d7d551bed`.
  **Correction to earlier mandatory-peer shorthand:** the actual Emscripten peer
  is optional. Actual `web-tree-sitter.d.ts:136` nevertheless references global
  `EmscriptenModule`, with no direct emscripten import. An authentic definition is
  still missing if that declaration is consumed; no stub or suppression supplies
  it. Three direct OpenCode archives lack standalone notices; the pinned root
  notice mapping still requires package-specific review.
- Validation ledger:
  `556bc56b724275877f019059c9c05c8a38c39a1fc7f5c560cd657a97ccefc894`.

All execution/type/native approvals remain separate. Pure reader/hash/metadata
checks passed; no code suite was duplicated for this read-only inventory unit.
Primary corrected current README peer wording while preserving historical failure
evidence. PR #23 remains watched at unchanged head
`8011b2967e49b15bdafb616941f58d60ce74e49e`; this local evidence/doc correction is
not pushed or claimed as checked by its pending CI. No duplicate worker, reminder,
new spending, credential use, host/binary deployment or phase closure occurred.

## PR #23 qualified merge and runtime-inventory continuation

Fresh inspection verified all **12** exact-head checks SUCCESS on
`8011b2967e49b15bdafb616941f58d60ce74e49e`, with target `main`, MERGEABLE/CLEAN,
no draft, no unresolved review threads and no additional branch-protection/ruleset
approval gate. No forge approval was invented. The integrated macOS job trace in
run `43326501854` was inspected: its actual fixed C guard passed all 32 controls
on kernel **24.6.0**, with `verified-owned-artifacts-removed`, no host and no
TypeScript launch. This is remote C evidence, not native acceptance.

Under Suhaas's standing qualified-merge authorization, PR #23 was squash-merged
at `e1d7b9c461a33d2270af35971bc8131bfe5672f2`. Its exact tree
`156383fe1d9c6129be2a8b295b5c1a40cf555b94` matches the tested PR tree. The watch
was stopped, and the same assigned branch integrated merged main without branch
switch, reset or cleanup. Local README/progress corrections and inventory evidence
were preserved. No runtime/binary deployment or phase closure followed. Post-merge
workflows are a separate unverified gate until freshly inspected.

Next bounded work reviews authentic Node linked-library inventory and the pinned
compiler's conditional helper/compile-cache behavior, with no Node/TypeScript/SDK
execution. C bootstrap success does not approve Node/system reads or compiler
module execution. Any proposed Node-only diagnostic needs its own exact hash-
bound policy review and explicit primary authorization; a compiler run remains
a later separate gate.

## Authentic runtime review — fixed Node-only implementation decision

Sherlock independently re-read the exact pinned compiler archive through strict
preflight. Authentic `lib/tsc.js:2–7` attempts `node:module.enableCompileCache()`
unconditionally in try/catch; fixed compiler options do not prevent it.
`lib/_tsc.js:134458–134459` enables optional source-map support only for
`NODE_ENV=development`; replacing the environment without NODE_ENV avoids that
branch. CPU inspector entry requires excluded generateCpuProfile settings.
Dynamic system `require(modulePath)` is defined at lines 5008–5014; static review
found no caller in this CLI bundle. These are static findings, not formal runtime
closure or execution approval. The installed Node manpage documents cache
disablement; explicit `NODE_DISABLE_COMPILE_CACHE=1` is a candidate control whose
interaction with enableCompileCache still needs measured proof.

Bounded static traversal found Node plus **17 non-system dylibs**, **111,994,336
bytes** total. Aggregate SHA-256 over sorted canonical-path/tab/file-hash records:
`d3f1d8c3136212ded1088e2791f6490b5dd0c30363004dc43aa54b9fe3f70520`.
Homebrew aliases drifted from Node receipt versions (Brotli 1.1.0 → 1.2.1,
OpenSSL 3.6.0 → 3.6.4, SQLite 3.50.4 → 3.53.4). Therefore a Node-only binary hash
does not bind the runtime; exact canonical library hashes and alias edges must be
reviewed/revalidated too. ICU uses system ICU 77, with its actual data dylib in
that inventory; no extra ICU data directory is assumed necessary.

Primary authorizes implementation/pure tests of an exact-runtime inventory
preflight and **fixed Node-only** bootstrap/negative-control guard, not execution
yet. No TypeScript entrypoint, SDK, arbitrary argv/profile or host launch may be
accepted. A future exact inventory, external approval digest and independent
policy/code review are required before one separately authorized measured probe.
Version output would bind observed version to reviewed local bytes, not certify
publisher provenance. Same-UID parents/no concurrent Homebrew mutation are an
explicit trust boundary; immediate before/after byte/alias revalidation must fail
closed on drift.

The proposed discovery policy may name exact Node/17 dylib and alias paths plus
metadata ancestors, fixed owned probes/canaries/state only, no recursive Homebrew,
home/repository/private-data read, no target fork or network allowance. An explicit
**public-system discovery baseline**, not minimum closure, may include `/usr/lib`,
the actual OS dyld-cache directory and the two statically linked CoreFoundation/
Security framework subtrees. Unobserved broad PrivateFrameworks/Mach-service,
sysctl, ICU or user-data allowances are not authorized. Literal root directory
data read remains disclosed, not a subtree permission. Public-system metadata
and shared-cache images require honest OS/build identity; no invented image hash.
Any additional allowance needs failure evidence and fresh review.

Node-only controls must measure the candidate cache-disable behavior, version,
permitted read/write, forbidden private read/write, child spawn and owned-loopback
network denials using fixed hashed CommonJS source and retained-owner cleanup.
Per-probe budgets are at most 5 s/16 KiB. Compiler/SDK/type/native acceptance and
all existing provenance/closure blockers remain separate and CLOSED.

## Exact Node-only candidate review and first-run authorization

Primary freshly verified all five PR #23 merge-head workflows SUCCESS on
`e1d7b9c461a33d2270af35971bc8131bfe5672f2`: foundation `43327960909`,
integrated `43327961011`, extraction `43327960866`, offline OpenCode `43327961193`
and synthetic host isolation `43327961002`. These remain prerequisite CI, not a
runtime/binary deployment or native certification.

Joffrey independently reviewed the Node-only implementation and exact initial
candidate, revalidated the real 18-file/24-alias runtime and passed 53 pure tests.
He found one P2: cancellation/interrupt during post-attempt validation could
delete artifacts and leave reuse enabled without completed integrity proof.
Primary repaired both postcheck handlers, adding cancellation/KeyboardInterrupt
quarantine and retention. Both new regressions fail against the exact pre-fix
implementation and pass the repair; the repaired Node-only suite passes 27 tests.

The source-bound candidate was regenerated, not silently reused. New candidate
SHA-256: `1e87d0598ab2b6dea9c616f22d0de5b92c0ef9e370ca5fbe64b2d7adef1d1fd5`.
Joffrey independently checked its 0400 file/0700 parent and revalidated every
actual file/alias/ancestor. Old/new candidates differ only in the expected guard
source record; runtime, system, CJS probe, helper, supervisor, sandbox and policy
implementation identities are unchanged. Six targeted tests passed, including
both corrected cancellation paths. No execution was performed by either review.

Primary now authorizes **one exact fixed Node-only diagnostic guard run** for that
digest after committing the reviewed implementation. Known local bytes are
trusted for this bounded discovery experiment, not publisher-certified. The
guard may attempt fixed `--version`, fixed hashed CommonJS controls, exact
reviewed read/discovery baseline and owned loopback receivers, with immediate
before/after inventory validation and <=5 s/16 KiB per-probe budgets. A forwarding
observer may retain only already-bounded stdout/stderr in a fresh private 0700
directory/0600 files; argv, environment, budgets, results, source and policy must
remain unchanged. Raw diagnostics/private paths are not public evidence.

No automatic retry or permission expansion is authorized after bootstrap/control
failure. No TypeScript/compiler, SDK/TUI, native host, provider or external network
target is authorized. Actual outcomes, cleanup and remaining limitations must be
recorded separately; synthetic tests cannot satisfy this measurement gate.

## First Node-only measurement — version PASS, CommonJS/OpenSSL BLOCKED

Reviewed implementation commit `712e8ac73f3d116fb717b0408890f7213f52f76a` was
measured once using exact approved digest
`1e87d0598ab2b6dea9c616f22d0de5b92c0ef9e370ca5fbe64b2d7adef1d1fd5`.
The contained fixed version action passed exact `v24.10.0` output, binding that
observed version to the reviewed local Node/runtime bytes (not publisher
provenance). The next fixed CommonJS attempt exited **1**, stdout 0 bytes, stderr
243 bytes, SHA-256
`6b74abc6ca21daee1edf2a5e4923807378ac5043328b446158415ea16aa3dff4`.
All filesystem/cache controls remained failed-or-unverified; network controls
were NOT_RUN. Cleanup was verified-or-not-launched; no TypeScript or host ran.
Both runtime pre/postchecks completed. Owned artifacts were removed; bounded
private diagnostic copies were retained outside the repository.

Private startup diagnosis identified **OpenSSL ambient configuration loading
denied by the sandbox**, specifically its BIO_new_file/fopen path. No private
config was read or allowed and no raw captured diagnostics/path is public here.
The installed Node 24.10 manpage lines 374–377 documents `--openssl-config=file`;
lines 858–865 documents that this flag overrides OPENSSL_CONF. This establishes
a specific isolation repair, not permission to allow ambient host configuration.

Primary proposes a fresh candidate with a fixed comment-only owned OpenSSL config,
literal read-only (not executable-map) permission, exclusive creation/protected
hashes and a new write-denial control. Every fixed Node attempt receives the
documented explicit flag; environment inheritance stays disabled. No system,
Homebrew config, fork, network, Mach or sysctl allowance is added. Pure Node tests
pass **28**, including config-drift quarantine and exact argv/bytes/policy checks.

Regenerated UNAPPROVED candidate digest:
`b5efaf1b9be6fe427f5996274c5eea5f4a47a17b83c617874985d43082e178c4`.
It needs independent review and new primary authorization before one measurement.
The prior failure remains preserved. Compiler/SDK/native execution stays CLOSED;
the inert compiler plan does not yet model the required owned OpenSSL config.

Joffrey independently reviewed this owned-config delta and exact regenerated
candidate. He verified only the expected two source bindings changed; static
18-file/24-alias/6-source validation passes; literal data-only access and protected
config bytes remain bound; documented flag precedence is correct. He found no
substantive blocker for one separately authorized measurement. His review did
not rerun the 28 pure tests; primary ran those successfully. Neither review nor
tests claim comment-only config startup behavior or CommonJS control success.

Primary now authorizes **one exact fixed Node-only measurement** for digest
`b5efaf1b9be6fe427f5996274c5eea5f4a47a17b83c617874985d43082e178c4` after
committing the reviewed change, with the same bounded exact-forwarding private
diagnostic observer. No host OpenSSL settings are read/reused or changed. This
synthetic empty config does not establish host crypto/FIPS equivalence or authorize
a later compiler/SDK. Stop on any new failure; no automatic retry, ambient config
permission, network or other relaxation follows.

## Owned OpenSSL candidate — new allocator failure, page-size hypothesis

Commit `dff0fb86acc731c95d7696b4e76a4cfcae63b5a6` was measured once for approved
digest `b5efaf1b9be6fe427f5996274c5eea5f4a47a17b83c617874985d43082e178c4`.
Version again passed; CommonJS startup changed from the OpenSSL config error to
**SIGABRT (-6)**, stdout 0 bytes, stderr 89 bytes, hash
`d47bd95de820291fc5c33eeb4d175ba5673ba02867d88de0beb8a925463eaf1b`.
The content-free diagnosis is LowLevelAlloc arithmetic overflow, before any
control observation. No CommonJS/cache control is marked passed; network remains
NOT_RUN. Runtime pre/postchecks completed and owned cleanup was verified. No
TypeScript, SDK/host or provider ran. Bounded private diagnostics remain retained.

Earlier controlled evidence in [host isolation](phase-1-host-isolation.md)
isolated denied page-size access with `getconf PAGESIZE` A/B fixtures: the unchanged
profile failed, and only named `hw.pagesize`/`hw.pagesize_compat` reads produced
16384. The currently installed Apple `container.sb:95` still names exactly those
metrics. This supports a **Node allocator bootstrap hypothesis**, not proof of its
failing syscall or which single metric is necessary. It does not justify general
sysctl, Mach, fork, network or private-file access.

Primary proposes exactly those two named read-only public page-size metrics as a
fresh diagnostic candidate. All other policy/runtime/owned-config/probe bindings
remain unchanged. The independent pure policy decoder now parses the emitted
sysctl-name rule semantically and rejects unrestricted/regex forms; Node pure
tests pass **29**. New UNAPPROVED digest:
`c69fa4dbc31af9ad2f47be64efc21fc06634afb93909a8e4d5fe5a038314074a`.
It requires independent review and a new explicit primary diagnostic decision
before another measurement. Both previous Node failures remain evidence;
compiler/SDK/native execution and all full-system/type closure claims stay CLOSED.

Joffrey independently reviewed the named-page-size candidate, found no
substantive finding, passed all 29 pure tests and revalidated the exact digest,
18 runtime files, 24 aliases and source/system bindings without launch/socket
creation. Only the guard Python source record changed. He confirmed no broader
sysctl/write/Mach/network/fork rule and preserved the distinction between Python
policy decoding and actual Apple enforcement.

Primary authorizes **one bounded fixed Node-only diagnostic counterfactual** for
`c69fa4dbc31af9ad2f47be64efc21fc06634afb93909a8e4d5fe5a038314074a` after
committing this reviewed delta, with the same exact-forwarding private bounded
diagnostic observer. No further metric, permission or automatic retry is
authorized. Both names are public page geometry, not private data access. Any
success still requires all 30 controls, complete runtime pre/postchecks and
verified cleanup; it does not prove which single name is necessary, minimum
system closure, TypeScript/SDK compatibility or native acceptance.

## Page-size candidate — control prefix observed, cache/uname assertion BLOCKED

Commit `1ef10c1e1ac0527c0945d6b391c52b4488424e06` was measured once for approved
digest `c69fa4dbc31af9ad2f47be64efc21fc06634afb93909a8e4d5fe5a038314074a`.
Version passed. CommonJS startup progressed beyond the allocator failure and
emitted 19 known filesystem/spawn labels, then aborted **SIGABRT (-6)** before
cache-disabled. The complete filesystem mode remained failed-or-unverified and
network remained NOT_RUN. stdout was 367 bytes, stderr 4717 bytes, stderr hash
`19e6170a8cf56b69203983367a841d3423ac52993fc200489cc31494ed2c6811`.
Runtime pre/postchecks and owned cleanup were verified; bounded private diagnostics
remain retained. No TypeScript/SDK/host/provider ran. The partial labels are not
promoted into whole-mode acceptance.

The observed native assertion was Node `GetOSInformation`, args.Length >= 1;
the JS frames identify `node:os:78` and enableCompileCache/internal module helpers.
Targeted public source inspection explains that specific failure path:

- [Node v24.10.0 lib/os.js](https://github.com/nodejs/node/blob/v24.10.0/lib/os.js)
  initializes OS information by calling the binding without arguments.
- [Node v24.10.0 node_os.cc](https://github.com/nodejs/node/blob/v24.10.0/src/node_os.cc)
  calls uv_os_uname and asserts an error-context argument only on its error path.
- [libuv v1.51.0 core.c](https://github.com/libuv/libuv/blob/v1.51.0/src/unix/core.c)
  uv_os_uname calls libc uname (lines 1770–1822).
- [Apple uname.c at pinned source](https://github.com/apple-oss-distributions/Libc/blob/71bbe350ab79eef58113991d817ccc6165061a64/gen/uname.c)
  reads exactly KERN_OSTYPE, KERN_HOSTNAME, KERN_OSRELEASE, KERN_VERSION and
  HW_MACHINE, returning failure if any read fails. This source is supporting
  evidence, not cryptographic matching of the installed system library.

Primary proposes only the corresponding five named read-only uname metrics in
addition to the already reviewed page-size pair. This includes transient local
hostname access by libc; libuv's returned OS-information fields omit nodename,
and the fixed probe does not call/print hostname. No value is logged or transmitted.
This bounded local metadata read is not a general sysctl, credential, home-file,
network, Mach or host-modification allowance. Fixed tests parse the emitted seven
names and reject unrestricted forms; all **29** Node pure tests pass.

New UNAPPROVED candidate digest:
`d3f0f76c6ccbb124d14b478e825b6cbf967e561e5551a09e4fe99b4c2881ea2d`.
It requires independent review and a new explicit primary decision before another
measurement. All three prior Node failures remain preserved; cache behavior,
full system closure, compiler/type resolution and native acceptance remain CLOSED.

Joffrey independently reviewed the exact uname candidate, passed all 29 pure
tests and statically revalidated its 18 files/24 aliases/system records. Only the
expected guard-source binding changed; the other five source bindings are
identical. He found no substantive blocker for one separately authorized bounded
Node-only measurement. **Risk correction:** kern.hostname permission is process-
wide hostname-read capability, not a libc-only enforced permission. Anticipated
transient use alone is not containment; the fixed hash-bound probe, no arbitrary
code input and no network permission bound this diagnostic's use. No general
host-information access or later compiler/SDK is approved.

Primary authorizes **one exact Node-only measurement** for
`d3f0f76c6ccbb124d14b478e825b6cbf967e561e5551a09e4fe99b4c2881ea2d` after
committing the reviewed change. The prior bounded exact-forwarding private
diagnostic observer remains permitted. No further permission or automatic retry
is authorized. All 30 controls, runtime/artifact pre/postchecks and cleanup must
pass; otherwise preserve the failure and diagnose without claiming certification.

## Exact Node-only discovery PASS — still no compiler/native execution

At commit `4b2558081bfcb014a249ae4d04c9b5b241ebd19f`, the single newly authorized
run for candidate digest
`d3f0f76c6ccbb124d14b478e825b6cbf967e561e5551a09e4fe99b4c2881ea2d`
passed **all 30 controls**. Result `node-only-discovery-pass`; cleanup
`verified-owned-artifacts-removed`; all runtime/artifact pre/postchecks completed;
`node_launched: true`, `typescript_launched: false`, `host_launched: false`.

Observed: exact v24.10.0 output; approved read and six state write/read checks;
denied home/repo/config/sibling/symlink reads and protected writes (including owned
OpenSSL config); real unauthorized spawn permission denial; exact compile-cache
APIs returning undefined cache directory and named DISABLED status even after
enableCompileCache; IPv4/IPv6 connect/UDP/bind/listen permission denials; zero
traffic at owned loopback receivers. No external target or DNS operation ran.
Final attempt status 0 with empty stderr. No OS-identity/hostname value was printed
or transmitted. Bounded private observation copies remain outside the repository.

Measured policy SHA-256:
`453bdb01390b912d80805c531c701c8160f64faf23187461d90e457e0fff4b51`.
Fixed CommonJS source SHA-256:
`1ad0b1c51db4012797e0b840b1e3fcd5fdc5f96aeb628e45082ba0c736481b29`.
The reviewed 18-file/24-alias runtime and all source/system identities remained
unchanged through the guard. Earlier OpenSSL/allocator/uname failures and reviews
are retained above; no blind retry or silent broad permission was substituted.

This closes only the exact local Node discovery measurement. Public-system
baseline is not minimum closure; seven named metadata reads are explicit, including
process-wide hostname capability; no necessity of each name is claimed. DNS/IPC,
JIT policy, total RSS, publisher provenance, compiler archive execution, authentic
type/consumed-file closure and native OpenCode behavior remain separate unpassed
gates. No TypeScript, SDK/TUI, provider or host service ran. Phase 1 stays OPEN.

Final full source verification and publication follow separately. No machine-
specific Node action is added to CI without an independently reviewed inventory;
existing CI discovers the pure tests only. The inert compiler descriptor still
needs the owned OpenSSL configuration and concrete compiler runtime/read inventory
modeled before any new compiler authorization.

## Final Node-discovery source verification

Primary fresh full integrated verification passed **502 tests**: **422 Python**
(including **119 native** and 29 Node-guard pure tests) plus **80 Node** abstract
offline contracts. Both existing actual C guards passed; the strict fixed C guard
again passed 32 controls with verified owned-artifact removal. This verification
did not repeat the new Node-only guard; its separately authorized 30-control
measurement remains bound to the reviewed commit/digest above, with unchanged
guard/probe source bytes.

`python3 scripts/check.py` passed foundation Rust format/build/Clippy/tests/docs,
finite offline diagnostics, local links and intentional-failure rejection.
`cargo deny --locked --offline check` passed using cached advisories, not a fresh
online database. Staged secrets and full staged whitespace passed after the final
documentation changes. No dependency/lock acquisition, provider, credential
change, SDK/native host or production/binary deployment occurred. Final published
head and exact-head CI remain to be recorded separately; no local result is called
remote green. Phase 1 and full product acceptance stay OPEN.

## Published Node-discovery prerequisite — PR #24

PR: <https://github.com/suhaasbadada/threadmark/pull/24>, target `main`.
Full tested implementation head `930c2c420d5fc5d831a61e4dbbca637b2e55bfe8`,
tree `c40d0fbd5c6aea41c9b5b72b06d9dc2a1d05e733`. Local verification is recorded
above: 502 tests, both existing C guards, foundation, cached offline cargo-deny,
staged secrets and full whitespace. The actual local 30-control Node measurement
remains separately bound to its reviewed digest and unchanged guard/probe bytes;
it is not claimed as a CI-host or compiler/native certification.

Initial exact-head inspection registered seven queued/in-progress jobs:

- Foundation CI: <https://github.com/suhaasbadada/threadmark/actions/runs/43335474112>
  — both Rust platforms plus dependency/license/secret checks.
- Integrated experiments:
  <https://github.com/suhaasbadada/threadmark/actions/runs/43335474092>
  — Linux/macOS pure tests and existing measured C guards, not an unapproved
  machine-specific Node action.
- Offline OpenCode contracts:
  <https://github.com/suhaasbadada/threadmark/actions/runs/43335474007>
  — Linux/macOS, abstract host contracts only.

Pending is not green. Before merge, freshly verify exact-head complete checks,
approvals/discussions, target and prerequisite-only acceptance. This local progress
append is not another published head. No duplicate worker/scheduler, TypeScript,
SDK/TUI, provider, host/binary deployment or phase closure is claimed.

## PR #24 qualified merge and compiler-only next gate

Fresh inspection verified all seven exact-head jobs SUCCESS for
`930c2c420d5fc5d831a61e4dbbca637b2e55bfe8`, target `main`, MERGEABLE/CLEAN,
no draft, no unresolved review threads/comments and no additional repository
approval gate. No forge approval was invented; independent reviews and their
repairs/candidate approvals are recorded above. Under standing qualified-merge
authorization, PR #24 was squash-merged at
`d2a1fdace6b1125bf4d41bda7b821ec9011cc27d`. Its tree equals tested tree
`c40d0fbd5c6aea41c9b5b72b06d9dc2a1d05e733`. The PR watch was stopped and the
assigned task branch integrated merged main without branch switch/reset/cleanup,
preserving the local progress append. Post-merge CI remains a separate unverified
gate until freshly inspected. No native deployment or phase closure followed.

Primary selects the next executable prerequisite: a **fixed compiler-only smoke
and containment experiment using authentic TypeScript 6.0.3 bytes**, initially
with synthetic positive/intended-error roots and authentic default libraries only.
This is not SDK compatibility and does not substitute for the full native bridge.
The SDK's missing authentic Emscripten/type/notice graph remains blocked; it is
not requested by these isolated compiler fixtures and must not be stubbed away.

Implementation, inert compiler materialization from already-verified owned
archives, private candidate preparation and pure tests are authorized now.
**No compiler execution is authorized yet.** The exact artifact/source/config/
runtime inventory and actual launcher/policy must receive independent review and
a new explicit primary decision first. Preserve complete metadata/notices,
byte-identical helpers/default libraries and exact archive pin; no npm install,
scripts, new acquisition, modified compiler, ambient SDK types or library skips.

Reuse the measured Node runtime and named-metadata/public-system discovery
baseline as an explicit candidate, not minimum closure or compiler proof. Add only
literal approved compiler/library/owned-root/config reads; keep no target fork,
network or private host config allowance. Supply fixed owned OpenSSL bytes and
the measured cache-disable environment. Bound <=120 s wall/16 MiB aggregate
output/1 GiB old-space/2 s cleanup proof, with retained ownership, before/after
runtime/compiler/artifact validation and unknown-state retention/quarantine.

Real compiler acceptance must later require exact version, positive semantic
success, intended negative diagnostic, and every reported program file bound to
authentic compiler libraries/owned roots. `listFiles` proves reported program-file
closure, not every metadata/system read; distinguish those from sandbox read
containment and runtime inventory. No source path/content may enter public evidence.
No extra compiler flags, plugins, extends, custom resolvers, watch/build, arbitrary
argv, source suppression, `skipLibCheck` or unknown-result success is permitted.

## Fixed Node-only preflight and guard candidate — implementation, NOT RUN

Bob completed the next bounded code/pure-test unit in the same assigned branch,
based on full HEAD `4d1ee4d76a31cebb827713d82df5dab5dc4c0c9b`, which integrates
merged main `e1d7b9c461a33d2270af35971bc8131bfe5672f2`. The primary's preexisting
README correction and all prior progress/PR #23/failure evidence were preserved.
There is no new commit, pushed head, PR, CI run, merge or deployment for this
unit. Existing PR #23 results above are not evidence for these working changes.
TM-04/TM-05/TM-08/TM-10, supporting P1-A2/P1-A5 prerequisites only; Phase 1 and
both acceptance gates remain open, not completed by models or mocks.

`node_containment.py` adds inert explicit static inventory preparation, strict
external-digest preflight and a fixed Node-only guard API. It does not consume
the compiler descriptor or accept an executable/script/profile/extra argv/budget;
there is no CLI or measured CI action. The separate fixed CommonJS probe uses
Node builtins only. Source/harness/serializer/owner/supervisor/sandbox hashes and
OS/build, actual dyld/SystemVersion files bind the review. Shared-cache virtual
images are honestly identified as not individually hashed. Exact Node and 17
canonical dylibs, all 24 actual alias edges, load graph and metadata ancestors
are revalidated before/after each future attempt; no runtime rediscovery occurs
after approval. Identity includes mode/size/single-link/inode checks and bounded
before/open/after reads. Same-UID/no-concurrent-Homebrew-mutation trust remains
explicit. Post-launch drift or unknown cleanup retains owned state/quarantines
reuse, including zero-exit cases; ordinary verified failure removes owned state.

The deny-default typed policy/serializer and private artifacts/retained owner
reuse the C prerequisite rather than broadening that guard. Only exact Node may
exec; no fork/network/Mach/sysctl allowance exists. Runtime paths are literal,
state writes are six owned subtrees, and the four approved public-system discovery
baseline roots plus literal root-directory data read are disclosed separately
from minimum system closure. No whole System/PrivateFrameworks/Homebrew/home/
repository/private-data read is emitted. Any bootstrap failure requires evidence
and fresh review, not automatic broadening.

The future guard has 29 strict observations: separate exact ASCII v24.10.0
version, owned read/writes, forbidden shaped/private/symlink reads and protected
writes, actual unauthorized spawn, IPv4/IPv6 loopback TCP/UDP/bind/listen denial,
empty owned receivers, and named compile-cache API checks. Each attempt is fixed
to 5 s/16 KiB combined output with shared retained-owner cleanup. A 110 s launch
deadline reserves cleanup within the 120 s envelope; 64 MiB V8 old-space is not
total RSS. Unknown Node API/errno/output fails closed, never mocked certification.
Compiler plan environment now explicitly adds `NODE_DISABLE_COMPILE_CACHE=1` and
still excludes NODE_ENV and ambient overrides; its approval fields remain false.

Read-only static Apple-tool preparation independently reproduced **18 files,
111,994,336 bytes, 24 alias edges**, aggregate SHA-256
`d3f1d8c3136212ded1088e2791f6490b5dd0c30363004dc43aa54b9fe3f70520`.
A fresh 0700 private root contains the 0600 candidate JSON, read back and fully
revalidated. Candidate SHA-256:
`0333ce968d5a514b3b66b3b0a7456330b7fbd1d59fcf44a639f332d46105d5cf`.
This is **UNAPPROVED**, not a self-authorizing digest, and was not uploaded or
vendored. No archive was modified or compiler bytes projected. Implementation
source SHA-256 `30cee1feebfc6d0942818ece00cd47b11deb66a45ec54e012c980d9769835286`;
fixed probe SHA-256 `58ca2fa62e35afa2be528a6a65e72ddddaafe5b3a6f56ca54ba4d3e5821af393`.

Verification on the working changes: **498 offline tests PASS** = **418 Python**
(including **115 native**, 25 new pure Node-candidate tests) + **80 existing Node
offline contract tests**. Python 3.12.6 ran the full integrated suite; native
discovery additionally passed with the default Python. Foundation checks passed
(fmt/build/clippy/tests/docs/offline smoke/intentional failing-test rejection),
as did cached `cargo deny --locked --offline check`. Staged secrets, full staged
whitespace and local documentation link checks also passed. No C guard measurement was
duplicated; no Node version/diagnostic/guard, TypeScript, SDK, host, sandbox target
or compiler ran. The existing Node offline contract command was the only Node
execution in this unit; it is abstract-contract evidence, not this guard.

Next mandatory gate: independent exact code/policy and private inventory review,
then **explicit primary authorization for the first fixed Node-only measurement**.
Node bootstrap and compile-cache API semantics are unmeasured and may fail closed;
no guessed OS permission has been added to make them pass. DNS/IPC/JIT, minimum
system/runtime closure, publisher provenance, total memory, compiler declarations/
consumed-file/type closure and native capture/review/admission remain unproved.

## Fixed compiler-only candidate — implemented and inertly prepared, NOT EXECUTED

Bob completed this bounded next unit at full base/tested HEAD
`29e62348dfa531dcbae2cb8d63d0d276361a629e`, integrating PR #24's main
`d2a1fdace6b1125bf4d41bda7b821ec9011cc27d`. Changes remain staged/uncommitted in
the same task branch; no new push, PR, CI run/head, merge or deployment exists.
The preceding primary progress text, qualified merge/CI evidence and three actual
Node failures remain preserved. Earlier NOT RUN entries are historical, not a
revocation of the separately reviewed 30-control Node measurement recorded above.
TM-04/TM-05/TM-08/TM-10; P1-A2/P1-A5 **PARTIAL** prerequisites only, not acceptance
completion or Phase 1 closure. Prior PR checks do not certify these working bytes.

`compiler_containment.py`, the fixed positive/negative TypeScript roots and pure
tests implement the separately reviewed-next candidate described in
[the compiler containment contract](../../experiments/opencode/native/COMPILER-CONTAINMENT.md).
No compiler, new Node program/probe, SDK, sandbox target or host was executed.
No network, acquisition, installation, package script or new workflow was used.
The existing ordinary Node offline-contract command was the only Node execution.

Authentic preparation rehashed compressed SHA-256
`33cd0ee1beaa8c9e9d15a9da836c62ddea4c34a42d7c2d349dbc80d94165d22a` and the
exact previously pinned SHA-512 before full archive inspection. Exactly **112 files,
10,073,711 bytes**, including **107 authentic default libraries**, complete
metadata and both actual legal notices, were exclusively copied unchanged into a
fresh private 0700 root with 0400 nonexecutable files. Bin/native/extra build files
were not selected. The archive and prior inventory were not modified. All 112
selected hashes matched the previously owned authentic inventory, whose hash was
independently rechecked as
`0ddbaa519352d4b02cbc691a552b24936f6eb512cba9c10cd8dab6d868ad353f`.

Final private review candidate SHA-256:
`1fde5aef6ebaa96b1762965d778546941f832851dbd304b3ff0a313685a1098f`.
Selection/roles/size inventory SHA-256:
`c6340da859a10d0505112cd14b1ae8ab83228d9c5ebd18ba384047e34af0fe5a`.
Launcher/preparation method SHA-256:
`cfe9e9fe385c4600c10dd335f3be8497d417978c68aef8b7e52d38e5f00a6795`.
Positive fixture SHA-256:
`f52d78a949b5fe57c24e1a06a82f27a7c3cd341d5007013307050990d39a797e`;
negative fixture SHA-256:
`915453356fdbdf2cf410e77b163d7b3b13229238173aa87b2780ce92de228cbe`.
The final candidate is **UNAPPROVED**, read back/revalidated as data only. An earlier
inert candidate was superseded by the final size-validation source refinement;
its original private artifacts were retained, not overwritten or silently removed.
No authentic package artifacts, private paths or machine inventory are committed.

The exact approved Node-review bytes/digest
`d3f0f76c6ccbb124d14b478e825b6cbf967e561e5551a09e4fe99b4c2881ea2d` were preserved
inside the outer candidate and successfully revalidated without new discovery.
`node_containment.py`, its probe and shared helpers were **not modified**; the
18-file/24-alias runtime and existing measured baseline/source/system fingerprints
remain valid. The compiler candidate adds only literal approved data reads and
metadata ancestors, removing unused probe/read-canary rules. There is no new OS,
target-spawn, network, recursive compiler/SDK/private/Homebrew read permission.

Future fixed attempts are exact compiler version, strict positive non-any semantic
success, and controlled TS2322/exit-2 failure, with separate verdicts. Fixed strict
noEmit/listFiles config is generated from hash-bound source, never caller options.
The inert ESNext literal-reference oracle expects **93** default libraries; actual
reported program closure must contain all of them and exactly the selected owned
root. This is deliberately not a general resolver or all-read trace. Unknown,
partial, duplicate, outside or unexpected diagnostics never become proof.

Pre/postchecks cover runtime aliases/bytes, compiler tree/roles/hashes, fixed
sources/config/policy and protected artifact directory identities around every
attempt. Interrupted postchecks and unknown owner cleanup quarantine/retain, never
retry or infer success from EOF/zero exit. The retained process owner and clean
cache-disabled/OpenSSL-owned environment are reused. Budgets remain 120 s envelope
with a 110 s preflight/launch/final-validation deadline and cleanup reserve, 16 MiB
**aggregate** output, 1 GiB V8 old-space (not RSS), and 2 s independent owner proof.
The reserve is not a universal filesystem-latency guarantee; actual compiler
timing/cleanup and policy behavior remain unmeasured and must pass the next gate.

Verification on final implementation: **529 offline tests PASS = 449 Python +
80 existing Node contract tests**, including **146 native tests / 27 new pure
compiler tests**. Python 3.12.6 ran the full integrated suite; default Python also
passed all native tests. Tests use invented inert archives/inventories and mocked
orchestration, never actual compiler execution/containment proof. An initial test
run exposed case-insensitive filesystem alias handling in a test and intermediate
workspace/state directory modes; both were repaired and the full suite rerun green.
Foundation fmt/build/clippy/tests/docs/offline smoke/intentional failing-test gate
and cached `cargo deny --locked --offline check` passed. Staged secrets, full
staged whitespace and local documentation links also passed before handoff.

Next gate: independent final source/policy/private candidate review, then a **new
explicit primary decision before the first actual compiler attempt**. No earlier
Node approval or generated digest authorizes it. The authentic Emscripten/SDK
type/notice graph remains blocked and is not requested or waived by these fixtures.
Publisher provenance, formal dynamic helper/minimum system closure, DNS/IPC/JIT,
total memory, native TUI capture/review/admission and full product acceptance remain
open. Reported program-file closure, literal sandbox containment and loader
inventory remain separate evidence categories, none certified by these pure tests.

## Compiler path-representability repair — inert, pending independent review

Bob resumed only the preserved compiler unit at base/tested HEAD
`29e62348dfa531dcbae2cb8d63d0d276361a629e` on `t3/004628d1`. The eight staged
files, primary's late-marker fix/regression and priority checkpoint were preserved.
Changes remain staged/uncommitted; no push, PR, CI run/head, merge or deployment
exists for these working bytes. Independent review of this regenerated candidate
has **not run**. TM-04/TM-05/TM-08/TM-10; P1-A2/P1-A5 remain **PARTIAL**, not met.

Read-only inspection confirmed authentic `_tsc.js`'s `normalizeSlashes` replaces
literal backslashes with separators, and `normalizePath` invokes it. Shared
`c.artifacts()` deliberately includes a POSIX backslash in its adversarial prefix;
putting a safe child beneath it cannot repair the absolute config/program path.
The smallest isolated fix is compiler-local artifact naming, not changing measured
C/Node source or weakening their quoting tests. `compiler_containment.artifacts`
uses a representable quote/injection-shaped prefix in the approved private parent
and the existing shared quarantine/retention registry, retained process owner and
signal-masked owned removal semantics. No generic framework was introduced.

`compiler_path` rejects backslashes anywhere (including parents), raw dot/empty/
traversal components, control characters and non-ASCII policy paths before Path
can silently normalize them. Compiler materialization and candidate revalidation
check compilerRoot too; config, policy, fixed command and artifact parent checks
fail before a target launch. Fresh directories remain 0700, protected/compiler
files 0400. Primary's INCOMPLETE-through-validation repair is unchanged. Exact
pre/postchecks, policy scope, cancellation/unknown cleanup retention, 110-second
deadline/cleanup reserve, aggregate 16 MiB output and 1024 MiB old-space remain.

Fresh **UNAPPROVED, INERT, NOT EXECUTED** candidate SHA-256:
`7fb64794f4dd856ddcec40afda792538be67742beba411ca49d6ebd70f3da2b8`.
Launcher/preparation source SHA-256:
`3f5439ca36d936a1f7e61ae86fbf7b237a2acbfbf2374912a27d733463e51593`.
Private paths and authentic bytes remain outside the repository; the parent has
the exact candidate path and a private inert-preparation receipt. Prior candidates,
materializations and failure evidence were retained, not overwritten or removed.

The already-owned authentic archive was revalidated against both pins and copied
into a fresh private root: **112 files / 10,073,711 bytes / 107 libraries / 93
literal-reference-reachable libraries**, complete metadata and both actual notices.
All selected bytes matched the prior owned materialization exactly; selection
digest remains `c6340da859a10d0505112cd14b1ae8ab83228d9c5ebd18ba384047e34af0fe5a`.
Archive and prior candidate were reread unchanged. The nested exact Node review
`d3f0f76c6ccbb124d14b478e825b6cbf967e561e5551a09e4fe99b4c2881ea2d`
successfully revalidated, including current runtime/source/system identities.
**Node baseline source-fingerprint impact: NONE**. Shared C/Node/owner/projection/
compiler-plan sources have no diff against HEAD, and original C/Node adversarial
quoting tests remain unchanged and pass.

Verification: **454 Python offline tests PASS** with installed Python 3.12.6,
including **151 native tests / 32 compiler-only pure tests**. The default Python
also passed all 32 compiler tests. Four new tests cover rejected nonrepresentable
candidate/config/command/policy paths, backslash parents before creation, private
representable quoted artifact naming, and removal-failure quarantine/retention.
Existing mocked tests verify cancellation, timeout, drift, unknown cleanup and
successful owned removal; they are not actual compiler/containment evidence.
Foundation fmt/build/clippy/tests/docs/smoke/intentional-failure gate and cached
`cargo deny --locked --offline check` passed with Cargo network disabled.
After staging all nine owned/preserved files, the tracked-file secret scan and
synthetic-secret rejection, staged/unstaged whitespace checks and local docs links
also passed. No unstaged source changes remain.

No Node (including the ordinary offline-contract suite), TypeScript, C probe,
sandbox target, SDK or host ran. No acquisition, network, download, Docker,
delegation, branch/worktree change, commit or publication occurred. First compiler
execution still requires independent exact regenerated-candidate review and **new
explicit primary authorization**. Full SDK/type/notice closure, native capture/
review/admission and product/Phase 1 acceptance remain blocked/open without waiver.

## Private compiler diagnostic retention repair — NEW candidate NOT EXECUTED

Bob preserved the nine staged owned files and primary's unstaged authorization/
failure record above, on full base/tested HEAD
`29e62348dfa531dcbae2cb8d63d0d276361a629e`, branch `t3/004628d1`. No commit,
push, PR, CI run/head, merge or deployment exists for these working bytes. The
preceding exact candidate `7fb64794f4dd856ddcec40afda792538be67742beba411ca49d6ebd70f3da2b8`
received Joffrey's no-findings review and 143 pure/static tests, then ONE explicit
primary-authorized actual guard invocation. **Version 6.0.3 PASS; positive BLOCKED;
negative NOT_RUN; program-file closure NOT established.** Cleanup reported
verified-or-not-launched. The prior generic wrapper discarded the raw output and
masked the precise reason; no root cause can honestly be inferred. No retry ran.

The smallest repair adds `PrivateEvidence` in the already exact-source-bound
`compiler_containment.py`. Each guard invocation must prepare/fsync a fresh
fixed-prefix 0700 private sibling directory before any launch. It is outside all
target read/write allowances; policy/config/fixtures/observe semantics are
unchanged. Exclusive nofollow dirfd 0400 pending writes, exclusive final-name
reservation, atomic rename and directory fsync retain bounded returned stdout/
stderr and fixed per-attempt metadata privately on BOTH pass and failure. The
aggregate retained output cannot exceed 16 MiB. Old, failed and interrupted evidence
is never overwritten/deleted. No raw output, source, private path or arbitrary
exception repr enters public evidence. Public metadata has only safe stages,
recognized failure codes, exit codes and before/after-validation/cleanup outcomes.

Retention failure blocks further launch/pass; incomplete capture or postchecks
quarantine and retain run artifacts. Known semantic failure with verified cleanup
may remove fresh run artifacts but never the separate diagnostic evidence. Missing
final metadata/pending files mean incomplete evidence and unknown final cleanup,
not success. Measured `owner.bounded` has **no partial-capture/exit API on raises**;
those cases explicitly record unavailable capture/null exit instead of inventing
bytes/status or changing the measured shared helper. A successful helper return
preserves its exact exit and raw bounded output before postvalidation/observation.
This is private local retention, not a general output logger or network sink.

Fresh **UNAPPROVED, INERT, NOT EXECUTED** final candidate SHA-256:
`a8a01b0d9b9c1d6ac601ec32b634694e19987a51cb027fd354f80e6ada2bcbc3`.
Launcher/source SHA-256:
`09a4b5bed912a6ff7e1e45036c640e38aef48e594ccf13fa79328256ab02a458`.
The parent has the exact private candidate path and immutable inert-preparation
receipt; no authentic bytes/paths were added to repository evidence. All prior
candidates, intermediate inert preparations, materializations and failure evidence
remain intact. The owned archive revalidated against both pins; fresh preparation
contains the same **112 files / 10,073,711 bytes / 107 libraries / 93 reachable
libraries** as the previous candidate, complete metadata and actual notices.
Selection digest remains
`c6340da859a10d0505112cd14b1ae8ab83228d9c5ebd18ba384047e34af0fe5a`.
Nested Node review
`d3f0f76c6ccbb124d14b478e825b6cbf967e561e5551a09e4fe99b4c2881ea2d`
successfully revalidated actual current runtime/alias/source/system fingerprints.
**Measured Node/C/owner source-fingerprint impact: NONE**; shared source diff is
empty, including projection/compiler-plan helpers. No Node process was run.

Verification: **469 Python offline tests PASS** under installed Python 3.12.6,
including **166 native tests / 47 compiler-only pure tests**. Default Python also
passed all 47 compiler tests. Fifteen new pure mocked-boundary tests cover retained
success/failure, safe positive-stage/exit/error metadata, private redaction, owner
raise/cancel/unavailable partial API, unknown cleanup, pre/postvalidation,
interrupted retention, output cap, secure preparation/fsync/close failure,
exclusive/nofollow writes, identity drift, policy exclusion and strict diagnostics.
Mocks are not actual compiler or sandbox evidence. Foundation fmt/build/clippy/
tests/docs/offline smoke/intentional-failure gate and cached
`cargo deny --locked --offline check` passed with Cargo network disabled.
After staging all nine owned/preserved files, the tracked-file secret scan and
synthetic-secret rejection, staged/unstaged whitespace and local docs links passed.

No Node/TypeScript/C probe/sandbox target/SDK/host execution, acquisition, network,
download, install, Docker, delegation, branch/worktree change, commit or publication
occurred in this repair. Independent exact-source/candidate review has NOT RUN;
new explicit primary execution authorization is still mandatory. TM-04/TM-05/
TM-08/TM-10, P1-A2/P1-A5 remain PARTIAL; SDK/type/notice/runtime closure, native
capture/review/admission, host certification and Phase 1/product acceptance remain
blocked/open without waiver. The prior positive failure is still undiagnosed.

## Two exact authentic declaration prerequisites — inert receipt, not closure

Bob completed this bounded unit on tested base HEAD
`926abccc729b5f19cebdd7e335098af884a1e292`, branch `t3/004628d1`, integrating
main `1590450e2c40684080fe67ac5c07d1aa87134af1` after PR #26. The primary's
entire preexisting uncommitted PR #26 progress append is preserved. Working
changes are staged/uncommitted: no current-unit commit, CI head/run, PR, push,
merge or deployment exists. Independent review of this unit has NOT RUN.
TM-04/TM-05/TM-08/TM-10 and P1-A2/P1-A5 remain **PARTIAL**, not met.

Added only development pins `@types/json-schema@7.0.15` and
`@types/emscripten@1.40.0`. Existing npm 11.6.0 generated the lock using
`install --package-lock-only --ignore-scripts --legacy-peer-deps --omit=optional
--no-audit --no-fund --registry=https://registry.npmjs.org/` with replacement
environment, fresh private HOME/TMPDIR/XDG/cache, empty private user/global
configuration and update notifier disabled. No inherited credentials, Node
overrides, scripts or installed packages were used. All **existing non-root lock
entries are byte-equivalent as parsed JSON**, with only the two new entries and
root pins added. No node_modules exists. Current lock SHA-256:
`20571ff490c60ed12a0e6b7eefb54138f9292778d2f4be1a2b874f5db1ed6651`.

Exactly two public registry archive requests used the existing redirect-denying,
proxy/auth/cookie-free opener, 30-second request timeout and 512 KiB compressed
read cap each. SHA-512 matched the exact primary-reviewed pins before the existing
strict project_types inspector parsed anything. Each archive's actual expansion
was bounded at 1 MiB (at most 1 MiB compressed / 2 MiB expanded combined).
Observed totals: **11,873 compressed / 60,928 expanded tar / 50,771 declared
file bytes**. Actual archives contain **four regular files each**, not the five
advertised by registry fileCount metadata: complete package.json, index.d.ts,
README.md and LICENSE. No extra file was invented to match the metadata count.
All eight authentic files and both original archives were exclusively preserved
as 0400 inert files in fresh private 0700 owned directories; no extraction API,
package import or package execution was used. Existing archives/evidence were
not changed or cleaned. No authentic declaration source was vendored in Git.

Compressed SHA-256 identities:
- `@types/emscripten@1.40.0`:
  `dd0dceaf2578bbaa1563db0632657806b18e48c0ff1cbff9f54171708e8d7fb1`.
- `@types/json-schema@7.0.15`:
  `12dcb1dcff7099bff0663fc220551ba53fcf23c136a22375e323bb6626d95724`.

`declaration-prerequisites.json` records both computed SHA-512 pins, compressed
SHA-256s, complete actual metadata, all file sizes/hashes and notice/type paths.
It supplements, rather than regenerates or approves, the older full blocked audit.
Both actual LICENSE files have the MIT License heading and Copyright (c)
Microsoft Corporation; identical notice SHA-256:
`c2cfccb812fe482101a8f04597dfc5a9991a6b2748266c47ac91b6a5aae15383`.
Their exact unmodified notice bytes were appended to THIRD-PARTY-NOTICES.txt;
every preexisting byte is preserved. No old runtime notice gap was waived.

Both actual manifests have empty dependency/script maps. Full declaration texts
were inspected as inert data: no external import/reference lines or wildcard
reference was found. JSON Schema defines JSONSchema7/JSONSchema7Definition;
Emscripten defines global EmscriptenModule. These are byte/inspection facts, not
semantic checking or complete declaration-graph proof. The former follows the
authentic provider 3.0.8 dev pin; the latter is for explicitly selected
web-tree-sitter, whose ordinary plugin/TUI reachability is still unestablished.
No Bun types or other closure dependencies were added.

`declaration_receipt.py` is a narrow offline identity/inventory checker reusing
the strict inspector; it has no acquisition CLI, resolver, execution or approval
path. Seven new tests cover real manifest/lock/receipt and actual notice-byte hash
agreement, exact source/version/integrity/root pins, corrupt archives, missing
notice/declaration, complete metadata preservation and wrong actual metadata or
extra dependencies/scripts, plus compressed/expanded rejection before the shared
tar parser. Archive fixtures are explicitly synthetic.
README now distinguishes the independently reviewed historical standalone compiler
PASS from the still-unselected/unexecuted SDK graph; no measured compiler policy,
oracle, fixture, source binding or successful candidate was changed.

Verification: **478 Python offline tests PASS**, including **175 native tests**
and five CI-interpreter tests, under installed Python 3.12.6. The existing 80
Node offline contracts were **NOT RUN** in this unit per execution restriction;
do not call this a new 558-test full-suite pass. No Node/TypeScript compiler,
SDK/runtime host or sandbox guard ran; only the expressly authorized npm metadata
generator used Node. Foundation fmt/build/clippy/tests/docs/smoke and deliberate
failing-test rejection passed through `CARGO_NET_OFFLINE=true python3
scripts/check.py`; cached `cargo deny --locked --offline check` passed. No Docker,
provider access, credential reuse, new workflow, deployment or delegation occurred.

Next: independent review of these staged prerequisites, then a separate bounded
authentic SDK selection/fixed-guard design and review. No projection approval,
SDK semantic/consumed-file closure, install/runtime approval or new target
execution is implied. Existing runtime notices/provenance, Node 24.10.0 versus
OpenTUI >=26.4.0, publisher authentication, native capture/review/admission and
full Phase 1/product gates remain open. Staged secrets/whitespace results are
recorded below after final staging; no exact-current-head CI evidence exists.

Final local handoff: all 478 Python tests reran green on the final checker source;
the seven receipt tests also pass under default Python. Both authentic private
archives/files revalidated against the final checker/receipt and restrictive
modes, and the two-entry-only generated lock delta rechecked. Staged tracked-file
secret scanning and synthetic-secret rejection, staged/unstaged whitespace and
local documentation links passed. Eight files are staged, including the entire
preserved primary progress append; no unstaged source changes remain. No new
independent review, remote CI or execution authorization is claimed.

## SDK declaration discovery — actual notice-binding stop, no projection

Bob inspected this bounded unit at full tested base HEAD
`693fa8a4d394da29e18788ea188b13d47785b6c0`, branch `t3/004628d1`, in the
assigned native worktree. All preexisting progress text, including the primary's
PR #27 append, is preserved byte-for-byte. PR #27's supplied merged main
`33bc8b010879d3bf0b846b154c736e4aa4c700b1` has the same source tree; no branch
switch, merge commit, reset, stash or second worktree was needed. The parent
reports post-merge CI `43356685088`, integrated `43356685052` and offline
`43356685092` SUCCESS; these were not fetched/reverified in this offline unit
and are NOT evidence for this changed tree. No current-unit commit/CI/PR exists.

Fresh inert inspection verified all nine already-owned archive compressed
SHA-256s and locked SHA-512s before strict tar inspection, then rechecked their
input hashes unchanged. Totals: **5,246,943 compressed / 28,210,688 expanded tar /
27,671,448 declared bytes**, **338 declarations**, **11 unselected implementation
type sources**, six packages with archive notices, three without. Complete
package.json bytes, all nested metadata and original notice bytes remain
unchanged in a retained private discovery candidate; public evidence contains
only hashes/relative identities/counts. No node_modules projection was created.

Private discovery candidate SHA-256:
`2336017f6fc2f53ae111948fc1c6df9421871d12a12e636cce3c27859a279cd3`.
Public `sdk-selection-discovery.json` SHA-256:
`360cf3d25405032f7ca69896857957a78c35157e648c9a1967982619985b2be6`.
Both are **blocked discovery data**, not operator approval or an executable
compiler descriptor: hasBlockingRequirements=true, executionApproved=false,
selectionApproved=false, materialized=false, compilerDescriptor=null.

Concrete stop: authentic manifests identify @opencode/client, plugin and theme
2.2.5 at packages/client, packages/plugin and packages/theme in anomalyco/opencode,
but have no gitHead or archive notices. Client/plugin READMEs do not contain a
full permission notice; theme has no README. Retained source evidence verifies
the root MIT bytes at source commit
`9bbb8ce18c80f099e0e448775f59d965ead40a21`; the previous parent release-mapping
assertion is not an immutable package-specific published-archive/source binding.
Those root-notice bytes are retained in source-notice-evidence.json, **not present
in THIRD-PARTY-NOTICES.txt**. No legal mapping was invented or approved from the
MIT identifier/repository directory. Required immutable package/source/notice-scope
evidence is unavailable among the supplied artifacts. Per the stop condition,
full projection and executable SDK candidate preparation were NOT completed.

`SDK-SELECTION.md` records the best nonfabricated fixed design and six blocking
requirements, not a new resolver/framework. Private positive/negative drafts use
actual inspected client/server-plugin/TUI-plugin/theme/core/Solid JSX/web-tree
surfaces, plus JSON Schema and explicit Emscripten global binding. No fixture
stubs/any/casts/suppressions/library skips were introduced. Actual member
signatures were read; neither draft was compiled. The proposed genuine TSX
react-jsx/OpenTUI jsxImportSource binding is outside compiler_plan's preserve-only
contract and still needs separate review. The real wrong-API-argument TS2345 is
only an expectation, NOT observed. Authentic Emscripten must be an explicit file;
types=[]/empty typeRoots cannot supply the global. Direct lexical inventory is
not consumed graph closure; Solid's rxjs text is an example, not an import, and
the inspected bun-ffi-structs declaration export chain does not import Bun types.
Transitive selection/nested identities, Node/ws/reference closure and upstream
directives remain unproved. Unknown newly consumed edges must block explicitly.

Six new evidence-consistency tests verify closed gates, current lock identities,
relative inventories/counts, package-specific notice gap, real prerequisite
bindings, nested metadata and full surface retention. They are not official SDK
resolution, archive-authentication, containment or compiler proof. Final local
verification: **484 Python tests and 80 offline Node contracts PASS (564 total)**,
including **181 native tests**, with Python 3.12 and ResourceWarning as error.
Default-Python native tests also passed. Foundation fmt/build/clippy/tests/docs/
offline smoke/intentional-failure gate passed via
`CARGO_NET_OFFLINE=true python3 scripts/check.py`; cached
`cargo deny --locked --offline check` passed. Private candidate complete/nested
metadata and notice-byte/hash bindings, draft hashes/modes and source drift checks
passed. The approved historical standalone candidate remains exactly
`aea72b77d1cacbcd2daf30aa5b555f6b52b94e8e7c336d3970b8235702039caf`;
compiler_plan/project_types/standalone/Node/C/shared owner implementations are
unchanged. No new execution approval or guard measurement exists.

No compiler, Node discovery probe, SDK, installed host, sandbox target, npm,
download/acquisition, network, credentials, Docker, delegation, commit, push,
publication or deployment occurred. The only Node execution was the existing
80 synthetic offline host/UX contracts. No workflow or runtime helper changed.
TM-04/TM-05/TM-08/TM-10 and P1-A2/P1-A5 remain **PARTIAL**. Full SDK/runtime,
agent/eastasianwidth/AWS provenance, Node/OpenTUI engine compatibility, native
capture/review/admission, product acceptance and Phase 1 remain open. Independent
review of this unit has NOT RUN; parent retains next-scope/authorization ownership.

Final handoff checks: all five owned/preserved files are staged; no unstaged
changes remain. Entire pre-unit progress bytes were verified as an unchanged
prefix. Staged tracked-file secret scanning/synthetic-secret rejection,
staged/unstaged whitespace and local documentation links PASS. Worktree and
private evidence retained; no commit/push or current-unit CI claim.

## 2026-11-12 — same inert SDK unit: authenticated direct notice mapping

This continuation supersedes only the preceding three-package missing-evidence
stop, not its historical measurements or the remaining SDK gates. TM-04/TM-05/
TM-08/TM-10 and P1-A2/P1-A5 remain PARTIAL. Tested base HEAD is
`693fa8a4d394da29e18788ea188b13d47785b6c0`; these are uncommitted staged changes,
so no tested commit containing this unit or exact-head remote CI exists.

The primary performed actual cryptographic verification separately: all three
`gh attestation verify` commands exited 0 with empty stderr. The retained npm
SLSA v1 payload subjects exactly match owned archive SHA-512 pins. This
continuation compared the provided bundle and verified statement/output; gh's
protobuf serialization omits only the empty keyid/rfc3161Timestamps fields.
No verification was re-run, weakened or replaced with custom crypto.

New public `sdk-notice-provenance.json` records explicit registry-version,
attestation, immutable source/tree URLs, bundle/output hashes, exact verification
command restrictions and safe verified certificate identities. Authenticated
build commit is **958f965d35ed44d32b018fd55b02a5357a7748fd**, not the earlier
9bbb8ce notice-source assumption. The source tree is complete/untruncated;
bounded data parsing and Git blob-ID comparison bind LICENSE, three source
package manifests and release.yml. Notice scanning across ancestors and all
three package subtrees found only root LICENSE; relevant symlinks/submodules
were rejected. Source manifest names/license plus archive repository.directory
support package-specific mapping. Workspace/build version transformation is
not manifest-byte equality or reproducible-build proof.

The original 1,155,887 notice bytes are preserved as a prefix. Appended attribution
contains the exact unchanged 1,065-byte MIT notice, SHA-256
`625f0f619133f89bbbb2abe37369613dfa1885eba1e50d02170deb62bb42cb6b`, scoped only
to @opencode/client, @opencode/plugin and @opencode/theme 2.2.5. No transitive
package notice, license waiver or distribution approval is inferred.
Receipt SHA-256:
`8045ca38b56644bed92347390e4a6d70a49ee989a2bc91d650744f000398377e`.
New private inert planning candidate SHA-256:
`81378958e9ea8590c3300adf497561a982c3a823dee4f706c14f3911bcdba74d`.
The prior blocked candidate remains untouched. Complete original metadata,
nested metadata and archive notices are retained; authentic source MIT bytes
are separately bound for each notice-less package. No declaration/source files
were projected, no full project_types manifest or executable descriptor exists.

`sdk_notice_receipt.py` is a narrow pure consistency checker, NOT a cryptographic
verifier or approval mechanism. Twelve new tests cover wrong archive, subject,
source commit, package path, incomplete tree, nearer mixed-case/extended notice,
source symlink, missing/changed raw source bytes, missing appended notice and
opaque-digest self-approval attempts. Receipt consistency is not self-authentication;
the actual gh measurement and independent review remain separate evidence gates.
Existing six selection tests now reflect resolved evidence and closed approval.

Local verification: **496 Python tests + 80 offline Node contracts PASS (576)**,
including **193 native tests**, Python 3.12 with ResourceWarning as error.
Foundation fmt/build/clippy/tests/docs/offline smoke and intentional-failure gate
PASS via `CARGO_NET_OFFLINE=true python3 scripts/check.py`; cached
`cargo deny --locked --offline check` PASS. No Node/compiler/SDK discovery or
sandbox-target execution occurred; Node ran only existing synthetic offline
host/UX contracts. No network/download/npm/delegation/commit/push/PR occurred in
this continuation. Public evidence contains no private filesystem paths.

Outstanding exact gates: Joffrey independent notice/selection review; full
transitive declaration/nested-identity and upstream-directive closure; authentic
Emscripten roots and Node/ws references; official OpenTUI JSX binding; exact real
positive/negative fixture and config review; SDK-specific retained-owner/read/
policy design and explicit authorization before any executable descriptor or
projection. Future transitive packages may have separate missing notices.
Runtime agent/eastasianwidth/AWS provenance, Node/OpenTUI engine compatibility,
native capture/review/admission, functional acceptance and phase closure remain
open. Shared compiler/Node/C/standalone implementation sources are unchanged.

Handoff verification: private candidate complete/nested metadata and original
notice bytes match the prior candidate; added source notice bytes/hash bindings
PASS. Both preceding progress snapshots remain unchanged prefixes. Public path
safety, shared-source drift checks, documentation links, staged tracked-file
secret scan with synthetic rejection, and whitespace checks PASS. All nine
owned/preserved files are staged; worktree/private evidence retained intact.
Independent review and current-unit CI have NOT RUN.

## SDK notice/selection PR tracking

The later Joffrey review recorded above supersedes the pre-review handoff state:
no substantive findings. All 576 offline tests, foundation, cached cargo-deny,
secrets, docs and whitespace reran/passed on full published head
`f64b67f517e8e4dd67545e24e89a485d4d4779fa` after merged-main integration.
The two merge conflicts contained only our added progress and source-notice
append versus an empty opposite side; resolution preserved exact reviewed bytes.
PR #28: https://github.com/suhaasbadada/threadmark/pull/28. CI `43360678505`,
integrated `43360678521`, offline OpenCode `43360678597` all target that head;
initially seven jobs running. This local tracking append is not in the pushed
head. No remote green, merge, SDK projection/execution or phase closure claimed.

## PR #28 qualified merge

Fresh inspection verified all seven exact-head jobs SUCCESS for
`f64b67f517e8e4dd67545e24e89a485d4d4779fa` (CI `43360678505`, integrated
`43360678521`, offline OpenCode `43360678597`), main target, CLEAN/MERGEABLE,
no draft/comments/unresolved threads and no additional approval/protection/ruleset
gate. Independent actual-artifact/notice review and inert prerequisite acceptance
above were retained; no forge approval was invented. Under standing qualified
merge authorization, PR #28 squash merged as
`18a88d9c3a2a57b1e9e88a48d4025b97396ade89`; tree equals tested tree
`76bcf4e5266c65ca2f7d19309dc889afc7060dd4`. PR watch stopped. Post-merge
offline OpenCode `43360926593` passed; CI `43360926644` and integrated
`43360926702` initially running on that exact merge SHA, not claimed green.
No SDK projection/execution, runtime deployment or Phase 1 closure followed.
Next gate remains authentic transitive/ambient/directive closure and a separately
reviewed fixed SDK compiler configuration/candidate; standalone guard stays fixed.

PR #28 post-merge CI `43360926644`, integrated `43360926702` and offline OpenCode
`43360926593` subsequently all passed on exact merge
`18a88d9c3a2a57b1e9e88a48d4025b97396ade89`.

## Independent transitive SDK preparation review

Joffrey reconstructed candidate
`a5b57c65fad62a83e0e2a52d446ffc6eb68f630740aec030bbc53977467d4846`
from 22 actual owned archives and its exact input plan: 1,464 declarations and
1,512 potential reads. Metadata, nested identities, roles/notices, excluded
sources, fixtures and retained artifact modes/ledger match. Authentic compiler
112-file / 107-library binding revalidated without execution. Four retained
successful provenance verifications, archive subjects/certificate identities,
source package manifests/Git blobs and notice scope cross-checked. Reviewer did
not rerun cryptographic verification. No substantive findings; 41 pure/read-only
tests and staged whitespace passed independently. Existing notice/progress
prefixes and shared measured implementations remain unchanged.

All 265 reference directives were independently reviewed: 248 relative targets
are inventoried, nine library references map to authentic compiler libraries,
eight name Node types. `esnext.float16` correctly maps to es2025.float16; no missing
library is inferred. All six suppression mentions are documentation examples,
not active trailing-line directives. Fixture APIs/JSX exports match declarations;
negative TS2345 remains UNOBSERVED. Standard-schema's `standard-schema-spec`
custom-condition source target is absent but inactive under fixed configuration;
it is not an established default-path failure. Optional references and
`#runtime-import` still need entrypoint-specific review; potential read presence
does not establish consumption. These qualifications do not authorize projection
or execution. Total implementation verification: 542 Python + 80 Node = 622 PASS,
plus foundation/cached cargo-deny/secrets/docs/whitespace PASS.

## 2026-11-12 — bounded transitive type selection and inert SDK candidate

TM-04/TM-05/TM-08/TM-10, P1-A2/P1-A5 remain **PARTIAL**. Same assigned branch
and base HEAD `f64b67f517e8e4dd67545e24e89a485d4d4779fa`; uncommitted changes
have no new tested commit, PR or exact-head CI. Prior PR #28 merge
`18a88d9c3a2a57b1e9e88a48d4025b97396ade89` has the identical tested tree;
the parent supplied post-merge CI `43360926644`, integrated `43360926702` and
offline `43360926593` as all SUCCESS on that merge, not this new delta. No
reset/stash/branch switch/new worktree/main integration or cleanup was needed.
All 131,920 pre-unit progress bytes, including the parent's local tracking
append, remain an unchanged prefix. All 21 legacy native implementation/fixture
source files match HEAD byte-for-byte; shared-owner implementation is untouched.

The new separate `sdk_compiler_candidate.py` prepares review data, not an SDK
launcher or a TypeScript resolver. Fresh actual owned-archive hash/structure
inspection expands nine direct/prerequisite packages to **22 packages and 1,464
declarations**, with 1,512 individually hash-bound potential reads including two
fixtures, 9 nested metadata files, 15 actual archive notices, and all 737 upstream
implementation-type files excluded. Whole original metadata and notice bytes,
lexical import/reference facts and declaration-file fixture API bindings remain
private. Potential reads are not necessarily consumed; static facts do not prove
semantic/module closure. Authentic standalone compiler inventory was rechecked
against its owned archive: 112 files/107 default libraries, no compiler JS copied
into SDK node_modules and no standalone execution authorization reused.

Private exact input plan SHA-256:
`1dc707d3d6fcac4949914698c5649a19cf48760409cb14fd1cb5d374fe4aa198`.
Final inert candidate SHA-256:
`a5b57c65fad62a83e0e2a52d446ffc6eb68f630740aec030bbc53977467d4846`.
The private location is retained in the operator handoff, not public evidence.
Only input-plan/candidate/ledger JSON were retained: fresh 0700 root, exclusive
0400 regular single-link files, INCOMPLETE through full inventory/hash/mode/ledger
validation. Earlier artifacts remain intact. **No package projection** exists:
independent review is required and project_types cannot express this combined
nested metadata/notice contract. No executable descriptor/run_guard was added.

New authorized evidence operations were limited to exact-version public npm
metadata/SLSA responses and immutable source manifests for protocol/schema/ai/util
2.2.5: 12 bounded no-proxy/no-redirect HTTPS reads, plus four actual required-policy
`gh attestation verify` measurements. All four verified owned archives exited 0
with empty stderr, matching source `958f965d35ed44d32b018fd55b02a5357a7748fd`.
The existing complete source tree/LICENSE/workflow were reused only after these
commit bindings. Git blobs and actual source names/licenses map all four package
paths; no closer notice or relevant source link/submodule was found. The same
1,065 authentic MIT bytes were appended with explicit new four-package scope,
preserving all 1,157,343 prior notice bytes. Separate transitive receipt SHA-256:
`0b4ccb6fe35a623a5337f6c86429f4aca9e64cf6d9510f9c9bc910931b18795e`.
The original fixed-three notice checker/receipt semantics are unchanged. Hash
consistency and synthetic verification JSON cannot authenticate themselves.
No new archive acquisition, npm/install, login, target SDK/runtime host/Node/
TypeScript/compiler/sandbox execution, worker delegation, commit or push occurred.

Fixed type-only positive fixture covers client/session, server plugin/app name,
TUI session cost, theme RGB, OpenTUI RGBA, Solid accessor/JSX/render and web-tree-
sitter Point/init, with non-any checks. Negative passes a string to authentic
rgbToOklch's numeric red argument; expected TS2345 is **UNOBSERVED**, not success.
New config/policy are typed intent only: strict/noEmit/Bundler, no library skips,
types [], empty owned typeRoots, explicit authentic Emscripten/Node roots and
official OpenTUI react-jsx binding. Existing preserve-only descriptor is untouched.
Future literal read/metadata-ancestor/owned-cwd policy, 120 s/16 MiB/1,024 MiB
old-space (not RSS)/2 s cleanup and private before/after evidence are not approvals.

Concrete unresolved facts remain staged before any descriptor: optional bun,
electron, vite, google-auth-library and #runtime-import conditions; standard-
schema's custom source export ./src/index.ts is absent from the owned archive/
selection and requires conditional relevance review, not a stub. All 265 upstream
reference directives and six effect documentation suppression mentions are
retained for review. Independent actual-byte selection/notice/directive/fixture/
config review, exact SDK/Node/compiler/system/owner policy, separate primary
execution authorization, measured containment/cleanup, official diagnostics and
consumed-file review remain open. Runtime agent/eastasianwidth/three AWS notices,
Node 24 versus OpenTUI >=26.4, native capture/review/admission and phase closure
remain separately blocked; no types-only waiver is inferred.

Final local verification: **542 Python + 80 offline Node tests PASS (622)**,
including 239 native Python tests (46 added), Python 3.12 with ResourceWarning
as error. Node ran only existing synthetic offline host/UX contracts, not the SDK
or compiler. Foundation fmt/build/clippy/tests/docs/offline smoke and intentional
failure gate PASS via `CARGO_NET_OFFLINE=true python3 scripts/check.py`; cached
`cargo deny --locked --offline check` PASS. Actual archive before/after hashes,
complete metadata/notices, final private modes/ledger and legacy source/progress
preservation checks PASS. Independent review and current-unit remote CI have
NOT RUN. Staged secret/whitespace handoff verification is recorded below.

Final handoff: all twelve owned/preserved files staged, no commit/push/PR.
Staged tracked-file secret scan and synthetic-secret rejection PASS; staged and
unstaged whitespace checks and documentation links PASS. Worktree and all private
evidence retained. Candidate source/fixture/receipt hashes and the original
progress prefix were rechecked; no SDK package projection/execution is approved.

## Transitive preparation PR tracking

PR #29: https://github.com/suhaasbadada/threadmark/pull/29. Full published/tested
head `26122cd4e2a5c5a3185878c7190679fcaf052735`. All 622 offline tests,
foundation, cached cargo-deny, secrets, docs and whitespace reran/passed after
main integration. Conflict resolution removed only merge markers around our
append-only sections, preserving reviewed progress/selection/notices bytes.
CI `43367636838`, integrated `43367636946`, offline OpenCode `43367636963`
target that exact head; initially seven jobs running. This local append is not
in the pushed head. No remote green, merge, projection or execution claimed yet.

## PR #29 qualified merge

Fresh inspection verified all seven exact-head jobs SUCCESS on
`26122cd4e2a5c5a3185878c7190679fcaf052735` (CI `43367636838`, integrated
`43367636946`, offline OpenCode `43367636963`), main target, CLEAN/MERGEABLE,
no draft/comments/unresolved review threads or additional approval/protection/
ruleset gate. Independent actual-byte review and inert preparation acceptance
above remain the evidence; no forge approval was invented. Under standing
qualified-merge authorization PR #29 merged as
`859053d9141e1b029dd43854b162014082011527`, tree identical to tested
`bd64751ec5121ce962b781b2c93ace3c15d640c2`. PR watch stopped. Post-merge
CI `43368074565`, integrated `43368074625` and offline OpenCode `43368074604`
initially running on that exact merge SHA; not claimed green. Worktree/local
evidence preserved. No SDK projection/execution or phase closure followed.

PR #29 post-merge CI `43368074565`, integrated `43368074625`, and offline OpenCode
`43368074604` subsequently all passed on exact merge
`859053d9141e1b029dd43854b162014082011527`.

## First SDK discovery review and primary decision

Joffrey independently verified exact candidate
`5613c8df9e39d0306e798858c2d3efd648326b9d7c84770224edd93a3c18f156`
with unmocked preflight, all 22 archives/projected bytes, 1,464 declarations,
31 metadata files including nine nested manifests, 15 archive notices and seven
external notice mappings, unchanged fixtures/fixed configs. Projection has
1,521 files plus ledger and 206 directories. Authentic compiler 112-file/
107-library inventory and 93-library default graph match. Strict unchanged Node
validation passes for 18 files/24 aliases/111,994,336 bytes/version 24.10.0.

Historical source-identity drift affects only compiler_containment.py and its
positive/negative fixtures: reviewed bytes unchanged, inode/mtime/ctime differ.
Historical validators still reject old identities; this exact new outer binding
is reviewed anew, not an old-validation pass or runtime-baseline bypass. Static
policy scope, budgets and fail-closed semantics were independently reviewed;
46 new pure/mocked tests pass. No substantive findings; no target ran in review.

Primary authorizes **one exact version/SDK positive/intended-negative discovery
sequence** on that digest with unchanged policy, immutable inputs and bounds.
No automatic retry, permission expansion, new acquisition, SDK runtime imports,
host launch, provider/deployment or phase closure is included. Any failure must
retain diagnostics and be diagnosed before another reviewed decision.

First exact SDK invocation BLOCKED: version 6.0.3/exit 0; positive exit -6 with
retained stderr `FATAL ERROR: Ineffective mark-compacts near heap limit Allocation
failed - JavaScript heap out of memory`. Positive stdout was empty; negative
NOT_RUN and reported program closure NOT established. Both attempts' before/after
validations and owner cleanup passed; owned execution artifacts removed. Raw
diagnostics remain private. This is an observed failure of the 1,024 MiB V8
old-space discovery budget, not SDK semantic failure or success and not total RSS.
No retry, budget/permission expansion, fixture scope cut or library skip followed.
Investigate fixture type-instantiation cost versus ordinary SDK checking before
selecting any new explicitly reviewed measurement budget; preserve this failure.

Sherlock's read-only RCA confirmed heap exhaustion around 1,014 MB after major
collection at 6.1 s, exactly three intended roots and no accidental glob/duplicate
tree. No justified source fix emerged; broad declaration/type instantiation load
versus a compiler hotspot remains unknown. Primary predeclared ADR 0007's separate
2,048 MiB resource-discovery experiment, preserving the failed original gate and
all other bounds/policy/fixtures. New kind/bounds reject historical authorization;
public results explicitly retain the original failure and do not adopt a product
budget. Original guard/test source bytes were privately snapshotted before change.

Joffrey reviewed exact new candidate
`d641ea056174aab3cb4c6ce049838c575fcb69be8d395bd4351e32e7add56349`:
unmocked preflight PASS, all projection bytes identical except owned absolute
config roots, unchanged compiler/runtime/notice evidence and equivalent policy.
47 pure tests PASS; no substantive code finding. His low stale-instructions
finding was fixed by clearly marking old SDK documentation historical and linking
the failed gate/new candidate/ADR. Primary authorizes **one** exact 2,048 MiB
version/positive/intended-negative resource-discovery sequence. No automatic
retry/escalation or product-budget/Phase 1 acceptance is authorized.

The single 2,048 MiB resource-discovery invocation BLOCKED with version PASS and
positive exit 2, zero stderr, exactly one TS2416 diagnostic: OpenTUI core
InternalKeyHandler.emit override is incompatible with the base KeyHandler/EventEmitter
signature. No missing-module/type diagnostics were reported. Positive list output
is retained but not accepted as semantic success; negative NOT_RUN. Before/after
validation and cleanup passed. The original 1 GiB gate remains FAILED.

Actual selected metadata shows @types/node26.6.6, whereas pinned OpenCode plugin
declares dev @types/node24.12.2 and OpenTUI Solid declares ^24.0.0. The Node26
EventEmitter generic signature is present in the incompatible base type. Primary
selects an authentic upstream-typings alignment investigation, not suppression,
library skipping or fixture reduction. Public exact-version metadata reviewed:
@types/node24.12.2 MIT/index.d.ts/empty scripts depends undici-types~7.16.0;
integrity sha512-A1sre26ke7HDIuY/M23nd9gfB+nrmhtYyMINbjI1zHJxYteKR6qSMX56FsmjMcDb3SMcjJg5BiRRgOCC/yBD0g==.
Exact candidate undici-types7.16.0 MIT/index.d.ts, integrity
sha512-Zz+aZWSj8LE6zoxD+xrjh4VfkIG8Ya6LvYkZqtUQGJPZjYl53ypCaUwWqo7eI0x66KBGeRo+mlBEkMSeSZ38Nw==.
Authorize bounded inert acquisition/notice inspection of only these two archives
and isolated generated-lock-only alignment to those exact pins. No compiler retry
is authorized; compare actual declaration signatures and independently review the
new candidate first. Preserve Node26/1GiB/2GiB evidence and historical plans.

The single generated lock-only operation stopped at unexpected drift. Joffrey
independently verified the exact 378 -> 384 record transition: two requested
typings replacements, six Redis6.3.1 peer records satisfying existing nonoptional
@effect/platform-node redis>=5<7, Emscripten dev->devOptional and TypeScript dev
flag removal consistent with existing peer edges. No other artifact identity or
record/top-level change. These Redis entries are a real future install expansion,
not merely descriptive metadata; no Redis acquisition/install/execution is approved.

Primary accepts **only this exact already-generated static prerequisite lock
transition**, with a hash-bound old/new receipt and pure structural allowlist test
for the two replacements/six exact new peer records/two flag changes. Do not
regenerate, hand-trim peers, use legacy-peer bypasses or broaden acquisition.
Upstream-aligned Node24 remains an investigation, not a proven TS2416 fix; the
existing bun-ffi-structs TypeScript^5 peer versus TS6, runtime engine/provenance
and original resource failures remain unresolved/separate gates.

## Reviewed SDK projection boundary and fixed discovery candidate — inert only

TM-04/TM-05/TM-08/TM-10; P1-A2/P1-A5 **PARTIAL**. Source/test base is full HEAD
`26122cd4e2a5c5a3185878c7190679fcaf052735` on the existing task worktree/branch;
this unit is an uncommitted staged delta, not a newly tested commit or CI head.
Primary reports post-merge CI `43368074565`, integrated `43368074625`, offline
`43368074604` all PASS on exact main merge
`859053d9141e1b029dd43854b162014082011527`, same tree. These historical results
were supplied by primary, not re-fetched or reused as current-unit CI evidence.
The entire pre-existing progress text, including primary's local append, remains.

New `sdk_projection.py` reconstructs only independently reviewed selection
`a5b57c65fad62a83e0e2a52d446ffc6eb68f630740aec030bbc53977467d4846` and plan
`1dc707d3d6fcac4949914698c5649a19cf48760409cb14fd1cb5d374fe4aa198` from already-owned
archives. Actual inert materialization retained 22 packages, 1,464 authentic
declarations, all whole/nested metadata, all archive notices, seven authentic
external source-notice mappings, unchanged fixtures and fixed configs: 1,521
files plus ledger, 206 directories including root. Complete private validation
and before/after owned-archive hash preservation PASS. No authentic bytes were
vendored into the repository. INCOMPLETE spans whole-tree validation; interrupted
or failed preparation retains artifacts, including tested late fsync/close cases.

New `sdk_compiler_containment.py` is a fixed future compiler DISCOVERY guard,
not a semantic-closure assertion. Util's default #runtime-import has an authentic
selected import.bun.d.ts with no external imports; standard-schema's absent source
target belongs to an inactive custom condition. Potential optional bun/electron/
vite/google-auth-library references are not yet proven consumed requirements.
Unknown real semantic errors block rather than being suppressed, stubbed, scoped
away or normalized to success. All explicit roots, the authentic 93-default-lib
graph and every positive imported SDK surface must be observed with per-file
provenance; not every potential read must be consumed. Positive zero diagnostics
and negative exact TS2345 line 4/column 9 remain expected but **UNOBSERVED**.

Inert validation found historical compiler source identity drift: Git integration
replaced compiler_containment.py and its two fixtures' inodes/timestamps, while
all reviewed hashes remained identical. The old validator correctly rejected this
and remains unchanged. The new boundary keeps exact historical compiler candidate
`aea72b77d1cacbcd2daf30aa5b555f6b52b94e8e7c336d3970b8235702039caf`, compares all
historical source/fixture bytes, and explicitly binds fresh full source identities
for NEW independent SDK review. No historical fingerprint/candidate or measured
Node/C/owner/project_types/compiler_plan source was changed. Node 18-file/24-alias
and compiler 112-file/107-library inventory validations remain strict and passed
inertly; this identity refresh does not inherit execution authority.

Final operator-private `sdk-review-candidate.json` SHA-256 is
`5613c8df9e39d0306e798858c2d3efd648326b9d7c84770224edd93a3c18f156`.
Private handoff/inventory retain the exact projection/review paths and 46 raw
evidence bindings. Earlier inert attempts are preserved, not overwritten/deleted.
Status: **INERT MATERIALIZED; INDEPENDENT REVIEW PENDING; EXECUTION CLOSED**.
Fixed deny-default literal-read policy, unchanged retained owner, clean env,
before/after validation, aggregate budgets, private capture-before-interpretation,
quarantine and provisional-success/returned-receipt separation are reviewable
candidates, not actual SDK containment measurements. Details and exact exclusions
are in `experiments/opencode/native/SDK-COMPILER-DISCOVERY.md`.

Local verification PASS: **588 Python + 80 offline Node = 668 tests**, including
46 new pure/mocked-owner tests and 285 native Python tests; Python 3.12 with
ResourceWarning errors. Existing offline Node ran only synthetic host/UX contracts,
not a Node probe/SDK/compiler. Foundation fmt/build/clippy/tests/docs/offline smoke
and intentional failure gate PASS via `CARGO_NET_OFFLINE=true python3 scripts/check.py`;
cached `cargo deny --locked --offline check` PASS. New-unit CI and independent
review have NOT RUN. Staged secrets/whitespace and final preservation results are
recorded at handoff below. No compiler, sandbox target, SDK/runtime host, network,
download/npm, acquisition CI, Docker, delegate, commit/push/PR or branch change.

FIRST SDK compiler decision requires independent exact-byte review (including
identity refresh) plus new explicit primary authorization; neither this hash nor
preparation self-readback grants it. Actual semantics/consumed closure/containment,
runtime agent/eastasianwidth/three AWS provenance, Node 24 versus OpenTUI >=26.4,
native capture/review/admission, host support and P1-A2/P1-A5 closure remain OPEN.

Handoff verification: all six owned/preserved files staged; tracked-file and
synthetic-negative secrets gates, local documentation links, staged/unstaged
whitespace PASS. Final private candidate/projection readback, original progress
prefix preservation and unchanged historical-source/fixture Git bytes PASS.
Worktree, immutable projection and all earlier evidence remain intact. No commit,
push, PR, independent review or SDK/compiler execution was performed.

## Authentic typings alignment — stopped on unexpected generated-lock drift

TM-04/TM-05/TM-08/TM-10; P1-A2/P1-A5 remain **PARTIAL**. Bob worked in the
same task worktree at HEAD `26122cd4e2a5c5a3185878c7190679fcaf052735`,
preserving all prior staged/unstaged work. No new tested commit or CI exists.

The two explicitly authorized exact public metadata records and archives were
retrieved with no ambient proxy/authentication, no redirects, 20-second request
timeouts and 2 MiB response bounds. Complete actual metadata and archives remain
in fresh private storage, directories 0700 and data files 0400; no extraction or
package execution occurred. Both archives matched their predeclared SHA-512
integrities before inspection. Archive SHA-256:

- @types/node 24.12.2: `d0d6910fab205566ade23a582838e93187f4337b03e63a799cd3443839943ed7`
  (461,127 bytes).
- undici-types 7.16.0: `53b5e2fa12a4118a4838e80b1cc6e1d8cd30d6f7e5bea69640e5386f6eb3f8af`
  (27,127 bytes).

Manifest edits added only the two exact dev pins. One isolated npm 11.6.0
`install --package-lock-only --ignore-scripts --no-audit --no-fund` operation,
using the explicit public registry, clean environment, empty HOME/XDG/TMP and
empty user/global configs, returned exit 0 and created no node_modules. However,
the generated lock changed **11 package records**, not just the intended root
pins and two typings packages: it added redis 6.3.1 and @redis/{bloom,client,json,
search,time-series} 6.3.1, changed Emscripten dev to devOptional and removed
TypeScript's dev flag. This triggers the explicit **STOP on unexpected broad
drift** instruction. No retry, manual lock edit, revert, additional acquisition
or continuation into candidate construction was performed.

Previous manifest/lock SHA-256 remain
`f1bea8babcc92323e67a6c35efc1fccd4527e79502bee660c086955fe4b8a628` /
`20571ff490c60ed12a0e6b7eefb54138f9292778d2f4be1a2b874f5db1ed6651`.
Current incomplete manifest/lock SHA-256 are
`6deb7b4d256721c2ce7c3ec481cb3966079fe55b5a2951f04fcfb444f6689cb0` /
`b4566d56a9656b8ff191af83d63cf301cb0398aaf174ae99d4765ab8cbfaae30`.
Private evidence retains both complete before/after files and exact record delta.
These incomplete changes are NOT a reviewed transition and historical receipts
still bind the old lock; their checks must not be represented as current passes.

No new candidate, notice append, signature-comparison conclusion, compatibility
result or independent-review readiness is claimed. Full offline/foundation/deny/
secrets checks were not run for this stopped incomplete unit. The earlier 1 GiB
OOM and 2 GiB TS2416 failures remain unchanged; no compiler/Node probe/SDK/host/
sandbox target, commit/push/PR/delegate or branch/worktree operation occurred.
Next action requires a primary scope decision on the unrelated lock drift, not
another compiler attempt. Runtime Node 24.10.0 versus OpenTUI >=26.4, provenance,
semantic closure, native admission/capture and product budgets remain blocked.

## Primary exact-transition decision and completed inert alignment unit

TM-04/TM-05/TM-08/TM-10; P1-A2/P1-A5 **PARTIAL**. Primary subsequently resolved
the stop above after Joffrey independently reviewed old378 -> new384 lock
records: no top-level drift/removals, precisely the two requested typings records,
six Redis6.3.1 peer records matching the existing @effect/platform-node Redis
range and Redis dependencies, Emscripten dev -> devOptional and TypeScript dev
removal. Primary explicitly accepted only this already-generated transition.
It is a real future ordinary-install graph expansion, NOT harmless metadata or
Redis acquisition/install/distribution/runtime authorization. Existing
bun-ffi-structs TypeScript ^5 versus TypeScript 6 remains unresolved and unwaived.
No npm regeneration, network or acquisition followed that decision.

New `typings-alignment.json` SHA-256
`ccac6466b5229205677fc82ee2469dbad83c828ac3ac1f421195d904c5c50ecf`
records every old/new delta field, original/current manifest/lock hashes above,
actual metadata/archive/file hashes and actual MIT notice blocks. Pure structural
validation binds both exact hashes, all six complete Redis records/edges, exact
flag changes and every unchanged record/top-level field. Historical receipts
remain byte-identical; tests reconstruct and hash-check their ORIGINAL manifest/
lock bytes through this explicit transition instead of accepting mismatches.
Two authentic MIT notices append verbatim; all old notice bytes are preserved.
Notice SHA-256: Node `c2cfccb812fe482101a8f04597dfc5a9991a6b2748266c47ac91b6a5aae15383`,
undici `a6db8096b2707bc0102d256917d4d33f298ba36d8c3f25de067a2b5bb379db27`.

Actual Node26 events.d.ts has EventEmitter<T extends EventMap<T> = any>, generic
emit<E extends string | symbol>(eventName: EventNames<T,E>, ...args: Args<T,E>)
and typed-map emit<E extends keyof T>. Node24 uses DefaultEventMap and
emit<K>(eventName: Key<K,T>, ...args: Args<K,T>), with Key<K,T> defined as
T extends DefaultEventMap ? string | symbol : K | keyof T. Actual OpenTUI line57
narrows emit<K extends keyof KeyHandlerEventMap>. File hashes and exact signature
line data are retained in the receipt; these are **not compiler semantics proof**.
Plugin's actual development pin24.12.2 and Solid's ^24.0.0 support alignment;
whether TS2416 is fixed remains UNOBSERVED.

New `sdk_aligned_inputs.py` preserves the historical preparer byte-for-byte,
validates the authentic archive-only `node v24.12` root without rewriting it,
and rechecks all unchanged twenty package selections/actual bytes plus new two
inventories. No JS/TS implementation source, stub, alias, cast, extra ambient
type, compiler option or custom condition was added. New exact selection
`bc0cf07f9cc037e82a4d990c134e9d86cce2d63c3d24f204a936450a1f5fee8a`
and input plan `15fab187404f5684d69fdefb344f436f6c6f3610443af0262c229d3d57c0a349`
bind the new lock and evidence. Full scope/fixtures/API identities, all twenty
other packages, compiler 112-file/107-library inventory and 93-default-library
graph remain unchanged. Historical plan retains 1,024 MiB; outer resource kind
retains predeclared 2,048 MiB and all other bounds/policy, not a product budget.

Fresh inert projection: 22 packages, 1,444 declarations, 1,492 potential reads
including fixtures, nine nested/31 total metadata, 15 archive notices and seven
external source-notice mappings. Twenty fewer declarations reflect only authentic
versioned Node/undici inventories. Projection has 1,501 files plus ledger and
202 directories including root. Actual before/after owned-archive preservation,
private complete projection validation and outer guard preflight PASS. Runtime
Node24.10.0 still validates unchanged18 files/24 aliases; no engine gate is waived.

Fresh operator-private `sdk-review-candidate.json` SHA-256:
`5e5179f1f0005ee6241d2ab43a385acfeea248622f6406681a5f43120f108f89`.
This was a draft, subsequently superseded after correcting aligned reference
counts to 214 (historical Node26 count 265 remains unchanged). Primary completed
fresh inert regeneration with selection
`f0dc38a0f023079235ef19b331d93ba0c8e266fa0d0831a302e839e10e13132e`,
input plan `70b9500102efccef297db94f5e22af08b9a133ad96259ecc637ddbecf074f203`,
and exact candidate `e4af2ede022b192a0eb639fa64bbe4e2e22492de3824a7b5105d93a87d724eb0`.
Unmocked preflight and archive preservation PASS: 22 packages, 1,444 declarations,
1,501 projected files plus ledger, 202 directories; no target execution. Final
tests and independent review of these exact corrected bindings remain required.

Joffrey subsequently reviewed exact corrected candidate
`e4af2ede022b192a0eb639fa64bbe4e2e22492de3824a7b5105d93a87d724eb0`
with no substantive findings. Unmocked preflight, actual 22 archive/projection
reconstruction, unchanged twenty packages/fixtures, historical lock reconstruction,
exact accepted Redis transition, actual notices and failure/source preservation
passed. Actual EventEmitter signatures support alignment as a hypothesis only.
214 directives and unchanged bounded literal policy verified; 19 pure alignment
tests PASS independently. Primary authorizes one exact aligned 2 GiB
version/positive/intended-negative resource-discovery sequence. Stop on failure;
no automatic retry, widening or claim that the original 1 GiB gate passed.

Aligned invocation: version PASS, positive semantic exit 0/no diagnostics with
669 reported approved program files. Negative compiler exit 2 produced exactly
the intended TS2345 at sdk_negative.ts(4,9), zero stderr, but guard rejected its
cwd-relative diagnostic spelling because its oracle incorrectly expected an
absolute diagnostic path. All pre/post validations/owner cleanup passed; execution
artifacts removed, output retained. Overall guard remains BLOCKED; no false pass.

Primary corrected only that oracle: compute the single expected relative filename
from the fixed invocation cwd and exact owned negative fixture; preserve exact
code/line/column/message/exit and absolute listFiles inventory checks. Alternate
absolute, ./, traversal-alias, wrong-file and wrong-cwd spellings reject. 29 guard
pure tests PASS after correcting an intermediate indentation error; no target ran
for those tests. Regenerated inert candidate
`73729d1f413da0ec65a96c9234d26e80fce410b0cacb88bda81319458bba99ca`
passes unmocked consistency preflight and awaits new independent review/decision.

Fresh Joffrey recheck of that exact candidate found no substantive code findings:
unmocked review/projection/runtime validation PASS, same fixed cwd passed to owner
and observer, exact relative diagnostic plus unchanged absolute program inventory/
exit/order/required-root checks, 68 pure tests PASS. Retained previous 0/0/2 exit
and cleanup evidence corroborated without reclassifying the overall BLOCKED run.
His stale-documentation finding was corrected before execution. Primary authorizes
one exact corrected-candidate version/positive/intended-negative resource sequence
on `73729d1f413da0ec65a96c9234d26e80fce410b0cacb88bda81319458bba99ca`.
No retry/widening or retroactive original-gate/product-budget acceptance included.

The single corrected-candidate invocation PASSED its predeclared resource-discovery
gates: TypeScript6.0.3/exit0, positive exit0/no diagnostics with 669 approved
reported program files and all explicit roots/SDK witnesses, negative exit2 with
only intended TS2345 and 483 approved reported files. Every before/after runtime,
compiler, projection/source/config check and retained-owner cleanup passed.
Temporary execution artifacts removed; immutable projection/private output retained.
Success receipt binds review
`73729d1f413da0ec65a96c9234d26e80fce410b0cacb88bda81319458bba99ca`
and provisional record SHA-256
`f8380920f9d96ec4585e33e4487c9d682b98fe3badcd7c5388bdc7f7f0a147d0`.
No automatic repeat or new permission followed. Earlier OOM, Node26 TS2416 and
aligned oracle failure remain preserved as failures. The original 1 GiB gate
remains FAILED. Reported file closure is not all-system read tracing or full
runtime provenance; peer/engine compatibility, native-host behavior, production
resource budgets, P1-A2/P1-A5 and Phase 1 remain open.
Its private handoff records exact candidate/projection paths and 46 original raw
notice evidence bindings. Status: **INERT PREPARED; INDEPENDENT REVIEW READY;
EXECUTION CLOSED**. Neither self-readback nor earlier Node26 approval authorizes
this distinct lock/selection/plan/source-bound candidate. Both historical failures
(1 GiB OOM/SIGABRT and 2 GiB Node26 TS2416), captures and source snapshot remain
preserved; no target retry occurred.

Verification PASS: **609 Python + 80 offline Node = 689 tests**, 306 native Python
tests, including 20 new alignment regressions over the 669-test resource baseline.
Python3.12 ResourceWarning errors enabled; Node tests are existing synthetic
host/UX contracts, not a probe. Full offline foundation fmt/build/clippy/tests/
docs/smoke/intentional-failure gate and cached offline cargo-deny PASS. Tests cover
exact transition/hash failures, all Redis fields/edges, preserved historical
receipt/notice bindings, authentic inventory/metadata identity, archive-space-root
handling, required declarations/notices, corrupt bytes/roles, full scope/fixture
pins and rejection of inherited Node26 candidate approval. Secrets, whitespace
and final staged readback are recorded at handoff below.

Full source/test base HEAD remains `26122cd4e2a5c5a3185878c7190679fcaf052735`
plus this uncommitted unit; no current-unit tested commit/CI exists. Historical
CI identities remain only historical. No compiler/SDK/Node probe/sandbox target,
host, delegate, commit/push/PR, branch switch/worktree creation or cleanup ran.
SDK semantics/negative diagnostic/consumed closure, runtime provenance, Node24
versus OpenTUI>=26.4, native capture/review/admission, certified support and
product budgets remain OPEN/BLOCKED. Phase1 stays open.

Preservation evidence: private `historical-failure-bindings.json` records every
raw capture/result and the original two-file guard/test snapshot without
publishing diagnostic content or private paths. Original 1 GiB failed result
SHA-256 `3dafa1de09e36310c5746fa82196942b42ba8d18ea6fbc7aed953889cb8274cd`;
Node26 2 GiB failed result SHA-256
`b2a136eaf5a72a7488db13f0336a1800382115311878ada48dd5284a88456f51`.

Final handoff: all 19 owned/preserved files staged, including primary resource
guard/test/ADR/progress changes. Historical planner/receipts and measured
standalone/compiler/Node/C/owner/fixture Git bytes unchanged. Staged tracked-file
and history secrets scan plus intentional synthetic-secret failure gate PASS;
documentation links and staged/unstaged whitespace PASS. Final 306-native-test
rerun and immutable candidate/projection/archives readback PASS. A prior inert
alignment draft remains preserved as superseded after correcting a misleading
review-status docstring; the final digest above alone identifies this handoff.
No new independent review, actual target measurement or current-unit CI ran.
