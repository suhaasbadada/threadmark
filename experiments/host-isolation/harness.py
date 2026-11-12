#!/usr/bin/env python3
"""Optional fixed synthetic guard experiment. NOT an installed-host launcher."""
from contextlib import ExitStack, contextmanager
import json
import os
from pathlib import Path
import platform
import selectors
import signal
import socket
import subprocess
import sys
import tempfile
import time

PROCESS_SECONDS = 5
COMPILE_SECONDS = 30
TOTAL_SECONDS = 60
OUTPUT_BYTES = 16 * 1024
GRACE_SECONDS = 0.5
SANDBOX = Path("/usr/bin/sandbox-exec")
COMPILER = Path("/usr/bin/clang")
SDK = Path("/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")
SOURCE = Path(__file__).with_name("probe.c")
SUPERVISOR = Path(__file__).with_name("process_supervisor.py")


class GuardError(Exception):
    """Explicit closed failure; messages never contain captured process output."""


class Cancelled(GuardError):
    """Distinct from InterruptedError, which selectors may transparently retry."""


def _cancel(_signum, _frame):
    raise Cancelled("experiment cancelled")


@contextmanager
def cancellation():
    previous = {}
    try:
        for number in (signal.SIGTERM, signal.SIGINT):
            previous[number] = signal.signal(number, _cancel)
        yield
    finally:
        for number, handler in previous.items():
            signal.signal(number, handler)


def clean_env(state):
    return {
        "HOME": str(state / "home"), "XDG_CONFIG_HOME": str(state / "config"),
        "XDG_CACHE_HOME": str(state / "cache"), "XDG_DATA_HOME": str(state / "data"),
        "XDG_STATE_HOME": str(state / "data"), "TMPDIR": str(state / "tmp"),
        "LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin",
    }


