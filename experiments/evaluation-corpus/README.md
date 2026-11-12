# Offline synthetic evaluation corpus

Phase 1 fixture preparation only: TM-02/04/07/10; **P1-A5 PARTIAL**.
[ADR 0006](../../docs/decisions/0006-phase-1-evaluation-protocol.md) remains
**proposed**, not accepted by this implementation. No Phase 2 indexer or runner.
All source bytes are authored public-synthetic-only Rust, Python and Markdown;
no external repository, library, private source or downloaded corpus is used.

From the repository root, using Python 3.10+ and its standard library only:

```sh
python3 -B -m unittest discover -s experiments/evaluation-corpus -v
python3 -B experiments/evaluation-corpus/corpus.py --check small
python3 -B experiments/evaluation-corpus/corpus.py --check medium
python3 -B experiments/evaluation-corpus/corpus.py --check large
```

The finite CLI prints only the validated tier digest. It cannot load a path,
export, launch a worker, or execute generated source. `build(tier)` returns a
frozen `Corpus`: sorted `(relative_path, bytes)` source pairs and three separate
canonical JSON byte strings (`manifest`, `inputs`, `oracle`). `validate(candidate)`
returns the digest or raises `ValueError`, without mutating or persisting state.
It accepts only the exact versioned recipe, not arbitrary valid repositories.
Do not import or execute generated source. No disk corpus snapshots are needed.

## Frozen contract

Schema/generator/templates version 1 uses similarly named `harbor` / `harbour`,
each with independent fixture worktree/revision labels. These labels are neither
credentials nor real Git facts. Counts total **both** source roots: 32/256/2048;
UTF-8 aggregate caps are 1/8/32 MiB and each source is at most 64 KiB. Metadata,
instructions, queries and oracle are outside source inputs. Templates vary
Rust/Python definitions and direct calls, scoped audit decisions, retired rules,
negations, macro expansion and dynamic-call gaps. They are deliberately compact,
not filler or evidence of real-repository representativeness.

Canonical serialization is ASCII JSON with sorted keys, compact separators,
ASCII escapes, no NaN and no trailing newline. SHA-256 covers exact source bytes;
the overall digest covers the manifest **without** its `digest` field, including
oracle/input hashes. The source recipe and three freeze pins in `corpus.py`
reconstruct the complete frozen per-file manifest and anchored oracle; a changed
recipe requires reviewed version/pin changes. No generated output is hand-edited.
No timestamps, host paths or random identities participate.

Validation checks counts, strict normalized project-scoped POSIX path grammar,
uniqueness, byte/file/aggregate caps and exact oracle line text, then compares the
entire candidate to the fixed recipe and pinned digest. Thus altered scope,
schema, order, metadata, hashes, conflicts or even self-consistent refreezing is
rejected. There is no filesystem interface or symlink resolution; path-like
symlink encodings are invalid names, not followed links. No hostile-input
resource-containment claim is made for the in-process Python API.

## Answers are not query inputs

Only `sources` are future source inputs; `inputs` holds scoped instructions,
queries and original task constraints. Never supply `oracle` or `manifest` to a
retrieval arm: they contain answers/answer hashes. The oracle holds evidence
kinds with exact path/line/text/scope, cross-root conflicts, expected unknowns,
and **fixed recipes**, not observed extraction outcomes. Four task families are
declared for both projects in every tier: definition/direct-call;
conflicting/stale/wrong-revision rules; original negations/unresolved permission;
rename/delete/malformed/interruption/recovery. Failure recipes include dependency
unavailability. Nothing authorizes a send, deploy, inference or live execution.

Tests observe only generator/validator determinism, integrity and fail-closed
candidate validation. Fresh validation after a bad candidate leaves good values
unchanged; it does not demonstrate extractor recovery, cancellation, deletion
handling or containment. Macro-generated symbols and dynamic calls are unknown.

Retrieval/extraction, inference, hosts, live executor and task-quality evaluation
are **NOT RUN**. Comparative arms, queries, ranking, evidence-unit matching,
duplicates, partial credit and denominators are **NOT AVAILABLE**; no scoring or
quality/performance numbers are produced. ADR 0006's separate runner review and
containment gates still precede any evaluation-worker launch. CI merely tests
inert bytes on Linux/macOS, without installation, extraction or API egress
(platform checkout itself still uses GitHub infrastructure).

See the [progress and verification record](../../docs/progress/phase-1-evaluation-corpus.md).
