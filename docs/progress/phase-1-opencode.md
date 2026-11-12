# Phase 1 — OpenCode V2 host-contract feasibility

Status: **bounded offline prototype only; Phase 1 remains open**.
Traceability: TM-05 (explicit refinement), TM-08 (host integration), TM-10
(privacy/control); P1-A2 **partial**, P1-A5 **non-extraction partial**.
No P1-A1/P1-A3/P1-A4 completion, product adapter, Phase 4 refinement engine,
extraction/indexing implementation, inference, site or deployment is included.

## Parent review and finalization

Joffrey independently reviewed the full experiment, including approval binding,
timeouts/cancellation, unknown admission and context ownership. No substantive
must-fix findings. All 48 tests passed in review; an additional read-only probe
resolving approval synchronously during deadline abort still admitted nothing.
The parent reserved ADR 0003 to avoid the extraction unit's ADR 0002 and limited
the dedicated workflow to this experiment's paths. These are offline engineering
results, not runtime approval. The owner authorized earlier foundation/site PRs
only; this new unit is not authorized for automatic merge or deployment.
The delegate snapshot below predates final commit/current-main integration;
final committed revision and exact-head CI must be recorded separately.

Final committed code revision after incorporating current main:
`8df9a11512a499286b2ecc2dcb80562954264074`. Parent reran all 48 Node tests,
`python3 scripts/check.py`, and `cargo deny --locked check` successfully on that
exact revision; staged/history Gitleaks and whitespace checks passed for the unit.
No runtime admission, SDK compatibility or full Phase 1 acceptance follows from
these offline checks. This subsequent edit changes only this evidence record;
the eventual PR head requires its own Linux/macOS/security CI.

## Provenance and environment

Public V2 documentation fetched on **2026-11-12 UTC**:

