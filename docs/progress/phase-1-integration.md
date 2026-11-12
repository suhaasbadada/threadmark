# Phase 1 — Authorized integration and combined verification

2026-11-12. **PRs #3–#13 merged; Phase 1 remains OPEN.** The owner's direct
instruction to keep working and merging authorized these merges. GitHub
auto-merge was not enabled; no admin override, force push, branch deletion,
worktree cleanup, production deployment or credential action was performed.
Earlier approval-limit statements describe the earlier authorization snapshot,
not a reason to leave these now-authorized changes unmerged.

TM-02/04–08/10; P1-A1–A5 evidence integration only. Merging experiments does not
turn prototypes into certified adapters, adopt Graphify for production, complete
the feasibility phase or authorize Phase 2. Runtime remains Phase 0 offline
foundation; no service, storage or inference is advertised.

## Exact merge ledger

Before each merge: freshly verified the recorded head, green check contexts,
non-draft/open state, target, review requirements and no unresolved review
threads. Repository main had no active ruleset/branch-protection approval or
strict-update requirement. Reviews were the recorded independent/primary reviews,
not fabricated GitHub approvals. Supplemental foundation runs for #9/#10 were
also verified successful at their exact heads. All merges used exact-head SHA
guards and ordinary server-side merge commits; GitHub enforced mergeability.

Dependent PRs were retargeted to main only after their prerequisites merged;
source heads remained unchanged and their two/five-file intended diffs were
checked. Source branches and all assigned worktrees were preserved.

| PR | Tested source head | Actual merge commit |
| --- | --- | --- |
| [#3](https://github.com/suhaasbadada/threadmark/pull/3) | `9a45e749a4dcb971660ef3efe528f2fa3267abbf` | `37bac297f7561318620f4b6f7e23e1c3122a7895` |
| [#4](https://github.com/suhaasbadada/threadmark/pull/4) | `6b43f39d11bd672f352e23a76ce7b1fa432f0acc` | `7cf1184f80fc953dfb58649a67defcd53d233cbb` |
| [#5](https://github.com/suhaasbadada/threadmark/pull/5) | `55a1c81bf25fc46e569ae48be3eff111b9f0c098` | `d100aea7d4b53150780291f6aafa5ffe76552460` |
| [#6](https://github.com/suhaasbadada/threadmark/pull/6) | `e2a3e24948c0bb0e692c74a6b24c3bd083bb039b` | `262d97cb0d537ce192f0b3aa85a9b2a89c81efcb` |
| [#7](https://github.com/suhaasbadada/threadmark/pull/7) | `5c6d433433a98a23711f16f6637967f45bf1c4a1` | `9ea050fb110b0b3307806a2461d540f202ffb2d7` |
| [#8](https://github.com/suhaasbadada/threadmark/pull/8) | `9227571c6e9f0b090ec883121dc9babfc25cc59f` | `86883c53d88fdb53158ffce871a555c7d49e60ca` |
| [#11](https://github.com/suhaasbadada/threadmark/pull/11) | `03df2fd42424807f83bc583b543b6770c0a34b55` | `58c6c314cf45d5f9f6e1471776483a4592544aea` |
| [#9](https://github.com/suhaasbadada/threadmark/pull/9) | `eba04746fcbf0857e7b8af18e217b047f0353829` | `0ae36aa094a3e4e98711740d7fb4e94ab0cac11e` |
| [#10](https://github.com/suhaasbadada/threadmark/pull/10) | `23ad31623dba76fa518de1865c2d92ee836225c1` | `af9f097106cfcf1c4ce821a0f43b26c31ad51c9f` |
| [#12](https://github.com/suhaasbadada/threadmark/pull/12) | `3220bde0ecceea5c1e03d4632be007837222df68` | `2b9367b2db1162bbd0207a1af104b0add8639f0f` |
| [#13](https://github.com/suhaasbadada/threadmark/pull/13) | `2d783f82ab4c0c07ab10246c1fa37a85979912c6` | `242d3d737002d8da76d7e9ecab33131017b35df3` |

## Combined-tree local verification

The retained primary task branch was clean and fast-forwarded, without switching
branches, to actual main revision
`242d3d737002d8da76d7e9ecab33131017b35df3`. On that exact committed tree:

- Extraction harness: **8 passed**; no Graphify extraction or dependency install.
- Portable containment/supervisor: **25 passed**.
- Corpus/scoring/adapter/lexical fixtures: **10/24/18/21 passed**.
- Node OpenCode/T3/UX contract suites: **80 passed** combined.
- Total experimental tests: **186 passed**, no skips or failures.
- Actual local macOS synthetic guard: `synthetic-only-pass`,
  `host_launched=false`; no installed OpenCode service or host integration.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: passed foundation format,
  build, Clippy, unit/integration/doctests, docs, finite diagnostics, local links
  and deliberate assertion-failure rejection.
- `cargo deny --offline --locked check`: passed using cached advisory data,
  not a newly fetched vulnerability database.

These results validate the combined code tree, not a comparative retrieval
study, approved inference, native consent/admission, clipboard/composer behavior
or a deployment. No generated Rust/Python fixture source was executed.

## Integrated CI gate

[Integrated offline experiments](../../.github/workflows/experiments.yml) runs
all nine existing offline experiment suites on Linux/macOS together for PRs and
main pushes; the actual synthetic guard additionally runs on macOS. The event
is unprivileged pull_request; permissions are read-only, checkout SHA-pinned
without persisted credentials, jobs bounded to eight minutes, and runtimes are
runner-provided. No packages, provider credentials, corpus downloads, host
startup, Docker, deployment or site workflow changes. Existing individual gates
remain intact. This adds combined-tree coverage, not a new product capability.

Primary reviewed the workflow against the exact commands executed above.
The constituent implementations retain their recorded independent reviews;
no new independent review of this small orchestration/evidence change is claimed.
The new gate's final head/run and outcome must be recorded on its own PR before
the authorized merge; prior main/branch greens are not its CI result. Continue
through merge and verification rather than stopping at a ready-to-merge state.
