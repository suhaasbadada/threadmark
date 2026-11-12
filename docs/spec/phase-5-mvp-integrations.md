# Phase 5 — First complete OpenCode and T3 workflows

[Specification index](README.md) · Previous: [Phase 4](phase-4-refinement.md) · Next: [Phase 6](phase-6-cross-agent.md)

**Status:** open. **Requirements:** TM-04–TM-08, TM-10. **Milestone:** functional MVP when all preceding gates also pass. **User outcome:** get project-aware help while continuing to work in an existing coding environment.

## OpenCode workflow

An explicit host command captures request text and attachments, prepares a brief through the daemon, shows native review where supported, and admits only the approved payload through the normal host path. Preserve original input in ephemeral review or opt-in retained history; do not change persisted user messages by default. Command names remain placeholders until implemented and documented.

Use documented message identity and reconciliation for uncertain admission. A timeout does not prove rejection. Reconcile with the host before offering a retry, and never duplicate admission to manufacture a success signal. Closing the review or disconnecting is not approval. Native Context mode is separately opt-in, bounded, and deduplicated for a turn across tool continuations.

The OpenCode Desktop composer adapter is a separate experimental surface: review, apply to composer, then the user sends. Terminal support does not prove Desktop or T3 support.

## T3 draft bridge

The user explicitly selects a destination through a supported thread link, prepares/reviews the brief, and chooses **Open draft in T3**. The user verifies the composer and sends in T3. Setup/indexing never creates or messages threads. Link opening records only a handoff attempt unless a documented acknowledgment proves more.

Prefer validated local app-link handling. Private prompt content must not be routed through hosted HTTPS links by default. Disclose local-link/clipboard exposure; do not log prompt-bearing links. Validate destination and supported size; occupied drafts require the host's replacement confirmation. An oversized brief offers copy or explicit shortening, never truncation. If destination/host support cannot be verified, use deliberate copy rather than fake native integration.

The companion review surface is temporary and invocation-driven, not a second coding workspace. T3 provider-specific deeper hooks remain uncertified until independently tested. Threadmark never presses Send on the user's behalf in this bridge.

## Installation, trust, and failure behavior

Before modifying host config show exact location/scope, proposed diff, capability, trust requirements, and rollback. Record ownership of Threadmark entries. Preserve unrelated settings/comments and do not edit host credentials or application databases. Uninstall removes owned entries only; conflicting user edits require an explicit resolution.

Expose daemon/adapter/version status and a non-destructive connection test. Unsupported versions degrade visibly to a tested fallback or disable the mode. Context failure can leave the host request unchanged within host policy and with visible status. Explicit Refine failure retains the draft and requires a user choice. Remote execution is not laptop localhost; do not upload knowledge or expose a public daemon to make a connector appear functional.

## MVP conformance matrix

Test each advertised host/version/mode with text, attachments, cancellation, disconnect, late response, daemon restart, scope mismatch, source change during review, output over budget, duplicate invocation, unknown admission, and unrelated config edits. Record the actual acknowledgment each surface provides. A passing unit test is not host runtime certification.

## Acceptance

- **P5-A1:** OpenCode demonstrates capture → preparation → review → approval → one normal admission; cancellation or closed review yields zero admissions.
- **P5-A2:** Attachments and original constraints survive; opt-in context appears once per turn and does not rewrite persisted user input or host policy.
- **P5-A3:** Unknown admission is reconciled without blind retries; rejected and unobservable delivery remain truthfully labeled.
- **P5-A4:** T3 tests verify destination, occupied draft, size limits, and copy fallback. No draft bridge action auto-sends or claims downstream success.
- **P5-A5:** Install/disable/uninstall round trips preserve unrelated config and credentials; daemon failure does not prevent ordinary host use.
- **P5-A6:** A new user on the declared MVP matrix completes onboarding, edits context, refines a request, and hands it off without adopting a Threadmark chat/editor/dashboard.

## Exit and exclusions

Deliver certified capability manifests, installation ownership records, exact-version runtime evidence, and a complete MVP walkthrough. Direct T3 send/start, universal provider passthrough, remote/cloud connectors, and autonomous task execution are excluded.
