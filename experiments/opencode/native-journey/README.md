# Native OpenCode journey spike

**Source prototype, not certified host support.** TM-02, TM-04–TM-08, TM-10;
[P1-A2/P1-A4/P1-A5](../../../docs/spec/phase-1-feasibility.md).
No daemon, inference, storage, context hook, listener or background capture.
Preparation is a deterministic synthetic suffix, not intelligence or retrieval.
The currently verified runnable product remains the offline foundation CLI.

## Source and API boundary

`server.js` registers `threadmark-refine` with `Plugin.define`,
`ctx.command.transform` and an asynchronous `Promise<void>` executor.
It captures only that explicit invocation's `sessionID`, `prompt` and `delivery`.
`ctx.location` supplies project/location/workspace binding. Branch and revision
are not captured from the host; any authored constraints in the prompt remain
verbatim. Live branch/revision invalidation is **not demonstrated**.

`rpc.js` defines portable JSON-Schema `pending`/`decide` methods and a
content-free `reviewReady` event. `tui.js` uses `ctx.client.rpc`, native
`ctx.ui.dialog.confirm` and a host-owned keymap layer. No JSX, build step or new
dependencies. `package.json` exposes `./server` and `./tui`. Both entrypoints
import the real installed host SDK, not a replacement implementation. Runtime
resolution of those imports is an **unverified host-loading gate**: stop on
failure, do not install packages or rebuild a dependency closure to hide it.

API references supplied by the primary, cross-checked against existing approved
2.2.5 declaration projection (22-package scope):

- <https://opencode.ai/v2/docs/build/plugins>
- <https://opencode.ai/v2/docs/build/plugins/cli>
- <https://opencode.ai/v2/docs/build/plugins/rpc>
- `@opencode/plugin/dist/promise/{command,plugin,rpc,registration}.d.ts`
- `@opencode/plugin/dist/tui/{plugin,context}.d.ts`
- `@opencode/client/dist/promise/{rpc,generated/types}.d.ts`
- `@opencode/schema/dist/{prompt-input,location,session-inbox,rpc}.d.ts`

No new network fetch, host launch, SDK execution or compiler invocation was used.

## Bounds and semantics

- Rough UTF-8 text ≤2 KiB; each files/agents/skills array ≤4 items; each metadata
  string ≤256 characters; full invocation JSON ≤6 KiB. Unknown fields/undefined
  optional values, invalid mention spans and unsupported values fail closed.
- File support is deliberately **inline synthetic `data:text/plain` only**.
  HTTP/file/resource URI capture is rejected, not dropped or fetched. No host
  file resolution or remote egress is requested by this bridge.
- Original text is an exact prefix of prepared text. Mentions, skills, agents,
  delivery, attachment metadata and authored constraints remain unchanged.
  The review displays original, exact prepared text, metadata and destination.
  Candidate objects are frozen; SHA-256 binds stable JSON of scope, session,
  delivery, original and prepared prompts. A fresh random candidate ID prevents
  stale decisions from matching a new invocation with identical text.
- One active invocation per session; at most 32 active/unknown sessions. First
  `pending` owner claims the candidate. Owner/claim/candidate IDs are correlation,
  **not credentials**; real host authentication and location-scoped RPC are the
  trust boundary. This does not isolate mutually untrusted authenticated plugins.
- A content-free event opens one native confirm in the matching current session.
  `/threadmark-review` recovers a missed event without polling. A second TUI
  cannot claim that same candidate while its first claim remains outstanding.
- Approval must match session/candidate/digest/owner/claim. The send latch is set
  synchronously before the sole `ctx.session.prompt` call. Cancel, close,
  pre-approval abort, unload, unavailable notification and 30-second expiry
  produce zero calls. A disconnected reviewer cannot send a decision; its claim
  expires. This is not a fictional disconnect callback or immediate disconnect
  detector. A disconnected client cannot prove server receipt of cancellation.
- The command and decision waiter settle within the original 30-second window,
  even if the host prompt promise hangs. After admission starts, cancellation,
  unload, timeout, exception or malformed receipt means **unknown, never retry**.
  The session is blocked for further invocations after unknown until plugin
  reload; reload is not permission to retry without external inbox inspection.
  A late completion cannot upgrade the unknown result. The host may still finish
  its call; there is no containment/rollback/secure-erasure claim.
