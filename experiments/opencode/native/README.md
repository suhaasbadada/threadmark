# OpenCode 2.2.5 native bridge — notice/provenance gate BLOCKED

**Audit candidate only. No bridge implementation, install, typecheck, TUI runtime
test or installed-host certification. Do not install or load this directory.**
It is deliberately outside all auto-loaded plugin directories.

The parent requested a real server-command/RPC/TUI review bridge against public
release v2.2.5 (source commit
`9bbb8ce18c80f099e0e448775f59d965ead40a21`). The implementation must not begin by
installing an unreviewed dependency closure. The first gate failed; no ambient SDK
stubs or mock called native were substituted.

## Current conditional acquisition (base `13bdeb0`)

The parent's exact development-only CC-BY exceptions are approved; they do not
waive actual notices/provenance or authorize installation. The regenerated npm
lock replaces the wrapper with **typescript 6.0.3** and explicitly adds mandatory
**web-tree-sitter 0.25.10**. Other direct pins remain unchanged.

- `dependency-audit-conditional.json`: **364 verified archive records, 345 unique
  archives**, 11 optional records explicitly unacquired. All acquired SHA-512s,
  actual manifests, script declarations, executable/platform-artifact paths and
  notice/README hashes are recorded. No claim of complete license review.
- Bounds: **36,269,486 compressed / 200,261,936 declared extracted bytes** counted
  conservatively per lock entry. Each archive is below 32 MiB; these recorded
  totals are below 256 MiB / 1 GiB. Bob rechecked all 345 unique owned archives
  offline (35,784,107 compressed / 198,094,950 declared extracted bytes).
  **Historical limitation:** that ledger predates the reviewed aggregate actual
  expansion fix; it does not record or prove the sum of decompressed tar bytes
  including headers/padding. No corrected acquisition run is claimed here.
- `audit_archives.py`: explicit inert acquisition/inspection utility, never run
  by CI. Rejects absolute/backslash/dotdot paths, links/special files, conflicting
  canonical duplicates, redirects, unapproved actual license expressions,
  mismatching manifests/integrities and bound excess. Gzip output is bounded
  before tar/PAX parsing. Harmless single-root DefinitelyTyped archives and
  byte/mode-identical canonical duplicates are supported and fully size-counted.
- `THIRD-PARTY-NOTICES.txt`: actual archive legal notices and both exception
  attribution READMEs; **provisional, incomplete, not distribution approval**.
- `source-notice-evidence.json`: bounded public-source follow-up. Registry
  metadata pins `@npmcli/agent@4.0.2` and `eastasianwidth@0.2.0` to immutable
  source trees with no project license notice (agent has only an unrelated
  fixture license). Three AWS archives omit license files and their registry
  metadata has no gitHead. One guessed version-tag LICENSE URL returned 404;
  this does not prove no valid alternative source exists. OpenCode's pinned
  root MIT and the exact SPDX upstream README are preserved as evidence.

**STOP before installation:** 16 archives lack standalone notices; some are
resolvable from the pinned OpenCode root or embedded README, but the independent
agent/eastasianwidth/AWS notice/provenance gaps remain unresolved. A manifest's
ISC/MIT/Apache identifier is not a fabricated package-specific copyright notice.
Options: obtain authoritative immutable notices/source mapping, use a separately
reviewed authentic declaration-only mechanism, or seek upstream packaging fixes.
No blanket license allowance, invented attribution or dependency removal applied.

This lock is still **not proven type-closure-complete**: web-tree-sitter declares
`@types/emscripten ^1.40.0`, currently absent; further authentic declaration needs
have not been compiler-tested. No further acquisition/install was attempted after
the notice/provenance stop. Legacy-peer resolution is not closure proof.
Node 24.10.0 / OpenTUI's Node >=26.4.0 mismatch remains a runtime blocker.
Compiler 6.0.3's independently acquired archive matches the exact parent SHA-512
and declares Node >=14.17, but **no compiler ran** while the closure gate is open.

Offline archive regression tests (stdlib only, no package imports/network):

