# Phase 1 — Offline evaluation corpus preparation

2026-11-12. **TM-02, TM-04, TM-07, TM-10; P1-A5 PARTIAL ONLY.**
Phase 1 remains open; Phase 2 is not authorized. This does not close P1-A5 or
establish representative quality, performance, user value or certified hosts.

## Preregistered boundary and protocol

Inherited base: `9227571c6e9f0b090ec883121dc9babfc25cc59f` (unmerged PR #8).
Assigned branch: `t3/phase1-evaluation-corpus-fixtures`; the assigned T3 checkout
was reused, without branch switching or another worktree. No commits, pushes,
PR creation, merge, deployment, scheduler/watch or subdelegation in this unit.
No unrelated source, runtime, landing page, Pages, dependency or lockfile edits.

Read [Phase 1](../spec/phase-1-feasibility.md), [product](../product.md),
[ADR 0006](../decisions/0006-phase-1-evaluation-protocol.md) and the
[feasibility ledger](phase-1-feasibility-ledger.md). ADR 0006 remains **proposed**.
Its paired synthetic tier bounds were retained before generator validation:
32/256/2048 source files across both roots, 1/8/32 MiB UTF-8 aggregate ceilings,
64 KiB/file. Four task families, scope labels, oracle anchors and adversarial
recipes are fixed in authored source. No source execution, extraction/evaluation
process, network API, provider, credential, host/clipboard/configuration, listener,
Docker or package installation is implemented by this experiment.

The [experiment README](../../experiments/evaluation-corpus/README.md) specifies
canonical serialization, digest construction, source/oracle separation and
finite reproduction commands. The committed recipe plus pinned metadata digests
is the compact frozen manifest/oracle representation; builds hold expanded
per-file hashes and oracle facts only in memory. No giant generated snapshots.

## Observed generator facts (not retrieval measurements)

Both projects have equal source counts and distinct fixture-only scope labels:
`harbor-fixture-worktree-1` / `harbor-fixture-revision-1` and
`harbour-fixture-worktree-1` / `harbour-fixture-revision-1`.

| Tier | Total files | Files/project | harbor bytes | harbour bytes | Total bytes | Ceiling |
| --- | --- | --- | --- | --- | --- | --- |
| small | 32 | 16 | 2,076 | 2,088 | 4,164 | 1 MiB |
| medium | 256 | 128 | 16,762 | 16,858 | 33,620 | 8 MiB |
| large | 2,048 | 1,024 | 135,294 | 136,062 | 271,356 | 32 MiB |

Frozen SHA-256 metadata digests (include exact source hashes, oracle and inputs):

```text
small  c497a577eb9699d15da30b02a215784df36bafeafcb643c83c983ba540e6c9e8
medium 624273d696f2be78040bc04a7c8b999b87ad34e84c3cf43de8dcb0d66abf2847
large  7ca4207ef45dc63b7eb6a66cbf16869a29e00210d2a1b4f96b4ff8466b6058df
```

These tiny templates exercise scale in file count, not the full byte ceilings or
real-world diversity. Macro expansion/dynamic calls remain coverage gaps.
Fixed rename/deletion/malformed/interruption/dependency-failure/recovery recipes
are expected future rejection outcomes, **not observed extractor safety**.

## Acceptance mapping and exclusions

| Requirement | Fixture preparation evidence | Still unrun / excluded |
| --- | --- | --- |
| TM-02 | Exact byte hashes and path/line/text anchors, labeled macro/dynamic gaps | Extraction, parser coverage and provenance from real tooling |
| TM-04 | Source budgets, repeated symbols in isolated project scopes, conflicting rules | Retrieval algorithm, comparative arms, ranking and relevance |
| TM-07 | Current/retired distinctions, wrong-revision expectations and explicit unknowns | Observed stale-fact rejection or reduced unsupported claims |
| TM-10 | Original negations/unresolved material permission, no execution APIs | Actual consent/cancellation/host behavior or permission enforcement |
| P1-A5 PARTIAL | Frozen synthetic recipes/manifests/oracle, three bounded tiers | Representative corpus validation, hardware declaration, runner, measurements, inference and independent task outcomes |

Instructions/query/original task text are separate from oracle answers. No
retrieval/scoring implementation exists. Lexical/symbol/candidate-arm, query,
ranking, evidence-unit, duplicate, partial-credit and denominator contracts are
**not_available**. Retrieval, extraction, inference, review effort, host handoff,
executor and task-quality stages are **not_run**, not successful zero-cost runs.
No fake scores, timing or quality/performance claims. Independent runner review
and ADR 0006 containment tests are still mandatory before any worker launch.

## Verification and parent-owned gates

Local checks on the staged implementation are recorded below before handoff.
On the local macOS checkout:

- `python3 -B -m unittest discover -s experiments/evaluation-corpus -v`: **PASS**,
  10 test methods, including repeated builds for all three tiers, exact counts/
  budgets, independent hashes/anchors, scope conflicts and source/oracle
  separation. Negative subcases cover tamper, missing/duplicate/unsorted source,
  malformed/schema/duplicate-key manifests, foreign paths/scopes, invalid
  anchors, oversized files/aggregate, self-consistent refreezing and fresh
  validation after rejection. Authored-module AST inspection checks the narrow
  stdlib import surface and absence of executable-source/file-opening APIs;
  it is not a sandbox or general security proof.
- `python3 scripts/check.py`: **PASS**, format/build/Clippy, workspace tests,
  rustdoc, finite foundation diagnostics, local links and intentional failing
  assertion gate. These foundation commands do not run corpus extraction.
- `cargo deny --locked check`: **PASS**, advisories/bans/licenses/sources.
- `python3 scripts/secrets.py` after staging all five new files: **PASS**;
  synthetic sentinel rejected as intended.
- `git diff --cached --check`: **PASS**.

No Linux run is claimed locally; Linux/macOS CI remains parent-owned. No
generated corpus is persisted, and the incidental owned Python bytecode cache
was removed. No Docker resources were created.

The added path-scoped, read-only GitHub workflow runs only stdlib fixture tests
on `ubuntu-24.04` and `macos-15`, bounded to five minutes, pinned checkout with
persisted credentials disabled. Push triggers only main; PR triggers only scoped
paths, avoiding duplicate branch/PR runs. It installs nothing and launches no
extraction worker. CI platform checkout is not a claim of network isolation.

Parent owns independent review, final full tested implementation SHA, dependent
PR, exact CI run/head, approvals and any later action. The inherited SHA above
is **not** the SHA of these uncommitted changes. Remote CI is **not run** for this
unit. No phase closure or protocol acceptance is implied by local checks.
