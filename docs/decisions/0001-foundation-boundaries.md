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
