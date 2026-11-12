"""Private POSIX retained-owner primitive; not a public command launcher."""
import math
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time

TIMEOUT = 120
OUTPUT_LIMIT = 16 * 1024 * 1024
CLEANUP_SECONDS = 2
SUPERVISOR = Path(__file__).with_name("process_supervisor.py")
_QUARANTINED = False
_UNVERIFIED_OWNERS = []


class CleanupUnverified(ValueError):
    """Missing ownership/termination proof blocks subsequent invocations."""


def _target_status(ready, status):
    """Only canonical private helper records count as target wait evidence."""
    try:
        pid = int(ready)
        if pid < 0 or ready != f"{pid}\n".encode("ascii"):
            raise ValueError
        if pid == 0 and status == b"launch-error\n":
            return None
        code = int(status)
        if pid == 0 or status != f"{code}\n".encode("ascii"):
            raise ValueError
        return code
    except (ValueError, UnicodeError):
        raise CleanupUnverified("worker cleanup unverified; further invocations blocked") from None


def _finish(process, read_fd, ready_fd, status, ready):
    """Signal the still-owned group, then reap; EOF is not target exit proof."""
    end = time.monotonic() + CLEANUP_SECONDS
    failed = False
    status_nonblocking = False

    def drain(fd, record):
        try:
            record.extend(os.read(fd, 33))
        except BlockingIOError:
            pass
        if len(record) > 32:
            raise ValueError("invalid private worker record")

    try:
        os.set_blocking(read_fd, False)
        status_nonblocking = True
        os.set_blocking(ready_fd, False)
        until = min(end - 1, time.monotonic() + 0.7)
        while not ready.endswith(b"\n") and time.monotonic() < until:
            drain(ready_fd, ready)
            time.sleep(0.005)
    except (OSError, ValueError):
        failed = True
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except OSError:
        failed = True
    try:
        until = min(end - 0.5, time.monotonic() + 0.5)
        while status_nonblocking and time.monotonic() < until:
            drain(read_fd, status)
            time.sleep(0.005)
    except (OSError, ValueError):
        failed = True
    finally:
        try:
            # No owner wait/poll before this final group signal.
            os.killpg(process.pid, signal.SIGKILL)
        except OSError:
            failed = True
        finally:
            try:
                process.stdin.close()
            except OSError:
                failed = True
            try:
                process.wait(timeout=max(0.001, end - time.monotonic()))
            except (OSError, subprocess.TimeoutExpired):
                failed = True
    if failed or time.monotonic() > end or process.returncode != -signal.SIGKILL:
        raise CleanupUnverified("worker cleanup unverified; further invocations blocked")
    return _target_status(ready, status)


def bounded(command, cwd, env, timeout=TIMEOUT, limit=OUTPUT_LIMIT):
    """Return (target code, bounded stdout, bounded stderr, elapsed seconds).

    A nonzero target status is data; unknown cleanup is never a normal failure.
    Budgets are fixed hard maxima, not CLI/environment configuration.
    """
    global _QUARANTINED
    if _QUARANTINED:
        raise CleanupUnverified("worker cleanup unverified; further invocations blocked")
    if (isinstance(timeout, bool) or not isinstance(timeout, (int, float))
            or not 0 < timeout <= TIMEOUT or not math.isfinite(timeout)
            or type(limit) is not int or not 0 < limit <= OUTPUT_LIMIT):
        raise ValueError("invalid worker budget")
    start = time.monotonic()
    process = None
    chunks = {}
    descriptors = []
    status, ready = bytearray(), bytearray()
    code = None
    try:
        read_fd, write_fd = os.pipe()
        descriptors.extend((read_fd, write_fd))
        ready_fd, ready_write = os.pipe()
        descriptors.extend((ready_fd, ready_write))
        mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
        try:
            process = subprocess.Popen(
                [sys.executable, "-I", "-S", str(SUPERVISOR), str(write_fd),
                 "--ready-fd", str(ready_write), *command],
                cwd=cwd, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, close_fds=True, pass_fds=(write_fd, ready_write),
                start_new_session=True)
            for fd in (write_fd, ready_write):
                os.close(fd)
                descriptors.remove(fd)
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, mask)
        chunks = {process.stdout: bytearray(), process.stderr: bytearray()}
        with selectors.DefaultSelector() as selector:
            for stream in chunks:
                selector.register(stream, selectors.EVENT_READ, chunks[stream])
            selector.register(read_fd, selectors.EVENT_READ, status)
            selector.register(ready_fd, selectors.EVENT_READ, ready)
            total = 0
            while selector.get_map():
                remaining = timeout - (time.monotonic() - start)
                if remaining <= 0:
                    raise ValueError("worker timeout")
                for key, _ in selector.select(min(remaining, 0.1)):
                    data = os.read(key.fd, 8192 if key.fileobj in chunks else 33)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    if key.fileobj in chunks:
                        total += len(data)
                        if total > limit:
                            raise ValueError("worker output budget exceeded")
                    elif len(key.data) + len(data) > 32:
                        raise ValueError("invalid private worker record")
                    key.data.extend(data)
    except OSError:
        raise ValueError("worker launch or I/O failed") from None
    finally:
        mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
        cleanup_error = None
        try:
            if process is not None:
                try:
                    code = _finish(process, read_fd, ready_fd, status, ready)
                except (OSError, ValueError, subprocess.TimeoutExpired):
                    _QUARANTINED = True
                    cleanup_error = CleanupUnverified(
                        "worker cleanup unverified; further invocations blocked")
        finally:
            try:
                if process is not None:
                    for stream in (process.stdin, process.stdout, process.stderr):
                        if stream is not None:
                            try:
                                stream.close()
                            except OSError:
                                _QUARANTINED = True
                                cleanup_error = CleanupUnverified(
                                    "worker cleanup unverified; further invocations blocked")
                for fd in descriptors:
                    try:
                        os.close(fd)
                    except OSError:
                        _QUARANTINED = True
                        cleanup_error = CleanupUnverified(
                            "worker cleanup unverified; further invocations blocked")
            finally:
                # Retain even a reaped owner object if any proof was missing.
                if cleanup_error is not None and process is not None:
                    _UNVERIFIED_OWNERS.append(process)
                try:
                    signal.pthread_sigmask(signal.SIG_SETMASK, mask)
                finally:
                    if cleanup_error is not None:
                        raise cleanup_error
    return code, bytes(chunks[process.stdout]), bytes(chunks[process.stderr]), round(time.monotonic() - start, 4)
