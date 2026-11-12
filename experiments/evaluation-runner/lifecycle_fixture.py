"""Fixed authored lifecycle negatives. Never imports candidate or corpus code."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import runner as r


def record(name, value):
    temporary = Path(name + ".tmp")
    temporary.write_bytes(r.canonical(value))
    temporary.rename(name)


def main():
    if sys.argv[1:2] == ["owner"]:
        # Outer test owns this complete temporary tree, including crash leftovers.
        tempfile.tempdir = sys.argv[2]
        result = r.Runner()._fixture("descendant")
        print(result.status, flush=True)
        return 0
    if sys.argv[1:2] == ["leaf"]:
        signal.pthread_sigmask(signal.SIG_UNBLOCK, {signal.SIGTERM, signal.SIGINT})
        if sys.argv[2] == "closed_output":
            os.close(1)
            os.close(2)
        if sys.argv[2] == "descendant_overflow":
            os.write(1, b"x" * 10000)
            os.write(2, b"y" * 10000)
        time.sleep(60)
        return 0
    arm, project, mode = sys.argv[1:]
    child = None
    def stop(_number, _frame):
        if child is not None:
            child.terminate()
            status = child.wait(timeout=0.25)
            record("terminal.json", {"worker": os.getpid(), "child": child.pid,
                                     "exit": status, "reaped": True})
        raise SystemExit(0)
    mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
    try:
        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        if mode in ("descendant", "closed_output", "descendant_overflow"):
            child = subprocess.Popen([sys.executable, "-I", "-S", str(Path(__file__).resolve()),
                                      "leaf", mode], stdin=subprocess.DEVNULL, close_fds=True)
            record("ready.json", {"worker": os.getpid(), "child": child.pid,
                                  "group": os.getpgrp()})
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, mask)
    if mode == "closed_output":
        os.close(1)
        os.close(2)
    if mode in ("sleep", "descendant", "closed_output", "descendant_overflow"):
        time.sleep(60)
        return 1
    if mode == "overflow":
        # Each stream fits 16 KiB individually; aggregate deliberately exceeds it.
        os.write(1, b"x" * 10000)
        os.write(2, b"y" * 10000)
        return 0
    if mode == "nonzero":
        return 7
    if mode in ("malformed", "partial", "nonutf8"):
        sys.stdout.buffer.write({"malformed": b"{}", "partial": b'{"schema":',
                                 "nonutf8": b"\xff"}[mode])
        return 0
    # A successful protocol conformance fixture is CLOSED, never fake admission.
    payload = r.envelope(arm, project, r.bindings(), {
        "status": "unavailable" if mode == "dependency" else "blocked",
        "reason": "preparation_unavailable" if mode == "dependency" else "admission_rejected",
        "original": None, "candidate": None})
    if mode == "arm":
        payload["arm"] = "symbol"
    if mode == "scope":
        payload["scope"]["revision"] = "wrong-revision"
    if mode == "foreign_scope":
        payload["scope"] = r.scope("harbour")
    if mode == "incomplete":
        payload["state"] = "partial"
    if mode == "pin":
        payload["corpus_pin"] = "0" * 64
    if mode == "bindings":
        payload["bindings"]["evaluation-candidate/candidate.py"] = "0" * 64
    if mode == "unknown":
        payload["provisional"] = "forbidden"
    if mode == "closed_candidate":
        payload["result"]["candidate"] = "e30="
    if mode == "stderr":
        os.write(2, b"synthetic diagnostic, never public")
    if mode == "complete":
        assert sys.flags.isolated and sys.flags.no_site
        assert "PYTHONPATH" not in os.environ and "SYNTHETIC_SECRET" not in os.environ
        assert Path(os.environ["HOME"]).parent.resolve() == Path.cwd()
        assert sys.stdin.buffer.read(1) == b""
    encoded = r.canonical(payload)
    if mode == "duplicate":
        encoded = b'{"schema":"evaluation-runner/1",' + encoded[1:]
    sys.stdout.buffer.write(encoded + (b"trailing" if mode == "trailing" else b""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
