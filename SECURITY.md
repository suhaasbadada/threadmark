# Security and privacy design

**Status:** planning requirements, not audited or shipped guarantees. There is no supported production release yet.

## Intended boundaries

- Local storage and structural processing by default.
- Explicit authorization before source content leaves the machine for inference or synchronization.
- Source allowlists/exclusions and secret filtering before indexing, embedding, logging, or remote processing.
- OS-protected inference credentials, separate from coding-agent subscriptions and login tokens.
- Project/namespace authorization before retrieval; no automatic cross-project sharing.
- Local IPC or authenticated loopback with restrictive permissions and origin protection; no public unauthenticated service.
- No silent task submission, permission escalation, application-database modification, or credential interception.

## Untrusted knowledge

Repository text, documents, imported graphs, tool outputs, and agent-generated notes are evidence—not higher-priority instructions. Model-generated lessons remain candidates. User endorsement can establish a policy, not prove observed technical truth. Prompt-injection resistance requires adversarial tests, not just delimiters or a confidence score.

## Data lifecycle

Prompt/brief content history is off by default. Original text, selected excerpts, and generated briefs remain ephemeral unless the user explicitly enables content retention with a defined deletion policy. Metadata-only receipts and OS notifications must not expose source or prompt content. See [background experience](docs/spec/phase-3-background-experience.md) and [refinement](docs/spec/phase-4-refinement.md) for acceptance requirements.

Minimize retained transcripts and evidence excerpts. Make provenance, retention, export, correction, and forgetting inspectable. Forgetting must remove active derivatives and prevent unintended re-import, while documenting limits for backups, SQLite WAL, exports, logs, and already-sent host transcripts. Do not promise forensic erasure without evidence.

Draft handoff links and clipboard copies also carry sensitive text. Avoid hosted prompt URLs by default and avoid logging prompt-bearing local links. A local transport is not proof that operating-system or application logs cannot retain content.

## Reporting a concern

Do not post credentials, private repositories, prompt transcripts, or exploitable vulnerability details in public issues. Use GitHub's private vulnerability reporting if enabled, or the repository owner's privately listed contact channel. No dedicated security response address or response-time commitment has been established yet.
