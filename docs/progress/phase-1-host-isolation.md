# Phase 1 — Synthetic host-isolation prerequisite

Status: **synthetic guard and exact-head CI passed; installed OpenCode version
diagnostic remains blocked, not host certification**. TM-02,
TM-04–TM-08, TM-10. P1-A2 prerequisite; partial P1-A5 capability evidence.
P1-A2 admission/approval acceptance and Phase 1 exit are **not established**.
No extraction or OpenCode mock experiment files are dependencies or modified.
Budgets were set before probes in [ADR 0004](../decisions/0004-synthetic-host-containment.md).

## Current evidence — bounded version diagnostic, 2026-11-12 UTC

The sections below this update retain earlier implementation and delegate
snapshots. Their pending-CI and never-launched-host statements describe those
earlier stages, not this later version-only diagnostic. No service, plugin,
session, provider, prompt, admission or host integration was exercised.

### Exact-head synthetic CI

PR #5 remained open/unmerged at full head
`dbcc3cf2d4639891ba1de647acd5971e6db2621f`. All six checks passed:
[foundation CI](https://github.com/suhaasbadada/threadmark/actions/runs/43191936827)
and [synthetic isolation](https://github.com/suhaasbadada/threadmark/actions/runs/43191936937),
including the real macos-15 guard. These runs establish the synthetic contract
at that head only, not the later installed-binary diagnostic or this evidence
update's eventual CI head. Independent supervisor reviews and focused repairs
are recorded below; no new independent review of the version diagnostic is claimed.

### Confirmed original trap

An unchanged filesystem-only policy launched installed OpenCode **2.2.5** with
only `--version` under the existing reviewed, bounded supervisor. Disposable
HOME/XDG state, constructed environment, closed inherited descriptors and default
deny networking remained in force. A wrapper recorded its PID before `exec`;
PID and timestamps precisely matched the owned crash report. At
`2026-11-12T10:19:39.441397Z` through `10:19:39.994368Z`, exit was **-5** with
662 captured diagnostic bytes. The synthetic outside canary was unchanged and
the owned fixture root was removed. No raw report or private path is published.

The report's original exception offset, normalized to the executable's static
image, was `0x10002b254`. Static LLDB disassembly (no attachment or execution)
identified `WTF::pageSize()`, `PageBlock.cpp:64`, a `brk #0` after the call to
`sysconf(29)` (`_SC_PAGESIZE`) and its power-of-two assertion. The bundled Bun
revision is `38afee6c84fcf48c0edb2466aa4b27d287a59c30`; its WebKit pin
`d6375c72affe0f70222cdcb45012b10f0bf3a9d5` confirms this
[page-size implementation](https://github.com/oven-sh/WebKit/blob/d6375c72affe0f70222cdcb45012b10f0bf3a9d5/Source/WTF/wtf/PageBlock.cpp).
The blank OS-version diagnostic is not the established trap cause. Broad Mach,
JIT or sysctl requirements were not established by this evidence.

### Narrow diagnostic allowance and remaining failure

Apple's installed `container.sb:95` explicitly names `hw.pagesize` and
`hw.pagesize_compat` in its sysctl-read rules. A disposable diagnostic appended
only `(allow sysctl-read (sysctl-name "hw.pagesize" "hw.pagesize_compat"))`;
no system profile was imported, and **the committed harness policy was not
changed**. `/usr/bin/getconf PAGESIZE`, separately allowlisted as the sole
executable for its fixture, produced:

| Policy | Exit | Result |
| --- | --- | --- |
| Unchanged filesystem-only profile | 71 | No numeric page size; 52 diagnostic bytes |
| Same profile plus the two named reads | 0 | `16384`; 6 output bytes |

This isolates the page-size access restriction, but does not distinguish which
of the two names is individually necessary. No general sysctl access is justified.

With only those named reads added to the OpenCode version fixture, the attempt
at `2026-11-12T10:21:56.992178Z` through `10:21:57.640172Z` exited **1**, not
the original trap, with 2421 output bytes; output was **not** the expected version.
A same-policy diagnostic confirmed exit 1 and the same byte count. A restricted
error-marker scan found no `SIGTRAP`, `EPERM`, `EACCES`, `ENOENT`, assertion,
syscall identifier or JavaScript frame-name match; it does not diagnose the new
failure. Raw output was not published. Every fixture's outside canary remained
unchanged and every owned root was removed. Execution used the existing five
second/process and 16 KiB/output limits with cancellation/group cleanup.

**Outcome:** the original page-size bootstrap blocker is localized, but successful
`--version`, complete installed-host containment, P1-A2 and Phase 1 exit remain
unverified. Further runtime allowance needs evidence of the actual failing
operation and separate review; do not infer permission to widen the policy or
invoke a service. No runtime/source/policy changes, host configuration changes,
listener, credential reuse, provider access, merge or deployment in this update.

Evidence-only update verification: `python3 scripts/check.py`,
`cargo deny --locked check`, staged `python3 scripts/secrets.py` and
`git diff --cached --check` passed. No runtime file changed; the 25 portable
tests and real synthetic guard are retained at the exact green CI head above,
not claimed as rerun for this documentation update. The final evidence commit
and its new CI run/head are recorded on PR #5 after publication.

## Parent investigation and current results — 2026-11-12 UTC

The initial delegate result below failed closed. Parent investigation of the
experiment's own crash identified dyld `ignition_halt` / `boot_boot`; the installed
Apple `dyld-support.sb` explicitly documents ignition opening `/`. Adding read
permission for the **literal root directory only**, not its subtree, allowed the
same synthetic filesystem/process probe to pass. No system profile was imported,
and no HOME, user configuration, Mach services or arbitrary executable access
was added. Raw crash reports and machine identifiers are not repository artifacts.

The numeric IPv4-only SBPL contract is unsupported here. Rather than silently
equating it with `localhost`, the parent declared and tested a different synthetic
endpoint contract: **one owned TCP port on both 127.0.0.1 and ::1**. All permitted
listeners are bound before launch and kept open by the supervisor. Extended C
probes establish successful connection to both address families at that port,
denial at a second owned port on both families, and UDP denial at the permitted
port. The supervisor independently observes expected TCP arrivals and no denied
TCP/UDP arrivals. This is a dual-stack loopback-port experiment, **not proof of an
IPv4-only rule, every loopback alias, DNS behavior or universal zero egress**.
No external endpoint was contacted. A local alternate IPv4-loopback bind was
unavailable; no interface alias or OS setting was changed to enable it.

Current local commands: all **25 portable tests passed**, including actual
SIGTERM and timeout cleanup; the full synthetic guard returned
`result=synthetic-only-pass`, `host_launched=false` on Darwin 27.0.0 arm64.
The SDK resolver accepts the installed CLT SDK or a bounded `xcrun` lookup of an
installed system Xcode SDK; it never installs tools or accepts arbitrary SDK paths.
Joffrey's first safety review found two supervisor defects: group signaling after
leader reaping (PID reuse risk), and cancellation before `Popen` ownership was
recorded. The repaired supervisor uses a dedicated unreaped session/group leader
with a private target-status pipe; all group signals precede its only reap.
SIGTERM/SIGINT are blocked across spawn/ownership recording and then delivered
inside cleanup protection. Regression tests check signal/reap ordering and actual
launch-boundary SIGTERM. The first wrapper repair exposed a launch-error cleanup
failure, repaired by retaining the leader on that path too. Joffrey's follow-up
review verified both original findings repaired and found one further defect:
owner death was not monitored during target execution. The helper now monitors
owner-pipe EOF concurrently with target completion and terminates the owned
group; an actual EOF regression proves ordinary target reaping. All 25 tests
pass with ResourceWarning treated as error, and the real local synthetic guard
still passes. This last focused repair was verified by the parent, not a third
independent review. No review finding was waived or converted to a success claim.
No installed host or host plugin has been launched. macos-15 CI remains required
before this unit can be accepted; review and repairs are recorded above. Even a passing
synthetic guard does not authorize host-specific permissions or real admission.

Full committed code revision after current-main integration:
`d5de9e12cec28b339e41539328ee06851b960335`. On this exact revision the parent
reran all 25 portable tests with ResourceWarning as error, the actual synthetic
macOS guard (`host_launched=false`), and the full foundation check script: all
passed. Staged/history Gitleaks, cargo-deny and whitespace checks also passed for
the unit. This follow-up is evidence-only; the final PR head still requires its
own CI. No automatic merge, new publication or installed-host test is authorized.

## Delegate snapshot before parent repair

The sections below retain the initial failures, original two-listener protocol
and then-unmet prerequisites as historical evidence, not current passing claims.

## Version, execution location and syntax sources

- Local Darwin 27.0.0 arm64; Python 3.12.6; Apple clang 21.0.0
  (clang-2100.3.34.2), installed Command Line Tools SDK.
- Assigned T3 worktree, branch `t3/phase1-host-containment-harness`.
  Tested base HEAD `984703bfd73d5178a1748898bd95c97619d50438`; additions are
  staged/uncommitted, so no commit SHA represents the changed tree yet.
  Parent supplied newer main `7b3f8ad4dabdfe1f675601864c42a61977b1048d`;
  parent owns integration and retesting. No branch switch or worktree creation.
- Read local `sandbox-exec(1)` (deprecated; `-f` profile-file), `sandbox(7)`
  (inheritance and already-open file descriptor caveat), and Apple-installed
  `/System/Library/Sandbox/Profiles/{bsd,system,dyld-support}.sb`.
  Syntax examples: version, deny default, literal/subpath, process-fork,
  process-exec, file-read/map/write and network-outbound/remote tcp.
  `com.apple.AssetCacheTetheratorService.sb:49–52` shows localhost endpoint
  syntax; `system.sb:43–55` shows runtime-library mapping syntax.
  `dyld-support.sb` warns of private unstable interfaces and broader cryptex
  bootstrap allowances. None of these profiles is imported or modified.

## Owned resources, policy and permission requirements

One private temporary root (0700), private HOME/config/cache/data/tmp/database
directories, synthetic outside canary, inside state canary and symlink, generated
profile files (0400), compiled synthetic probe (0500), two ephemeral IPv4 loopback
TCP listeners. Parser-negative profiles contain no secrets. The C fixture receives
only synthetic canary path and ports. No listener/database/product service is
added to Threadmark. No Rust/runtime code changes.

Default-deny filesystem/network/process policy. Only fixture exec, fork for
inheritance checks, own state read/write, `/usr/lib` and `/System/Library/dyld`
read/map, and one numeric TCP loopback destination are described. No allow-default,
policy imports, broad HOME/System/Library access, Mach service allowances,
DNS/UDP/nonloopback allowances, listening or executable-child-service allowance.
System/global OpenCode and managed-preference paths have no allowance; portable
tests check that structurally, without opening/statting real configuration.

Environment is constructed from scratch, not filtered from inherited secrets.
Child stdin is null, stdout/stderr pipes, inherited descriptors closed. Temporary
roots and both listener sockets are context-owned and removed/closed even on
failure. Process groups receive TERM, bounded grace then KILL; direct children
are waited. Portable fixtures demonstrate cooperative descendant reaping, not
adversarial orphan reaping. No sudo, entitlements, firewall/OS/global settings,
installed OpenCode, plugins, sessions, admissions, credentials, user config,
models, providers, external endpoints, Docker or downloads were used.

## Local commands and observations

1. `python3 -m unittest discover -s experiments/host-isolation -p 'test_*.py' -v`
   — **21 tests passed**, 2.678 seconds after staging. Policy validation/escaping,
   clean environment, unsupported OS/missing tool/unknown CLI rejection,
   parser-failure control, dependency failure cleanup, positive/negative process
   status, bounded output, timeout including closed stdout, actual SIGTERM and
   cooperative child-group termination/reaping all passed. These are portable
   supervisor/policy tests, **not successful macOS containment probes**.
2. `python3 experiments/host-isolation/harness.py --synthetic-guard`
   — **failed closed**, exit 1: `filesystem/process guard failed (exit -6);
   no host may launch`. Compilation succeeded after specifying installed SDK;
   initial ambient header search had failed compilation under `-Werror`.
   This SDK selection is build-only, not a sandbox-policy relaxation.
   Unknown operation and malformed SBPL profiles each returned exit 65 before
   the fixture produced state. Narrow filesystem/process policy compiled but
   fixture aborted without captured diagnostics. No broad bootstrap allowances
   were imported to force startup.
3. Earlier exact-network-policy attempt — sandbox compiler exit 65:
   `host must be * or localhost in network address`. Numeric
   `remote tcp "127.0.0.1:<owned-port>"` was rejected, so no network probes ran.
   The final harness keeps this exact policy fail-closed; it does not silently
   substitute localhost (whose address-family/address breadth is unvalidated).

No successful sandboxed own-state write/read, outside-canary denial, inherited
child denial or allowlisted endpoint connection is claimed: runtime startup
currently blocks those probes. Outside synthetic canaries remained unchanged
on observed failures. DNS/UDP/nonloopback and real configuration denial are
**policy inspection only**, not packet-level or real-file-access evidence.

4. Instrumented repeat of the real guard (same fixed entry point, tracking only
   experiment-owned fixture/socket references) — same closed failure; verified
   the actual temporary root was absent and both owned listeners had closed
   descriptors afterward. Synthetic outside-canary bytes are checked after
   every sandbox attempt, including failures; no change was observed.
5. After staging all eight new files:
   - `python3 scripts/check.py` — **passed**: format, build, Clippy, workspace
     tests/doctest, docs, finite CLI/daemon smoke, local Markdown links and
     intentionally failing assertion rejection. No Rust source changes.
   - `cargo deny --locked check` — **passed**: advisories, bans, licenses, sources.
   - `python3 scripts/secrets.py` — **passed**: history and tracked/staged-file
     scan, synthetic leak correctly rejected.
   - `git diff --cached --check` — **passed**.

Linux portable execution and remote macos-15 execution were **not available
locally**; the workflow defines those checks but no remote result is claimed.

## CI and independent review

Dedicated path-scoped workflow: `.github/workflows/host-isolation.yml`,
read-only contents permission, SHA-pinned checkout, no persisted Git credentials,
5-minute jobs. Portable tests on ubuntu-24.04/macOS-15, separate real macos-15
guard. Tool/platform/policy failures are blocking (no skips or continue-on-error).
No remote run/head/PR exists for this staged result; CI **not run**, not green.
Independent safety review **not run**; parent owns it and PR finalization.
The known local guard failure is actionable, not a waiting/green claim.

## Next safe prerequisites and exclusions

1. Parent independently reviews supervisor, policy construction, fixture and CI.
   Integrate onto current main, record resulting full tested SHA and repeat tests.
2. Resolve synthetic runtime bootstrap abort using documented narrow allowances
   or record platform unsupported. Do not import system.sb or broadly grant
   filesystem, Mach services, syscalls or execution simply to start a binary.
3. Establish an enforceable exact loopback endpoint contract. If this deprecated
   SBPL interface cannot express it, keep guard blocked and seek an explicitly
   approved containment design; localhost/wildcards are not automatic substitutes.
4. Obtain passing synthetic positive and negative filesystem/network/child probes
   on the target OS and macos-15 CI, cancellation/cleanup evidence and independent
   review. Portable test success alone cannot authorize installed-host execution.
5. Only after explicit parent/user authority: define a separate pinned host launch
   plan with reviewed executable/runtime allowances, system/global config denial,
   hidden network paths, service/process bounds and content-free evidence. Current
   harness intentionally exposes no host-launch option or reusable command API.

No actual host certification, universal containment, zero-egress proof, product
service, Phase 2+, provider authorization, phase closure, commit, push or merge.
