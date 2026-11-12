# ADR 0004 — Synthetic macOS host-containment prerequisite

Status: experimental; not installed-host approval or production sandbox certification.

Scope: TM-02, TM-04–TM-08, TM-10; P1-A2 prerequisite and P1-A5 evidence only.
No dependency on the separate extraction or OpenCode mock experiments.

## Decision and budgets (chosen before probes)

Use an optional stdlib Python supervisor and a compiled synthetic C probe under
`experiments/host-isolation/`. Compile only the checked-in fixture with the
already-installed Apple compiler, never install tools. Execute only that fixture
with `/usr/bin/sandbox-exec -f` and an experiment-generated private profile file.
No installed host, plugin, admission, model, provider, or real configuration is
opened. Missing tools, invalid policy, unsupported OS and failed probes block.

Budgets: compilation 30 seconds; each sandbox process 5 seconds; complete guard
experiment 60 seconds; aggregate captured output per process 16 KiB; shutdown
grace 0.5 seconds followed by process-group SIGKILL and direct-child reap.
An owned supervisor holds the session/group identity until after the final group
signal; a private pipe reports target status without reaping that leader. Block
SIGTERM/SIGINT across spawn/ownership recording to avoid a cancellation leak.
Monitor owner-pipe EOF concurrently with target execution so ordinary owner death
does not leave an unbounded target; the leader remains owned through final KILL.
The initial protocol used two IPv4 listeners. Before the parent extended network
probes, the declared contract became one owned dual-stack loopback TCP port:
two IPv4 and two IPv6 TCP listeners (allowed and denied ports), plus one denied
IPv4 UDP listener on the allowed port. One outside synthetic canary, one private
temporary root, no external connection attempts. CI jobs: 5 minutes.

Default deny; no imported policy or allow-default. Permit fixture execution,
fork for inheritance probes (not arbitrary exec), own state read/write, and only
the selected TCP loopback port on 127.0.0.1 and ::1, using supported SBPL
`localhost:port` syntax. This is not an IPv4-only numeric-address contract.
Permit read/map of `/usr/lib` and the dyld runtime directory, and read of literal
`/` for dyld ignition bootstrap (never its subtree); no whole `/System`, HOME, `/Library`, Mach services,
UDP, DNS, nonloopback, listening, or general subprocess executable allowance.
Profile strings are escaped, not interpolated Scheme. Runtime/profile/probe
files are outside the writable state. Close inherited descriptors; stdin is
null, output is pipes; environment is constructed from scratch.

## Rationale and limits

HOME/XDG isolation does not stop system/managed configuration discovery or
hidden network paths. `sandbox-exec(1)` documents the file interface and
deprecation; `sandbox(7)` documents inheritance and pre-opened descriptor limits.
Installed Apple profiles supply syntax examples, not a stable public contract.
Do not import their broad system allowances. Policy compiler rejection must not
trigger an unsandboxed retry or policy relaxation merely to start a host.

Synthetic probes cannot certify adversarial native code or universal containment.
System/global path exclusion and DNS/nonloopback denial are policy evidence,
not reads of real config or external packet tests. UDP denial is also probed
against an owned loopback listener, not an external endpoint. Future host-specific runtime
allowances, compiler/runtime trust and macOS-version behavior require independent
review. Parent authorization and review are required before any installed-host
test; Phase 1 remains open. See the [evidence record](../progress/phase-1-host-isolation.md).
