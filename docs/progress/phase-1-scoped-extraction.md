# Phase 1 — Prospective scoped static extraction

**Status: bounded actual six-case experiment passed; Phase 1 OPEN.**
TM-02/TM-04/TM-07/TM-10; P1-A1 and extraction-only P1-A5 partial, under
[ADR 0009](../decisions/0009-scoped-static-extraction.md).

## Revision and evidence boundary

Base HEAD `04de3eb6d90effc8feb280edd930ddf62540ae73` plus this uncommitted unit;
no final tested commit exists. Parent supplied merged PR #33 revision
`d68e7b8e1962af128dc2f4bd4ae39cb0fbf170ce` with equivalent content, post-merge
CI `43409251027` / integrated `43409251029` passing at that exact merge. Not
reverified by this child and **not CI evidence for these new files**. No commit,
push, PR, review acceptance or remote CI for this prototype. Primary owns those
gates. Existing unstaged progress appends in the native OpenCode, retrieval-pilot
and evidence-selection records were not modified or staged by this unit.

## Initial implementation snapshot (before primary review/run)

- Separate pure stdlib scoped-static-v1 normalizer and opt-in six-case CLI;
  historical run/validator/results remain unchanged. Whole-candidate rejection,
  relative content-backed anchors, scope/content-sensitive IDs, retained raw IDs,
  unchanged confidence and explicit LIMITED_STATIC coverage.
- Python stdlib syntax check; pinned Rust parser preflight behind the explicit
  worker path. The actual Graphify API and Rust parser constructor were checked
  by read-only installed-source/stub inspection, **not imported or invoked**.
- Actual API wrapper reuses the existing retained process owner with unchanged
  budgets. Each prospective case gets fresh isolated copies/caches/environment;
  private diagnostic streams survive cleanup. No persistence or fallback.
- Two exact fixture question rows return source excerpts/citations and IDs, not
  a ranking study, inventory-only receipt, semantic certainty or adopted engine.

Offline tests normalize **historical recorded replies**, exercise rejection and
fresh pure-function recovery, deterministic reordered IDs, changed scope/content,
anchor integrity, confidence preservation and scope mismatch. Mocked native/API
tests verify parser error, dependency failure, malformed Python before native
imports, cancellation propagation and case cleanup/budget wiring. Only stdlib
Python `ast.parse` actually parses source here; fixtures are never executed.
These tests are **not new actual Graphify or native-parser evidence**.

## Local verification for this uncommitted unit

- `python3 -B -W error::ResourceWarning experiments/extraction/test_normalized.py`:
  19 tests passed (including rejection matrices); no Graphify/native imports.
- `python3 -B experiments/extraction/scoped_run.py --help`: passed; no workers.
- `python3 scripts/check.py docs`: passed.
- `cargo deny --locked --offline check`: passed against cached Rust advisory
  data; not a Python dependency audit or fresh online advisory check.
- Full foundation/source-execution checks and existing bounded lifecycle tests
  are primary-owned and **not run by this child**. An initial new-test attempt
  exposed an unclosed list in the new CLI; repaired before the passing run.
- After staging only the six owned files, `python3 scripts/secrets.py` passed
  (tracked/staged scan and synthetic negative probe), as did
  `git diff --cached --check`. No CI/workflow changes were made by this child.

## Primary execution gate and exact command

After meaningful independent review and the existing lifecycle tests pass, use
the already installed pinned interpreter from the worktree root. Choose a new
private diagnostic directory under the approved session temporary location:

```sh
python3 -B -W error::ResourceWarning experiments/extraction/test_harness.py
python3 -B -W error::ResourceWarning experiments/extraction/test_normalized.py
python3 -B experiments/extraction/scoped_run.py --run-six \
  --private-diagnostics "$TMPDIR/threadmark-scoped-private-unique" \
  > experiments/extraction/scoped-results-v1.json
```

The report filename is prospective and does not yet exist. Run the six cases
once after prerequisites, inspect actual status/citations, and retain failures
rather than relabeling them as success. Bind resulting evidence and review to
the final exact SHA/CI separately. Do not claim the malformed case exercised
Graphify if preflight reports NOT_RUN. CLI default/help performs no extraction.
No additional workers are needed for revision changes: offline tests cover them.

## Acceptance and remaining limits

P1-A1: implemented rejection/identity boundary; new actual six-case behavior
**NOT RUN**. Historical engine completeness/collision defects remain upstream.
P1-A5: prospective protocol/caps/output declared before actual execution; tiny
public synthetic fixtures only, no representative comparative-quality evidence.
Graphify adoption deferred; no full license closure/redistribution approval,
new inference, host/auth boundary, runtime, site changes or Phase 1 closure.

## Primary review and bounded execution decision

