# Local product adapter contract v1

Frozen integration seam for parallel core, companion and refinement work.
Implementation ordering is explicitly authorized ahead of incomplete Phase 1
host/inference gates; it does not close those gates or authorize live endpoints.

Core remains the only owner of authorization, SQLite and source freshness.
Adapters never accept a request-supplied root as authority. Every operation names
an explicitly registered `project` ID; IDs and snapshot hashes are not credentials.
No network listener, host admission, model credential discovery or send operation
belongs to this contract. The local owner selects an explicit private data directory.

## Core service port

The companion service adapter exposes these bounded operations, mapping them to
the Rust daemon API/CLI rather than duplicating storage:

- `projects()`: registered project summaries (`id`, approved source paths,
  nullable `snapshot`); adapters must not log private roots.
- `project(project)`: identity and exact approved source list.
- `addProject(project, root, sources)`: explicit approval of a root and file list.
- `setSources(project, sources)`: replaces policy, invalidating source evidence.
- `index(project, cancellation)`: explicit bounded job; completion returns
  `project`, `snapshot`, `files`, `anchors`, `coverage`, `empty`.
- `query(project, text, cancellation)`: returns `project`, nullable `snapshot`,
  `currentness` (`current-at-read` or `stale-or-unindexed`), `coverage`, `results`.
  Each result has `project`, `path`, positive `line`, `text`, `source_hash`,
  `producer`, `kind` (`observed-source-line`), `currentness`, `coverage`.
- `contexts(project)`: current metadata (`id`, `revision`, `kind`, `retired`,
  `producer=human-authored`); `context(project,id)` returns bounded edit history.
- `writeContext(project,id,kind,text,update)` and `retireContext(project,id)`:
  explicit human edits, never inferred permission or source truth.

Errors are typed/content-free (invalid, unavailable, canceled, scope mismatch,
stale); source text, roots, prompts and credentials never enter diagnostics.
Requests are single local-owner operations, not an authenticated remote API.
Bounds: 64 approved files, 64 KiB/file, 1 MiB total source; retrieval at most eight
items and 8 KiB serialized output. There is no implicit scan or model operation.
Adapters may tighten bounds, not silently truncate material input.

The coordinator supplies concrete core transport integration. Until then shell
tests inject a clearly named fake service; unavailable production transport must
be visibly unavailable, never silently use sample projects or fake readiness.
Fake tests do not establish a native tray, background process or live core link.

## Refinement service boundary

The provider-neutral Rust engine receives an immutable request containing:
`request_id`, `project`, `snapshot`, original text, explicit constraints,
attachment references, destination identity, mode, and bounded selected evidence.
Selected evidence retains the query-result fields above. Missing/stale evidence,
scope mismatch and material unknowns remain explicit; untrusted excerpts cannot
override original intent or grant permission.

A provider trait receives only this bounded selection after explicit provider
configuration/consent is supplied. No concrete network client or credentials are
implemented by this slice. An injected test provider must be labeled as such.
Context-only output is not advertised as AI refinement. Structured output keeps
original, objective, constraints, evidence references, decisions, unknowns,
evidence-backed risks and proposed verification distinguishable. Unsupported
material assertions reject or require clarification, never become verified facts.

Preparation states: preparing, needs-input, ready, failed, canceled. Review binds
the exact immutable request and exact edited brief, snapshot, destination and
attachments. Any edit, project/snapshot/destination change or superseding request
invalidates prior approval. Cancellation rejects late results. Delivery remains
`not-attempted`: no engine or shell action may send a task. Prompt/evidence/brief
history is memory-only by default; no background inference or content logs.

The first implementations may use language-native DTOs behind these ports. Do
not build a general RPC framework, schema registry or parallel database. Changes
to this small seam are coordinated before integration, not guessed in clients.
