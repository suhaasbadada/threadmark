# Coding-environment integrations

[Documentation home](../README.md) · [Roadmap](roadmap.md)

**No Threadmark integration is shipped or runtime-certified yet.** Host documentation informs the following proposed workflows; versions and environments must be tested before support is advertised. Command names are placeholders, not installation instructions.

## Four distinct paths

1. **Native context:** a supported hook attaches relevant evidence before executor inference, without silently rewriting user intent.
2. **Native refinement:** a host command/UI prepares a brief, shows the difference, and requires explicit approval before admission or composer replacement.
3. **Agent-assisted MCP:** the executor first receives the request, then calls a Threadmark tool. This is not pre-model interception.
4. **Desktop handoff:** the app prepares a brief for explicit copy, draft prefill, or a separately authorized send.

Capability manifests record mode, host, version, execution environment, capture limitations, trust requirements, and delivery acknowledgment. MCP connectivity does not prove automatic invocation or prompt interception.

## OpenCode terminal

Proposed flow: `/threadmark-refine <request>` → server-owned preparation with prompt attachments and delivery mode → TUI preview → explicit approval → one normal session admission.

Use a server command for attachment fidelity and a pending-brief/approval contract for the UI. Preserve original input in Threadmark activity. Use a client-generated message ID and supported admission reconciliation rather than blind retries. Closing the preview or disconnecting is not approval.

Opt-in automatic Context uses a non-persisting context hook with a stable turn-scoped evidence packet. Deduplicate across tool continuations. Do not mutate persisted user input by default, particularly when another client such as T3 maintains its own visible transcript.

## OpenCode Desktop

The documented experimental GUI plugin supports composer access and text replacement while keeping attachments. Proposed flow: Refine draft → inspect diff → Apply to composer → user presses Send. The composer API itself does not send.

This is a separate, version-gated adapter. An OpenCode Desktop GUI or terminal plugin does not automatically extend T3's UI.

## T3 Code

The first-release design uses draft handoff:

1. The user selects a T3 thread destination using its copied link.
2. Threadmark prepares a brief and shows the original, evidence, risks, and final text.
3. Open draft in T3 prefills that thread's composer.
4. The user checks the destination, edits, and presses Send in T3.

Official prompt links never execute and do not change permissions, branches, or worktrees. Existing drafts require replacement confirmation. The reviewed implementation limits prompts to 8,000 characters; oversized briefs use explicit copy, not silent truncation.

Prefer a locally handled app link after validating behavior on the installed version. Do not route private prompts through hosted HTTPS URLs by default. App links can still appear in operating-system/application logs; do not claim zero exposure. Sensitive content may require copy or a future approved local IPC route.

Opening a link is not acknowledgment that a draft was received or sent. Record handoff attempts honestly.

Deeper integration is certified per T3 provider: OpenCode server commands/context hooks and Claude/Codex configuration may behave differently. Do not assume universal MCP passthrough or a third-party T3 composer API. T3's outside-agent MCP interface lets an external client act on T3; it is not the same as T3-hosted agents calling Threadmark.

Direct thread send/start is deferred. It needs explicit destination and send confirmation, safe handling of broad permissions, and no automatic retry of uncertain delivery. Setup and indexing must never create or message threads.

## Claude Code and Codex

Certify documented prompt-submit context and lifecycle capture independently. Additional context is not editable composer replacement. Explicit refinement can use the app or a certified command/skill, accurately labeled if agent-mediated. Respect host hook trust review, output-size limits, and local/cloud configuration differences.

## Antigravity, Copilot, and Cursor

- **Antigravity:** validate invocation context and repeated-call deduplication; never inject content impersonating the user.
- **Copilot:** validate exact CLI/VS Code harness contracts. Submitted-prompt hook output is not a universal injection mechanism. Any transformed-prompt path needs explicit disclosure and append-only evidence semantics.
- **Cursor:** support only verified session/MCP behavior. A pre-submit allow/block hook is not proof of per-turn context injection.

## Installer and failure behavior

Show config diffs and scope before consent. Own only Threadmark entries, preserve comments/unrelated settings, record versions and ownership, respect hook trust, and make uninstall reversible. Do not modify provider credentials or application databases.

Ordinary Context may fail open with a visible status while respecting host policy. Explicit refinement failures retain the draft and offer a choice; cancellation or provider failure never silently executes the original request.

A daemon on a laptop is not localhost for a remote execution server. Remote support needs an explicitly authorized connector, not silent index uploads or public unauthenticated access.

## Certification suite

Prove no admission before approval, zero sends on cancel, faithful attachments, deduplicated context, correct project/revision binding, host policy preservation, explicit size handling, safe retry/reconciliation, visible degraded behavior, truthful acknowledgment, and preservation of unrelated configuration after uninstall.

## Primary references

- [OpenCode server plugins](https://opencode.ai/v2/docs/build/plugins/server)
- [OpenCode TUI plugins](https://opencode.ai/v2/docs/build/plugins/cli)
- [OpenCode experimental GUI plugins](https://opencode.ai/v2/docs/build/plugins/gui)
- [T3 prompt links](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/docs/user/prompt-links.md)
- [T3 outside-agent access](https://github.com/pingdotgg/t3code/blob/main/docs/user/outside-agents.md)
- [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- [Codex hooks](https://learn.chatgpt.com/docs/hooks)
- [Antigravity hooks](https://antigravity.google/docs/hooks/)
- [Copilot hooks](https://docs.github.com/en/copilot/reference/hooks-reference)
- [Cursor hooks](https://cursor.com/docs/hooks)
