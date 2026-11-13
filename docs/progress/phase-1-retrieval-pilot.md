# Phase 1 — Actual fixed SMALL retrieval pilot

**TM-02/04/07/10; P1-A1/P1-A5 PARTIAL; Phase 1 OPEN.** Bob implemented and ran
one explicitly parent-authorized offline public-synthetic comparison. This is
anchored retrieval evidence, not task correctness, Graphify adoption, product
quality, a performance benchmark or a functioning companion.

## Identity, preregistration and scope

Assigned existing T3 checkout; inherited full HEAD
`e540ee1bfd99dc6e056e21a41f51b1ec2b7c7c90` plus this **uncommitted** unit.
No commit/push/PR/watch/branch switch/delegation. The parent's existing unstaged
native-host progress append was preserved. No bridge/workflow/native-host code
changed. Primary owns review and exact-new-head CI. Supplied PR31/head CI IDs
43401430089 / 43401430141 / 43401430345 concern the inherited head, not this unit;
the child did not query or claim those checks for these new files.

The [authored preregistration](../../experiments/evaluation-pilot/README.md) and
exact [run manifest](../../experiments/evaluation-pilot/evidence/manifest.json)
were retained **before the first pilot worker**. The manifest freezes all 18
ordered cases, original tasks, scoring/query/ranking contracts, eight-anchor /
8192-byte full-envelope ceilings, corpus/public source hashes, reviewed code
bindings and supplemental candidate policy. No oracle enters retrieval.

- Actual run ID: `2026-11-13T09:33:17.843652+00:00` (machine UTC timestamp).
- Manifest SHA-256:
  `a816fab893d9e8010eb1f06ccf38910f0578fd5af200ddff7641e2109cd8e455`.
- Exact [actual report](../../experiments/evaluation-pilot/evidence/report.json) SHA-256:
  `5970f8d28c1cccaf7184fa17997d9a0a3b0bb3f732750392b703ad559541b1f2`.
- Tested pilot source SHA-256:
  `ba95e592f5eefd6baaa8769ed5c69967feb1064a2d228dcdb6ca24b2b3151dd5`.
- Unchanged SMALL corpus pin:
  `c497a577eb9699d15da30b02a215784df36bafeafcb643c83c983ba540e6c9e8`.

Environment declared before pilot: CPython 3.12.6, Clang 17.0.0; Darwin/arm64,
macOS 27.0.1, Mac17,3, 34,359,738,368 RAM bytes (32 GiB). Manifest records exact
kernel build (`xnu-13432.1.9~1/RELEASE_ARM64_T8142`); pre-pilot `sw_vers` also
reported product build 26A434 (session evidence, not a manifest field). Python
binary digest `528c40317937f99ae472ab3998602f3685b72801347c5632098fbce9e3c9a592`;
exact interpreter path stays private. Tools: stdlib and source-bound authored
modules only. No dependency installation. Public evidence contains only synthetic
tasks/anchors and non-private environment metadata, not raw logs or private paths.

## All observed outcomes

Normal unchanged `Runner().run` only. **18/18 ready, exit zero, cleanup verified;
18 actual scorer results valid. No failures, retries, widened limits or discarded
cases.** All rows submit eight unique anchors, zero duplicates; gold count 16
per project and strict slot-budget recall ceiling 0.5. Scorer reconstruction uses
the actual frozen adapter and trusted candidate normalization after return.
Candidate policy/observation commitments, original coverage gaps and source map
remain intact. Byte limits include the full metadata envelope, not just items.

The following quality tuples repeat identically in all three repetitions:

| Arm | TP / FP / FN | Precision | Recall | Payload harbor / harbour bytes | Gold definitions / callers retrieved |
| --- | --- | --- | --- | --- | --- |
| lexical | 7 / 1 / 9 | 0.875 | 0.4375 | 2345 / 2380 | 4 / 3 |
| symbol | 8 / 0 / 8 | 1 | 0.5 | 2285 / 2320 | 8 / 0 |
| candidate | 8 / 0 / 8 | 1 | 0.5 | 2472 / 2507 | 8 / 0 |

Every case is visible below; exact scores/payload/duplicates, canonical candidate
object, hashes, coverage and source anchors are retained in the report. Rounded
times are **runner-inclusive** monotonic seconds: process startup, parent admission
and cleanup, excluding subsequent pilot rescoring; not retrieval-only latency.

| Case | Rep | Arm | Project | Outcome / cleanup | Runner seconds |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 | lexical | harbor | ready / verified | 0.620705 |
| 2 | 1 | lexical | harbour | ready / verified | 0.594915 |
| 3 | 1 | symbol | harbor | ready / verified | 0.605421 |
| 4 | 1 | symbol | harbour | ready / verified | 0.600657 |
| 5 | 1 | candidate | harbor | ready / verified | 0.644970 |
| 6 | 1 | candidate | harbour | ready / verified | 0.631846 |
| 7 | 2 | lexical | harbor | ready / verified | 0.601595 |
| 8 | 2 | lexical | harbour | ready / verified | 0.610118 |
| 9 | 2 | symbol | harbor | ready / verified | 0.599621 |
| 10 | 2 | symbol | harbour | ready / verified | 0.586846 |
| 11 | 2 | candidate | harbor | ready / verified | 0.624673 |
| 12 | 2 | candidate | harbour | ready / verified | 0.614695 |
| 13 | 3 | lexical | harbor | ready / verified | 0.599751 |
| 14 | 3 | lexical | harbour | ready / verified | 0.592711 |
| 15 | 3 | symbol | harbor | ready / verified | 0.591568 |
| 16 | 3 | symbol | harbour | ready / verified | 0.594788 |
| 17 | 3 | candidate | harbor | ready / verified | 0.627500 |
| 18 | 3 | candidate | harbour | ready / verified | 0.619100 |

