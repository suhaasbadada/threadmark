"""Select an already-installed reviewed CI interpreter. Never install/download."""
import os
from pathlib import Path
import shutil
import subprocess
import sys


def candidates(cache, executable, version, find):
    result = []
    if cache:
        root = Path(cache) / "Python"
        versions = sorted((p for p in root.glob("3.12.*")
                           if p.name.split(".")[-1].isdigit()),
                          key=lambda p: int(p.name.split(".")[-1]), reverse=True)
        for directory in versions:
            for arch in ("arm64", "x64"):
                result.append(directory / arch / "bin" / "python3")
    installed = find("python3.12")
    if installed:
        result.append(Path(installed))
    if version == (3, 12):
        result.append(Path(executable))
    return tuple(dict.fromkeys(result))


def select(paths, run=subprocess.run):
    for path in paths:
        if not path.is_file():
            continue
        try:
            probe = run([str(path), "-I", "-S", "-c",
                         "import sys; print('%d.%d' % sys.version_info[:2])"],
                        env={"PATH": "/usr/bin:/bin", "LANG": "C"},
                        stdin=subprocess.DEVNULL, capture_output=True,
                        text=True, timeout=5, check=False)
        except (OSError, subprocess.TimeoutExpired):
            continue
        if probe.returncode == 0 and probe.stdout == "3.12\n" and not probe.stderr:
            return path.resolve()
    raise ValueError("reviewed Python 3.12 is not installed; no download fallback")


def main():
    destination = os.environ.get("GITHUB_ENV")
    if not destination:
        raise ValueError("CI environment output is required")
    selected = select(candidates(os.environ.get("RUNNER_TOOL_CACHE"), sys.executable,
                                 tuple(sys.version_info[:2]), shutil.which))
    if any(c in str(selected) for c in "\r\n"):
        raise ValueError("invalid interpreter path")
    with open(destination, "a", encoding="utf-8") as output:
        output.write("THREADMARK_PYTHON=" + str(selected) + "\n")
    print("Selected installed Python 3.12; no installation or download")


if __name__ == "__main__":
    main()
