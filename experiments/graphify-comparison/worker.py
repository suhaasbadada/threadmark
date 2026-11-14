"""Private fixed authored worker; never execute or import supplied sources."""
import contextlib
import hashlib
from importlib import import_module
import json
from pathlib import Path
import sys
import traceback

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
a = import_module("experiments.graphify-comparison.adapter")
s = import_module("experiments.extraction.scoped_run")


def run(work):
    request = s.parse_reply((work / "request.json").read_bytes())
    a.norm.require(set(request) == {"arm", "task", "sources"} and request["arm"] in a.ARMS, "request")
    root, cache = work / "source", work / "cache"
    paths = sorted(root.rglob("*"))
    a.norm.require(all(not p.is_symlink() for p in paths), "input")
    files = [p for p in paths if p.is_file()]
    a.norm.require(len(files) == 16 and sum(p.stat().st_size for p in files) <= 65536, "input_budget")
    sources = tuple((p.relative_to(root).as_posix(), p.read_bytes()) for p in files)
    a.source_map(sources, request["task"])
    a.norm.require({p: hashlib.sha256(data).hexdigest() for p, data in sources} == request["sources"], "source_changed")
    versions = s.installed_versions()
    with contextlib.redirect_stdout(sys.stderr):
        s.python_preflight(dict(sources))
        s.rust_preflight(dict(sources))
        if request["arm"] == "graphify":
            graph = s.extract_graph(files, root, cache)
            result = a.graphify(s.relative_coverage(graph, root), sources, request["task"])
        else:
            result = a.authored(sources, request["task"])
    a.norm.require(all((root / p).read_bytes() == data for p, data in sources), "source_changed")
    return {"schema": "graphify-comparison-worker/1", "status": "ready",
            "arm": request["arm"], "task": request["task"], "versions": versions,
            "result": result}


if __name__ == "__main__":
    try:
        a.norm.require(len(sys.argv) == 1, "arguments")
        sys.stdout.buffer.write(a.scoring.canonical(run(Path.cwd())))
    except Exception as error:
        traceback.print_exc(file=sys.stderr)
        failure = "unsupported_coverage" if type(error) is ValueError and error.args == ("unsupported_coverage",) else "invalid_output_or_dependency"
        sys.stdout.buffer.write(a.scoring.canonical({"status": "unavailable", "failure": failure}))