| Arm / project | Median runner seconds | Range runner seconds |
| --- | --- | --- |
| lexical / harbor | 0.601595 | 0.599751–0.620705 |
| lexical / harbour | 0.594915 | 0.592711–0.610118 |
| symbol / harbor | 0.599621 | 0.591568–0.605421 |
| symbol / harbour | 0.594788 | 0.586846–0.600657 |
| candidate / harbor | 0.627500 | 0.624673–0.644970 |
| candidate / harbour | 0.619100 | 0.614695–0.631846 |

Trial elapsed 11.132987 seconds. Each arm/project's complete candidate bytes
were identical across three repetitions: determinism observations, **not independent
samples** or a performance comparison. No p95. Cache/warm measurement
**NOT_AVAILABLE**: fresh process, no indexed cache; no OS-cold claim. Memory
enforcement / peak RSS unavailable; existing 30-second worker / 16 MiB combined
output / two-second cleanup and 30-minute trial ceilings unchanged. No scaling.

## Concrete decision and useful case

For “Locate resolve and its direct callers in this scope,” candidate **does not
retrieve callers within this frozen envelope**: eight declarations exhaust the
declaration-first eight slots. Symbol returns identical source items (candidate's
extra policy metadata changes bytes); neither returns any of the eight expected
direct-call anchors. Lexical returns three callers but loses one slot to
`unit_0003.rs:2`, a macro-gap line that is allowed current text but not gold.
Candidate's overall recall is 0.5 vs lexical's 0.4375, yet it demonstrates **no
incremental caller retrieval over symbol** and fewer caller anchors than lexical.
Do not use the aggregate metric to claim a graph benefit. No algorithm/query/
cutoff was changed to rescue this counterexample.

Useful case: a developer checking the direct `entry` → `resolve` path can inspect
lexical's exact `harbor/src/unit_0000.rs:3`,
`pub fn entry() -> u32 { resolve() }`; symbol/candidate omit it under this query's
cutoff. This is a traceable synthetic fact, not execution permission or task success.
Paired roots share templates and are not independent. Future query/ranking/corpus
changes require separate prospective review, not rewriting this trial. No
Graphify adoption/rejection decision follows.

## Verification and remaining gates

Before actual pilot: existing runner **25 tests PASS**, covering actual
cancellation/timeout/overflow/dependency/recovery/ownership/cleanup negatives and
reviewed SMALL conformance. Existing module suites **228 PASS**: candidate 39,
scoring 24, adapter 18, directcall 79, lexical 21, symbol 37, corpus 10.
New focused pilot suite **8 PASS**: opt-in/no-effects defaults, dry retained
manifest/order, actual scorer all arms/roots, foreign anchors/original/coverage/
noncanonical/closed-result rejection, failure stop/no retry, manifest/budget
prelaunch rejection and complete report using pure mocked runner receipts.
Only the authorized invocation above ran an actual 18-case pilot; unit tests do
not repeat it. No new CI job/workflow was added.

Full tested committed SHA, independent review and exact-head CI for this new unit:
**PENDING primary**. No native host/VM/account/runtime/install/network/provider/
clipboard/T3 mutation/private upload, source execution, Graphify command, new
containment or package universe occurred. Only reviewed offline workers and fixed
synthetic inputs ran. Foundation/static verification is recorded at handoff;
full-study representativeness, refinement/inference/handoff/UX/task correctness,
hard memory enforcement and all existing host blockers remain open.

Final local checks: **261 focused Python tests PASS** (25 runner + 228 existing
modules + 8 pilot); authorized pilot separately **18/18 PASS**. Documentation
link check (`python3 -B scripts/check.py docs`), cached
`cargo deny --offline --locked check`, staged tracked/history secrets plus
intentional synthetic-secret rejection, staged/unstaged whitespace and exact
private/public evidence-byte/hash readback **PASS**. Cached advisory freshness
was not verified; no network refresh. Full `python3 scripts/check.py` was **not
run**: it builds/executes Rust diagnostics and generated assertion-probe source,
outside this unit's explicit only-reviewed-offline-worker execution scope.
No Rust/runtime source changed. Seven owned files staged; the unrelated parent
append remains unstaged. Review, full integrated checks and new-head CI remain
primary gates, not inferred from these focused checks.

## Primary independent review and integration

Joffrey independently reviewed the meaningful source/evidence change: no
substantive findings. He independently rescored all 18 retained cases and checked
candidate hashes, scores, order, summaries, source/environment bindings and exact
private/public report/manifest equality. Eight pure pilot tests passed without
relaunching workers. Code enforces manifest retention before launch; file artifacts
alone do not independently prove historical preregistration chronology.

Primary verified the actual scoring/normalization and retained counterexample,
then added the eight-test suite to existing integrated Linux/macOS CI. No repeated
pilot or ranking/corpus/query change followed the observed result. This is the
next independent Phase 1 unit while native-host launches stay paused; native
approval/admission is not replaced by retrieval evidence.