Joffrey independently reviewed the meaningful change and found a P2 coordinate
defect: Python `splitlines()` splits embedded Unicode separators that Graphify's
tree-sitter rows do not. A valid Python string could shift the cited excerpt.
Primary replaced both manifest counting and anchor slicing with one LF-row
splitter, normalizing only CRLF and omitting the terminal empty split segment.
Regression tests cover U+2028/U+2029/U+0085 inside valid Python strings, CRLF,
bare CR preservation, empty input and trailing newlines. No parser or graph policy
was broadened. Corrected **21 normalization tests** and **20 existing lifecycle
tests** passed; the latter includes actual cancellation/ownership cleanup.

No additional substantive API/ownership/output-scope problems were identified by
review. Primary authorizes **one** invocation of the already-declared six-case
experiment on these corrected sources, under the unchanged installed-package and
process bounds. This is trusted local structural-only execution, not a new native
host/trust boundary, provider permission or redistribution approval. Preserve any
failure and stop rather than retry/widen. The earlier CLOSED execution decision
was the pre-review state; actual outcome is recorded separately below.

## Actual pinned Graphify and parser observations

One authorized invocation of `scoped_run.py --run-six` exited zero with empty
parent stderr. The new [synthetic report](../../experiments/extraction/scoped-results-v1.json)
was created separately; historical `results.json` was neither overwritten nor
reclassified. macOS 27.0.1 arm64, Python 3.12.6. Each worker checked installed
metadata for graphifyy 0.9.101, tree-sitter 0.25.2, tree-sitter-python 0.25.0 and
tree-sitter-rust 0.24.2; four valid workers actually invoked the native Rust syntax
parser and Graphify AST API. These are installed-version observations, not package
integrity attestations or redistribution approval.

| Project | Case | Actual outcome | Admitted nodes | Graphify |
| --- | --- | --- | --- | --- |
| orbit | baseline | accepted, LIMITED_STATIC | 9 | returned |
| orbit | malformed | rejected at Python syntax preflight | 0 | NOT_RUN |
| orbit | recovery | accepted, identical baseline snapshot | 9 | returned |
| orbit-next | baseline | accepted, LIMITED_STATIC | 7 | returned |
| orbit-next | malformed | rejected at Python syntax preflight | 0 | NOT_RUN |
| orbit-next | recovery | accepted, identical baseline snapshot | 7 | returned |

Seven upstream IDs still overlap between the two valid roots, including
`lib_normalize` and `service_normalize`. Their normalized node ID sets are
disjoint; every edge endpoint belongs to its own snapshot. This fixes the
experimental **boundary**, not the producer's IDs or known malformed-source
completeness defect. Bad cases never imported Graphify or the native Rust parser;
do not call them new observations of Graphify parsing malformed input.

Each valid snapshot returns two definition rows (`lib.rs:2`, `service.py:4`) and
two direct-caller rows (`lib.rs:3`, `service.py:9`) with source-backed excerpts,
namespaced identities and original confidence. For example, `orbit` returns
`pub fn submit(value: &str) -> &str { normalize(value) }` at `lib.rs:3`, while
`orbit-next` returns its distinct `String` signature. No scope merge, graph
advantage, permission inference or runtime execution truth is asserted.

Both fresh recoveries exactly reproduced their own baseline normalized snapshot;
there is no persisted last-good state, watcher or incremental recovery claim.
All six bounded workers returned through the existing retained owner; their
temporary source/cache/HOME trees were removed. Twelve private stdout/stderr
streams were retained, including expected syntax-failure diagnostics. Final
owned-directory `lsof` found zero processes with those files open. No host,
listener, configuration, credential, provider, network or fixture execution was
requested, and no installation or retry followed the successful sequence.

Exact SHA-256 evidence:

- `normalized.py`: `8986493fd5ce448772d8eccd91956f8fcb811b4782f9b53916fcb2df58ccfd2a`.
- `scoped_run.py`: `96c3779a2ad0ed9f5cd025fb6e5ac34caae603e40ba9fddb9823194806b2adb1`.
- Corrected tests: `1693d47aafcb2ce38bba6385e004f9f6495eb291242629dfa93e1e7f8df179af`.
- New public synthetic report: `4e3d9e0ceda5352c2f109bd51532a6e9de2ce9af2e4f0ee9d1f53b8b2d5f8afe`.
- Private diagnostic/cleanup manifest: `c9a338be8bc5520e170231a39c826ccb45db90b74b285b9efbd1f0a3af355a7c`.

Primary checked public output for private filesystem paths/credentials, uniqueness,
endpoint closure, actual query citations and baseline/recovery identity. Output
contains only the authored public synthetic sources. The recorded seconds include
worker/interpreter/parsing/serialization overhead; no benchmark or latency target
is inferred. Full source/phase verification and exact-head CI follow separately.
