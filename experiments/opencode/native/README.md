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
the **optional** peer `@types/emscripten ^1.40.0`, currently absent. Its actual
`web-tree-sitter.d.ts:136` references global `EmscriptenModule` (not a direct module
import), so consuming that declaration still needs an authentic definition;
optional peer metadata is not proof of a complete strict type graph. Further authentic declaration needs
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

`compiler_plan.py` now validates an externally reviewed compiler-only inventory
and produces an **inert candidate descriptor**, not a launcher or execution
approval. See [the plan and trust boundaries](COMPILER-PLAN.md). It revalidates
projection bytes against owned archives, exact ledger, compiler/Node/source
inventories, fixed strict config and clean environment. Compiler archive provenance
and Node version identity require external reviewed inventory authority, not a
self-approved copied ledger. All actual runtime/system policy and negative controls
remain pending; containment/type closure are explicitly unestablished. Only pure
synthetic tests ran. No real SDK selection, compiler projection or execution.

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

## Fixed C-only containment experiment — locally measured, not native certification

`synthetic_containment.py` is a separate synthetic prerequisite for
TM-04/TM-05/TM-08/TM-10, supporting P1-A2/P1-A5 **PARTIAL** only. It does not
consume a compiler descriptor or launch Node, TypeScript, an SDK or a host.
Pure tests run through existing native discovery. After independent review and
explicit primary authorization, the C fixture was compiled and sandboxed locally:
all 32 fixed controls passed on Darwin kernel 27.0.0 with verified owned-artifact
cleanup. The existing macOS integrated job now also runs this fixed guard; exact-
head remote results remain a separate gate.

The reviewed fixed action (macOS only):

```sh
python3.12 -B experiments/opencode/native/synthetic_containment.py --synthetic-compiler-guard
```

Policy changes require fresh review before execution. This requires already-installed
Apple clang, SDK inspection and sandbox-exec; there is no installation fallback.
There are no executable, descriptor, profile, command or budget CLI inputs.
Unknown arguments and unsupported platforms close before any target launch.
No automatic relaxation or retry follows a failed control. In particular, initial
exec bootstrap failure is a blocker, **not** permission to restore process-fork.

The policy is deny-default, without network or process-fork allowances. It
permits only literal fixture exec, individual fixture/canary reads, exact ancestor
metadata and writes into six fresh owned state directories. `/usr/lib` and
`/System/Library/dyld` subtrees are an explicitly **SYNTHETIC C baseline**, not
Node's reviewed minimum inventory. The separately reviewed bootstrap repair
allows `file-read-data` on the **literal `/` directory only**, not its descendants,
to let dyld open the root directory. Two preceding SIGABRT failures are preserved
in the progress record; the counterfactual root-only candidate passed. This is not
a recursive root read allowance. Private/home/
repository read subtrees and workspace/probe/policy/inventory writes are absent.
SBPL strings reject controls/non-ASCII and escape quotes/backslashes. The actual
artifact root deliberately contains quotes and injection-shaped text. Pure tests
independently decode and behaviorally evaluate the emitted policy subset; they
cannot substitute for Apple's parser; the quoted-path control was also measured.

The fixed C fixture checks approved read and each state's write; owned sibling,
home/config/repository-shaped canary reads and symlink target read/write denial;
workspace/probe/policy/inventory write denial; fork, unauthorized posix_spawn and
separate direct exec denial (an invalid executable marker ensures ENOEXEC is not
accepted). Probe/policy write controls are owner-writable so DAC does not create
a false sandbox pass. Negative controls require EPERM/EACCES, not generic errors.
Owned IPv4/IPv6 TCP/UDP receivers bound before each network launch check connect,
UDP send, bind and listen denial, plus zero receiver traffic. There is no external
internet attempt or DNS/resolver IPC proof. Two malformed policies must prevent
fixture execution. Partial, duplicate, extra and malformed observations reject.

The private shared `../../host-isolation/_bounded_process.py` is the one repaired
retained-owner loop; `process_supervisor.py` and the older host guard are unchanged.
Hard maxima are 120 s wall and 16 MiB combined output, with 2 s cleanup proof;
this experiment uses 5 s controls, 30 s compilation, 256 KiB output and a 120 s
overall launch deadline. Extraction's compatibility wrapper retains 15 s/256 KiB,
stdout/elapsed and nonzero translation. No budget environment override exists.
Owner readiness/status are independent of output EOF; cancellation is deferred
through owner recording and cleanup; TERM and KILL are attempted before owner
reaping. Missing/malformed proof, EPERM or reap failure quarantines all helper
reuse and retains owner references. Group cleanup does not prove escaped child
cleanup; actual sandbox fork denial is separately measured by this fixed C guard,
not inferred from group cleanup or generalized to Node.

Artifacts use a fresh private owned directory, not an unconditional temporary
directory finalizer. Verified ordinary failure removes only that directory and
permits a fresh deliberate run. Unknown cleanup retains artifacts and blocks
reuse, without a production reset API. Removal failure likewise quarantines.
Structured results expose only observed control states, fixture/binary/policy/
code hashes and OS/kernel identity, never target output, canary bytes or paths.
Failure is nonzero and cannot become synthetic-only-pass from partial evidence.
Failure summaries expose only fixed mode/status, byte counts/hash, categorical
diagnostic hints and exact known observation fragments. They are not whole-mode
acceptance and never publish captured stderr. The first bootstrap failure exposed
the need for this evidence; its diagnostic repeat and reviewed repair are retained
in the progress record rather than replaced with a fabricated first-pass success.