- `inbox-receipt` requires the actual returned `SessionInboxUser` ID, matching
  session, type, delivery, text, agents and ordered skill IDs/mentions. Resolved
  skill names/content are not claimed equivalent (`inbox-receipt-attachments-unverified`). For files it says
  `inbox-receipt-files-unverified`: host resolution changes file representation;
  the external inbox check must verify bytes and metadata. Receipt is admission
  only, **not processing, model completion, tool execution or user-value proof**.
- Cleanup settles server waiters, disposes command/RPC registrations, unsubscribes
  TUI events, aborts client calls and best-effort cancels the claimed review.
  OpenCode removes its keymap layer on deactivation. No prompt/path/token logging.
  The review necessarily displays the bound project location privately in-host.

## Focused local tests (no SDK substitute)

```sh
node --test experiments/opencode/native-journey/kernel.test.mjs
```

These are **pure orchestration tests**, not installed-host integration tests.
Injected notification/prompt functions test the kernel only. Entry files receive
syntax checks; no mock SDK is loaded or advertised as native evidence.

## Decisive 15-minute installed-host experiment — STOPPED BEFORE READINESS

The authorized startup attempt failed at OS Segmenter initialization; one narrow
OS ICU-read correction progressed to standalone-server readiness failure. No
prompt was submitted and no native dialog/inbox behavior is demonstrated. See the
[preserved outcomes and next-route decision](../../../docs/progress/phase-1-native-journey.md).
The checklist below remains acceptance criteria, not completed evidence or
authorization to repeat the experiment.

Primary observed installed `/opt/homebrew/bin/opencode` version **2.2.5**, macOS.
Execution/isolation decision belongs to the primary; do not run this checklist
until that decision authorizes a disposable, provider-credential-free host with
effective zero-egress containment and no reuse of the user's existing service,
sessions or configuration. Do not launch or alter the user's normal host.

The V2 [OpenAPI contract](https://opencode.ai/v2/openapi.json) explicitly describes
`session.prompt` as durable admission that schedules execution **unless `resume`
is false**. The reviewed 2.2.5 declarations also expose that field. This spike
binds `resume: false` into review and always sends it; no provider-disabled
generation failure is an acceptable substitute. Before admission, compare the
isolated installed server's own OpenAPI contract and verify enforced egress and
provider denial. If those preconditions fail, stop without submitting a prompt.

1. **0–3 minutes: load gate.** In the approved isolated location, reference this
   local plugin package using the documented V2 plugin-loading mechanism and
   enable its TUI entrypoint in the experiment-only CLI configuration. Record
   exact config scope, host version, location and registered command. If the SDK
   imports or entrypoint loading fail, stop with the content-free error category;
   no installation, bundler, acquisition or host rebuild. No global changes.
2. **3–6 minutes: zero path.** Create an empty synthetic session. Record its
   baseline inbox via the documented host API. Invoke
   `/threadmark-refine synthetic: describe a local counter; do not execute tools`.
   While review is open, independently read the inbox: delta must be zero.
   Cancel; delta must remain zero. Repeat once with dialog close and once with
   TUI disconnect (wait for the single 30-second expiry). Record zero counts,
   not prompt-bearing logs. Exercise `/threadmark-review` if an event was missed.
3. **6–10 minutes: one path.** On a fresh synthetic invocation inspect the full
   native confirm, then approve once. Read the inbox using the same host API:
   delta exactly one, actual ID/session/delivery/text equal the candidate. Compare
   metadata and synthetic inline file bytes in the private evidence if attachments
   were used. Check both queue/steer if time permits. Do not infer completion from
    the toast. Verify no active session drain/model request and no token/cost
    change. Never resume, generate, or steer an existing inbox item in this spike.
4. **10–13 minutes: failure path.** Replay a stale/duplicate decision only through
   documented experiment RPC and check zero additional inbox items. Unload during
   a pending review and confirm zero; reload does not revive the candidate. If an
   admission response is lost, mark unknown and inspect the inbox, never retry.
5. **13–15 minutes: decision.** Record exact host/OS, scoped configuration,
   permissions, load outcome, observed IDs/counts, review friction and failure
   exit. Do not publish private paths, credentials or prompt logs. Retain synthetic
   artifacts privately. Stop at the first load/privacy/zero-send breach and report
   it; do not grow prerequisite machinery during this experiment.

Minimum proof gates are native load, scoped host-authenticated RPC, real native
review, zero before approval/cancel/disconnect/unload, exact-one admission and
real inbox receipt identity. Redistribution/license/dependency hardening remains
a separate future decision, not a substitute for this host journey. This spike
does not certify broader daemon/storage/inference/context-hook product scope.
