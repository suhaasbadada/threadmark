# Human knowledge search — narrow Lane C contract and evidence

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A1/A2/A3/A4/A5/A6.
Owner: implementation delegate, with primary responsible for review/integration.
Base: reviewed main `530fe81c396d6984637fd00bb980bfa034e02478`, merged into
the assigned isolated branch before implementation. No separate worktree or
delegate was created.

## Gap and command contract

Inspection found `Store::query` selects only `evidence` and validates source
content; `contexts` lists metadata and `context` returns a selected history.
None retrieves persisted human text by query. This slice adds only:

```text
threadmark --data-dir EXISTING_PRIVATE_STORE context search PROJECT QUERY
```

Daemon `Command::SearchContext` validates project/query before opening an
existing store and delegates semantics to core `Store::search_context`.
There is no implicit store creation, migration, indexing, source read, inference,
provider call, network egress, host delivery, or cache. Existing source `query`
and context preparation remain unchanged. Existing context kinds are reused:
`note`, `decision`, `constraint`, `correction`, `pitfall`; no new `rule` kind.

Query must contain non-whitespace text, be at most 256 UTF-8 bytes before trim,
and contain no control characters (including NUL, newline and tab). Leading and
trailing Unicode whitespace is trimmed for matching. Matching is literal substring
over Rust Unicode-lowercased human text/query. No Unicode normalization, token,
symbol, stemming, fuzzy, semantic, source, history, ID or kind search is implied.
Ranking is descending non-overlapping occurrence count, then ascending ID using
Rust string ordering. All admitted latest records are considered, not an arbitrary
matching prefix. No semantic relevance/performance-quality claim follows.

## Output, identity and privacy

Top-level fields: `project`, `root_identity`, `incarnation`, `producer`, `status`,
`authority`, `coverage`, `selection`, `matched_entries`, `omitted_entries`,
`truncated`, `results`. Registration identity scopes **every** returned result;
`incarnation` is null on legacy v1/v2 stores, not an invented registration token.
Local identities are not credentials. No root path, query echo, source hash,
source anchor, snapshot or source-currentness label is emitted.

Each result has `id`, `kind`, `revision`, complete `text`,
`producer="human-authored"`, `status="active"`. Top-level status is
`active-latest-at-read` and authority is
`context-not-authorization-or-observed-truth`. Human authorship is the existing
local manual-write classification, not an authenticated author identity or
verified source provenance. Treat text as untrusted data, never instructions,
permission, verified facts or source evidence. Conflicts are not resolved.

At most 8 entries and 8192 compact JSON bytes **including the CLI newline** are
returned. JSON escaping, metadata and Unicode bytes count toward the envelope.
An overbudget entry is omitted whole; later smaller entries may fit. No text
is silently truncated. `matched_entries` counts all active latest lexical matches;
`omitted_entries = matched_entries - results.length`; `truncated` is exactly
whether any matches were omitted. `selection` declares both envelope limits and
whole-entry omission. Omitted IDs/text are not returned; the counts do not
distinguish entry-cap from byte-cap omissions. An oversized single match can
produce no results with explicit matched/omitted counts and `truncated=true`.

Stdout intentionally exposes sensitive local human text only to the explicit
caller. Errors use the existing content-free CLI failure, never query/note text.
No file export, content logging or automatic handoff is introduced. Earlier
outputs cannot be recalled after an edit or Forget; existing SQLite backup/free
page/journal/display retention limits remain, with no forensic-erasure claim.

## Consistency and boundedness

One SQLite read transaction encloses admitted project metadata, root/identity/
incarnation checks, Forget markers, latest-revision selection and final checks.
The existing private-store admission and healthy-store identity checks are reused.
No source filesystem/root access occurs, even if approved source roots are absent.
This is registration/worktree isolation, **not** source-currentness verification.
No new schema, dependencies, lockfiles or persistent index is introduced.

Only the latest revision per ID is eligible; retired latest revisions suppress
all history. Forget markers suppress the entire ID. Removal/re-registration
returns only new-scope data and its new incarnation. Concurrent writers cannot
publish a mixed pre/post-Forget snapshot. Like other read snapshots, a completed
pre-Forget result cannot be recalled; a later read observes the committed state.
There is no cached-incarnation approval API or external caller authentication.

Existing writer admission caps project history at 4096 revisions and text at
4096 UTF-8 bytes. Search rejects project row-count overflow and malformed latest
records instead of claiming complete coverage of a prefix. It checks cancellation
before storage, at read/publication boundaries and per candidate. SQLite's own
bounded synchronous statement execution is not an interruptible background job.
Database admission remains the existing 128 MiB maximum. No representative latency
benchmark or Phase 1 resource-budget certification is claimed.

## Acceptance evidence and gates

New core tests: `crates/core/src/knowledge/human_search/tests.rs`.
New real-process CLI tests: `crates/cli/tests/human_search.rs`.
All fixtures are synthetic; no Docker or external services are used.

- P2-A1: similarly named projects in different roots isolate conflicting human
  text; stable root identity/incarnation is returned; re-registration changes the
  incarnation and cannot resurrect old text.
