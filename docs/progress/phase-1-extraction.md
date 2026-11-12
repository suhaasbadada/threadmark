# Phase 1 — Bounded extraction feasibility

**Status: partial experiment; Phase 1 remains OPEN.** Bob implementation unit:
TM-02/TM-04/TM-07/TM-10, P1-A1 and extraction portion of P1-A5. No product,
storage, listener, adapter, shell, inference or host support implemented.

## Revision and gates

### Parent finalization update

Foundation PR #1 is now merged at
`42b3c764e3685e7d3d061c0fdd5f1d5ef804acd6`; its main-branch CI run
`43182751442` passed. The historical delegate snapshot below predates that merge.
The owner authorized merging foundation/site PRs #1/#2 and publishing the site,
**not automatic merging of this future extraction PR**. Phase 1 remains open.

Joffrey independently reviewed this experiment and found that real SIGTERM
cancellation could bypass cleanup. The parent added a controlled cancellation
exception and actual-SIGTERM regression checking child reaping and temporary
directory removal. An initial repair using `InterruptedError` failed because
selectors swallow interrupted system-call errors; a distinct exception fixed
the regression. The failed test's exact empty temporary directory was removed;
subsequent test cleanup is fail-safe. Eight stdlib harness tests now pass.
The new standalone `Extraction experiment harness` CI workflow runs these tests
on Linux/macOS without Graphify, packages or provider access. The optional actual
extraction experiment remains outside default runtime/foundation commands.

### Delegate implementation snapshot

Assigned branch `t3/phase-1-extraction-feasibility`; worktree basename
`t3-272fc060-e7ab553ef99d6dcc`. Tested foundation HEAD:
`984703bfd73d5178a1748898bd95c97619d50438` **plus uncommitted files in this unit**.
There is no committed/tested extraction SHA yet; parent owns finalization and
independent review. Parent supplied foundation exact-head CI run `43181565931`,
all three jobs passed; not reverified here and not evidence for these edits.
Foundation PR 1 remains unmerged. This unit has no PR, remote CI, review acceptance,
merge, publication or deployment. None authorized.

## Reproduction and capability

Read [ADR 0002](../decisions/0002-extraction-feasibility.md) for limits declared
before extraction. From the repository root, with the **already installed**
release available to that interpreter:

```sh
python3 -B experiments/extraction/test_harness.py
python3 -B experiments/extraction/run.py --run > extraction-local.json
python3 scripts/check.py
cargo deny --locked check
python3 scripts/secrets.py
```

The last command scans tracked/staged files: stage new files first. The optional
experiment is not called by foundation CI, Cargo, or `scripts/check.py`.
No installation command is supplied or executed. Missing distributions, wrong
metadata, missing dependencies or worker failure cause nonzero exit, not a skip.
Reproduction output is synthetic but should still be reviewed before publishing.

Capability: **prototyped only**, local macOS Darwin arm64, Python 3.12.6,
graphifyy 0.9.101. AST library API inspected in installed `graphify/extract.py`,
lines 9811–9859: explicit `paths`, `root`, separate `cache_root`, `parallel=False`,
`max_workers=1`. No CLI pipeline, build, clustering, watch, semantic agent,
provider, model download or credentials. The API can emit `INFERRED` structural
resolution edges according to its docstring; these fixtures emitted only
`EXTRACTED`. Real inference/provider labeling remains **UNTESTED**.

Recorded parser dependencies: tree-sitter 0.25.2, tree-sitter-python 0.25.0,
tree-sitter-rust 0.24.2. Other declared installed base dependencies observed:
networkx 3.6.1, numpy 2.5.1, rapidfuzz 3.14.6, PyYAML 6.0.3. Distribution metadata
also requires many other language parsers (JS/TS, Go, Java, Groovy, C/C++, Ruby,
C#, Kotlin, Scala, PHP, Swift, Lua, Zig, PowerShell, Elixir, Objective-C, Julia,
Verilog, Fortran, Bash, JSON) and conditional tomli below Python 3.11. Optional
extras include MCP, databases, media, inference backends and other parsers. These
were not exercised, locked or audited as a redistribution dependency closure.
This is a release pin/metadata check, **not** a reproducible Python dependency
lock or package integrity attestation. No Python dependency added to runtime.

## License evidence — inspected installed release, not metadata alone

Installed distribution contains Apache 2.0 `LICENSE`, legacy `LICENSE-MIT`, and
`NOTICE`. Inspected full license texts and NOTICE. NOTICE attributes Copyright
2026 Safi Shamsi and Graphify contributors; says Apache 2.0 applies, with prior
MIT contributions retained under those terms. Apache section 4 requires license,
change notices where applicable, attribution and NOTICE preservation on relevant
redistribution; MIT requires preservation of its notice. Metadata expression
`Apache-2.0` alone is insufficient. Installed text SHA-256 evidence:

