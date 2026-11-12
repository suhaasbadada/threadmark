# Phase 1 — Full-candidate admission integration

2026-11-12. **Phase 1 OPEN; P1-A1/A5 integration PARTIAL ONLY.**
TM-02/04/05/07/10. The [contract](../../experiments/evaluation-candidate/README.md)
implements a missing offline integration boundary using the actual merged
corpus/adapter/lexical/scorer modules in this assigned checkout. It does not
replace full context/refinement/OpenCode/T3/inference/UX/safety implementation,
define a new MVP, adopt a production knowledge core, or close any phase.
[Product](../product.md), [security](../../SECURITY.md),
[Phase 1](../spec/phase-1-feasibility.md) and
[ADR 0006](../decisions/0006-phase-1-evaluation-protocol.md) remain authoritative.

## Parent repair, independent review and integrated verification

Full committed implementation: `44bde8fd8350478e882fbf8a5067cba795f7b2cf`,
based on actual merged main `700f5fbe1f258818a41a22ac20087fde59fe2544`.
The assigned branch fast-forwarded from the inherited PR #14 head to its
tree-identical merge commit, preserving all task changes and other worktrees.
Main's post-merge foundation run
[43269307591](https://github.com/suhaasbadada/threadmark/actions/runs/43269307591)
was freshly confirmed successful at that full main SHA.

Primary reproduced a binding regression before repair: a preparation probe
changed `harbor` scope to the valid `harbour` scope and a ready candidate then
targeted the latter. The failing assertion demonstrated the wrong project.
Scope is now copied before **any** cancellation/dependency callback; a new
observable regression verifies the original invocation remains bound even when
the probe mutates the caller's dict to another valid project. All **16** new
behavior tests passed; late-mutation, cancellation and failure checks remain.

Joffrey independently reviewed that exact commit and actual dependencies: no
substantive findings. His 16 tests, 48 additional boundary probes and whitespace
check passed; checkout unchanged. He did not run the full integrated suite,
remote CI, host certification or quality study.

Primary separately executed the exact Python, Node and synthetic-guard commands
from the expanded integration workflow on that committed revision: **202 tests
passed** (122 Python + 80 Node), plus real local macOS `synthetic-only-pass`,
`host_launched=false`. No failures/skips in the experimental suites. Offline
foundation, cached cargo-deny, staged secrets and whitespace passed on the same
implementation tree. This is conformance, not comparative quality evidence.

The earlier 15-test/uncommitted child record below remains historical. This
follow-up changes documentation only; final PR-head CI must bind its own head
and run. Standing direct owner authorization covers merge to main after fresh
head/check/review/discussion/target gates, then continued full-scope implementation.
No deployment/spend/credential authority or Phase 1 closure is inferred.

## Trust and acceptance evidence

Public `build` accepts only the actual immutable small frozen artifact, scope
and family, never a candidate-author expected pin, private fixture or candidate
headers. It validates the actual corpus recipe and trusted small pin, then uses
`adapter.prepare`. Adapter-produced immutable bytes are the only trusted fixture
lineage. Scorer `Fixture`/`Anchor` construction retains every line, gold and
rejection. Scope labels/pins are consistency, not authentication or permissions.
Private test-only policy admits two-line boundary artifacts under fixed test
pins; it is not a transport/authentication boundary or production corpus recipe.

| Requirement / acceptance | Evidence in this unit | Remaining limits |
| --- | --- | --- |
| TM-02 | Real adapter source map, scope/hash/version bindings and explicit limited coverage into actual scorer admission | No extractor, syntax/language completeness or production index |
| TM-04 | Real lexical top eight, exact whole full-envelope 8192-byte inclusive admission; no truncation/filtering; duplicate slots/bytes count | No task usefulness, relevance or quality conclusion |
| TM-05 | Exact original query/instructions/original/constraints separately preserved; nonquery and conformance explicitly unsupported | No refinement, semantic intent/permission judgment or invented negation mapping |
| TM-07 | Real retired-evidence counterexample blocks whole candidate; unknown/scope/revision/schema/coverage/anchor rejection | No production freshness model, extracted facts or task correctness |
| TM-10 | Immutable ephemeral output; fail-closed cancellation/dependency errors; fresh deliberate recovery, no host/IO effects | Synchronous checkpoints only, no abort/timeout/process cleanup or authentication |
| P1-A1/A5 partial | Small frozen corpus → adapter → actual lexical → exact full candidate → actual scorer conformance | No representative study, symbol/candidate retrieval arms, extractor decision, bounded runner, inference, host certification, independent outcome evaluation or phase exit |

The decision query selects retired evidence normally; that result is blocked
without dropping items or changing query/ranking. Scorer metrics are discarded
internally and never reported as measurements. A ready value is not host send
permission. Original input is retained once validated preparation reaches the
case; cancellation before preparation has no validated original in its receipt.
Caller inputs are never modified. No network/provider/session/composer/send,
filesystem corpus export, source execution, listener, worker, dependency,
lockfile, Docker, site or runtime changes.

## Verification and handoff

Assigned worktree: `t3-bf506180-b31fe939f3a8f19c`; branch `t3/bf506180`.
Inherited/base SHA: `c10e9ee5ec31569c908dab9d2a556b3c0c99a6d7`, containing
merged PRs #3–#13 plus the parent's PR #14 integrated-CI change. This child did
not query/poll remote CI. Changes are staged **uncommitted**; the base SHA is
not a full tested implementation SHA for this unit. Parent owns independent
review, committed tested SHA, exact PR head/CI run, approvals and authorized merge.
No commit, push, PR, merge, deploy, subdelegate, watcher or scheduler by this child.

Only these task
files are staged: candidate module, public behavior tests, experiment README,
this progress record and one fixed additional command in the existing
`.github/workflows/experiments.yml`. Existing gates remain intact.

### Actual local verification

- New public behavior suite: **15 tests passed**, zero failures/skips. Actual
  frozen SMALL artifact through all four authored modules, both selected scopes;
  independent explicit top-eight coordinates and exact source lines; complete
  limited envelope; original/query/instruction/negation/constraint preservation;
  no oracle leakage into retrieval; retired evidence blocks whole output;
  unsupported conformance families; source/scope/pin/type failures; foreign,
  revision, malformed/unknown/line/text anchors; schema/header/coverage mutations
  at mocked external boundary; duplicates count toward slots and bytes; exact
  8192 full UTF-8 bytes including astral text, 8193/8194-byte rejection while list
  still fits; every cancellation stage; dependency failures and fresh recovery;
  detached immutable results and late scope/task changes.
- Existing integrated Python commands: extraction **8**, containment/supervisor
  **25**, corpus **10**, scorer **24**, adapter **18**, lexical **21** passed.
  Existing corpus tests build their established tiers; no medium/large retrieval
  or quality pilot was added or run.
- Integrated Node OpenCode/T3/UX commands: **80 tests passed**. Combined
  experimental suites: **201 tests passed**, zero failures/skips.
- Actual local macOS synthetic guard: **synthetic-only-pass**,
  `host_launched=false`. This is not installed-host certification.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, format, build,
  Clippy, workspace/integration/doctests, rustdoc, finite foundation diagnostics,
  local documentation links and intentional assertion-failure rejection.
- `cargo deny --offline --locked check`: **PASS**, advisories/bans/licenses/
  sources against **cached advisory data**, not a fresh online advisory audit.
- `python3 scripts/secrets.py` after staging all task files: **PASS**, tracked
  file/history scan and synthetic-secret rejection sentinel.
- `git diff --cached --check` and `git diff --check`: **PASS**; only these five
  task files are staged, no unstaged changes or unrelated edits.

No new generated corpus export, bytecode cache, worker/server or Docker resource
was created. No local Linux run or remote CI outcome is claimed. All new runtime
behavior is pure synchronous value plumbing; existing containment tests remain
separate evidence, not proof that this API aborts work or cleans up processes.
Parent review, full committed tested SHA and exact-head Linux/macOS CI remain
pending, without reducing the required full product scope or Phase 1 gates.

## Symbol arm admission prerequisite — staged child handoff

2026-11-12. **TM-02/04/07/10; P1-A1/P1-A5 PARTIAL; Phase 1 OPEN.**
This entry supersedes only the earlier statement that symbol integration is
absent. The full product/context/refinement/OpenCode/T3/inference/UX/safety scope
remains unchanged. Graph/direct-call candidate retrieval, production extraction,
representative evaluation and every phase-exit gate remain separate open work.

### Scope and acceptance evidence

The existing `candidate.build` now accepts optional keyword-only
`method="lexical"` or `method="symbol"`, using the exact frozen scorer arm
names. Lexical remains the default; existing result/candidate fields and bytes
are unchanged for existing callers. Method must have exact type `str`; invalid
types/subclasses/strings block as `invalid_method` after the preparation probe
and before any dependency loading/retrieval. The scope snapshot still precedes
every callback. Only fixed authored import names select the actual module.

There is one admission implementation, not a parallel candidate builder or
copied validation. It reuses small recipe/pin validation, adapter preparation,
immutable trusted fixture lineage, exact task binding, all four checkpoints,
canonical full 8192-byte admission and the actual scorer. The exact selected
module's `Anchor` class is required; other-arm/ducktyped values reject. Original
declared tasks/instructions/negations remain separate unchanged bytes. No new
method metadata, permission claim or rewritten coverage is emitted. `complete`
still describes only the original limited adapter source map, never symbol,
extraction, syntax or semantic completeness. Ready bytes are not host permission.

Eight new parameterized public-behavior tests retain all 16 original lexical
regressions. Actual frozen SMALL symbol retrieval returns independently authored
expected Rust/Python declaration coordinates in **both** similarly named roots;
direct calls and macro bodies are absent. Spies verify all selected immutable
sources and only the original five-field task reach the selected retriever,
with no fixture/oracle/coverage/hash leakage or other-arm invocation. Boundary
tests cover invalid methods without coercion, preparation-probe scope mutation,
mismatched scope, changed tasks, wrong-arm/malformed/unknown/stale anchors,
duplicate slots/bytes, exact whole-envelope 8192/8193/8194 UTF-8 boundaries,
no cheaper fallback, zero candidates and no unnecessary downstream callbacks
on each cancellation stage, dependency/probe failure and fresh recovery.

Byte-boundary tests reuse the existing tiny fixed private test pins and inject
independently authored selected-class anchors: their inert boundary text is not
a symbol declaration. Actual SMALL retrieval is a separate observable test;
no algorithm, corpus recipe/tier, schema or scoring pin changes were made.
The actual symbol decision query returns an admitted **empty** anchor list,
not retired evidence; this is not a quality win. Injected stale evidence proves
the guard for both arms; the original actual lexical retired-evidence rejection
remains intact. Scorer metrics remain internal and discarded.

### Exact base, local verification and pending parent gates

Assigned branch `t3/candidate-symbol-arm-admission`, assigned worktree
`t3-fe603890-ee41b25356942a02`. Initially clean at
`c10e9ee5ec31569c908dab9d2a556b3c0c99a6d7`; fetched origin main and
fast-forwarded this same branch to required base
`c25d2f6f73a9e964d5bf80e56610c672a24b84e8` before edits. No branch switch,
second worktree, other-checkout edit or discarded user work. Tested state is
that exact base **plus the staged uncommitted diff**, not a committed head SHA.
Only candidate module/tests/README and this ledger are changed. No workflow,
runtime, site, dependency, lockfile, schema, pin or symbol implementation changes.

- Existing integrated workflow's exact Python commands: extraction **8**,
  containment/supervisor **25**, corpus **10**, scoring **24**, adapter **18**,
  lexical **21**, candidate **24**, symbol **37**: **167 passed**.
- Existing integrated Node command: **80 passed**. Combined **247 tests passed**,
  zero failures/skips. Existing corpus tests still exercise their established
  tiers; no medium/large retrieval or study was added/run.
- Actual local macOS guard: **synthetic-only-pass**, `host_launched=false`.
  Python >=3.10 and Node >=22 workflow runtime prerequisites passed.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, including format,
  build, Clippy, Rust tests/doctests/docs, finite diagnostics, local doc links and
  intentional failing-assertion rejection.
- `cargo deny --offline --locked check`: **PASS**, using cached advisories;
  this is not fresh online advisory evidence.
- After staging all four task files, `python3 scripts/secrets.py`,
  `git diff --cached --check` and `git diff --check`: **PASS**.

Parent owns independent review, commit, full tested implementation SHA, exact
PR head/CI run and any authorized merge. Those gates are **not run by this
child**. No commit/push/PR/merge/deploy/subdelegate/watch/scheduler; no study,
quality/performance claims, installed-host certification or phase/product closure.
No network/inference/source execution/discovery/export/host/config/clipboard,
new process worker or Docker capability is added. Existing integrated containment
and guard checks are separate tooling, not synchronous API abort guarantees.
