# Phase 1 — Synthetic host-isolation prerequisite

Status: **local synthetic guard passed after narrow repairs; review findings
addressed, remote CI pending, not host certification**. TM-02,
TM-04–TM-08, TM-10. P1-A2 prerequisite; partial P1-A5 capability evidence.
P1-A2 admission/approval acceptance and Phase 1 exit are **not established**.
No extraction or OpenCode mock experiment files are dependencies or modified.
Budgets were set before probes in [ADR 0004](../decisions/0004-synthetic-host-containment.md).

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