- [Plugin overview](https://opencode.ai/v2/docs/build/plugins): server/TUI/GUI
  package parts, loading/trust and version compatibility.
- [Server plugins](https://opencode.ai/v2/docs/build/plugins/server): Commands;
  Sessions; Hooks → Prompt admission, Model requests, Retry policy and Session
  reference. Only V2 behavior is used, not the page's V1 compatibility section.
- [JavaScript client](https://opencode.ai/v2/docs/build/client): request signals,
  live-only event streams, service discovery versus starting a service.
- [API reference](https://opencode.ai/v2/docs/api): experimental session routes,
  prompt/command/inbox/message/form surfaces and schema names. This is public
  documentation, not a query to the user's local server.

These are rolling docs, not a release-pinned SDK contract. The installed CLI
reported **`opencode v2.2.5`** from `opencode --version`. This establishes CLI
version only: no plugin SDK package/types were loaded or typechecked, no shared
service was queried/restarted, and no `/api` operation was invoked. Compatibility
between today's docs and the installed host is **runtime-UNTESTED**.

Execution: local macOS **27.0.1**, arm64, Node **v24.10.0**; standard library
only. Linux/macOS CI is configured but has **not run** for this uncommitted unit.
Canonical foundation base tested: **984703bfd73d5178a1748898bd95c97619d50438**
plus staged, uncommitted files. Assigned branch: `t3/a25a5bbd`. No final tested
change SHA exists yet. Parent must incorporate current main, review, commit,
retest and record the exact head and CI run before any acceptance claim.

## Capability matrix (labels must remain separate)

| Capability | Documentation-backed | Mock-prototyped | Runtime |
| --- | --- | --- | --- |
| Explicit command | `command.transform` adds executor receiving `{sessionID,prompt,delivery}`; executor may call `ctx.session.prompt` | Registration alone has zero admissions; capture is an injected port | UNTESTED |
| Approval boundary | No exact Threadmark review contract established by these sources | Separate preparation → review → exact-match approval → attempt latch | UNTESTED |
| Attachments/delivery | Command receives prompt attachments and `steer`/`queue`; prompt changes must update/remove mention offsets | URI/MIME descriptors, agents/skills and all other fixture bindings stay exact; mention fields rejected | UNTESTED |
| Prompt hook | Before resolution/durable admission; edits persist canonically; IDs readonly; no typed rejection API | Deliberately not registered or used | UNTESTED |
| Concurrent admission | Hooks once per admission, but concurrent submissions may run more than once; existing IDs may return original admission | Duplicate continuation of one invocation shares one promise/attempt; not cross-invocation deduplication | UNTESTED |
| Transient context | `context` edits outgoing calls only and runs on tool continuations; auxiliary hooks are separate | Opt-in evidence, owner-only snapshot deduplication, supplied turn/scope binding | UNTESTED |
| Cancellation/disconnection | Client accepts request signals; subscriptions are live-only, no replay/automatic reconnect | Closed/canceled/disconnected/mismatched/late reviews never send; local deadlines abort injected ports | UNTESTED |
| Admission acknowledgment | `session.prompt` returns `Session.Inbox.User`; inbox/message routes exist | `{admitted:true}` is an abstract fake acknowledgment only; unknown results never retry | UNTESTED |
| Provider policy | Prompt hook cannot be provider-scoped because model resolves later; model-call hooks can be provider-scoped | No provider selection, generation or policy changes | UNTESTED |

## Experiment contract and declared budgets

The [experiment README](../../experiments/opencode/README.md) identifies every
injected field that is **not** a host SDK affordance. Registration is never loaded
by a host. Core semantics, daemon orchestration and host ownership remain distinct.
No credentials, real drafts, active sessions, instructions, permissions, application
databases or host config were read/modified. Only public documentation was fetched;
the test program performs no network I/O. No model calls, tokens or cost.

The [provisional budgets ADR](../decisions/0003-opencode-offline-feasibility.md)
was written before tests: 4,096-byte input, 8,192-byte candidate, four descriptors,
1,024-byte context, 100 ms per preparation/review/admission stage, one preparation
and at most one deliberate admission attempt per invocation. UTF-8 bytes, not
character counts. No performance/memory/RSS or user-value benchmark is claimed.

Corpus: tiny in-memory synthetic widget request, one opaque `fixture:` attachment,
one agent/skill label, one constraint, both delivery modes, mutated bindings,
malformed/oversized responses, dependency failures and fresh/repeated tool-call
snapshots. This is a failure matrix, not a representative repository evaluation
corpus sufficient to complete P1-A5.

## Evidence and results

Local execution on the above base plus changes:

| Command | Actual result |
| --- | --- |
| `node --test experiments/opencode/contract.test.mjs` | 48/48 passed on final code run; finite synthetic run, 371.5 ms total; not host latency |
| `node --check` on both `.mjs` files | Passed syntax checks; no external linter installed or required |
| `python3 scripts/check.py` | Passed format/build/Clippy/workspace tests/docs/CLI and daemon diagnostics/local links; intentional failing Cargo assertion rejected |
| `cargo deny --locked check` | Passed advisories, bans, licenses and sources; cargo-deny 0.20.2 |
| `python3 scripts/secrets.py` | Passed after staging all six new files; tracked files/history clean and synthetic sentinel correctly rejected (Gitleaks 8.30.1) |
| `git diff --check` / `git diff --cached --check` | Passed unstaged/staged whitespace checks |

Tests directly assert fake-host logs contain **zero admissions** before approval,
on cancellation/closed/disconnected review, mismatch, daemon failure, malformed
or oversized output, unsupported attachment metadata and pre-canceled work.
Matching approval submits only the exact reviewed candidate; original fixture
is unchanged, and attachments/constraints/destination/session/scope/delivery
are compared. A repeated pending or settled continuation makes no extra attempt.
Lost acknowledgment, timeout, unrecognized result and cancellation after an
attempt remain unknown. Recovery from failed preparation requires a fresh
deliberate invocation/review, not a silent original-prompt fallback.

Context tests leave persisted fixture input and permission data unchanged,
preserve identical foreign text, repeat injection for a fresh tool continuation,
replace only known owned object references in a reused snapshot, and remove
owned parts when disabled/out of scope/turn. A deliberate counterexample shows
cloned/serialized owned parts are **not** deduplicated: do not call this a
certified host continuation solution or an exactly-once guarantee.

## Safe-mode decision and blockers

**Go:** keep this disposable offline harness and use it to refine the contract.
**No-go:** installed native refinement/send, automatic context, or any assertion
of OpenCode runtime support. No plugin installation or global/project config is
necessary or authorized by this experiment. No UI review integration was built.

Remaining blockers before even bounded live certification:

1. Isolated fixture host/provider with explicit authorization, no shared sessions
   and no real credentials/content/inference. Bind SDK package/version to the
   tested host, compile against actual types and test the packaged plugin.
2. Trusted native review lifecycle and diff rendering. Show original/candidate,
   attachments and destination; close/disconnect/navigation/crash must invalidate
   approval. A fake review port is not user authentication or host permissions.
3. Capture and independently validate actual project/worktree/revision/session
   location. `ctx.location` is plugin-instance location, not every session's
   location; synthetic supplied IDs and local equality are not authorization.
4. Full attachment fidelity: source resolution, binary/data/file handling,
   mention offset remapping, agent/skill behavior and other prompt metadata.
   This model rejects unknown fields rather than silently dropping them. Host
   limits are unknown; fixture limits are not advertised host limits.
5. Supported admission identity/reconciliation: client-generated IDs, concurrent
   submissions, process crashes and late acknowledgment. Readonly prompt-hook
   IDs do not prove a usable send idempotency contract. Provider retry is not
   admission retry; never blindly resubmit unknown work. Host queue acceptance
   is not completed execution or successful task outcome.
6. Real context ownership, stable turn identity, hook ordering and snapshot
   serialization across tool continuations, compaction and retries. Session hook
   reference exposes session/model/agent/system/messages, not a documented
   Threadmark turn field. Prototype `currentTurn` is supplied, not discovered.
7. Inference/provider budgets, consent, egress redaction and cancellation are
   excluded, not validated by a daemon fake. Abort signals cannot revoke an
   already admitted request or terminate uncooperative work. JS byte checks
   happen after receipt; they do not bound transport allocation/CPU or memory.

## Cleanup and handoff gates

Only experiment-owned source/docs/workflow files were created. No Docker,
listener, host resource, plugin config, external package install or content
history was created. Deadline timers and abort listeners are cleared on each
stage settlement; in-memory references are dropped, not securely erased.
Foundation checks produced ordinary ignored Cargo build output; it is left intact.
Scanner/failure-probe temporary directories use existing context-manager cleanup.

No independent review, commit, push, PR, exact-head remote CI, merge, deployment
or runtime acceptance occurred. Parent owns those gates and current-main
integration; this unit neither reads nor depends on unmerged extraction files.
No phase is closed by these local results.
