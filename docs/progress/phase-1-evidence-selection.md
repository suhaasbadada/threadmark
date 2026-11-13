# Phase 1 — Prospective bounded evidence-assisted draft

**TM-02/04/07/10; P1-A1/P1-A5 PARTIAL. Phase 1 OPEN.**
Bob implemented a separate selection feasibility unit in the assigned existing
worktree. Inherited/tested base HEAD:
`dc772948beb2b6e6d95501e61739ca5dbd96052b`, plus the uncommitted files listed
below. No commit/push/PR/branch switch/new worktree/delegation. The two existing
unstaged native-host and retrieval-pilot progress appends remain untouched.

## Decision and authored implementation

[ADR 0008](../decisions/0008-bounded-evidence-selection.md) declines adopting the
old candidate as default or claiming graph benefit from its declaration-only
pilot result. It proposes `evidence-selection/1` for explicit bounded
declaration/direct-caller requests only. The [module and runnable CLI](../../experiments/evidence-selection/README.md)
use the existing reviewed **public** `directcall.extract` over all selected
sources. Core-owned static facts retain their semantics and declared limitations.
Separate ordered groups alternate definition/call lines with duplicate skipping
and exhausted-group spill; at most eight whole anchored lines. No parser copy,
oracle input, intent classifier, ranking override or dynamic caller loading.

The complete envelope includes exact original task/instructions, scope/path list,
requested/available/selected categories, anchored text and full extractor coverage.
Whole-envelope 8192-byte and original-object 4096-byte limits reject overflow,
never truncate or choose cheaper evidence. Caller-supplied scope labels are not
independent Git verification, authorization or freshness proof. Omitted sources
and stale bytes relabelled current cannot be detected by this API.

Policy, exclusions, README, ADR and holdout tests were authored **before** the
actual two CLI demonstrations. Twenty independent-name holdout tests passed first,
alongside 79 existing extractor tests. An initial test expected three unresolved
calls where the extractor correctly reports four (`globals()` is itself another
unresolved call); only that test expectation was corrected before demonstrations.
No policy adjustment followed the demonstrations.

Initial authored source SHA-256, before the readable CLI follow-up below:

- `selection.py`: `ce8f71abcfee7f8b27b198dc52cd6f91761660d6cb2f43770ed5fb8b06b5ff08`.
- `test_selection.py`: `2b35b9552cb3381b6afbb819130687469e8fca44df2342cd9ce55e1076fd8ad8`.
- ADR 0008: `85852029f4cd9d84c4159e62fb944419926c65ef07042da49407f5306b38e21e`.

## Initial JSON demonstrations (historical CLI default)

Exact commands, each run once after the successful tests:

```sh
python3 -B experiments/evidence-selection/selection.py --synthetic harbor
python3 -B experiments/evidence-selection/selection.py --synthetic harbour
```

Both exited zero. Their actual stdout was retained in a newly owned mode-0700
directory under the approved private temporary area, not in public evidence.
Hashes below cover complete stdout including its one terminal LF:

| Synthetic project | Canonical envelope bytes | Stdout SHA-256 |
| --- | --- | --- |
| harbor | 7679 | `6c7e1f8dbc827400cf6c8222b5934e5f2abff7059fb8861998a99f07bf148696` |
| harbour | 7749 | `a0b79443299b9e2d6bc92ba0cfb730b355e2cd74918d27a0a5b4dbd676827be7` |

Actual ORIGINAL REQUEST, both roots:
“Locate resolve and its direct callers in this scope.”

Actual unchanged instructions:
“Use selected scope only. Preserve original constraints; ask about unresolved
material permission. No execution authorization.”

Actual policy `evidence-selection/1`; each selected project has its exact original
`<project>-fixture-worktree-1` / `<project>-fixture-revision-1` labels. Each draft
offers eight unique whole lines: four definitions and four direct-call lines;
eight definition and eight call lines were available before selection. These are
category counts, **not precision/recall or comparative quality scores**.

The actual ordered draft evidence below uses `P=harbor` or `P=harbour` separately;
the CLI prints each full concrete path, not this abbreviation:

| Citation | Category | Exact text |
| --- | --- | --- |
| `P/src/unit_0000.rs:2` | definition | `pub fn resolve() -> u32 { 0 }` |
| `P/src/unit_0000.rs:3` | direct_call | `pub fn entry() -> u32 { resolve() }` |
| `P/src/unit_0001.py:2` | definition | `def resolve():` |
| `P/src/unit_0001.py:5` | direct_call | `    return resolve()` |
| `P/src/unit_0004.rs:2` | definition | `pub fn resolve() -> u32 { 4 }` |
| `P/src/unit_0004.rs:3` | direct_call | `pub fn entry() -> u32 { resolve() }` |
| `P/src/unit_0005.py:2` | definition | `def resolve():` |
| `P/src/unit_0005.py:5` | direct_call | `    return resolve()` |

