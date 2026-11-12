# Initial threat model and risk register

Status: foundation design review input, not a security audit.
Owner for all open items: project maintainer. Traceability: TM-01–TM-10, P0-A4.

Assets: approved local sources, project decisions, credentials, ephemeral prompts,
host permission boundaries and integrity of evidence/approval receipts.
Untrusted inputs: repository documents, extracted graphs, model outputs, caller
IDs, filesystem events and imported metadata. Local processes are not inherently
trusted. A compromised host/OS is outside current containment guarantees.

| Risk / boundary | Current mitigation or evidence | Remaining gate |
| --- | --- | --- |
| Cross-project/revision confusion | Exact scope comparison and negative matrix before worker invocation | Verified durable identities/aliases; Phase 2 |
| Spoofed local caller | No transport listener exists | Authenticated IPC, permissions/origin tests; Phase 1 |
| Prompt injection in evidence | No content ingestion or execution in foundation | Untrusted-data handling and adversarial retrieval/refinement tests; Phases 2/4 |
| Exfiltration / credential reuse | No network/provider dependencies, credential access or telemetry | Egress approval, source exclusions and credential storage tests; Phases 1/2 |
| Partial/malformed worker reply | Version, scope, completion and item-budget validation | Content/schema validation, bounded process isolation, timeout and cancellation; Phases 1/2 |
| Interrupted writes / false complete snapshot | No persistence; fresh-run failure test makes no durable claim | SQLite atomic swap/migration/kill tests; Phase 2 |
| Deleted/renamed source survives | Synthetic operation fixture only | Freshness, forget/re-import and WAL/backups limitations; Phase 2 |
| Silent host send / retry duplication | No send implementation, capability port read-only | Exact approval binding and unknown-send reconciliation; Phases 4/5 |
| Leaking diagnostics | Fixed diagnostic messages, rejected args never echoed; synthetic tests | Log redaction fuzzing before real inputs; Phase 2 |
| Supply chain / accidental secrets | No external Rust crates; lockfile, license/advisory checks, pinned CI tools, redacted Gitleaks + negative probe | Ongoing pin/advisory review; CI does not prove absence of all secrets |
| False support or release claim | Status states offline foundation; phase evidence separate from CI | Exact host/version conformance and explicit release approval |

No real credentials or user content may enter fixtures. Report vulnerabilities
using [SECURITY.md](../SECURITY.md), not a public reproduction with secrets.
