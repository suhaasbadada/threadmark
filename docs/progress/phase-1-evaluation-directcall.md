# Phase 1 — Evaluation-only Rust/Python static direct-call prerequisite

2026-11-12. **Phase 1 OPEN; TM-02/04/07/10; P1-A1/P1-A5 PARTIAL ONLY.**
The complete context/refinement/hosts/inference/UX/safety product remains required.
This is not a reduced MVP, Graphify adoption/replacement, production graph,
daemon, integration, comparative pilot, quality study or phase closure.

## Exact handoff and scope

- Assigned branch `t3/directcall-static-binding-extraction` (T3 renamed the initial
  `t3/0d012021` label during startup; no branch switch/rename by this child);
  assigned T3 worktree basename
  `t3-0d012021-c61746d5f484e3d1`. No other checkout or task work modified.
- Initial clean inherited HEAD `c10e9ee5ec31569c908dab9d2a556b3c0c99a6d7`.
  Fetched origin/main and fast-forwarded this exact branch to merged main
  **`d00b94e225233595d026481c4e241187bfa0b657`**. No reset, branch switch,
  extra checkout or worktree creation.
- Deliverable: staged, **UNCOMMITTED** changes in the four requested experiment/
  progress files plus one command in the existing experiments workflow. No
  duplicate workflow; no other arm/runner/worker/adapter/scorer/corpus edits.
- Exact tested committed implementation SHA: **PENDING parent commit and rerun**;
  the base SHA above plus staged edits is the local verification tree, not a
  committed implementation. Independent policy/coverage review: **PENDING**.
  Exact CI run/head: **NOT RUN by child; parent-owned**. No PR created or assumed.
- No commit/push/PR/merge/deploy/subdelegate/watch/scheduler or Graphify execution.

## Acceptance and remaining gates

| Requirement / acceptance | Evidence in this unit | Remaining limitation |
| --- | --- | --- |
| TM-02 / P1-A1 partial | Both languages' whole-input binding collection, source-byte identity, distinct call spans and per-file observed coverage | Static subset assumptions, not runtime/type truth or language completeness |
| TM-04 | Frozen one-hop declaration-first query/path/line ranking, coordinate dedup, top-eight then whole8192-list reject | Full candidate envelope with independently reconstructed observations not integrated |
| TM-07 | Explicit unresolved reasons, poisoned affected scopes, late-failure rejection, generic content-free errors, dependency pin | Same-interpreter code is trusted; no authorization, missing-source detection or runtime certainty |
| TM-10 | Pure immutable in-memory APIs, no source execution/discovery, network/provider, fallback/cache or new worker | No cancellation/containment interface offered by this synchronous prerequisite |
| P1-A5 partial | Supplemental version/dependency/policy manifest and independent literal tests in existing workflow | Policy/coverage review, committed SHA/exact-head CI and separate admission review required before arming/comparisons |

The [README](../../experiments/evaluation-directcall/README.md) records precise
predeclared Python grammar/binding contexts, Rust subset/masks, IDs/coordinates,
coverage semantics, failures, limits and counterexamples. Module functions are
static binding assumptions, not monkeypatch-proof object identities. Python
definition-time execution calls are unsupported with gaps and binding masks;
Rust unsupported binding constructs poison affected scopes. Rust syntax/type
certification and all cross-file/type/alias/qualified/macro/cfg resolution remain
unavailable. No arbitrary Rust grammar claim is made.

The existing scorer CONTRACT/digest, corpus/schema/algorithm pins and historical
NOT_IMPLEMENTED/NOT_RUN strings are unchanged. The supplemental manifest explicitly
pins the reviewed symbol internal source dependency rather than copying its
lexer or calling its cropped retrieve output. Graphify 0.9.101 is neither run
nor wrapped; earlier ID/completion/inference/location/edge-collapse limitations
remain evidence against assuming that a wrapper meets this contract.

## Local verification