```sh
python3 -B -m unittest discover -s experiments/opencode/native -p 'test_*.py' -v
```

## Declaration preparation implementation (synthetic tests only)

`project_types.py` implements the parent's separate design-only gate. **No actual
SDK projection has been prepared or compiler run.** The archive inspector above
is not a safe extractor; projection performs its own stricter full-archive and
selected-output preflight and never uses tar extraction APIs.

The API requires exact lock bytes and an externally reviewed plan: lock SHA-256,
per-package npm location/name/version/resolved URL/SHA-512, explicit archive root
(including DefinitelyTyped roots), metadata SHA-256, approved license and notice
status/evidence, and explicit selected relative file SHA-256s. It cannot infer
approval from a license field or turn the current blocked audit into approval.
Plans with missing/unresolved requirements reject before destination creation.
Plan approval is a caller trust boundary, not a cryptographic signature mechanism.

Complete `package.json` and selected `.ts/.tsx/.mts/.cts` bytes (including their
declaration variants) retain exact contents and nested package locations. No
exports/typesVersions resolution, rewriting, aliasing, runtime JS/bin/native
copying or execution occurs. The future pinned compiler must perform official
resolution and consumed-file closure verification; a prepared projection is not
a complete type graph or npm/runtime closure.

Projection rejects effective PAX/GNU unsafe paths, controls, links, sparse/special
members, all duplicates, Unicode-NFC/casefold aliases (including implicit
directories), file ancestors and ambiguous nested package metadata. Limits are
32 MiB/archive, 256 MiB total compressed, 1 GiB expanded/declared total, 100,000
members/archive and 1 GiB output including ledger/marker. All input preflight
precedes writing; archives are rehashed before parsing. Output is a fresh 0700
private root with exclusive nofollow writes, 0400 inert files, copied-file hash
verification, an incomplete marker and an atomically finalized verified ledger.
Exceptions preserve owned incomplete artifacts, not a claimed cleanup. Never
reuse stale roots or upload package artifacts. Trusted same-process parent path
ancestors are required; dirfd/nofollow child traversal is not a universal defense
against an arbitrary hostile same-UID process.

Successful ledger state is only `prepared_not_compiled`; type and runtime closure
remain `NOT established`. No CLI, compiler launcher, install/download step or
real-SDK selection is provided. The existing workflow's native `test_*.py`
discovery includes all synthetic projection tests without another workflow step.
Compiler execution still needs the separate containment-plan review in progress.

Acquisition redirects now reject in `HTTPRedirectHandler.redirect_request`
**before** following, while retaining the final-response URL check. Pure tests
verify callback denial and opener wiring without listeners or network.

Independent review also found that acquisition previously aggregated declared
file sizes but not actual decompressed tar bytes. The corrected inspector returns
both, and acquisition separately enforces and records both totals (including per-
record `expandedBytes`). Two real synthetic-archive regressions cover the inclusive
limit and aggregate overflow. The historical blocked audit is retained unchanged;
neither this correction nor the tests authorize a new acquisition run.

Authentic upstream notice whitespace is preserved unchanged. The root
`.gitattributes` disables diff whitespace diagnostics **only** for this exact
`THIRD-PARTY-NOTICES.txt` path, not implementation files or other notices, and
does not change file bytes or disable other checks.

## Historical first audit artifacts (retained unchanged)

The following describes the original candidate at committed base `13bdeb0`.
Its lock is preserved in Git history, not represented by the newly generated lock.

- `package.json`: exact direct-pin **candidate**, not an approved install recipe.
- `package-lock.json`: npm 11.6.0 generated, never hand-edited. Lock-only
  resolution used `--ignore-scripts --legacy-peer-deps --omit=optional
  --no-audit --no-fund --registry=https://registry.npmjs.org/`.
- `dependency-audit.json`: all 375 resolved lock entries, advertised integrity,
  license, dependency and peer metadata; five computed tarball-integrity checks.
  `tarballIntegrityVerified: false` means **not verified**, not passed.

