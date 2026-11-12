# Phase 2 — Rust mem-z knowledge core

[Specification index](README.md) · Previous: [Phase 1](phase-1-feasibility.md) · Next: [Phase 3](phase-3-background-experience.md)

**Status:** open. **Requirements:** TM-01–TM-04, TM-07, TM-10. **User outcome:** a project has a trustworthy, inspectable, incrementally maintained evidence base independent of any coding client.

## Primary journey

An authorized caller registers a project root, inspects source scope, starts structural understanding, sees coverage and gaps, and queries source-backed knowledge. Editing files updates relevant evidence. Switching worktrees cannot silently apply incompatible facts. This journey is initially testable through the CLI/API; management UX follows in Phase 3.

## Identity and access

Give projects stable local IDs. Bind repository aliases only after verification and keep worktree, branch/revision, and dirty-file content identity distinct. Names and remote URLs are not authorization. Do not follow symlinks beyond approved roots, silently index submodules/external folders, or use repository instructions to broaden source access. Permission/exclusion changes invalidate affected retrieval and caches immediately.

## Minimum knowledge model

| Record | Required semantics |
| --- | --- |
| Project/worktree | Stable identity, authorized roots, exclusions, revision and working-tree snapshot |
| Source anchor | Relative path, content identity, location, extraction version, readability/currentness |
| Claim | Kind, text, producer, supporting anchors, scope, freshness, candidate/accepted/retired status |
| Relationship | Typed endpoints, extracted/inferred/ambiguous origin, evidence and applicability |
| Decision overlay | Human authorship, scope, revision history, supersession/conflict links |
| Index job | Input snapshot, stages, progress basis, cancellation, error and committed output |
| Forget marker | Target identity/scope, suppression policy and auditable non-content receipt |

Concrete serialization and schema migrations require reviewed contracts before implementation. A confidence score is not a substitute for provenance or authorization.

## Index and retrieval behavior

Structural indexing works without inference. Import extraction through schema/integrity checks and map external node IDs to Threadmark-owned identities. Stage results and atomically commit a coherent snapshot; failed/empty/partial extraction cannot masquerade as a complete replacement. Expose file counts, skipped reasons, language gaps, and semantic coverage separately.

Debounce file events, bound queues/workers, reconcile watcher overflow, and detect branch switches and renames. Recheck selected anchors when preparing evidence. Unreadable or deleted sources are removed from active factual retrieval; retain only policy-authorized historical metadata. Mark dependent interpretations stale rather than silently preserving them as current.

Retrieve only inside authorized project/worktree/namespace scope. Rank lexical/symbol/relationship candidates within declared budgets, return compact excerpts with anchors, and label uncertainty/conflicts. No background model call on every file event and no indexing work on the prompt-send critical path.

## Lifecycle and recovery

Jobs expose queued, running, cancel-requested, canceled, failed, and complete states. Cancellation acknowledgment follows worker teardown; late output cannot commit after cancellation or scope change. Pause stops new automatic work; quit closes owned workers and does not leave an independent updater running unnoticed. Persist only resumable checkpoints that still match source and permission identities.

SQLite transactions and migrations protect edits and usable snapshots. Export includes selected records/provenance but no credentials. Forget removes active derivatives and suppresses unintended re-import; a later rebuild cannot silently recreate the same forgotten entry. Explain backup/WAL/export limits rather than promise forensic erasure. Removing a project must never delete source files.

## Acceptance

- **P2-A1:** Conflicting rules in similarly named projects and incompatible worktrees never cross retrieval scope, including cached results.
- **P2-A2:** Add/edit/rename/delete, dirty-file changes, branch switch, lost watcher events, and revoked permissions produce correct currentness and coverage states.
- **P2-A3:** Malformed extraction, worker crash, cancellation, disk-full, and process interruption preserve the previous usable snapshot and human edits; recovery is tested.
- **P2-A4:** Every returned material claim has resolvable provenance or an explicit unsupported/candidate label; structural-only indexing makes no inference request.
- **P2-A5:** Export, forget, rebuild, project removal, and migration fixtures prove active-data semantics without deleting repository content or resurrecting forgotten entries.
- **P2-A6:** API requests enforce caller scope before retrieval, and indexing/retrieval stay within the Phase 1 provisional resource budgets on declared fixtures.

## Exit and exclusions

Deliver tested CLI/API, schema and migration contracts, recovery fixtures, and resource measurements. Embedding services, an external graph database, automatic cross-project memory, and team sync are not dependencies.
