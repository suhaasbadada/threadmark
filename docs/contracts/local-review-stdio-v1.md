# Local review private stdio v1

Lane J; **TM-04–TM-07, TM-10; P4-A1–A4**, with core scope P2-A1/A2/A6.
This is one finite, process-private CLI review, not RPC, an authenticated listener,
credentials, a daemon, a host launcher or a delivery mechanism. No phase closes.

## Invocation and consent

`--data-dir EXISTING_STORE refine review PROJECT QUERY` takes exactly the same
required profile/model/numeric-loopback endpoint/expected-root/root-identity/
incarnation/snapshot/`--confirm-local-inference` flags as `refine preview`.
Inspect the project, query selection and provider before human confirmation as
specified in `../progress/local-refinement-preview.md`. Profile enablement is not
consent. Local servers can forward elsewhere; no network isolation is claimed.
No environment keys, credentials, remotes, automatic retry or fallback exist.
The old one-shot preview command remains unchanged.

## Framing and closed input grammar

UTF-8 JSON lines, exactly one object per LF-terminated frame. Size is checked
**before parsing**, including LF: <=8192 bytes/frame, <=8 frames and <=65536 bytes
in each direction. No partial final frame. Duplicate/unknown fields, trailing JSON,
invalid UTF-8, malformed JSON, extra fields and premature actions close the session.
JSON strings must be escaped: embedded newlines/action-looking text are data and
cannot introduce frames. Original is 1–4096 UTF-8 bytes. First frame only:

```json
{"version":1,"original":"Do not deploy.\nReview synthetic_blue."}
```

No caller evidence, constraints, attachments, snapshot or destination is accepted
in this frame. Core supplies evidence through reviewed `Store.query_bound` before
source reads. Intent, evidence, attachment and destination fields stay immutable.
Subsequent frames are externally tagged, single-action objects:

```json
{"edit":{"revision":1,"digest":"64 lowercase hex","objective":"Proposed objective","output_expectations":"Proposed output"}}
{"use-prepared":{"revision":2,"digest":"64 lowercase hex"}}
{"use-original":{"revision":2,"digest":"64 lowercase hex"}}
{"cancel":{}}
```

Edit replaces only objective and output-expectations prose; questions, unknowns,
risks, intent and evidence are retained. Existing `Brief.edit` validation applies.
No inference after edit. Actions other than cancel are valid only after a review
event has been published. Queue capacity is one; queue overflow fails closed.
Cancel, EOF and invalid input signal the same `Control` immediately, including
while the synchronous provider call is in progress. EOF never accepts anything.
The invoking parent must keep its private stdin pipe open, read a review event,
obtain an explicit human choice, then write the matching action. It must wait for
terminal output/process exit and reap the child. A prequeued action transcript or
closing stdin after capture is not a supported approval interaction. The parent
owns force termination/reaping when its own I/O or UI is abandoned.

## Output and approval

All events have `version:1`, closed `event` of `preview`, `needsinput`, `failure`,
`canceled`, or `handoff`, `terminal` boolean, and
`delivery:"DeliveryNotAttempted"`. Preview/needsinput, provider-failure review and
ReviewRequired are nonterminal; handoff/canceled and all fatal failures are terminal. No diagnostic text
or content is logged. Stdout previews/handoffs are sensitive and must not be logged.
Preview/needsinput carries exact engine `proposed`, `changed`, material questions,
editable prose and coverage. Original remains memory-only; failure events contain
only closed metadata, never original/provider diagnostic text. Explicit use-original
handoff alone returns original as its selected text (successful proposed briefs
also retain immutable intent as the existing engine requires).

Every review event has a monotonic `revision` and SHA-256 `digest` over the full
frozen request, brief, actual captured core registration/policy, expected binding,
query, provider identity, coverage, state, rendered proposal and process-session
identity. Length-prefixed components avoid ambiguous concatenation. This is an
equality guard, not a signature or authorization token. No approval object crosses
stdio. Both use actions must match the last emitted binding; stale bindings produce
a nonterminal `failure` code `ReviewRequired` without approval, permitting a fresh
explicit action. Prepared use while needs-input is likewise recoverable
`ReviewRequired` and retains the last preview. Questions block prepared use; provider failure permits only
explicit original or cancel with the failure event's binding. All other errors are
terminal. Bound exhaustion terminates with closed failure metadata if space permits.

Actual `ReviewSession.approve` and `handoff` re-read core for both choices. Changed
sources/root/policy/incarnation/snapshot invalidate review even after edit and even
for use-original. One handoff/cancel/terminal error/EOF/timeout ends the process.
Handoff returns exact reviewed text only; clipboard, host draft, downstream send,
execution and host admission are **not attempted**.

## Lifetime and limits

Session/control deadline <=300 seconds from CLI entry, including input waits.
Separate consent/provider deadline <=30 seconds; one call, <=1024 requested tokens,
existing full engine output <=8192 bytes. No retries, refunds or silent truncation.
An in-process watchdog enforces process exit at the session deadline, including
blocked stdio. One bounded stdin reader and watchdog are process-owned threads,
not independent workers/processes; process exit terminates them. No unsafe code,
global signal handlers or detached child process. The invoking parent owns actual
termination/reaping; cancellation/EOF closes cooperative provider I/O promptly.
OS scheduling and external server work are not hard-real-time guarantees. Tests
must prove idle/provider cancel, EOF, deadline and parent kill teardown. A parent
must not interpret absence of a final event (blocked pipe/kill/deadline) as success.

## Acceptance and exclusions

Dedicated synthetic actual CLI/SQLite/owned-loopback tests cover preview/edit/exact
fresh approval, stale rejection, questions, failure/original, source/namespace
changes, malformed/duplicate/unknown/oversized/trailing frames, input/output/queue
bounds and process lifetime. No plaintext persistence or second call; human notes
and core history remain unchanged. See `../progress/local-review-stdio.md` for
actual results, tested SHA and remaining gates. No GUI, live model, quality,
native adapter, host certification, authenticated IPC or phase-closure claim.