The graph includes optional platform entries even though optional installation
was omitted. `--legacy-peer-deps` avoids automatically adding unrelated optional
GUI/Vite/Electron peers. Explicit direct pins supply the selected TUI peers;
**the graph is not yet a complete typecheck closure**: OpenTUI's nonoptional
`web-tree-sitter@0.25.10` peer still needs explicit resolution, and further type
dependencies may be needed. Do not use legacy-peer mode to waive those needs.

Resolution ran in this assigned worktree with a newly owned private HOME,
XDG config/cache/data/state, TMPDIR, empty private user/global npm config files,
explicit public registry, no inherited environment, auth or credentials, disabled
scripts/audit/funding/update notifier, and no global install. No `node_modules`
was created. Owned isolated npm audit state was preserved, not cleaned broadly.
Public tarballs were read in memory with Python's standard library, without
filesystem extraction or execution. No SDK host module was imported.

## Historical blocking findings and parent options

1. `@opentui/solid@0.8.0 → @babel/core@7.29.7 →
   @babel/helper-compilation-targets@7.29.13 → browserslist@4.29.5 →
   caniuse-lite@1.0.30001826` is **CC-BY-4.0**. Its tarball SHA-512 matched the
   public registry integrity, and its actual LICENSE says Attribution 4.0.
2. `@opencode/plugin@2.2.5 → @opencode/util@2.2.5 →
   @npmcli/arborist@9.4.0 → @npmcli/package-json@7.0.5 →
   spdx-expression-parse@4.0.0 → spdx-exceptions@2.5.0` declares **CC-BY-3.0**.
   Its actual tarball integrity and package manifest were checked; no standalone
   license file was present in that archive. No attribution-compliance conclusion
   is asserted.
3. These data-license cases are outside this task's authorized MIT/BSD/Apache
   compatible-only gate. This is a scope/approval blocker, not a claim that CC-BY
   data necessarily makes a proprietary application impossible. The graph also
   includes ISC, BlueOak-1.0.0, CC0-1.0 and an AFL/BSD alternative: compatibility
   and notice treatment require review, not a silently expanded allowlist.
4. The 375-entry graph includes mandatory npm installer, telemetry and AWS/Google
   credential-library dependencies through `@opencode/util` and `@opencode/ai`.
   No such code ran. Whether that closure is acceptable for a type-only fixture
   needs the parent's excessive-closure decision before full acquisition.
5. `typescript: npm:@typescript/typescript6@6.0.2` is a small Apache-2.0 wrapper,
   with dependency `@typescript/old: npm:typescript@^6`; this generated lock resolves
   the latter to **6.0.3**. The wrapper's tarball was verified but neither compiler
   was executed. An exact underlying compiler pin must be deliberately reviewed
   (then regenerated by npm), not inferred from the wrapper's version.
6. OpenTUI 0.8.0 declares Node `>=26.4.0` and Bun `>=1.3.14`; available Node is
   24.10.0. npm emitted EBADENGINE. This is not evidence that declaration-only
   checking requires running OpenTUI, but no runtime compatibility is established.

**Options for the parent:**

- Keep the current license gate: stop here and seek a release/upstream packaging
  split exposing actual declarations without these runtime/build closures.
- Explicitly approve the data-license exceptions, notices, closure size and
  precise underlying compiler; then audit the missing peers and every acquired
  artifact before installation. This changes the current gate and needs approval.
- Historical option: propose a separately reviewed declaration-only acquisition mechanism using
  authentic, hash-checked release files. It must preserve declaration resolution
  and licensing, not invent SDK types, modify packages, or call a partial graph a
  full dependency closure. The current section above supersedes only the
  implementation portion; execution and actual SDK selection remain unapproved.

Removing real UI dependencies, copying ambient stubs, enabling scripts, using an
installed binary as SDK source, or silently downgrading the release is not an
acceptable workaround. No CI download/install step was added.

See the [progress record](../../../docs/progress/phase-1-opencode-native.md) for
verification and all still-open product/host gates.
