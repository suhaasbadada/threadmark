# Static landing-page unit

## Scope and revision

### Parent finalization — 2026-11-12 UTC

Site implementation committed independently on current `origin/main`
(`f4d05ee474d055fb8345c831a733ebd4f5dd1f64`), excluding all foundation changes.
Full tested site-code revision: `616d5bee9dc86cb1a699ef97117ff019ac4b621d`.
The parent reran `python3 scripts/site_check.py` successfully after isolation and
verified the diff contains only the four site files listed below. Source review
confirmed no active content/remote resources, only one source CTA, no runtime
claims, SHA-pinned actions, read-only PR checks, and owner-merge-gated deployment.
This evidence-only follow-up does not modify site code or workflow. Exact-head
PR CI remains required; no merge, approval, Pages setting change or deployment
has occurred. The original implementation snapshot below is historical, not the
current commit/publication status. Inherited local build artifacts are preserved
and excluded from the PR.

### Delegate implementation snapshot

Site-only implementation for a separate PR, not part of the runtime foundation.
Prepared on `t3/static-landing-page`, based on
`9515e7f87af4710cdc5e2ef3f52ec5ad92e4796c`, with uncommitted additions.
That SHA identifies the inherited base, **not a tested site commit**. The parent
must transplant only this site's files onto main, review, commit, and record the
resulting full tested SHA and exact PR CI run/head before handoff. No site PR,
remote CI run, approval, merge, or publication exists from this implementation.

Files: `site/index.html`, `scripts/site_check.py`,
`.github/workflows/pages.yml`, and this record. No README, runtime, dependency,
repository setting, or foundation file changes. The site, gate, and workflow do
not require unmerged foundation tooling. The only external page link is the
repository root; it does not assume unmerged documentation paths exist on main.

## Acceptance evidence (2026-11-12 UTC)

| ID | Scope | Result and evidence |
| --- | --- | --- |
| SITE-A1 | Static responsive, keyboard, light/dark, reduced motion | Implemented. Live Chromium DOM checks found no horizontal overflow at observed widths 320, 375, 650, 768, and 1280 CSS pixels. Light and dark styles were exercised; mobile thread becomes a vertical sequence. Real Tab revealed the skip link, Enter focused main, and the next Tab focused the sole source CTA with a solid 3px outline. Both themes' body/muted/link contrast was calculated from computed colors: light 13.07/5.71/6.31, dark 13.89/8.31/9.45. No active animations/transitions were observed; reduced-motion rule inspected. Visual inspection via HTML preview: 390px dark and 1100px light. |
| SITE-A2 | Honest product explanation and source CTA | Copy reviewed against product/architecture and Phase 0/3 specifications. TM-02/04/07 evidence semantics, TM-08 host ownership, TM-10 authorization boundaries, and P0-A5 proposed-versus-shipped distinction preserved. Every feature remains design direction; early/unshipped status and no download/certified integration explicit. Exactly one source/docs CTA plus the accessibility skip link. |
| SITE-A3 | Build, links, accessibility/security guards | Standalone stdlib gate passes; includes balanced structure, unique IDs, language, one h1/main, heading order, labeled sections, skip target, local fragments, allowlisted external source URL, no scripts/embedded content/event handlers/resources, restrictive CSP, size budget, and CSS preference/focus guards. Four deliberately broken fixtures are rejected. Temporary build is byte-for-byte and rechecked. An isolated copy containing only the site, checker, and workflow passed artifact creation; rerun safely refused an existing output. |
| SITE-A4 | Gated Pages workflow; no publication | PR is check/build-only with read-only permissions. Artifact upload and deployment are push-to-main-only; a read-only GitHub API gate requires the exact SHA to be a main PR merge by the repository owner before artifact upload. Deployment needs successful build and uses github-pages environment. Only deploy receives pages/id-token write. No dispatch, pull_request_target, Pages configuration, or live deployment was used. Official action commit pins resolved using gh api; see below. Remote CI/deployment remains untested. |

## Reproducible commands and results

- `python3 scripts/site_check.py` — PASS; finite, offline, stdlib-only.
- `python3 scripts/site_check.py --output NEW_DIRECTORY` — creates the checked
  artifact; destination must not already exist. Tested in a temporary isolated
  site-only tree (no Rust/foundation files). Existing-output rejection also PASS.
- `python3 scripts/check.py` — PASS on inherited foundation plus these additions:
  format, locked build, Clippy, tests, rustdoc, finite diagnostics, documentation
  links, and intentional failing-assertion rejection. This command is not a site
  dependency and need not exist on main for site CI.
- `cargo deny --locked check` — PASS: advisories, bans, licenses, sources.
- Extracted workflow Python merge guard compiled and exercised with mocked,
  synthetic GitHub API replies — owner merge accepted; direct push, non-owner,
  unmerged PR, wrong SHA, wrong branch, and API error all failed closed. No real
  merge, workflow run, or repository settings operation was performed.
- `python3 scripts/secrets.py` — PASS after staging all four new files;
  tracked/uncommitted content and history clean, synthetic sentinel rejected.
- `git diff --check` / `git diff --cached --check` — PASS.

Action pins resolved via `gh api repos/actions/NAME/commits/TAG`:

| Official action | Tag checked | Resolved full commit |
| --- | --- | --- |
| actions/checkout | v4 | 11d5960a326750d5838078e36cf38b85af677262 |
| actions/upload-pages-artifact | v3 | 56afc609e74202658d3ffba0e8f6dda462b719fa |
| actions/deploy-pages | v4 | d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e |

## Browser evidence and limitations

The named local page was exercised through T3 preview tools using a
loopback-only, five-minute Python static server because the tab preview accepts
HTTP rather than local file paths. Resource timing reported no fetched page
subresources. The source href and local fragment were checked; the external CTA
was not followed and remote documentation availability was not audited.
The verification tab was closed and the bounded server exited successfully after
its five-minute lifetime; no persistent server was left running.

Two accessibility-snapshot attempts timed out at 15 seconds. Subsequent DOM
inspection and actual keyboard input succeeded. Semantic coverage is therefore
from source/DOM gates, not a successful accessibility-tree capture. HTML visual
previews reported no console messages. A separate theme-adapted inline preview
was shown (same content/layout, thread theme colors and no outer page padding);
it is not a deployed site or a screenshot-only behavioral claim.

No screen-reader, Lighthouse/axe, forced-colors, browser zoom, alternate-browser,
physical-device, or OS-level reduced-motion emulation audit was performed.
There is no motion even without the preference; the explicit reduce rule is
additional protection. The stdlib gate is a narrow reviewed-site contract,
not a general HTML/CSS/YAML validator or full accessibility certification.

The main-branch trigger alone cannot establish human approval. The additional
read-only API gate rejects direct pushes without an exact matching owner-merged
main PR; API failure also blocks artifact upload. This intentionally excludes bot
or non-owner merges. It is not proof of out-of-band chat authorization: the parent
must still obtain fresh explicit owner merge authorization and use branch/environment
protections as applicable; none were inspected or changed here. Pages must already be configured
by the owner before deployment can succeed. Do not interpret a local pass as a
successful Pages release. No commit, push, merge, release, or publication was
performed. No analytics, model downloads, real project data, or product host
execution was used. Product phase exits remain open.