Host: Darwin 27.0.0 / arm64, Python 3.12.6. No other interpreter/platform was
locally certified. Supplemental Python 3.12 policy digest:
`c66d5404f17a8cc596bad68e718b287e6c2e96b25d88f78fdb3aac3fe374612e`.
Grammar-version-specific digests are deliberate, not source/corpus schema changes.

Initial new-suite run exposed three incorrectly hand-counted test offsets (not resolver
edge failures); expected literals were independently recounted and corrected.
Subsequent inspection added definition-time named-expression masks, module lexical
isolation, opaque Rust type contexts and extern/generic binding poison regressions.
No negative result was converted to completeness or a production claim.

The initial complete integrated run passed **264 existing tests + 63 new tests**,
all actual workflow commands, plus actual synthetic macOS guard. Follow-up code
inspection added opaque local-type/turbofish contexts, exact noncallable ownership,
same-line macro exclusion, inclusive source counts and unknown-parameter-pattern
regressions. Final results are recorded below after rerunning those changes.

Important distinction: the unchanged existing runner suite includes its previously
reviewed lexical/symbol actual-SMALL transport conformance test (four fixed arm/root
cases). That existing regression ran as part of the requested **all 264 existing**
commands; there was no additional/manual worker launch, no directcall worker,
no directcall admission and no new arm/candidate/runner integration. Existing
corpus/adapter tests build inert larger-tier fixture bytes; no medium/large
retrieval was run. All new directcall fixtures remain small, independently authored
in-memory examples; the 32-MiB Markdown arithmetic boundary is not a study.

Second complete integrated run: **332 tests PASS (264 existing + 68 new;
252 Python + 80 Node)**, zero failures/skips. Actual synthetic macOS guard:
**synthetic-only-pass**, `host_launched=false`. After this run a final identity
inspection retained Rust raw-identifier spelling (`r#name`) separately from query
names and added explicit expensive-top-eight/cheap-ninth rejection; the final
focused **69-test directcall suite passed again**, including raw-name retrieval.
Final unique test inventory verified: **333 PASS (264 existing + 69 new;
253 Python + 80 Node)**. Existing arm/runner source and pins were not modified.

