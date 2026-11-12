"""Authored SMALL worker. NOT run by fixture tests; parent review required."""
import base64
from importlib import import_module
from pathlib import Path
import sys

# -I -S: only this explicit reviewed checkout root is added, never fixture paths.
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
r = import_module("experiments.evaluation-runner.runner")


def main():
    if (len(sys.argv) != 3 or sys.argv[1] not in ("lexical", "symbol")
            or sys.argv[2] not in ("harbor", "harbour")):
        return 2
    arm, project = sys.argv[1:]
    pins = r.bindings()
    corpus = import_module("experiments.evaluation-corpus.corpus")
    candidate = import_module("experiments.evaluation-candidate.candidate")
    result = candidate.build(corpus.build("small"), r.scope(project), r.FAMILY, method=arm)
    def encoded(value):
        return base64.b64encode(value).decode("ascii") if value is not None else None
    payload = r.envelope(arm, project, pins, {
        "status": result.status, "reason": result.reason,
        "original": encoded(result.original_input), "candidate": encoded(result.candidate)})
    sys.stdout.buffer.write(r.canonical(payload))
    return 0


if __name__ == "__main__":
    try:
        code = main()
    except Exception:
        code = 1  # Never echo dependency/provisional/error content.
    raise SystemExit(code)
