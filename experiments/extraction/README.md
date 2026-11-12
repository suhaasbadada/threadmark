# Optional extraction experiment

Not a runtime component or default CI check. Standard-library harness checks:

```sh
python3 -B experiments/extraction/test_harness.py
```

A dedicated Linux/macOS CI workflow runs only these offline stdlib harness
tests, including real SIGTERM cleanup; it never installs or invokes Graphify.

To opt into a bounded local structural-only run using **already installed**
Python 3.12.6 / graphifyy 0.9.101 (no automatic installation):

```sh
python3 -B experiments/extraction/run.py --run > extraction-local.json
```

POSIX only. Uses synthetic copied fixtures, a fresh clean-environment worker and
temporary caches. No providers, models, semantic agents or CLI pipeline. Failure
is explicit. Not a sandbox: do not point this at user repositories or untrusted
packages. Local output is not auto-admitted anywhere. `results.json` is recorded
synthetic evidence, not a golden timing assertion; don't overwrite it merely to
obtain passing results.

See [predeclared protocol](../../docs/decisions/0002-extraction-feasibility.md) and
[results, counterexamples and acceptance limits](../../docs/progress/phase-1-extraction.md).