- Offline foundation `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**:
  formatting/build/clippy, 10 Rust tests + one doctest, docs, finite diagnostics,
  local Markdown links and intentional-failure rejection.
- `cargo deny --offline --locked check`: **PASS** advisories/bans/licenses/sources;
  cached advisory data only, freshness not verified, no network refresh.
- `python3 scripts/secrets.py` after staging all five files: **PASS**, tracked-file
  scan and intentional synthetic-secret rejection. `git diff --cached --check`:
  **PASS**. No unrelated files staged or unstaged; exact final status rechecked.

Parent must independently review policy and observed coverage before integration,
then bind eventual committed SHA and exact CI run/head. No local check closes
Phase 1 or establishes quality/performance, host certification or a product decision.

## Parent review repairs (supersede initial 69/333-test snapshot)

Initial implementation commit: `a976033a02038476b0fa790991e4247f74b2dcd0`.
Joffrey independently ran 69 tests and three additional probes, finding three
substantive false-edge defects. Primary reproduced all three without executing
source: Rust cast trait syntax `x as &dyn Fn()` was reported as a call to a
same-spelling free function; a module annotation's walrus rebinding was ignored;
a class-body call before its later method definition targeted that uninitialized
method instead of remaining unresolved.

Repairs poison the affected Rust cast scope (not sibling functions); collect
annotation named-expression masks without resolving unsupported annotation calls;
and require class-local callable bindings to have completed before their call.
New independent literal regressions cover exact cast coordinates and unaffected
sibling calls, module/class annotation masking, and forward-vs-initialized class
method identity. Supplemental pending policy descriptions now explicitly include
these rules. Its Python 3.12 digest is
`9244239f9063407e51d942d2f36e056147e78355a60660dcaa95d2d9a994cb7a`;
the prior supplemental digest above is historical. Existing scorer/corpus/schema/
algorithm pins remain unchanged. This is not a retroactive scoring-rule change.

Primary independently ran **72 directcall tests and all 336 integrated tests**
(256 Python + 80 Node), plus actual synthetic macOS guard: PASS. Foundation and
cached cargo-deny also PASS; advisory freshness remains unverified. No directcall
worker/integration/study was launched. Fresh repaired-head policy/coverage review,
staged secrets/whitespace and exact-head CI remain the next recorded gates.

### Second review: qualified types and compiler-scope bindings

Joffrey freshly reviewed `018259f2ea692e8be3cb06b1f50607bc55dc1712`, ran
72 tests and additional probes, and blocked approval on three further false-edge
cases. Primary reproduced qualified Rust trait syntax inside
`<dyn Fn()>::factory()` becoming a call to a same-spelling free function; class
private names targeting raw module names and mangled parameters failing to mask;
and methods treating implicit `__class__` as a module function.

Repairs conservatively poison expression-angle contexts (including qualified type
paths and comparisons), preserving unrelated scopes; implement lexical class-name
mangling for **both binding and lookup keys**, preserving raw evidence names/IDs;
and mask implicit class cells in class-associated function/lambda/comprehension
scopes. Global/nonlocal masks use the initiating class-mangled key. Tests cover
the exact qualified type, correct private target identity, parameters/assignment/
global masks, nested and leading-underscore class contexts, implicit class cells
and unaffected ordinary module calls. No existing language/type certainty claim
is strengthened. The pending Python 3.12 supplemental digest is now
`82ebc050e58f1595e8d42fc06a323229dcdf3d7b8382bd301861aef70f1db867`;
both earlier supplemental digests are historical, not current admissions pins.

Primary independently reran **77 directcall tests, all 341 integrated tests**
(261 Python + 80 Node), synthetic macOS guard, foundation and cached cargo-deny:
PASS. Directcall remains NOT ARMED, with no candidate/runner integration or
study. Fresh exact repaired-head review and CI are still required.

### Third review: item masks and compiler-created class dictionaries

Joffrey freshly reviewed `f90289c9ec19ea04ccdb859e961cc878f72ee857`, ran
77 tests plus nine probes and blocked approval on multiline Rust nonfunction
bindings and Python compiler-created class dictionary names. Primary reproduced
the local multiline tuple constructor incorrectly targeting a file function,
and `__module__`, `__qualname__`, docstring `__doc__` and annotation
`__annotations__` class calls incorrectly targeting module functions.

Rust item-header binding masks now install independently of same-line emitted
declaration eligibility, covering multiline/raw tuple structs, constants and
statics. Python class dictionaries collect those compiler-created masks before
resolution; methods still skip class dictionaries and retain legitimate module
references. Independently authored regressions verify both rejection and unaffected
sibling/method identity. **79 focused tests PASS**. Supplemental pending Python
3.12 policy digest is now
`5ef8bfd20b2be4e9c82ad85b314a0156a73095bdf20fbf777e3576414c6d9b36`.
Earlier pending-policy digests above remain historical; no scorer/corpus/schema/
algorithm pin changed. Fresh repaired-head review and full integrated rerun remain
required; standalone prerequisite is not assumed approved or armed.

### Compatibility review follow-up

Joffrey freshly reviewed `1778592b90feb01336e045baa5bbcb9fbe636bf3`:
79 tests plus 13 additional in-memory probes passed on Python 3.12.6, with no
further substantive issue in that grammar. Approval remained blocked on a
Python 3.13+ compiler-created class binding, `__firstlineno__`, whose absence
from masks could fabricate a module-function edge. Python 3.13 was unavailable
to the reviewer; its runtime behavior was not claimed tested.

The class mask now conservatively includes `__firstlineno__` across grammars,
with the existing paired class-body/method regression expanded to cover it.
This intentionally under-resolves that class-body name on older Python versions
rather than falsely claiming universal compiler-version support. Method lookup
still skips the class dictionary. Pending Python 3.12 policy digest:
`7e126aabcfca4db0b01568139cd711cd22391bcd2eb979c3b78083fc588ed622`.
Prior pending digests remain historical; existing frozen arm/corpus pins unchanged.
Final verification and fresh review are recorded next; no arm integration/study.
