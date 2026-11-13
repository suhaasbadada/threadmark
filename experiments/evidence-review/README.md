# Recorded evidence → local review (P1-A4)

Disposable standard-library Python terminal experiment, not a product, AI
refinement, native consent receipt or future host approval authority. It attaches
deterministic source context to this **unchanged fixed synthetic request**:

> Locate normalize and its direct callers in the selected project. Do not modify files, send messages or execute tools.

```sh
python3 -B experiments/evidence-review/cli.py
python3 -B experiments/evidence-review/cli.py --synthetic orbit
python3 -B -W error::ResourceWarning experiments/evidence-review/test_review.py
```

No arguments/help reads no evidence and does not wait for input. Explicit
`--synthetic orbit|orbit-next` displays recorded definition and direct-call rows
from the actual retained Graphify baseline. `show`, `project orbit|orbit-next`,
`review`, `cancel`, `stale`, `restore`, `unavailable`, `recover`, `help`, `quit`
are the only commands. There are no query, source-path, command, plugin, pin or
manual-edit inputs. Review re-reads the fixed artifact and fixed original sources,
checks their bytes and exact displayed draft equality, then marks only local
review. Nothing is copied, sent or executed. Cancellation/EOF/quit/limits returns
only the original, with no approved draft. Unknown commands reject without echo
and invalidate review. Every context change invalidates review; restore/recover
never restore approval. SIMULATED outage persists across project switches.

## Predeclared bounds and protocol

Before focused tests or walkthroughs: report ≤128 KiB, source bytes ≤64 KiB
combined / ≤16 paths (only two fixed source files per selected project), draft
≤8 KiB UTF-8 inclusive of original and all context. Fixed leaf symlinks rejected;
parent directories trusted under same-UID task authority, not a general filesystem
sandbox. Missing/drifting/invalid data means content-free unavailable, zero
evidence, never last-good fallback. One hardcoded expected artifact SHA is a
consistency check, not authentication. No source execution or upstream extraction.
At most 32 stdin commands, 1024 characters per line including newline; bounded
read, no arbitrary command execution. Each mechanical CLI demonstration has a
10-second external timeout; no child processes/listeners created by the app.

Six fixed scripts, **declared before execution** (all start with `--synthetic
orbit`; literal lines below; EOF follows each):

1. `show\nreview\n` — first project shows actual recorded citations, local review.
2. `review\nproject orbit-next\nshow\nreview\n` — switch clears review, shows
   different actual source, requires new review.
3. `review\nstale\nreview\nrestore\nshow\nreview\n` — simulated stale blocks;
   restore displays unreviewed candidate, explicit re-review required.
4. `review\ncancel\n` — exact original retained, no approved draft.
5. `unavailable\nproject orbit-next\nreview\nrecover\nshow\nreview\n` —
   simulated outage survives switch; recovery alone does not approve.
6. `unknown\n` followed by `help\n` repeated 31 times, then EOF — unknown is
   content-free rejected; command cap cancels. Earlier five EOFs separately
   check fail-closed termination after successful review or blocked state.

Focused tests must pass before these scripts run. Save exact stdin/stdout and
hashes only to the approved private temporary artifact directory. Publish a
content-free summary and observed synthetic citation coordinates/hashes in
[progress](../../docs/progress/phase-1-evidence-review.md). These are mechanical
scripted CLI checks, not actual human consent, usability research, native host
admission, live refresh or inference. No performance/user-benefit claim.

## Evidence limitations

Artifact: `experiments/extraction/scoped-results-v1.json`, SHA-256
`4e3d9e0ceda5352c2f109bd51532a6e9de2ce9af2e4f0ee9d1f53b8b2d5f8afe`.
It is the existing recorded extraction, not rerun here. Only baseline snapshots
and `normalized.query_rows`' two known same-scope questions are used. Current
source-manifest match means bytes match the recorded fixture, **not** Git/daemon
freshness. Scope IDs are synthetic, not authenticated. LIMITED_STATIC omits
semantic closure, macros and runtime proof; definition anchors may contain only
a signature (the Python body is not claimed as returned evidence). Rust
definition rows expose trim vs lowercase directly. Missing node confidence is
displayed as “not supplied”; call confidence is the actual recorded value.
No project prose becomes a permission rule. Original constraints remain exact.
Native host remains paused; no clipboard/send/composer placement, T3 mutation,
inference, network, provider, storage or runtime installation capability.