| File | SHA-256 |
| --- | --- |
| LICENSE | `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` |
| LICENSE-MIT | `36ecff6bbb97aca1be64e95f42538cf796adde5864edac583e620643c096931a` |
| NOTICE | `3448ea175bba09f6fed8a743000139fb4c7112de83f164355b5540b158576621` |

No upstream code/binary is copied into this unit. This supports investigation,
not legal approval, supply-chain provenance or installer approval. Full transitive
license/notice audit, artifact verification and packaging remain blockers before
redistribution. Threadmark's own license is unchanged.

## Corpus, protocol and observations

Two tiny synthetic projects (`orbit`, `orbit-next`), each initially one Rust and
one Python file, deliberately repeat function names but conflict on retention
(seven versus thirty days). No Git repository creation or source execution.
The Rust fixture adds a macro-generated function; Python adds a dynamic callback.
Each extraction runs in a fresh process, sequentially, with project-specific
temporary cache. "Cold" means empty Graphify cache, **not** cold OS disk/page
cache. "Warm" reuses that cache but not the Python process. Renaming and deleting
are performed only on copied fixtures. Added malformed `broken.py` after deletion
to probe parser tolerance; no limits changed. One initial run exposed an uncaught
SyntaxError in the stdlib baseline, fixed to record an explicit error; that failed
attempt is not counted as a successful fixture run.

Durable full synthetic payloads, baselines, coverage arrays, timings and dependency
metadata: [results.json](../../experiments/extraction/results.json). Temporary
absolute paths from Graphify's coverage arrays are normalized relative to the
fixture root before emission; out-of-root coverage paths fail. This transform
does not alter node IDs, edges or anchors. Measurements below are the recorded
successful ten-invocation run, not a broad performance benchmark:

| Project / stage | Seconds | Nodes / edges | Worker peak RSS bytes |
| --- | --- | --- | --- |
| orbit cold | 0.2411 | 9 / 9 | 51232768 |
| orbit warm | 0.2573 | 9 / 9 | 50528256 |
| orbit renamed | 0.2580 | 9 / 9 | 50413568 |
| orbit deleted | 0.2651 | 4 / 4 | 50528256 |
| orbit damaged | 0.2580 | 5 / 4 | 50479104 |
| orbit-next cold | 0.2570 | 7 / 7 | 50987008 |
| orbit-next warm | 0.2505 | 7 / 7 | 50561024 |
| orbit-next renamed | 0.2578 | 7 / 7 | 50167808 |
| orbit-next deleted | 0.2408 | 3 / 3 | 49872896 |
| orbit-next damaged | 0.2462 | 4 / 3 | 50151424 |

Elapsed includes interpreter/import/serialization overhead, excludes baseline and
admission work. RSS is worker `getrusage` maximum, bytes on this Darwin host (not
portable units; Linux reports KiB). All observed runs below provisional bounds;
memory is measured, **not enforced**. No cost estimate beyond zero provider calls
and API-reported zero input/output tokens. No inference-time, host-handoff,
review-effort, p95, scalability, throughput or user-value result is claimed.

### Structural facts and retrieval comparison

| Declared question | Graph observation | Lexical / symbol baseline |
| --- | --- | --- |
| Where is normalize defined? | `service_normalize` at service.py L4; `lib_normalize` at lib.rs L2, both `_origin=ast` | Substring returns definitions plus call sites (four lines); AST/regex symbol map directly locates both definitions. No demonstrated graph advantage. |
| What directly calls normalize? | `service_submit → service_normalize`, `calls`, service.py L9; `lib_submit → lib_normalize`, lib.rs L3; EXTRACTED | Lexical returns the call lines but requires enclosing-function reading. Declaration-only map lists functions, not call edges. Graph encodes useful direction explicitly; no timed retrieval or task-success improvement measured. |
| Which retention rule applies? | Python docstring rationale node anchored L1, `rationale_for → service`. Distinct seven/thirty-day text when roots kept separate; no authoritative policy classification. Rust comment not a policy node. | Searching retention text in each selected root reveals both rules. A symbol map alone cannot answer. Graph does not resolve conflicts or authenticate scope. |
| Does a deleted Python definition survive? | Fresh full extraction of remaining files returns only Rust nodes; warm graph exactly equals cold graph before mutation. Renaming changes `service_*` to `renamed_*`, Rust IDs unchanged. | Current-files lexical/symbol scan also drops deleted definitions. Neither proves durable importer cleanup or filesystem-watcher recovery. |

Graph IDs `lib_normalize` and `service_normalize` collide between projects: IDs
are not globally unique, revision identity or authorization. The worker envelope's
scope is supplied by this harness, **not authenticated by Graphify**. Input lists
are separate; no automatic cross-project merge is attempted. Full rename lineage,
same-process extraction and incremental merge/deletion were not tested. Old cache
entries may remain inside the temporary cache until cleanup; no secure erasure.

Dynamic callback target is not resolved; Rust `generated!` macro is captured but
expanded `hidden()` is absent as a standalone definition (the regex baseline can
see its text). No compiler/type checker, macro expansion or runtime truth proof.
Only these Python/Rust constructs were exercised; other languages unsupported by
this evidence, not necessarily unsupported by Graphify.

