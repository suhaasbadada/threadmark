# Architecture and knowledge lifecycle

[Documentation home](../README.md) · [Integrations](integrations.md) · [Phase specifications](spec/README.md)

**Status:** proposed architecture. Dependencies, packaging, and performance require validation.

## Components

- **Rust core:** project identity, knowledge records, retrieval, freshness, and execution-brief logic.
- **Local daemon:** authorized API, bounded jobs, transports, and adapter coordination.
- **CLI:** automation and diagnostics over the same core contracts.
- **Companion shell:** a menu-bar presence and occasional management window for onboarding, context editing, connections, and privacy, plus temporary review/handoff panels. Native host UI is preferred for routine refinement. Tauri is the initial candidate, subject to accessibility and packaging tests. No replacement coding UI is planned.
- **Client adapters:** small native plugins/hooks or MCP transports where supported. TypeScript may be required by a host SDK.
- **Extraction workers:** versioned, replaceable structural and semantic extraction.

Start with three Rust crates—core, daemon, and CLI—rather than a distributed service per feature. Use SQLite transactions, WAL, FTS5, and adjacency tables. Do not add an external graph database, unsafe Rust, or custom allocator without a demonstrated requirement.

The shell does not become an independent executor or own a parallel conversation model. Window close and process quit have distinct lifecycle semantics. Phase [2](spec/phase-2-knowledge-core.md) specifies knowledge/job ownership, Phase [3](spec/phase-3-background-experience.md) specifies shell behavior, and Phase [4](spec/phase-4-refinement.md) specifies preparation/approval boundaries. Concrete schemas and protocols remain implementation deliverables, not claims that an API already exists.

## mem-z

The knowledge layer contains four complementary elements:

1. A searchable source/evidence index.
2. Typed structural and semantic relationships.
3. Human-curated decisions, constraints, corrections, and pitfalls.
4. Provenance, freshness, revision applicability, and extraction coverage.

It is a maintained map with known gaps, not a complete snapshot of everything about a project.

## Graphify boundary

Graphify is the initial extraction candidate. Its documented pipeline separates local deterministic code structure from inference-backed extraction for documents and other supported media. A graph edge is not automatically runtime truth; inferred and ambiguous relationships remain labeled.

Before redistribution, validate the selected release's license/NOTICE, packaging, provider compatibility, supported language constructs, edge direction, identifier stability, logging, and incremental deletion/rename behavior. Import output through schema and integrity checks. Threadmark owns durable identities and knowledge semantics rather than treating external node IDs as permanent authority.

Compare graph-assisted retrieval with lexical and symbol/repository-map baselines. Adopt additional graph infrastructure only when query needs and measured performance justify it.

## Knowledge records

Records include claim type/content, source/evidence anchors, producer, namespace, project/worktree/revision scope, timestamps, freshness, status, sensitivity, and supersession/conflict links.

Distinguish intended policy from observed implementation. Human endorsement can establish a decision; it does not prove technical correctness. Model-generated and agent-reported assertions remain candidates until supported by appropriate evidence or explicit endorsement.

Project identity uses a stable local identifier and verified repository aliases. Worktree/revision identities remain separate. Repository folder names and remote URLs are discovery hints, not authorization.

## Updates

- File events enqueue bounded, debounced structural updates.
- Branch changes and lost watcher events trigger reconciliation.
- Relevant source anchors are checked when preparing a brief.
- Semantic refresh is batched, cancelable, and constrained by approved egress and inference budgets.
- User edits survive rebuilding; dependent interpretations become stale when their evidence changes.
- Failed or partial extraction cannot replace a usable snapshot with an apparently complete empty result.

## Request and delivery contracts

Version every extraction, context/brief request, observation, and delivery record. Bind requests to authorized project/worktree scope, source revision, original text, attachment metadata, mode, and budgets. Caller-supplied IDs are not authorization.

Keep preparation and delivery separate. A brief can be ready, require input, fail, or be canceled independently of whether it is copied, handed to a composer, admitted by a host, or left in an unknown delivery state.

Approval binds exact brief content, destination, attachments, and scope; material changes invalidate it. Content-bearing prompts/briefs are ephemeral by default, with explicit retention consent for any persisted history. Metadata receipts must not leak private content.

Use host idempotency keys where documented. An unknown send result is reconciled, never retried blindly. A successful preparation, host admission, completed tool, or green test is not a blanket claim of successful implementation.

## Performance

Use bounded Tokio concurrency and dedicated blocking storage work. Cap source sizes, queues, caches, retrieval candidates, output bytes/tokens, and worker counts. Keep indexing and semantic extraction off the prompt-send path.

Measure cold/warm retrieval, p50/p95/p99 latency, idle/peak RSS, CPU, index catch-up, index size, model/network time, and end-to-end task cost on declared fixtures. Rust enables resource control; it does not itself prove better task outcomes or model latency.

## Security and deletion

See [security and privacy design](../SECURITY.md). Extraction workers are not automatically sandboxes; validate containment before claiming it. Forgetting must cover active indexes and derived caches and document limits for WAL, backups, exports, logs, and already-sent host transcripts.
