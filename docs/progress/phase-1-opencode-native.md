# Phase 1 — Release-pinned OpenCode native bridge prerequisite

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
