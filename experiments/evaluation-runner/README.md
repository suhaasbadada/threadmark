# Bounded OFFLINE SMALL worker prerequisite

**TM-02/04/07/10; P1-A1/P1-A5 PARTIAL. Phase 1 OPEN.** Python 3.10+ stdlib,
POSIX main thread only. Not a daemon, installed host, sandbox, comparative pilot,
benchmark, study orchestrator or product knowledge core. The full context,
refinement, OpenCode/T3, inference, UX and safety scope is unchanged.
[ADR 0006](../../docs/decisions/0006-phase-1-evaluation-protocol.md) remains
prospective. This README declares the protocol **before any actual worker run**.

## Review and execution gate

```sh
python3 -B -m unittest discover -s experiments/evaluation-runner -v
```

The child implementation launched **only authored lifecycle fixtures**, never
`worker.py`. Parent subsequently repaired a review finding and obtained fresh
independent review of `dedfeaa89ed4b94310b0d342a18a3d96984ace25`, then verified
all lifecycle gates before launching tiny actual-SMALL transport conformance.
That passed for both arms and both roots; the suite and CI now retain those four
fixed cases in one additional test. This is not quality/performance evidence.
There is deliberately no CLI that launches actual evaluation, no default run,
study loop, repetition/order scheduler, scoring report or fake cache measurements.

## Exact public input and preflight

`Runner().run(arm, project, *, recipe="small", cancel=None)` accepts only exact
strings `lexical` / `symbol` / `candidate`, `harbor` / `harbour`, and `small`. Project selects
the fixed `*-fixture-worktree-1` and `*-fixture-revision-1` labels. Task is fixed
`definition_directcall`, unchanged original corpus query and instructions. No
family/query/command/executable/module/path/profile/environment/plugin/pin,
caller budget or fixture override is accepted. Labels are consistency values,
not authentication. Optional cancellation is an exact stdlib `threading.Event`,
not arbitrary callback code. SIGINT/SIGTERM also request cancellation. Pre-set
events reject before launch; active checks occur at most 20 ms apart while
reading, subject to ordinary OS scheduling (not a hard-real-time guarantee).
Only the main thread can own one invocation per interpreter at a time.

Memory enforcement is **unavailable**, no peak-RSS measurement is claimed, and
medium/large reject BEFORE launch. Other fixed ADR ceilings remain unchanged:

| Limit | Policy |
| --- | --- |
| Worker wall | 30 monotonic seconds, measured from before pipe/process creation |
| Output | 16 MiB aggregate stdout **plus** stderr, including inherited descendant writers |
| Cleanup / cancellation | 2 monotonic seconds from starting termination; failure is unverified, never success |
| Candidate / original | 8192 / 4096 decoded bytes, plus actual merged contract checks |
| Network / inference / spend | zero |
| Trial | no trial implemented; ADR's 30-minute prospective trial ceiling is unchanged |

Private `_fixture` selects only the fixed authored lifecycle file/mode with
**stricter test-only** 1 s wall / 16 KiB combined output. These are NOT study
thresholds or public budget knobs. Privacy is a Python ownership convention,
not protection against arbitrary same-interpreter code or monkeypatching.

## Fixed launch and input protocol

Each invocation owns a mode-0700 temporary tree and fresh process. Its clean
environment contains only HOME, XDG_CONFIG_HOME, XDG_CACHE_HOME, XDG_DATA_HOME,
XDG_STATE_HOME, TMPDIR, LANG, LC_ALL and fixed PATH. Each state path is owned;
no credentials, PYTHONPATH, DYLD settings, user configuration or caller env is
inherited. `sys.executable -I -S` launches the reviewed shared supervisor and
then exactly adjacent `worker.py` (or the test-only lifecycle fixture). Worker
imports add only the fixed reviewed checkout root. Standard input is null;
only the supervisor inherits the three owned control/status/readiness channels,
not the target. No generated Rust/Python source is compiled, imported or executed.