Both retain all 16 per-file extractor observations. Actual gap labels:
`aliases_macros_cfg_generics_types_dynamic_dispatch_not_resolved`,
`balanced_subset_not_rust_syntax_certification`,
`macro_may_introduce_bindings_scope_poisoned`, `markdown_validated_no_symbols`,
`standalone_file_no_crate_graph`, `static_not_runtime_binding_truth`.
Unresolved reasons remain `no_static_binding` and `non_bare_or_non_ascii_callee`.
The output explicitly says partial evidence selection, not a full graph, AI
refinement, execution or send authorization. It never copies or sends the draft.

## Verification and handoff gates

- `python3 -B -m unittest discover -s experiments/evidence-selection -v`:
  **20 PASS**, including real Python/Rust calls, crowded/sparse/empty groups,
  duplicate/shared lines, recursion/dynamic gaps, original query order, UTF-8
  path determinism/canonical input ordering, scope/foreign/malformed rejection,
  dependency failure/fresh recovery, exact original negations, inclusive budgets
  and no-effects CLI defaults/invalid task rejection.
- `python3 -B -m unittest discover -s experiments/evaluation-directcall -q`:
  **79 PASS**. Existing extraction semantics/pins are untouched.
- `python3 -B scripts/check.py docs`: **PASS**.
- `cargo deny --offline --locked check`: **PASS** (cached advisories; no freshness
  claim or network refresh).
- `python3 -B scripts/secrets.py` after staging the five owned new files:
  **PASS**, including tracked/history scans and intentional synthetic rejection.
- `git diff --cached --check` and `git diff --check`: **PASS**. Exactly five owned
  new files staged; both inherited progress appends remain unstaged.
- Full `python3 scripts/check.py`: **NOT RUN by child** because it builds and
  executes generated assertion-probe source beyond this bounded authorization;
  full integrated foundation and CI remain primary-owned.

No new evaluation worker/18-case study, score, performance comparison or adoption
claim. Frozen corpus, old query/ranking, source pins, candidate/scorer/runner and
stored pilot evidence are unchanged. Future quality/adoption requires separately
preregistered comparisons, independent review and ADR 0006's existing worker
gates. Other lexical/symbol tasks remain separate choices; no final baseline or
Graphify scope decision. Native P1-A2 is still blocked, with launch pause in force.
No host/VM/account/install/network/provider/inference/clipboard/source execution,
service, runtime, generated source or production capability was used or added.
Full committed implementation SHA, independent review, exact CI run/head and
Phase 1 acceptance remain **PENDING primary**; this record does not close a phase.

## Primary review and readable user journey

Joffrey independently reviewed both the selector and primary's readable-format
follow-up: no substantive findings. He verified ordering, shared-line
deduplication/spill, whole-line budgets, extractor-owned fact semantics, scope
limitations and non-adoption claims; 21 selector plus 79 extractor tests passed.

Primary changed only CLI presentation after the initial JSON demonstrations:
default output now has separate ORIGINAL REQUEST, INSTRUCTIONS, cited EVIDENCE
and STATIC COVERAGE sections. `--json` retains the complete canonical envelope,
including unresolved spans. Readable output separately rejects above 8192 bytes
without truncation; one terminal LF is outside either representation. This does
not rewrite the task, change selection policy or authorize a send.

Two authorized readable CLI demonstrations ran once per project after tests and
independent review, exited zero with empty stderr, and retained actual output
privately. The original JSON demonstrations' bytes were formatted with the new
pure renderer and matched these new CLI outputs exactly: no anchor, task,
instructions, category or canonical-envelope change.

| Project | Readable stdout bytes including LF | SHA-256 |
| --- | --- | --- |
| harbor | 3921 | `ac2b042812650885d1fd963eded13cb4ed6ddc49d883ad6aa20c6be453dcc512` |
| harbour | 3948 | `92f7c358721c2f99cf22c32de4a6b2cdbd6f6e496d3adbf21fb703572a207a40` |

Current reviewed source SHA-256:

- `selection.py`: `434366de867d8ddca5838909aa0a42299073fa356e1003a8277d6bf4ffd4d20a`.
- `test_selection.py`: `fa87bc49a39c9a9bff2d6f59d79114c053c75603234f3bd1eddad5bfa3eb91e0`.

The user-visible outcome is a runnable synthetic evidence draft containing both
definitions and callers with exact citations and preserved constraints, not an
AI-refined prompt or a host admission. No study, quality score or adoption claim
was added. Future measured comparisons remain prospective; native-host launches
are still paused. PR #32's separate post-merge CI `43404051948` and integrated
`43404051703` passed on `993d5f2ee49b59cd6bfa24f3bc2386e459e17db1`; they do not
validate this unit's new files. Current exact-head CI is still a separate gate.