- P2-A2 (human slice only): edit changes matching text/kind/revision; superseded
  matching history and retired latest entries are not returned. No source change
  detection or currentness claim is added.
- P2-A3: pre-canceled and boundary-canceled reads publish no result; malformed
  text, over-capacity storage and missing SQL table fail closed; another connection
  cannot publish an edit during the read snapshot. Registration tampering fails
  the final check and rolls back. Existing unrelated state remains intact.
- P2-A4: explicit human provenance/status/authority, no source-currentness field;
  source `query` does not start returning human text. A source-access counter stays
  zero with the source root unavailable.
- P2-A5: Forget survives reopen and source rebuild, suppresses same-ID writes,
  and does not affect the other project or source files.
- P2-A6 (bounded fixture slice): malformed/empty/control/oversized byte queries
  fail before store creation; Unicode lowercase behavior and non-normalization,
  occurrence ranking/ties, repeat-output determinism, 8-entry cap, aggregate JSON
  budget, escaped oversized entries, complete-text omission and newline accounting
  are exercised through actual SQLite/core and CLI output.

Verification revision/results are recorded below after checks. Independent primary
review, exact-head remote CI and publication remain separate **not-run** gates.
The supplied base CI evidence (PR 51 runs 43548355679 / 43548355730) applies only
to base main, not this lane. No push, PR, release, deploy or merge-to-main was run.
No phase is closed. Daemon ReviewSession/integration, preparation, refinement,
Companion/native hosts, source indexing and inherited progress docs are excluded.

## Local verification record

Tested implementation SHA: `1c49e1ab41f75d8a72c35639bd437f74f6ef9e0d`.
The subsequent evidence-only commit appends this record without runtime changes;
the final handoff also identifies the fully rechecked evidence-head SHA.
Environment: macOS, rustc 1.97.1, cargo 1.97.1, Python 3.12.6.

- `python3 scripts/check.py`: **PASS**. Formatting, locked workspace build,
  warnings-denied Clippy, all workspace tests/doctests, warnings-denied Rust docs,
  CLI/daemon diagnostics, local documentation links and intentional-failure gate
  all passed. Six new core tests and three new CLI tests passed. An earlier run
  found two Clippy `int_plus_one` test assertions; fixed before the passing run.
- `cargo deny --locked check`: **PASS** (advisories, bans, licenses, sources).
- `python3 scripts/secrets.py`: **PASS**, with only owned new files staged first;
  tracked-file scan and synthetic-negative probe both passed.
- `git diff --check` and `git diff --cached --check`: **PASS**.
- Independent review: **NOT RUN**; primary review/integration required.
- This lane's remote CI: **NOT RUN**; no CI run/head exists for these changes.
  Prior main runs are not evidence for this SHA.
- No Docker, real user content, global configuration, credentials, installer,
  source modifications, host launch, inference, push or remote publication.

Implementation files are the new `knowledge/human_search.rs`, its new targeted
test module, the new CLI integration test file, minimal core module/export lines,
daemon command/preflight/routing and CLI parsing/help. This document owns the
output/provenance/privacy contract and local evidence; no inherited progress
document was changed. Remaining gates: primary independent review, integration,
authorization to publish and exact integrated-head CI. Representative scale and
quality evaluation, native UI/handoff and complete phase acceptance remain open.

## Primary integration and review

Joffrey independently reviewed the completed lane and found no substantive issues,
passing all six core and three CLI search tests offline. The primary integrated
the owned commits onto PR #55 merge `8b04317dc21e748d7bcd75cf931138b8c56f2e47`.
Exact integrated runtime `0fa5776b89aa647c5eb8d283ae4ceb998b833b90` passed the
full workspace gate: 172 Rust tests plus two doctests. Dependency policy, staged
secrets and whitespace checks passed. No schema/dependency/lock changed.

This is the human-only CLI/API unit. The separately completed native search and
Refine consent/preview work still needs repair/integration/review and is not
certified by these results. Publication adds evidence only; exact remote head/CI,
native/GUI acceptance and whole-phase closure remain subsequent gates. All nine
inherited progress appends and user work remain untouched and excluded.

## PR #56 publication outcome

PR [#56](https://github.com/suhaasbadada/threadmark/pull/56) passed all five checks
on `195e85ac1ecab400a066fb1eb51dabc901553d0b`: CI
[43555054873](https://github.com/suhaasbadada/threadmark/actions/runs/43555054873)
and integrated [43555054956](https://github.com/suhaasbadada/threadmark/actions/runs/43555054956).
Fresh exact-head/main/rules/discussions checks found no blocker; independent review
and local acceptance applied. It merged at `2026-11-14T04:19:15Z` as
`535b049fb95730ee25cf17e74d5d5c2eceaf9cf3`, already green without a watch wait.
Separate exact post-merge CI
[43556055885](https://github.com/suhaasbadada/threadmark/actions/runs/43556055885)
and integrated [43556055846](https://github.com/suhaasbadada/threadmark/actions/runs/43556055846)
both passed. Native UI and preparation integration remain separate gates.
