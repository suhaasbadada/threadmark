# Fixed offline SMALL comparative pilot

**TM-02/04/07/10; P1-A1/P1-A5 PARTIAL; Phase 1 OPEN.** This is one public-synthetic
retrieval comparison, not a general study framework, Graphify adoption, task-success
evaluation, performance benchmark or functioning companion. No native host, VM,
inference, network, provider, package, clipboard or generated-source execution.

## Preregistration (written before the pilot)

The unchanged [ADR 0006](../../docs/decisions/0006-phase-1-evaluation-protocol.md)
and actual corpus/scoring/candidate contracts govern this deliberately limited
pilot. Exactly 18 cases: repetitions 1, 2, 3, each in lexical, symbol, candidate
order, each harbor then harbour. Task is **definition_directcall**, original
query and instructions verbatim, all selected public sources; no answer-aware
query/file selection. Gold is all adapter definition/direct-call anchors, not
just eight. Actual frozen scorer computes exact full-anchor TP/FP/FN, precision,
recall, duplicates and payload; invalid cases have no metrics. No partial credit.

Before **any** pilot worker, `manifest.json` is exclusively created, flushed and
fsynced. It retains ordered cases, original tasks, complete existing scoring
manifests, frozen corpus manifest including all exact public source hashes,
runner/source bindings, supplemental candidate policy, pilot source digest,
Python version/binary digest, OS/build/architecture and declared model/RAM.
Embedded historical NOT_RUN flags remain historical contracts, not this pilot's
execution status. This metadata never becomes a retrieval input. Retention and
hashes are consistency evidence, not permission or crash-proof archival storage.

Only normal existing `Runner().run(arm, project)` launches actual fixed workers.
No runner/worker/algorithm/ranking/budget/pin change. Scoring reconstructs the
actual frozen adapter case only after return, with the existing shared trusted
normalization (including candidate method/policy/observations/gaps/source anchors).
No copied retriever/scorer or worker-provided fixture is trusted. Candidate
declaration-first ranking and eight-item cutoff can exclude every caller.

Existing lifecycle suite must first pass cancellation, timeout, aggregate output,
dependency/fresh recovery, owner death and verified cleanup; operator/parent owns
that prerequisite and execution authority. The CLI does not invent another gate
or claim a manifest authenticates that authority. The assigned fixed invocation
was explicitly authorized by the parent, conditional on those passes.

SMALL only, one worker/project at a time; existing 30-second worker / 16 MiB
aggregate output / two-second cleanup limits unchanged. Memory enforcement and
peak RSS unavailable, so no scaling. Trial ceiling 30 minutes, with full worker
and cleanup allowance reserved before each launch; elapsed checked after scoring.
This is not an extra in-process hard watchdog. Any closed result, ownership,
cleanup, protocol, binding, scoring or budget failure stops the sequence, retains
the partial report, and never retries/widens. An output write failure propagates
and stops; the last retained prefix is not a completed trial.

Fresh process with no indexed cache: **cache/warm measurement NOT_AVAILABLE**;
no OS-cold claim. Monotonic time around `Runner.run` includes startup, admission
and cleanup, not retrieval-only. Publish every outcome, median/range only, no p95.
Three repetitions check repeated determinism, not independent samples, product
improvement, representative repository quality or human task correctness.

## Commands

From repository root, Python stdlib only. No arguments prints help with no writes
or worker launch. `--output` without `--run-small` writes a dry manifest only.
Outputs must be a **new**, operator-owned directory; never reuse a previous run.
Hardware arguments are explicit declarations, not private hostnames.

```sh
python3 -B -m unittest discover -s experiments/evaluation-pilot -v
# Run existing lifecycle prerequisites before an explicitly authorized invocation:
python3 -B -m unittest discover -s experiments/evaluation-runner -v
# Only with separate execution authority; substitute a NEW owned directory:
python3 -B experiments/evaluation-pilot/pilot.py --run-small \
  --output /approved/owned/new-synthetic-evidence \
  --hardware-model Mac17,3 --ram-bytes 34359738368
```

No query, arm, source, recipe, executable, environment, pin, retry or budget
override. Unit tests use pure actual-module values/mocked runner receipts, not
18 actual worker launches in CI. The primary added this eight-test suite to the
existing integrated Linux/macOS workflow after independent review. CI does not
rerun the comparative pilot or claim new quality measurements.

Actual synthetic-only evidence and exclusions:
[progress report](../../docs/progress/phase-1-retrieval-pilot.md).
