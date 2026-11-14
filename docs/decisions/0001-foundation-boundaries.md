# ADR 0001 — Offline foundation and component ownership

Status: accepted for Phase 0 implementation; owner: project maintainer.
Traceability: TM-01–TM-10, P0-A3/P0-A4/P0-A5.

## Decision and alternatives

1. **Background operation:** Rust core/daemon/CLI workspace. The daemon crate
   currently performs one synchronous synthetic check and exits, opening no IPC.
   A resident service and tray are deferred until Phase 1 feasibility. Rejected:
   shipping an empty tray or a replacement chat/editor as apparent product progress.
2. **Ownership:** core defines scope and worker metadata; daemon checks scope,
   cancellation and reply bounds; CLI reports offline diagnostics. Future host
   adapters do capture/draft handoff. Hosts retain chat, permissions and execution.
   Rejected: an independent agent launcher/executor or shared conversation model.
3. **Storage:** SQLite evidence/FTS/adjacency is the intended Phase 2 mem-z store.
   No database or migration exists yet. Rejected: adding an external graph service
   before measured retrieval requirements. Graphify remains replaceable and
   unbundled; its packaging/license/containment must pass Phase 1.
4. **Identity:** separate project/worktree/revision IDs compared to a locally
   approved scope. Folder basenames, remote URLs and caller IDs are not authority.
   Rejected: basename namespaces or trusting a transport-supplied ID. Discovery,
   durable IDs, canonical path aliasing and authenticated IPC remain Phase 1/2 work.
5. **Inference:** no provider dependencies, credentials or egress in Phase 0.
   The readiness port is injectable; actual data transfer requires explicit source,
   destination and budget authorization. Reject subscription-token reuse and
   silent fallback to an online provider.
6. **Preparation vs delivery:** a synthetic check receipt contains only count and
   clock ticks, not a brief or send receipt. The host capability port is read-only;
   no send method exists. Unknown future delivery must be reconciled rather than
   blindly retried. Approval must bind exact scope/content/destination in Phase 4.

## Dependencies, toolchain and licensing

Pin Rust 1.97.1 (observed available stable patch), edition 2024, Cargo.lock.
No third-party runtime or test crates. MIT project license; no CLA is required,
and contributions are under the same license. CI-only tools: cargo-deny 0.20.2
(MIT/Apache-2.0), Gitleaks 8.30.1 (MIT); binaries are not bundled. cargo-deny
checks RustSec advisories, licenses, sources and version duplication. Allowlist
is not permission to add dependencies without review. Pin tool actions by commit
and downloaded scanner by SHA-256. Review pins quarterly or upon advisories.

## Consequences and unresolved ownership

No runtime certification, persistence, durable recovery or resource-isolated
worker claim. The fixture metadata check is not a content import validator.
The maintainer owns remaining feasibility decisions: authenticated IPC, worker
timeouts/cancellation, SQLite migration/recovery, path identities, Graphify
release/NOTICE and shell accessibility. Phase 1 must resolve these with evidence
before the core grows into Phase 2. See the [risk register](../risks.md).

## Authorized sequencing exception — provider-independent product implementation

The owner explicitly superseded the project-wide checkpoint and directed actual
Rust product implementation and parallel shell/refinement lanes. Phase 1 native
host, T3 handoff, inference and evaluation acceptance remain OPEN. Their specific
authority boundaries still apply; they no longer block independently testable
Phase 2 storage/retrieval or provider-neutral Phase 3/4 contracts. This changes
implementation order, not the architecture, final acceptance or full product scope.

The first integrated core slice registers explicit roots and exact file consent,
persists source-line evidence and human context in private SQLite, and provides
manual bounded index/query/inspection through core → daemon → CLI. Its default
replaceable extractor captures lexical source lines, not a custom semantic parser
or adopted Graphify worker. Rollback-journal transactions protect this finite
slice; WAL/FTS/background maintenance remain subsequent implementation work.
Schema, cancellation/freshness bounds and dependency/license decisions are
recorded in [Phase 2 core evidence](../progress/phase-2-core.md).

Parallel clients use the small [local adapter seam](../contracts/client-v1.md).
Core remains the authorization/storage owner; clients do not create a second
database or infer authority from IDs. No listener, live provider/credential reuse,
native coding-host launch, global configuration, deployment or phase closure is
authorized by this exception. The original foundation decisions above remain
historical context where they describe deferred/not-yet-existing functionality.