Actual worker builds the actual frozen `corpus.build("small")` and calls actual
`candidate.build(..., method=arm)` for exactly that selected project/task. It
does not bypass admission, alter ranking or expose oracle/fixture/private coverage
to retrieval. Existing candidate/adapter/scorer APIs, algorithms and pins remain
unchanged. No file discovery, corpus export, network, provider, host, clipboard,
listener, configuration modification or login startup is implemented.

Input is only the fixed launcher argv: arm and project. There is no stdin request
stream or caller content. Exact authored SHA-256 file bindings are captured before
launch, included by the worker and checked again before output admission. They
cover runner, worker, supervisor, corpus, adapter, candidate, scorer and both
baseline retrieval implementations, directcall and shared `_trusted.py`. Candidate
policy/source/grammar pins check before launch; all file bindings recheck immediately
before spawn, after cleanup/admission and at final ownership return. They are local code integrity bindings, not
signatures or a defense against concurrent hostile checkout changes.

## Output protocol v1 (no trailing newline)

Exactly one canonical ASCII JSON object: sorted keys, compact separators,
`ensure_ascii=True`, no NaN, duplicate keys or trailing bytes. Unknown/missing
fields, malformed/partial/non-UTF8/trailing content, nonzero target exit or any
stderr content close admission. stdout and stderr are separately retained only
within their shared bound; neither is echoed in results, errors or logs. Reads
are at most 4096 bytes; a detecting overflow read can count up to 4096 bytes past
the ceiling, but that chunk is NOT retained/admitted. No unlimited communicate.

Exact top-level fields:

- `schema`: `evaluation-runner/1`; `state`: `complete`.
- `arm`, `recipe`: exact requested arm, `small`; `family`: `definition_directcall`.
- `scope`: exactly the three fixed selected labels.
- `corpus_pin`: `c497a577eb9699d15da30b02a215784df36bafeafcb643c83c983ba540e6c9e8`.
- `bindings`: exact fixed relative authored-file names and SHA-256 values.
- `result`: exactly `status`, `reason`, `original`, `candidate`.

Byte fields are canonical base64 or null. Accepted status/reason pairs are ready /
admitted_limited_envelope, blocked / preparation_rejected or admission_rejected,
and unavailable / preparation_unavailable, retrieval_unavailable,
admission_unavailable or final_return_unavailable. No provisional response exists.
Closed results MUST have null candidate. The validated original is preserved when
present, as in actual candidate's contract. Ready requires both original and
candidate. Parent admission reconstructs the actual frozen small adapter case,
checks exact original bytes and independently invokes actual merged scorer
admission against its complete source map/coverage/rejection bindings. No retrieval
is performed in that validation. Metrics are discarded. Source-map `complete`
means the existing LIMITED frozen envelope, never language/extractor completeness.

For `candidate`, both builder and parent re-admission use the same private
normalization helper. Parent rebuilds the real frozen SMALL adapter case and
reconstructs policy/full observations from **all** selected public sources using
`directcall.extract`, never retrieve/ranking or a worker-supplied Fixture. Exact
compact policy/observation commitments append to the unchanged adapter coverage;
the actual scorer still validates the entire canonical candidate, original and
all source anchors. Same-extractor consistency is not an independent semantic
oracle or runtime proof. Unknown code/grammar/policy states close; historical
standalone pending policy is not permission to launch this integration.

**Actual candidate-arm worker: NOT RUN by implementation child.** New tests use
pure `_admit` bytes from actual public candidate builds; prelaunch rejection spies
never spawn. Existing reviewed lexical/symbol worker regressions still run. Parent
must freshly review this integration, record committed pins and add/run the first
candidate-worker positive case only after review. See
[integration handoff](../../docs/progress/phase-1-evaluation-directcall-admission.md).

Frozen public `Result` contains status, cleanup, aggregate output byte count,
target exit code, candidate/original ephemeral immutable bytes, and
`memory_enforcement="unavailable"`. Apart from those explicitly admitted bytes,
fields are source-free operational metadata. Operational statuses include ready,
blocked, unavailable, preflight_rejected, owner_unavailable, dependency_failure,
canceled, timeout, output_overflow, worker_failed, protocol_rejected,
cleanup_unverified and quarantined. Cleanup is not_launched / verified /
unverified. A transport/protocol/cancellation/cleanup failure returns no bytes;
there is no last-good fallback, persistence or automatic retry.

