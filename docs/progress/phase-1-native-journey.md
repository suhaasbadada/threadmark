# Phase 1 — bounded native OpenCode journey source

## Scope and status

TM-02, TM-04–TM-08, TM-10; P1-A2/P1-A4/P1-A5 remain **open**.
Added a coherent native plugin source bridge in
[native-journey](../../experiments/opencode/native-journey/README.md): explicit
command → immutable deterministic synthetic preparation → location-scoped plugin
RPC → full native TUI confirm → one actual `ctx.session.prompt` attempt.
The previous offline abstract `admitted: true` receipt is not used here.

Primary observed installed host: OpenCode 2.2.5, macOS arm64, bundled Bun 1.4.4.
The authorized installed-host startup experiment stopped before readiness; see
the preserved failures below. No prompt was submitted. No compiler/SDK experiment,
dependency acquisition, real configuration change or provider call was performed.
Current verified runnable product remains
Phase 0 offline CLI, not a daemon listener, storage, inference or companion.

## Implementation evidence

- `server.js`: real SDK `Plugin.define`, command transform, RPC registration,
  cleanup and actual prompt admission API.
- `tui.js`: real TUI plugin, RPC event/claim, native confirm, manual missed-event
  recovery, exact decision and receipt toast; no JSX or new peer dependency.
- `rpc.js`: documented portable JSON-Schema RPC contract; no credentials in IDs.
- `kernel.js`: deterministic suffix preserves original prefix and mention offsets;
  stable digest binds exact scoped candidate; one session owner/claim and a
  synchronous admission latch; bounded review, unknown/no-retry semantics.
- Pure tests cover cancel/close/no-decision expiry, unload/abort, stale and
  mismatched decisions, competing UI owner, duplicate approval/invocation,
  unknown/fake/wrong receipt, hanging and late completion, dependency recovery,
  attachment limits and forbidden file/network URIs. These are not host proof.

## Initial implementation verification (historical)

Full tested base HEAD: `bda914e458ae7a29cad9715c8b62a4afad7ce5fa` plus this
uncommitted native-journey source and progress document. No commit was authorized;
there is no tested commit SHA for the new files. Parent's pre-existing progress
append was preserved without editing/staging it.

- New kernel tests: **18 passed**; existing Node experiments: **80 passed**;
  combined **98 passed**. All four new `.js` entry/kernel/contract files pass
  `node --check` (syntax only, not SDK resolution or typing).
- `python3 scripts/check.py`: passed (Rust format/build/clippy/tests/docs,
  foundation CLI/daemon finite diagnostics, doc links and failure-gate probe).
- `cargo deny --locked check`: passed.
- `python3 scripts/secrets.py` after staging owned files: passed; synthetic
  secret rejection probe passed. Documentation links and staged whitespace
  checks also passed.
- No new remote CI/run/head, independent review, host loading, native dialog,
  inbox admission, egress containment or functional acceptance was run. Prior
  branch CI is not evidence for these uncommitted changes. No phase closure.

## Remaining decisive gates

Follow the bounded 15-minute checklist in the source README. Stop on host SDK
resolution/load failure rather than installing a dependency universe. Native
RPC authorization/location semantics, event/dialog lifecycle, no-decision
disconnect expiry and actual zero/one inbox counts still require host evidence.
Inline synthetic text files only; resolved file bytes remain unverified until
external inbox inspection. Live branch/revision invalidation, context hooks,
daemon failure integration, inference, storage and redistribution hardening are
outside this unit and not advertised as implemented. Host after-admission work
is neither rolled back nor bounded by the bridge's Promise timeout.

## Primary safety correction and independent review

