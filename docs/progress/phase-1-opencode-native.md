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
