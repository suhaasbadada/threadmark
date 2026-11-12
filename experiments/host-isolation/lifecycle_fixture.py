"""Fixed portable cancellation fixture; no host executable or config discovery."""
from pathlib import Path
import sys

# -I excludes the script directory; import only this adjacent checked-in harness.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import harness as h

root = Path(sys.argv[1])
mode = sys.argv[2]
worker = r'''
import json, os, signal, subprocess, sys, time
from pathlib import Path
child = subprocess.Popen([sys.executable, '-I', '-S', '-c', 'import time; time.sleep(60)'])
def stop(_number, _frame):
    child.terminate()
    child.wait(timeout=1)
    raise SystemExit(0)
signal.signal(signal.SIGTERM, stop)
ready = Path(sys.argv[1])
temporary = ready.with_suffix('.tmp')
temporary.write_text(json.dumps([os.getpid(), child.pid]))
temporary.rename(ready)
time.sleep(60)
'''

try:
    with h.cancellation(), h.fixtures() as (_, state, _):
        (root / "owned").mkdir()
        try:
            h._run([sys.executable, "-I", "-S", "-c", worker, str(root / "ready.json")],
                   cwd=state, env=h.clean_env(state), seconds=2 if mode == "timeout" else 5)
        finally:
            (root / "owned").rmdir()
except h.Cancelled:
    if mode != "sigterm":
        raise
    print("sigterm")
except h.GuardError as error:
    if mode != "timeout" or str(error) != "process timeout":
        raise
    print("timeout")
else:
    raise SystemExit("fixture unexpectedly completed")