This synthetic pass cannot establish Node plugins/loaders, ambient
compiler config, actual consumed-file/type closure, V8/total memory containment,
native OpenCode admission, SDK/TUI capture or full product acceptance. Those
gates, runtime provenance and Phase 1 remain OPEN.

## Fixed Node-only discovery candidate — version observed, controls BLOCKED

`node_containment.py` and the separately hash-bound `node_containment_probe.cjs`
are the next review candidate, not an execution authorization. They support
TM-04/TM-05/TM-08/TM-10 and prerequisite work for P1-A2/P1-A5; neither acceptance
ID is completed. No compiler, SDK, host, inference or network service is started
by importing them or by the pure Python tests. No measured Node action is added
to CI. There is deliberately **no CLI** and no arbitrary executable/argv/profile,
compiler descriptor, caller script or budget input.

Preparation (`prepare_review`) statically reads only the known ARM64 Node
24.10.0 linked Mach-O closure, using installed `/usr/bin/otool -l`. It excludes
dylib ID rows, resolves the observed loader-relative ICU dependency and the
single Brotli rpath subset, and rejects unsupported dynamic lookup. Node's known
binary hash is pinned; the candidate explicitly includes all 17 non-system
dylibs, their load edges, canonical byte hashes, modes/sizes/inodes and every
actual alias edge/metadata ancestor. Bounds are 64 non-system files, 128 MiB per
file and 512 MiB total; this fixed runtime requires exactly 18 reachable files.
No Homebrew install receipt is substituted for the current aliased runtime.
Generated machine inventories stay private, unapproved and unredistributed.

`run_guard(review_bytes, approved_sha256)` requires the exact bytes and a digest
approved through an independent trusted parent/review channel. The API does not
authenticate that caller; computing a candidate's own hash is **not approval**.
The review binds the fixed probe, harness, shared serializer/artifact owner,
retained process helper/supervisor, sandbox tool, OS/build, actual dyld and
SystemVersion files. Shared-cache virtual images are explicitly **not individually
hashed**. Full file/alias/ancestor and source/system revalidation occurs before
launch and after every attempt, without new runtime discovery. Parents and
Homebrew are trusted against concurrent same-UID mutation; this is not a hostile
same-UID container boundary. Any post-launch drift retains owned artifacts and
quarantines reuse even when the process returned zero.

The typed deny-default policy reuses the existing serializer and its independent
test oracle. Only literal Node may exec; no fork, network or Mach-service
allowance is added. A separately reviewable diagnostic candidate permits only
the named read-only `hw.pagesize`/`hw.pagesize_compat` metrics, not general sysctl
access. Runtime/alias reads/maps are exact; metadata traversal is
literal. Writes are confined to six fresh owned state directories. The explicitly
reviewable **public-system discovery baseline**, not minimum runtime closure,
permits `/usr/lib`, this OS's Preboot Cryptex dyld directory, and the directly
linked CoreFoundation/Security framework subtrees. Literal `/` directory data
read is disclosed separately and grants no recursive subtree access. No whole
System, PrivateFrameworks, Homebrew, home, repository or private-data read is
allowed. A bootstrap failure does not authorize a broader allowance.

Only fixed Node `--max-old-space-size=64`, a fixed owned `--openssl-config=...`,
and `--version` or the owned hashed CommonJS probe are proposed. The first
reviewed run observed `v24.10.0`, then blocked at OpenSSL's attempt to read ambient
host configuration. No controls were marked passed from that failed mode.
The candidate repair adds a fixed comment-only owned OpenSSL configuration,
literal data-read permission only, protected hash checks and a write-denial
control; it does not allow reading host OpenSSL configuration. The installed
Node manpage documents the flag and its precedence over OPENSSL_CONF. This
owned-config candidate removed that error but then aborted in LowLevelAlloc
before any CommonJS control. Prior controlled page-size evidence motivates the
two named metrics above as a hypothesis, not an established Node root cause.
The changed candidate requires fresh review/authorization before execution.
Replacement environment adds
`NODE_DISABLE_COMPILE_CACHE=1`; no ambient Node/cache/coverage/inspector/ICU/
OpenSSL/DYLD overrides are inherited. Per-attempt budgets are 5 s and 16 KiB
combined output, using the retained process owner and its 2 s cleanup proof; a
110 s overall launch deadline reserves 10 s within the 120 s envelope. The V8
old-space flag is not a total RSS bound. Fresh private artifacts use exclusive
creation; verified ordinary failures remove them, unknown cleanup/drift retains
them and blocks reuse. Evidence is status/count/hash/constant-label only.

The proposed 30 observations cover exact ASCII version, approved read/six state
writes, forbidden private/home/repo/config-shaped canaries and escaping symlink,
protected writes (including owned OpenSSL config), real unauthorized `spawnSync`
(only EPERM/EACCES counts), IPv4/
IPv6 TCP connect/UDP send/bind/listen permission denials, zero traffic at owned
loopback receivers, and compile-cache disablement via named Node APIs. Unknown
API behavior, nonpermission errors, stderr, partial/duplicate/extra labels or
any malformed version fail closed. The version-only action was observed; the
CommonJS controls/cache APIs have **not passed**. DNS/IPC/JIT, full system closure,
publisher provenance, V8/total
memory, compiler/consumed-file/type closure and native integration remain open.
Independent code/policy review, exact inventory approval and explicit primary
authorization are mandatory before each changed candidate's actual execution.
