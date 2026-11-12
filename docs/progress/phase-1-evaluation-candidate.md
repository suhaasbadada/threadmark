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
