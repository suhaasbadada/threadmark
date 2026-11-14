# Lane J — Finite private-stdio refinement review

**TM-04–TM-07, TM-10; bounded P4-A1–A4 and P2-A1/A2/A6.**
The contract was written before implementation in
`../contracts/local-review-stdio-v1.md`. This closes the one-shot CLI preview's
process-lifetime gap only; no native wiring, GUI, quality, real model, authenticated
IPC, listener, daemon, host delivery or phase closure is claimed.

## Implementation and authority

`refine review PROJECT QUERY` reuses the F parser and exact required explicit
profile/model/endpoint/expected registration/snapshot/confirmation flags.
`refine preview` remains unchanged. First typed JSON frame supplies original only;
all source selection uses reviewed `ReviewSession.capture_bound` and actual core
`Store.query_bound`. No caller source evidence or authorization echo exists.

The new daemon `review_session` module retains the real `ReviewSession`/`Engine`,
`ConfiguredProvider`, `LoopbackHttp` and `CaptureBinding` through preparation,
preview, edit, explicit approve and handoff. One call, no retries/refunds or calls
after edits. Only objective/output-expectations prose may be edited; questions,
unknowns, intent, evidence and destination cannot be supplied or cleared. Questions
block prepared use. Provider failure retains original privately for explicit
original/cancel; no automatic fallback. Core is revalidated at preview, approval
and handoff for both choices, including original after provider failure.

Every emitted review binds a monotonic revision and length-prefixed full-binding
SHA-256 digest, including process-session identity. Edits change the challenge;
stale approval and prepared-while-needs-input produce recoverable ReviewRequired,
never approval/handoff. The actual opaque engine Approval remains internal and is
created only on explicit matching use actions. It is not a signed receipt or auth
credential. Handoff returns exact reviewed text and DeliveryNotAttempted only;
clipboard, draft, send, execution and downstream admission are not attempted.

Strict typed serde decoders reject duplicates, unknown fields, trailing JSON and
arbitrary commands. Strings are JSON escaped. The reader checks <=8192-byte frames
including LF before parsing, eight frames/65536 bytes per direction, one queued
input, and reserves the eighth output for a terminal bound error. Whole output
overflow rejects without truncation. Provider consent is <=30 seconds/one call/
1024 requested tokens; independent review Control/process deadline is 300 seconds.

The CLI owns two in-process threads: bounded input reader and monotonic deadline
watchdog. Cancel/EOF/framing failure immediately signal the same engine Control,
including while HTTP waits; existing transport checkpoints close its socket. No
child/independent process, unsafe code, signal handler or daemon/global configuration
exists. The invoking parent owns termination/reaping. At the hard process deadline
the watchdog exits even if input/output/core is blocked: a final event is not
guaranteed, and EOF without a completed handoff is never acceptance. OS scheduling
and cancellation of independently operated server work are not guaranteed.

## Dependency and scope accounting

Typed duplicate/unknown-field rejection needs derive-backed serde; the full review
challenge needs SHA-256. Both were explicitly permitted in the task and already
workspace pinned: serde `=1.0.229` with existing derive feature, sha2 `=0.11.1`.
Cargo generated only the daemon's two new direct dependency edges. No package,
version, checksum, features or provider transport dependency was added/changed;
the lockfile was never hand-edited. No native/core/refinement implementation or
schema changes. F module helpers gained crate-only visibility for reuse; CLI root
routing and strict parser gained review-command admission only.

## Synthetic acceptance evidence

Dedicated `crates/cli/tests/local_review.rs` uses actual child CLI processes,
synthetic SQLite stores and owned numeric-loopback servers. Accepted macOS sockets
are explicitly blocking; accept/read/write/wait deadlines are bounded. Fixture
cleanup removes only fixture-owned directories. No Docker, real provider, keys,
environment credential reuse, user data, desktop capture, spend/install/deploy or
host launch was used.

| Acceptance | Evidence |
| --- | --- |
| P4-A1/A3 | Escaped UTF-8 original/action-looking embedded newlines remain data. Actual preview → edit → new preview → stale reject → fresh prepared handoff equals exact edited engine proposal. Human-note history and sources remain unchanged; owned SQLite/WAL scan finds no original/edit/provider plaintext. |
| P4-A2/A4 | Root/identity/incarnation/snapshot capture mismatches and missing confirmation contact no provider. Source, policy, replaced root, same-root re-registration and reindexed snapshot changes after edit block both choices. Changed source also blocks original after provider failure. |
| P4-A3/A4 | Questions survive edits and block prepared use recoverably. Provider failure returns closed metadata; only explicit original returns byte-exact original. No second provider call. Queued old approval cannot approve an edit (stale rejection or bounded queue failure). |
| P4-A3 | Actual provider/idle cancellation and EOF terminate/reap promptly without waiting for 30-second call deadline. Parent kill with stdin open closes stdout: no independent worker retains its pipe. No late handoff. |
| P4-A3 | Duplicate/unknown first and nested action fields, external duplicate tags, trailing/malformed JSON, invalid UTF-8, oversized original/frame, partial EOF and premature actions close with closed metadata. Eight-frame exhaustion closes; direct unit tests prove single-slot overflow cancellation, newline-inclusive bounds and output-slot/total/whole-frame rejection. |

The real 300-second production CLI idle-deadline test and 30-second provider
deadline test are intentionally ignored in the ordinary fast gate and invoked
explicitly; results are recorded below. No testing-only production timeout/env
override. The process deadline is armed before even flag-error output, so blocked
output on that path is bounded too. All review errors are closed JSON metadata;
no diagnostic prose is printed to stderr.

An output I/O failure permanently closes the output budget: no error JSON is
appended after a possibly partial frame, and attempted bytes cannot evade session
bounds. An actual owned broken-pipe fixture verifies prompt failure/reaping, no
retry, no stderr diagnostics and no content persistence. The contract also makes
parent pipe ownership explicit: keep stdin open through review, obtain human
choice, and wait/reap; prequeued transcripts are not approval interactions.

## Base and verification

Assigned checkout began at `661bdb3e11118efe979cc7adf06c39db723bf133`.
Reviewed `origin/main` `9daf74e9823e8037963b3ba46e28af2ff406584f` and exact local
published-evidence F integration `919b620` were merged in place, without branch
switch, reset/discard or extra worktree. Required reviewed local
`5bfca96bbb9a6e5cc70303d7f66931de68c65857` is an ancestor.

Final tested SHA/check counts and limitations will be appended after the gate.
Remote CI/head/run and independent review: **not run by this child**. Primary owns
review, publication and integration/CI. No push, PR, merge-to-main, scheduler,
watcher or subdelegation. Plum thread lookup was unavailable; no coordination
message or automatic follow-up is claimed.