def _run(args, *, cwd, env, seconds=PROCESS_SECONDS):
    """Private supervisor; public CLI never accepts executable/profile arguments."""
    if not 0 < seconds <= COMPILE_SECONDS:
        raise GuardError("invalid timeout budget")
    process = None
    output = bytearray()
    status = bytearray()
    read_fd, write_fd = os.pipe()
    try:
        # Block asynchronous cancellation until the new group owner is recorded.
        previous_mask = signal.pthread_sigmask(
            signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
        try:
            process = subprocess.Popen(
                [sys.executable, "-I", "-S", str(SUPERVISOR), str(write_fd), *args],
                cwd=cwd, env=env, stdin=subprocess.PIPE,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                close_fds=True, pass_fds=(write_fd,), start_new_session=True,
            )
            os.close(write_fd)
            write_fd = None
        finally:
            # A pending handler may raise here; ownership is already recorded.
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        deadline = time.monotonic() + seconds
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ, "output")
            selector.register(read_fd, selectors.EVENT_READ, "status")
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise GuardError("process timeout")
                for key, _ in selector.select(min(remaining, 0.1)):
                    chunk = os.read(key.fd, 4096)
                    if not chunk:
                        selector.unregister(key.fileobj)
                    elif key.data == "status":
                        status.extend(chunk)
                        if len(status) > 32:
                            raise GuardError("invalid supervisor status")
                    elif len(output) + len(chunk) > OUTPUT_BYTES:
                        raise GuardError("process output budget exceeded")
                    else:
                        output.extend(chunk)
            # Do not wait/poll/reap the group owner before the last group signal.
            if status == b"launch-error\n":
                raise GuardError("process launch or I/O failed")
            try:
                code = int(status.decode("ascii"))
            except (ValueError, UnicodeError) as error:
                raise GuardError("missing or invalid supervisor status") from error
        return code, bytes(output)
    except OSError as error:
        raise GuardError("process launch or I/O failed") from error
    finally:
        try:
            if process is not None:
                # Retain ownership through the last group signal, then reap once.
                handlers = {n: signal.signal(n, signal.SIG_IGN)
                            for n in (signal.SIGTERM, signal.SIGINT)}
                try:
                    try:
                        os.killpg(process.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    time.sleep(GRACE_SECONDS)
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    process.wait(timeout=GRACE_SECONDS)
                finally:
                    try:
                        process.stdout.close()
                        process.stdin.close()
                    finally:
                        for number, handler in handlers.items():
                            signal.signal(number, handler)
        finally:
            os.close(read_fd)
            if write_fd is not None:
                os.close(write_fd)


def _quoted(path):
    # SBPL string escaping: reject controls, escape backslash and double quote.
    text = str(path)
    if not text or any(ord(char) < 32 or ord(char) > 126 for char in text):
        raise GuardError("unsupported profile path characters")
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'


def filesystem_profile(state, executable):
    if not state.is_absolute() or not executable.is_absolute():
        raise GuardError("profile requires absolute fixture paths")
    return f'''(version 1)
(deny default)
(allow process-fork)
(allow process-exec (literal {_quoted(executable)}))
(allow file-read* file-map-executable (literal {_quoted(executable)}))
(allow file-read* file-write* (subpath {_quoted(state)}))
(allow file-read* file-map-executable
    (subpath "/usr/lib")
    (subpath "/System/Library/dyld"))
; dyld ignition opens the root directory; this is NOT its subtree.
(allow file-read* (literal "/"))
'''


def profile(state, executable, port):
    if type(port) is not int or not 1 <= port <= 65535:
        raise GuardError("invalid loopback port")
    # SBPL supports localhost, not numeric IP syntax. The declared fixture
    # endpoint owns this port on BOTH 127.0.0.1 and ::1 before launch.
    return filesystem_profile(state, executable) + (
        f'(allow network-outbound (remote tcp "localhost:{port}"))\n'
    )


def require_platform():
    if platform.system() != "Darwin":
        raise GuardError("real guard requires macOS; portable tests are not containment")
    if not SANDBOX.is_file() or not os.access(SANDBOX, os.X_OK):
        raise GuardError("required sandbox-exec unavailable")
    if not COMPILER.is_file() or not os.access(COMPILER, os.X_OK):
        raise GuardError("required installed Apple compiler unavailable")


def sdk_path(state):
    """Use installed CLT or the active Xcode SDK; never install developer tools."""
    if SDK.is_dir():
        return SDK
    code, output = _run(
        ["/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-path"],
        cwd=state, env=clean_env(state),
    )
    try:
        candidate = Path(output.decode("utf-8").strip())
    except UnicodeError as error:
        raise GuardError("required installed Apple SDK unavailable") from error
    if (code or not candidate.is_absolute() or candidate.suffix != ".sdk"
            or not candidate.is_dir()
            or not any(candidate.is_relative_to(base)
                       for base in (Path("/Applications"), Path("/Library/Developer")))):
        raise GuardError("required installed Apple SDK unavailable")
    return candidate


@contextmanager
def fixtures():
    with tempfile.TemporaryDirectory(prefix="threadmark-guard-") as directory:
        root = Path(directory).resolve()
        state = root / "state"
        state.mkdir(mode=0o700)
        for name in ("home", "config", "cache", "data", "tmp", "database"):
            (state / name).mkdir(mode=0o700)
        outside = root / "outside-canary"
        outside.write_bytes(b"synthetic-outside-unchanged")
        outside.chmod(0o600)
        (state / "outside-link").symlink_to(outside)
        yield root, state, outside


def run_guard():
    require_platform()
    deadline = time.monotonic() + TOTAL_SECONDS
    with fixtures() as (root, state, outside), ExitStack() as stack:
        env = clean_env(state)
        # Bound before policy generation, hold both sockets to avoid port reuse.
        listeners = [stack.enter_context(socket.socket()) for _ in range(2)]
        for listener in listeners:
            listener.bind(("127.0.0.1", 0))
            listener.listen(8)
            listener.settimeout(0.2)
        ports = [listener.getsockname()[1] for listener in listeners]
        # Own both permitted address families, not an unclaimed IPv6 exception.
        for port in ports:
            listener = stack.enter_context(socket.socket(socket.AF_INET6))
            listener.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
            listener.bind(("::1", port))
            listener.listen(8)
            listener.settimeout(0.2)
            listeners.append(listener)
        udp = stack.enter_context(socket.socket(socket.AF_INET, socket.SOCK_DGRAM))
        udp.bind(("127.0.0.1", ports[0]))
        udp.settimeout(0.2)
        executable = root / "synthetic-probe"
        sdk = sdk_path(state)
        code, _ = _run(
            [str(COMPILER), "-isysroot", str(sdk), "-std=c11", "-Wall", "-Wextra", "-Werror",
             str(SOURCE), "-o", str(executable)],
            cwd=state, env=env, seconds=COMPILE_SECONDS,
        )
        if code:
            raise GuardError("synthetic fixture compilation failed")
        executable.chmod(0o500)
        policy = root / "guard.sb"
        policy.write_text(profile(state, executable, ports[0]), encoding="ascii")
        policy.chmod(0o400)

        def launch(policy_file, arguments):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise GuardError("experiment timeout")
            try:
                return _run([str(SANDBOX), "-f", str(policy_file), str(executable),
                             *arguments], cwd=state, env=env,
                            seconds=min(PROCESS_SECONDS, remaining))
            finally:
                if outside.read_bytes() != b"synthetic-outside-unchanged":
                    raise GuardError("outside canary changed")

        # Parser failure controls: no fixture success and no own-state output.
        for invalid in ("(version 1)\n(unknown-threadmark-operation)\n",
                        "(version 1)\n(deny default\n"):
            bad = root / "invalid.sb"
            bad.write_text(invalid, encoding="ascii")
            code, output = launch(bad, [str(outside), *map(str, ports)])
            if code == 0 or b"synthetic-guard-ok" in output or (state / "state-canary").exists():
                raise GuardError("invalid policy did not fail closed")

        filesystem_policy = root / "filesystem.sb"
        filesystem_policy.write_text(filesystem_profile(state, executable), encoding="ascii")
        filesystem_policy.chmod(0o400)
        code, output = launch(filesystem_policy, [str(outside), "filesystem", "unused"])
        if code != 0 or output.strip() != b"synthetic-guard-ok":
            raise GuardError(f"filesystem/process guard failed (exit {code}); no host may launch")
        if outside.read_bytes() != b"synthetic-outside-unchanged":
            raise GuardError("outside canary changed")

        code, output = launch(policy, [str(outside), *map(str, ports)])
        if code == 65:
            raise GuardError("exact loopback policy rejected by sandbox compiler; no host may launch")
        if code != 0 or output.strip() != b"synthetic-guard-ok":
            # Do not leak private paths from sandbox diagnostics into evidence.
            raise GuardError(f"synthetic guard failed (exit {code}); no host may launch")
        if outside.read_bytes() != b"synthetic-outside-unchanged":
            raise GuardError("outside canary changed")
        for listener in (listeners[0], listeners[2]):
            for _ in range(2):
                connection, _ = listener.accept()
                connection.close()
        for listener in (listeners[1], listeners[3]):
            try:
                connection, _ = listener.accept()
            except socket.timeout:
                pass
            else:
                connection.close()
                raise GuardError("denied endpoint received a connection")
        try:
            udp.recvfrom(64)
        except socket.timeout:
            pass
        else:
            raise GuardError("denied UDP endpoint received a datagram")
    return {"result": "synthetic-only-pass", "platform": platform.system(),
            "kernel": platform.release(), "host_launched": False}


def main():
    if sys.argv[1:] != ["--synthetic-guard"]:
        print("usage: harness.py --synthetic-guard (never launches an installed host)", file=sys.stderr)
        return 2
    try:
        with cancellation():
            result = run_guard()
    except GuardError as error:
        print(f"guard blocked: {error}", file=sys.stderr)
        return 1
    except (OSError, subprocess.TimeoutExpired):
        print("guard blocked: resource or process cleanup failure; no host may launch", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
