"""Private fixed harness helper: retain group ownership until the caller kills it."""
import os
import signal
import subprocess
import sys
import threading


def hold(_number, _frame):
    # Caught handlers reset to defaults in the executed target, unlike SIG_IGN.
    pass


signal.signal(signal.SIGTERM, hold)
signal.signal(signal.SIGINT, hold)
signal.pthread_sigmask(signal.SIG_UNBLOCK, {signal.SIGTERM, signal.SIGINT})
status_fd = int(sys.argv[1])
arguments = sys.argv[2:]
# Optional private readiness channel for the offline runner. The original harness
# argv/status protocol is unchanged. Target identity is reported by its owner,
# not inferred from output EOF; the target never inherits this descriptor.
ready_fd = None
if arguments[:1] == ["--ready-fd"]:
    ready_fd = int(arguments[1])
    arguments = arguments[2:]
try:
    try:
        target = subprocess.Popen(arguments, stdin=subprocess.DEVNULL, close_fds=True)
    except OSError:
        target = None
    if ready_fd is not None:
        try:
            os.write(ready_fd, f"{target.pid if target is not None else 0}\n".encode("ascii"))
        except BrokenPipeError:
            pass
        finally:
            os.close(ready_fd)
    # Only the target retains output pipes. Status has a separate private pipe.
    os.close(1)
    os.close(2)
    def relay_status():
        status = f"{target.wait()}\n" if target is not None else "launch-error\n"
        try:
            os.write(status_fd, status.encode("ascii"))
        except BrokenPipeError:
            pass  # Owner may have exited; the control-pipe watcher handles cleanup.
        finally:
            os.close(status_fd)

    waiter = threading.Thread(target=relay_status, daemon=True)
    waiter.start()
    # Keep this session/group leader unreaped and alive. EOF means owner died.
    os.read(0, 1)
    # Watch owner EOF while the target runs, not only after target completion.
    os.killpg(os.getpgrp(), signal.SIGTERM)
    waiter.join(timeout=0.5)  # Permit ordinary target reaping before final KILL.
finally:
    # We are ourselves still in this group; its identity cannot have been reused.
    os.killpg(os.getpgrp(), signal.SIGKILL)
