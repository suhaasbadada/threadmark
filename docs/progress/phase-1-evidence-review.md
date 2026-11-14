# Phase 1 — recorded evidence terminal review

2026-11-13. **P1-A4 partial**, TM-02/TM-05/TM-07/TM-08/TM-10: joins
actual retained source-backed extraction to explicit local review/cancel.
[Protocol, six exact scripts and command](../../experiments/evidence-review/README.md).
No Phase 2 implementation, inference, host mutation, adoption or phase closure.

Tested base `ce6d04ec11e2a67706d6e31e2e53d0b2a31c5457` plus the uncommitted
`experiments/evidence-review/` files and this record. No committed/tested final
SHA or new CI exists for this unit. Parent-supplied prior merge evidence:
`7434995b2e98dd884f8f79636c2ee93927d20202`, PR 34; runs 43414583230,
43414583258, 43414583288 passed at that merge, **not checks of these edits**.
Primary review, final head and CI remain pending. Four pre-existing unstaged
progress appends were preserved; no frozen report/source/normalizer changes.

## Actual observations

Focused tests passed before demonstrations: 29 new stdlib tests; unchanged
normalizer 21/21; prior UX controller 14/14. Missing/tampered/oversized/symlink
report and sources, current manifest, cross-project rows, exact draft binding,
artifact/source drift before review, outage persistence, recovery without
approval, UTF-8 draft budget, EOF/cancel/unknown/input caps and no-argument
no-evidence/no-stdin behavior are covered. No Graphify/native parser was rerun.

Six predeclared real CLI invocations each exited 0 within its 10-second timeout;
stderr empty; every final state had original only and no approved draft:

| Script | Mechanical observation |
| --- | --- |
| 1 | Actual orbit citations displayed; explicit review became locally reviewed; EOF canceled |
| 2 | Switch cleared review; orbit-next source differed; explicit new review required |
| 3 | SIMULATED stale blocked review; restore/show remained unreviewed; explicit new review worked |
| 4 | Review then cancel retained exact original and removed candidate/approval |
| 5 | SIMULATED outage survived project switch and blocked review; recover remained unreviewed until explicit review |
| 6 | Unknown input rejected without echo/approval; 32-command cap canceled |

No children/listeners/resources were created by the CLI. The external harness
reaped all six processes through bounded `subprocess.run`; no cleanup of user
resources. Exact stdin/stdout and hash manifest retained privately under approved
temporary storage, directory basename `evidence-review-six-yv_536zu` (full local
path supplied in handoff, not public evidence).

| Script | stdin SHA-256 | stdout SHA-256 |
| --- | --- | --- |
| 1 | `8cffe863752c6301477bf5493f8a5166e720afc645ad40043529d1442f7152d5` | `f96fc96e502e026653e194ce8f07730d0c21e6fddb17aef602717bf437a60eb8` |
| 2 | `9d949c94a47ecce5382352ddd1d06c4e5f90e51c030bfd4febae88ec892af25a` | `2d5932dd0ee2ab867f191b8ecd1b5665fe12d84d87e6aabc5a345295bb69b0a4` |
| 3 | `4a7cdaabf3f7a02219c65dd02d87f45886491f3003fce57c1ee799138c4dcf0c` | `8a2f69fbf94b7cb831a3b8ca8e73722b698592b1fc5596ac12adf08e1e2d6494` |
| 4 | `56b077a81cfd25e6575864ab2641ddbb7b0ed0b60019461bfa0ce8778628e1f4` | `76bd3ad1fe32f5048b6ee2ccd3ae0b148a3421e55b2156f30bc621440968d344` |
| 5 | `99bce92ddd57311d79056b15dc579759f5b7c0c84340383e1f2dd0661aeae51e` | `77e71b7a65cd5802daff65c9ab12d22a78881c04fd96ba4b0fd15f85252d3694` |
| 6 | `c06eafa3924c0e0f5c89bd41a5a9f6b7a510376be1a745a0e14f9ca101e52ee1` | `55861598e8e4ea0cff61c45bb9c02b94b14e2d934e89744b745e304dc19a53d5` |

Observed synthetic citation coordinates in both projects: definitions
`lib.rs:L2-L2`, `service.py:L4-L4` (confidence not supplied), calls
`lib.rs:L3-L3`, `service.py:L9-L9` (EXTRACTED). Actual Rust definition excerpts
differ (trim vs lowercase); Python definition row is signature-only, not body
coverage. Per-project source hashes:

| Project | lib.rs SHA-256 | service.py SHA-256 |
| --- | --- | --- |
| orbit | `fe588be9d19020a7ab40f5f8b808d0eb962deb6371a8681c732e234769cdd5b8` | `c1db3a9983cb04c2cbae132f9ed805ce2af5867c4ccc6bc70f476b89c81761c5` |
| orbit-next | `39ec57cf805ed06d797eca8a931cdeaec3c5461c6da60d44f5ab0145225fd056` | `26babacefa536e2183ece5e62a8b0f12de5d8a891228b43b820b68e1145663b5` |

Artifact SHA is fixed in the README/loader. Recorded producer graphifyy 0.9.101,
`graphify.extract.extract`; synthetic-worktree / synthetic-snapshot-1, not Git
freshness. LIMITED_STATIC gaps remain visible. No prose permissions invented.

## Friction and limits

Repeated terminal display is verbose; Python signature-only evidence cannot
answer body semantics. Only two fixed same-scope questions, no ambiguity-solving
or arbitrary edits. A changed/unavailable candidate requires show/recovery then
fresh review; no automatic fallback/approval. These are observed mechanical
states, not human consent, an end-user usability study, refinement quality,
performance or reduced-friction evidence. No real daemon outage was tested.
No native consent receipt, copy/send action or composer acknowledgment exists.
Native-host pause remains authoritative; T3 has no composer placement API here.
Parent-directory trust is explicit, not general filesystem containment.

Additional verification passed:

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: format, build, Clippy,
  workspace tests/docs, finite foundation diagnostics, local links, deliberate
  failure rejection. These foundation checks do not execute the source fixtures.
- `CARGO_NET_OFFLINE=true cargo deny --locked --offline check`: advisories,
  bans, licenses and sources passed using local cached data only. An initial
  invocation additionally used unsupported `--disable-fetch` and exited 2;
  corrected offline command above passed, with no network fetch.
- `python3 scripts/secrets.py` after staging only owned new files: tracked scan
  and synthetic sentinel rejection passed; `git diff --cached --check` passed.

No commit/push/PR/new CI, network, fixture-source execution, provider or worker
launch authorized/performed. CI wiring remains primary-owned.

## Primary independent review and integration

Joffrey independently reviewed the meaningful code/claims with no substantive
findings. He verified fixed artifact/source-manifest/scope binding, actual
citations/confidence, size and symlink rejection, exact-draft review, invalidation,
outage persistence, recovery without approval, and original-only cancellation.
All 29 tests passed; he read retained stdin/stdout hashes and final cancellation
states without rerunning the six CLI demonstrations. No host, extraction, network
or inference behavior was inferred from those mechanical checks.

Primary inspected the loader/controller/CLI, preserved the four prior progress
appends, and added this 29-test suite to existing Linux/macOS integrated CI.
No old source/report/normalizer was changed. PR #34's post-merge CI `43414583230`,
extraction `43414583258` and integrated `43414583288` all passed on exact merge
`7434995b2e98dd884f8f79636c2ee93927d20202`; those checks do not certify this unit.
Full new-head verification and publication tracking follow separately.
