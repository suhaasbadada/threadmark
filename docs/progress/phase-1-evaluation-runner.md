# Phase 1 — Bounded offline SMALL worker prerequisite

2026-11-12. **TM-02/04/07/10; P1-A1/P1-A5 PARTIAL ONLY; Phase 1 OPEN.**
The full context/refinement/OpenCode/T3/inference/UX/safety product scope is
unchanged. This is one evaluation prerequisite, not a reduced MVP, daemon, host,
benchmark, comparative pilot, representative study or Phase 2 architecture.
[Protocol and limits](../../experiments/evaluation-runner/README.md),
[Phase 1](../spec/phase-1-feasibility.md),
[ADR 0006](../decisions/0006-phase-1-evaluation-protocol.md).

## Exact branch/base and staged handoff

- Assigned branch: `t3/phase1-offline-evaluation-runner`.
- Assigned T3 worktree folder: `t3-95fb7f23-0e5477b64a8df6a0` in the Threadmark
  worktree collection. No other checkout or user work was edited.
- Initial clean inherited HEAD: `c10e9ee5ec31569c908dab9d2a556b3c0c99a6d7`.
- Fetched origin/main and successfully **fast-forward-only** updated this assigned
  branch to actual merged main `f2697fb289cda6db6404898b078056b0b7ed7187`
  (PR #17), with no reset, branch switch or extra worktree.
- Implementation is **staged and UNCOMMITTED**. That base SHA is NOT a tested
  committed implementation SHA. Exact tested implementation SHA: **pending parent
  commit and rerun**. Local evidence below applies to the uncommitted tree.
- Independent review: **not run by child; parent-owned**. CI exact run/head:
  **not run by child; parent-owned**. No PR is created or taken over here.
- No commit, push, PR, product merge, deploy, subdelegate, watcher or scheduler.
  Only the specifically requested base fast-forward occurred.

## Design / acceptance evidence

| Requirement | Implemented boundary | Limits / remaining gate |
| --- | --- | --- |
| TM-02 / P1-A1 partial | Complete strict protocol; fixed recipe/source-code/scope bindings; parent-side actual source-map and scorer admission before returning candidate bytes | Actual worker transport/admission remains NOT_RUN; no extraction completeness claim |
| TM-04 | Exact lexical/symbol arm, SMALL recipe and paired selected labels; 30 s wall, 16 MiB combined live output, whole 8192-byte candidate | No study, quality/ranking change, medium/large or RSS enforcement |
| TM-07 | Malformed/partial/trailing/unknown/foreign arm/scope/revision/pin/code binding closes; no raw process diagnostics; explicit unverified quarantine | Cooperative reviewed code only; no universal escaped-process containment |
| TM-10 | Fresh isolated environment/state, null target stdin, retained owner, deferred launch cancellation, TERM/KILL/reap, real owned descendant evidence, owner-death control EOF, restored handlers/FDs | No sandbox or host authority; crash artifacts require owned cleanup; further trials blocked on missing proof |
| P1-A5 partial | Predeclared input/output/budgets/cleanup/preflight protocol and fixture-only CI command | Parent independent review, exact committed SHA/CI, separately authorized tiny actual-worker conformance and representative protocol remain pending |

Public results are frozen source-free operational fields except explicitly
validated ephemeral original/candidate bytes. Candidate is returned only after
actual merged scorer admission and exact original/source/scope/coverage binding;
it is null on all closed paths. Validated original bytes, when present, retain
the actual candidate contract. No provisional stdout/stderr/error content is
echoed. No cache/last-good candidate or automatic retry exists.

Only reviewed authored worker/fixture files can be selected by the fixed launcher.
The actual worker builds actual frozen corpus SMALL and calls actual
`candidate.build(..., method=...)`; it never executes generated source or feeds
oracle/private fixture data into retrieval. Existing guard profiles/APIs/budgets,
candidate algorithms/default, corpus pins and scoring contracts are preserved.

### Shared-supervisor refinement and retained negative evidence

Initial fixture tests exposed a macOS ownership-ordering failure: closing the
control pipe during normal cleanup lets the existing helper self-KILL before the
parent's final group signal. A signal against that already-dead group can report
EPERM; the runner correctly returned cleanup_unverified rather than success.
The first test pass also exposed a fixture child's inherited blocked TERM mask,
which prevented cooperative wait evidence. Neither was hidden by retrying trials
or weakening cleanup verification; no actual candidate worker was involved.

The focused repair reuses the existing shared `process_supervisor.py`, adding
only an optional private readiness FD with target identity. Original harness
argv, integer status protocol, owner-EOF behavior, containment profiles and
budgets remain unchanged. Normal runner cleanup now waits boundedly for ready,
keeps the control pipe open, sends TERM then final KILL, and only then reaps the
supervisor. Launch-boundary cancellation cannot lose ownership before readiness.
The authored fixture leaf explicitly unblocks the mask inherited during its
parent's ownership-critical spawn. A fixture environment assertion also needed
macOS temporary-path canonicalization; no user path/content was exposed.

Readiness is not cleanup proof. Actual target-wait status is required; fixed
descendant modes additionally require identity-bound child-wait attestation and
absent PID. Tests independently check both known PIDs absent after reaping. Missing
attestation is explicitly tested without leaving a live descendant, and latches
quarantine for every Runner instance in that process session. No public reset or
global disk state is introduced. New-process success is never prior-cleanup proof.

Owner-death test kills the actual fixture owner with SIGKILL. The helper sees EOF
while work is active, signals the owned group, and the cooperative target reaps
its known descendant before terminal exit. Tests inspect owned atomic artifacts
and exact worker/descendant identities, boundedly verify their absence, then
remove only their own crash artifact tree. No escaped setsid process is launched,
no broad kill/prune and no macOS adversarial orphan-grandchild reaping claim.

## Local verification

On macOS/Darwin kernel 27.0.0, Python 3.12.6. These are safety/conformance
assertions, not evaluation timing, RSS, retrieval quality or user-value metrics.

- New runner fixture suite: **15 tests passed**, zero failures/skips on the
  repaired tree. Real fixed processes cover complete CLOSED protocol, launch
  boundary SIGTERM, active Event/SIGTERM cancellation, timeout, mixed-stream and
  descendant output overflow, descendants alive after closing output, malformed/
  partial/duplicate/trailing/non-UTF8/unknown/foreign arm/scope/revision/pin/code
  binding, nonzero/dependency/OS-launch failure, owner death, verified fresh
  recovery and blocked recovery after missing cleanup proof. Tests assert
  termination within two seconds of cancellation, actual child-wait statuses,
  PID absence, signal handler/FD restoration and owned temp cleanup. A private
  simulated final close-error test verifies that even a constructed receipt is
  superseded by cleanup_unverified, all handlers restore and recovery is blocked;
  it closes the actual FD first so the negative test does not leak a resource.
- Existing integrated commands: **247 tests passed** (167 Python + 80 Node),
  unchanged commands. Including the new 15: **262 passed**. Existing candidate
  tests do pure in-process SMALL conformance as before, NOT an actual worker or
  study. Existing corpus tests may generate inert larger byte fixtures as before;
  no medium/large retrieval or generated-source execution was added.
- Actual synthetic macOS guard: **synthetic-only-pass**, `host_launched=false`.
  This is the fixed synthetic guard, not host certification or runner sandboxing.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, including fmt,
  build, clippy, 10 Rust tests plus one doctest, docs, finite CLI/daemon diagnostics,
  local links and intentional-failure rejection. Initial run passed Rust/CLI
  gates but stopped at the not-yet-created progress document link; final rerun
  passed after this document was added. No unrelated foundation repair.
- `cargo deny --offline --locked check`: **PASS**, advisories/bans/licenses/sources;
  cached advisory data only, freshness not verified and no network refresh.
- Staged `python3 scripts/secrets.py`: **PASS**, tracked scan and intentional
  synthetic-secret rejection. `git diff --cached --check`: **PASS**.

## Actual worker and remaining authorization gates

**Actual `worker.py` launch: NOT_RUN BY CHILD.** The positive admitted-byte
transport path is deliberately unrun before parent review. Fixture protocol
success is CLOSED, not a fake candidate, benchmark or trial. Public lexical and
symbol selection is tested without starting the real worker. Parent reviews
source/helper changes first, commits and records full tested SHA, independently
reviews/tests, then may authorize bounded tiny SMALL conformance through the
normal public entrypoint. Native exact-head CI/PR/merge belong to the parent.

Memory enforcement is **unavailable**; reject medium/large before launch. No
index/cache exists: immutable inputs and fresh process only, not cold/warm study
results or OS-cache eviction. No study orchestration (ADR's prospective 30-minute
trial cap remains unchanged), inference/network/spend, installed host, source
discovery/export, clipboard, configuration, listener, runtime/site/dependency/
lockfile or Docker change. No performance/quality metrics or full-study manifest
is fabricated. All representative environment, comparative retrieval/graph arm,
refinement, real-host, inference, UX and safety gates remain open.

## Parent review and finalization-cancellation repair

Initial committed implementation: `4e2ed88aa08c1b8af01c94bb9e188b50d9422d04`.
Joffrey independently reviewed it, ran 15 runner fixture tests and one existing
supervisor regression, and identified a medium finalization-cancellation race.
The final cancellation check preceded temporary-state/FD/stream cleanup; an
already constructed ready receipt could survive cancellation during cleanup.
Primary reproduced `ready` instead of `canceled` with an actual fixture process
and mocked admission receipt, triggering Event cancellation during actual
temporary-state removal. No actual candidate worker was launched.

The repair checks cancellation after resource restoration at ownership return,
superseding constructed receipts with byte-free `canceled`. Cleanup-unverified
and quarantine retain precedence. Regression covers both Event and SIGTERM;
the existing simulated final resource-error test now also requests cancellation
and confirms cleanup-unverified still wins. Repaired local suite: **16 fixture
tests PASS**; primary independently ran **263 integrated tests** (183 Python +
80 Node) plus actual synthetic macOS guard, foundation and cached cargo-deny:
PASS. Actual candidate worker remains NOT_RUN pending fresh repaired-head review.

Base post-merge CI was freshly verified successful on exact base
`f2697fb289cda6db6404898b078056b0b7ed7187`: foundation
[43279335179](https://github.com/suhaasbadada/threadmark/actions/runs/43279335179)
and integrated
[43279334934](https://github.com/suhaasbadada/threadmark/actions/runs/43279334934).
These base runs are not final-head CI for this runner. Initial child 15/262-test
and uncommitted statements above are historical snapshots, not repaired totals.
