# SDK selection planning — authenticated direct notice mapping

This is an **inert read-selection proposal**, not an executable compiler descriptor,
an approved projection, a resolved graph, or SDK/native acceptance. It supports
TM-04/TM-05/TM-08/TM-10 and P1-A2/P1-A5 prerequisites only. Full product scope is
unchanged. No compiler, SDK, host, sandbox target or package script ran.

`sdk-selection-discovery.json` records fresh SHA-256/SHA-512 verification and
strict archive inspection of nine already-owned archives: the seven direct SDK
packages plus the two authentic declaration prerequisites. It binds the current
lock, complete metadata hashes, every declaration's relative identity/hash,
nested package metadata, original notice hashes and proposed compiler surfaces.
Private candidate data retains unchanged complete package.json/notice bytes;
none of that upstream source is vendored here. No files were projected into a
node_modules tree, no approval was fabricated, and the 11 upstream TypeScript
implementation files remain explicitly unselected. The private candidate digest
is a review identifier, **not operator approval**.

## Resolved evidence gap: package-to-source notice mapping

The three notice-less archives contain authentic repository metadata:

| Archive | repository.directory | Standalone notice |
| --- | --- | --- |
| @opencode/client 2.2.5 | packages/client | absent |
| @opencode/plugin 2.2.5 | packages/plugin | absent |
| @opencode/theme 2.2.5 | packages/theme | absent |

The parent subsequently performed actual `gh attestation verify` for all three
owned archives using npm's retained SLSA v1 bundles: all exit 0, empty stderr.
`sdk-notice-provenance.json` records the exact command restrictions, public URLs,
bundle/output hashes, SHA-512 subjects and verified certificate identities. The
authenticated build source is **958f965d35ed44d32b018fd55b02a5357a7748fd**,
not the previously assumed 9bbb8ce notice commit. The signer is the repository's
release.yml on refs/heads/dev, GitHub-hosted, with the source digest constrained.
No weaker verification or new network verification was performed by this unit.

The complete untruncated source tree was parsed as data; raw root LICENSE, three
source manifests and release workflow matched their Git blob IDs. Case-insensitive
notice-basename/extension scanning across ancestors and complete package subtrees
found only root LICENSE; relevant symlinks/submodules were rejected. Source package
names/license and published repository.directory identify each package scope.
Source workspace manifests need not byte-match built release manifests. This is
authenticated build provenance, **not a reproducible-build proof**.

The unchanged 1,065-byte root MIT notice (SHA-256
`625f0f619133f89bbbb2abe37369613dfa1885eba1e50d02170deb62bb42cb6b`)
is appended verbatim to THIRD-PARTY-NOTICES.txt with scope limited to these three
2.2.5 packages. Every prior notice byte remains an unchanged prefix. This does not
cover any transitive package, grant a legal waiver or approve distribution.
The earlier blocked candidate is retained; a new inert planning candidate binds
this receipt while retaining complete metadata/notices and all closed gates.

`sdk_notice_receipt.py` only checks evidence consistency. Receipt hashes, a
self-authored JSON record and passing tests cannot authenticate themselves or
replace the parent's actual gh measurement. Private raw bundles/results/tree
remain available for independent review; no certificates/base64 or private paths
are published. **Independent package-specific review remains pending**; no
projection, full project_types manifest or executable SDK descriptor was built.

## Fixed compiler design still requiring review

The private fixture drafts use actual inspected exports: OpenCodeClient.session,
server Plugin.define/setup/app.name, TUI Plugin.define/setup/data.session.cost,
theme rgbToOklch, core RGBA.fromInts, Solid render/JSX and box/text elements, plus
web-tree-sitter Parser.init/Point and authentic JSONSchema7Definition. The negative
draft passes a string to rgbToOklch's numeric first parameter; TS2345 is an
**unobserved expectation**, not an actual diagnostic. Drafts contain no local SDK
stubs, `any`, casts, suppressions or library skips. Upstream declarations' own
`any` remain untouched. Fixture syntax and semantics have not been compiler-tested.

Proposed settings: strict/noEmit, ESNext module/target, official Bundler
resolution, default libraries, no library skips, `types: []`, fresh empty
typeRoots and explicit owned fixture files. Real TSX requires reviewed official
OpenTUI JSX binding; the proposal is react-jsx with jsxImportSource
`@opentui/solid`, **not a module alias/plugin or runtime import execution**.
The existing compiler_plan's preserve-only JSX contract does not represent that
proposal. No measured standalone/Node/C/shared-owner source was changed.

Explicitly include authentic `@types/emscripten/index.d.ts` for the
web-tree-sitter global EmscriptenModule; empty types/typeRoots do not supply it.
JSON Schema follows the plugin -> aisdk -> provider declaration chain. Node/ws
reference closure still needs review. Direct-file lexical inventories are not
transitive consumed graphs: rxjs occurs in a Solid documentation example, not
an established import; OpenTUI zig-structs refers to owned bun-ffi-structs whose
actual declaration exports were inspected and do not import Bun types. Do not
infer a Bun requirement solely from the package name or optional runtime-plugin
declaration. Any newly established missing edge must block, never become a stub.

Known missing requirements are enumerated in the JSON. Full transitive type
selection/nested identities, upstream-directive review, official consumed-file
closure, exact SDK policy/read/config inventory, private evidence/retained-owner
design and independent review/authorization all remain open. Future code must
reject these requirements before returning any executable descriptor. The
successful standalone compiler candidate is not an SDK launcher.

Runtime notice/provenance blockers for agent/eastasianwidth/three AWS packages,
Node 24.10.0 versus OpenTUI >=26.4.0, broader publisher authentication and native
capture/review/admission remain separate open gates; compile-only discovery does
not waive them. No companion, daemon, inference, certification or phase closure
is claimed.
