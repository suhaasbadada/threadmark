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

## Prospective scoped normalization (separate contract)

`normalized.py` and `scoped_run.py` implement experimental
`threadmark.scoped-static.v1`, not a changed interpretation of the historical
schema or evidence. Offline tests require no Graphify or native parsers:

```sh
python3 -B -W error::ResourceWarning experiments/extraction/test_normalized.py
python3 -B experiments/extraction/scoped_run.py --help
```

The actual six-case gate is **closed pending primary review and existing bounded
lifecycle tests**. See [ADR 0009](../../docs/decisions/0009-scoped-static-extraction.md)
for the predeclared schema, unchanged budgets, syntax limitations and protocol;
[prospective progress](../../docs/progress/phase-1-scoped-extraction.md) contains
the exact command and remaining gates. Default/help imports no Graphify/native
parsers and starts no worker. Not a product importer, engine repair or adoption.