## Ownership, deadlines and verification order

1. Reject unsupported input/tier, concurrency or quarantine; install signal
   handlers and test pre-cancel. Create bounded fresh owned state.
2. Block SIGTERM/SIGINT around Popen ownership recording. Restore prior mask
   only after recording owner and closing parent copies of write descriptors.
3. Reuse `host-isolation/process_supervisor.py`, not a copied supervisor. Its
   original argv/status contract remains compatible. An optional PRIVATE
   `--ready-fd` reports the owned target PID (or zero for launch failure).
   Target receives none of these private descriptors. Status is its separately
   bounded integer exit plus newline (or `launch-error\n`), only AFTER target wait.
4. Read stdout/stderr/status/readiness concurrently against monotonic deadline;
   status and readiness each have a 32-byte cap. EOF is NOT cleanup proof.
5. On every launched path, wait boundedly for target ownership readiness (including
   launch-boundary cancellation), keep the control pipe open, send group TERM,
   allow at most 0.5 s for cooperative exit/reaping, send final group KILL, THEN
   reap the immediate supervisor within the remaining 2 s cleanup deadline.
   Never poll/wait/reap that leader before the final group signal. No PID reuse
   window is introduced. Signal handlers, FDs and temp state are restored/removed.
6. Require target status from its owner's actual wait. Fixed actual worker and
   its reviewed dependencies create no descendants. Descendant fixtures require
   an independently recorded cooperative child-wait attestation, matching target
   identity and absent child PID; tests additionally check worker/child PID absence.
   Missing identity/status/attestation or cleanup errors produce unverified.
7. Only after verified cleanup validate the full protocol and admit bytes. An
   active cancellation still closes admission at final return, including after
   temporary-state removal and final resource restoration. Missing cleanup proof
   retains precedence over an ordinary canceled result.

On owner death, the retained supervisor control pipe sees EOF, sends TERM, gives
its existing at-most-0.5 s cooperative target-wait opportunity, and group-KILLs
itself. Tests kill the runner owner with SIGKILL and verify actual recorded worker
and descendant reaping/absence. Temporary state cannot be removed by a dead owner;
the outer test owns and removes those observed crash artifacts after verification.
This does NOT claim orphaned supervisor reaping by Python on macOS/Linux.

These are **cooperative process-group / fixed authored-code guarantees**, NOT
universal containment: no setsid escape test or adversarial orphan-grandchild
reaping claim. No sandbox/host policy is added or broadened. The runner cannot
authenticate an arbitrary worker's self-report or enumerate every OS process.
An unaccounted descendant or missing cleanup proof blocks further invocations
via a process-session quarantine latch shared by ALL Runner instances; there is
no public reset API and no global disk state. The unverified test deliberately
omits required attestation without leaving a live child. A dead owner's session
cannot resume; restarting evaluation after a crash requires operator review of
owned cleanup, not treating a new process as evidence of prior cleanup.

## Evidence and remaining gates

Fixture protocol success is a **closed** response, never a fabricated admitted
candidate. Unit fixtures exercise mixed-stream/descendant overflow, active Event
and SIGTERM cancellation, launch-boundary SIGTERM, timeout after output closure,
malformed/partial/foreign scope/revision/arm/pin/bindings, dependency/nonzero
failure, owner death, verified fresh recovery and quarantine after missing proof.
The parent added actual worker positive transport admission only after fresh
independent review and passing lifecycle negatives. The additional conformance
test uses normal `Runner.run` for both arms and roots; no study, generated-source
execution, host or inference operation is authorized or inferred from it.

There is no index/cache in the worker: immutable input, fresh process only.
Neither cold/warm measurements nor OS page-cache eviction are claimed. Full-study
environment/run manifests, comparative protocol, candidate integration review and
first worker conformance, representative outcomes, hard memory enforcement/scaling and all host/
inference/UX acceptance remain separate gates. See [local evidence and parent
handoff](../../docs/progress/phase-1-evaluation-runner.md).
