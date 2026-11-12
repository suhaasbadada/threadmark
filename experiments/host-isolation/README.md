# Synthetic host-isolation prerequisite

Optional experiment, not a Threadmark runtime or installed-host launcher. Uses
stdlib Python and an already-installed Apple C compiler/Command Line Tools SDK.
No installs, downloads, providers, actual host configuration, Docker or privilege
changes. No CLI option accepts an arbitrary command or custom profile.

```sh
python3 -m unittest discover -s experiments/host-isolation -p 'test_*.py' -v
python3 experiments/host-isolation/harness.py --synthetic-guard
```

The first command runs portable **non-containment** validation. On Linux run only
that command; an explicit real-guard invocation fails, never falls back. The
second command requires macOS and must pass before its synthetic boundary can
be considered observed. The repaired synthetic guard passes locally; remote
macos-15 CI remains pending; independent-review findings were repaired. Initial dyld bootstrap and
numeric-endpoint failures are retained in the evidence. Root-directory-only
bootstrap permission and the explicitly revised dual-stack loopback-port contract
are narrow experimental decisions, not approval to broaden host permissions.
The macos-15 CI guard is blocking, with no skip/continue-on-error.

The guard builds only `probe.c` in a private temporary directory, checks unknown
and malformed profile rejection, then attempts filesystem/process and exact-port
network probes. A filesystem-only intermediate check is diagnostic, not full
acceptance. Two IPv4 and two IPv6 TCP sockets are experiment-owned, bound before
launch and held through cleanup, plus a UDP listener used to prove denial.
Only the selected TCP port at 127.0.0.1 and ::1 is intended to succeed; another
owned port on both families and UDP at the allowed port must fail. No socket
descriptor is inherited by the probe.
The outside canary is also synthetic and experiment-owned. No real system/global
configuration is opened to test denial; exclusion is checked structurally.
No DNS or nonloopback connection is attempted. No IPv4-only rule or untested
loopback-alias behavior is claimed from SBPL's supported `localhost` syntax.

All subprocesses use clean environment, isolated state, null stdin, bounded output,
deadlines, new process groups, TERM/KILL and direct-child reap. Portable lifecycle
tests use only fixed Python fixtures (not the sandbox) to verify real SIGTERM,
timeouts and cooperative descendant reaping. No claim is made that a supervisor
can reap adversarial orphaned grandchildren on macOS.
The private helper retains group identity through the final signal, defers
cancellation while recording ownership, and monitors owner EOF while work runs.
Regression tests cover these ordering and owner-death cases; no installed host
can be selected through this experiment's CLI.

See [ADR 0004](../../docs/decisions/0004-synthetic-host-containment.md) for budgets
and [evidence](../../docs/progress/phase-1-host-isolation.md) for exact limitations.