The public V2 [OpenAPI contract](https://opencode.ai/v2/openapi.json) describes
`POST /api/session/{sessionID}/prompt`: durable admission schedules agent-loop
execution **unless `resume` is false**. The previously approved authentic 2.2.5
client declarations expose the same optional boolean. The bridge now binds
`resume: false` into its candidate, displays admission-only behavior, and always
passes false at the irreversible call. This is documentation/declaration evidence,
not proof from the installed server, whose readiness gate did not pass.

Joffrey independently reviewed the meaningful source change against the approved
declarations. His P2 finding: input skill references lack the resolved receipt's
mandatory `name`, so direct equality incorrectly classified every skill receipt
as unknown. Primary fixed ordered skill-ID/mention comparison; resolved content
is explicitly unverified, not silently asserted equivalent. Added a realistic
resolved-skill receipt fixture, wrong-skill rejection and file-only receipt case.
All **20 focused tests passed** after these fixes. Registration/RPC/dialog API
signatures were review-clear; no independent review claims actual host behavior.

## Bounded installed-host experiment — STOPPED

Fresh owned HOME, all four XDG roots, temp/project directories and an allowlisted
environment; local package copied into the owned synthetic project. Global
experiment-only config disabled updates/snapshots and denied every provider/tool.
No inherited real configuration, source, credentials, services or sessions were
authorized. Default-deny macOS Seatbelt allowed only the installed host executable,
its same-binary child, public OS libraries, owned state, terminal devices and
metadata/sysctl reads. Network was denied, including local listeners.

Before startup, effective controls rejected an external-address TCP connect and
unowned `/etc/hosts` read with `EPERM`. The first `nc` control omitted verbosity,
returned exit 1 with empty stderr and was correctly treated as inconclusive;
adding `-v` exposed the denial, without changing policy. Early minimal `/usr/bin/true`
policy probes also failed until using the existing dyld mapping/root-read baseline;
they were not host launches or prompt admissions.

1. First host startup exited 1 at `TypeError: failed to initialize Segmenter`.
   Terminal diagnostics were preserved, not overwritten.
2. Primary authorized one proportional correction: read access to the two installed
   public `/usr/share/icu` data files, no egress/config/credential widening. Startup
   passed Segmenter but exited 1 with `Standalone server exited before reporting
   readiness`. Owned CLI log shows native spawn `serve --stdio --port 0`.
   Child failure cause is **not proven**; network or another denied OS operation
   remains a hypothesis, not an attributed root cause.
3. Stop: no more startup retries under this decision. No prompt input, command,
   review dialog, installed-server API contract, inbox count, provider policy
   effectiveness or zero/one admission behavior was observed. No provider/model/
   tool call was requested. These failures do not satisfy P1-A2.

Both direct startup processes reaped; a final owned-directory `lsof` check found
zero processes with owned files open. Owned synthetic files/logs remain private
for diagnosis; no broad cleanup or normal-host mutation occurred.

Private evidence SHA-256 anchors (no private paths/prompt-bearing logs published):

- Manifest: `1135338d2eee9ebfbaa7c24a9029fabb4016e7a79ad1748182b02aa3ef2e606b`.
- Original terminal: `ccffb9ce15a9c4b25f387baac312343e685cb42095b52c57f064cae1436e6435`.
- Corrected terminal: `22d3e183b5dd8bb977fbca21a8d53fdbe6c701437aeaa20e098f47a19a7688f4`.

Actionable next decision sent to the parent: use the documented dedicated
`serve --hostname 127.0.0.1 --port <owned-fixed-port>` and TUI `--server` route,
with permission only for that owned loopback endpoint and continued denial of
external network/unowned files. This preserves native review/admission architecture
and avoids an unpinned standalone port. That later authorized attempt is recorded
below; this earlier recommendation is not evidence that networking caused failure.
Verify its installed OpenAPI admission-only semantics and effective provider denial
before submitting anything. If unavailable, retain this boundary rather than
building another sandbox/package-manager framework. Runtime redistribution notices
remain unresolved and separate; Phase 1 remains open.

## Authorized fixed-loopback alternate — STOPPED AT RUNTIME CRASH

Parent approved one further bounded dedicated-server/TUI route with no external
egress. Reused the same private HOME/XDG/project, environment, local bridge and
ICU-corrected profile. Added only bind/inbound/outbound permission for one selected
available localhost TCP port; dedicated server requested `127.0.0.1` explicitly.
External-address TCP and unowned-file controls again returned `EPERM` under that
exact policy. Neither normal-host configuration nor provider credentials were used.

Actual `opencode serve --hostname 127.0.0.1 --port <owned-port>` terminated with
`SIGTRAP` (exit -5) before readiness. Retained stderr identifies Bun 1.4.4
`38afee6c8`, macOS 27.0.1 arm64, `panic(main thread): Trap instruction`, elapsed
83 ms. The trap's cause is **unknown**; no attribution to networking, plugin code
or a specific denied operation is established. No speculative fix/retry followed.

Because readiness failed, the installed server's OpenAPI contract and effective
provider policy could not be inspected. No TUI client, prompt, native command,
review or inbox admission was attempted. Documentation-backed `resume: false`
remains distinct from verified installed-host behavior. Both attempts failed
before the P1-A2 behavior test; they cannot be advertised as zero/one host proof.

Owned server process group was terminated/reaped; final owned-directory `lsof`
found zero open-file processes and the selected loopback listener was closed.
Preserved synthetic state and failed diagnostics privately, with no broad cleanup.

- Final private manifest SHA-256:
  `6bd25c6c3b26f080e5f6404459cd5988996fbdc7c451ba6d2c890658b87b05d6`.
- Dedicated-server terminal SHA-256:
  `9117fc39e2238e0c0623f6717540074ab9bc3c5cff8ef1e9eecbe574ebf8374b`.

Reported precise boundary to parent and stopped host experiments. Next trust
decision: an existing disposable VM/OS environment with isolation outside Bun and
no real credentials/config/source mounted, if available and explicitly authorized,
or upstream runtime diagnosis before further host work. No provisioning, spending,
new runtime install, policy widening or third attempt is implied. A draft-only
handoff is a different partial capability, not a silent replacement for admission.
The native architecture/full product scope and outstanding phase gates are intact.

Parent subsequently **paused all native-host launches**. No VM, OS account,
alternative runtime, broader filesystem/Seatbelt/network policy or new trust
boundary is approved. Smallest diagnostic needed before reconsideration: identify
the dedicated server's Bun trap from the retained exact-version crash output and
upstream/runtime symbols or a documented supported requirement. No root cause can
be inferred from the trap address alone; diagnostic execution itself needs the
applicable authorization, not another silent launch. Continue independent Phase 1
work while retaining this block.

CI now runs the focused kernel tests on Linux/macOS in the existing offline host
and integrated workflows; syntax-only entrypoint checks do not load the host SDK.

Final local source checks: **100 Node tests passed** (20 focused plus 80 existing),
four syntax checks passed, foundation `scripts/check.py` passed, cached/offline
`cargo deny --locked --offline check` passed, staged secret scan and whitespace
passed. No new Python scope changed; full Python/runner suites remain remote CI
gates rather than a newly claimed local run. Publication head/run tracking follows
after the source commit; existing unrelated long-progress append stays unstaged.