Retention comparison is manual inspection of the declared fixture text and
returned rationale nodes, not a scored automated retrieval run. Automated
baselines in the artifact record normalize substring hits, declaration symbols
and parse errors. No broad benchmark accuracy score is inferred.

### Rejection probes, failures and recovery

The stdlib test gate checks wrong schema/scope, partial flag, missing manifest,
failed source, missing coverage, empty snapshot, duplicate IDs, foreign paths,
invalid anchor, semantic origin, dangling endpoint, node budget and truncated JSON.
Rejected candidates do not mutate the in-memory last-good fixture; a subsequent
valid fixture is admitted. Synthetic EXTRACTED/INFERRED/AMBIGUOUS edge labels are
preserved; unknown labels rejected. **Synthetic label tests are not inference
evidence.** No transactional persistence or Phase 2 importer is implemented.

Process probes verify timeout, stdout/stderr overflow, synthetic dependency failure,
release mismatch, parent cancellation (KeyboardInterrupt injection and actual
SIGTERM), child reaping
and a fresh successful subprocess after failure. They do not certify canceling a
real provider request or an adversarial process. Output is capped while reading,
not after unbounded `communicate()`. POSIX process groups are killed/reaped in
`finally`, even on cancellation. Only a clean environment allowlist is passed;
no ambient credential values are read or printed. Python `-I -B` ignores Python
environment/user-site and avoids bytecode writes. Installed system-site packages
are still trusted code. No enforced network/filesystem sandbox or hard RSS/CPU
limit; source review + restricted entry point are not containment certification.

**Counterexample:** malformed `def broken(` produces a `broken` file node, empty
failure arrays and extracted-source coverage. It is accepted by this schema gate,
while stdlib AST records SyntaxError. Thus completion/coverage metadata alone is
insufficient to claim syntactic completeness. Add parser-error/coverage semantics
or reject known-invalid inputs before product adoption; do not label this gate
"safe on all partial output." Anchor existence/end-line, duplicate JSON keys,
all graph field types, content hashes/revision binding, hostile oversized source,
symlinks and adversarial descendant behavior need stronger future validation.

Temporary HOME/cache/source copies and subprocesses are experiment-owned and
cleaned on normal/failure exits and ordinary handled SIGTERM cancellation. No global settings, installations, Docker,
background service, reminder or watch created. Abrupt SIGKILL/host crash cleanup
is not guaranteed. Kept artifacts are only code/fixtures/docs and synthetic results;
no runtime cache is retained in the repository.

## Decision and acceptance ledger

**Decision: defer production adoption; continue only as a replaceable extraction
candidate.** Direct-call/provenance facts justify further investigation, not a
dependency commitment. Named blockers: syntax/partial coverage ambiguity;
unverified inference labeling/provider budgets; durable scope/revision identity
and rename/deletion reconciliation; representative language quality; transitive
license/artifact packaging review; demonstrated containment and hard resource
limits. Lexical/symbol retrieval remains a credible simpler baseline.

| Acceptance | State / remaining gate |
| --- | --- |
| P1-A1 structural facts / provenance / IDs | Demonstrated only on declared tiny synthetic Python/Rust fixtures. |
| P1-A1 partial/invalid safety | Partial: explicit malformed envelope rejection/recovery demonstrated; parser-tolerated malformed source remains an open counterexample. |
| P1-A1 inference and adoption | Inference UNTESTED (no egress authorization). Adoption deferred with named blockers; P1-A1 **not complete**. |
| P1-A5 extraction record / budgets / ADR | Partial: pinned local capability, two tiny projects, predeclared bounds, baseline comparisons and ADR. Medium/large corpus, representative tasks and packaging not verified. |
| P1-A2 / A3 / A4 and non-extraction A5 | Excluded; parent/other units own host contracts and UX. |

## Local verification

Passed locally on foundation HEAD plus this uncommitted unit:

- `python3 scripts/check.py`: formatting, locked build, warning-denied Clippy,
  2 Rust unit tests, 8 integration tests, 1 doctest, rustdoc, finite diagnostics,
  local Markdown links and intentional assertion-failure probe passed.
- `cargo deny --locked check`: advisories, bans, licenses and sources passed
  for the existing Rust workspace, **not the optional Python dependency tree**.
- `python3 -B experiments/extraction/test_harness.py`: 7 stdlib tests (including
  subtest rejection matrices and recorded evidence consistency) passed.
- Optional Graphify experiment: ten recorded successful bounded invocations;
  malformed-source completeness counterexample remains open, not waived.

- `python3 scripts/secrets.py`, after staging all ten unit files: tracked/staged
  scan and history scan passed; synthetic secret negative probe correctly failed.
- `git diff --cached --check`: passed. Only the ten new unit files are staged;
  no foundation, workflow, landing-site or lockfile edits. No commits or pushes.

Parent must bind independent review and exact-head CI to its eventual commit.
These local checks cannot close Phase 1.
