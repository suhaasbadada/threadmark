# In-memory Rust/Python declaration baseline

Phase 1 measurement prerequisite only: **TM-02/04/07/10, P1-A1 baseline
portion / P1-A5 PARTIAL**. [ADR 0006](../../docs/decisions/0006-phase-1-evaluation-protocol.md)
remains proposed; Phase 1 stays open. This implements the frozen symbol method
in the [scorer contract](../evaluation-scoring/README.md), not graph/direct-call
retrieval, semantic indexing, a worker, a quality comparison, or Phase 2. The
full required [product scope](../../docs/product.md) is unchanged; this is not a
reduced MVP or a functioning companion.

Python 3.10+ standard library only; tested here on Python 3.12.6:

```sh
python3 -B -m unittest discover -s experiments/evaluation-symbol -v
```

## Pure API and declared input boundary

`retrieve(sources, task)` returns an immutable tuple of frozen six-field `Anchor`
values (`project`, `worktree`, `revision`, `path`, `line`, `text`), or raises a
generic `ValueError` with no partial result, last-good fallback or parser-content
diagnostics. Inputs are not mutated. No IO, repository discovery, index, cache,
persistence, exports, configuration, logging/receipts, compiler, subprocess,
network, provider/model, host, clipboard, package/dependency or Docker capability.
Synthetic Rust/Python source is **never executed**. Python AST parsing is the
explicitly permitted syntax operation, not importing or running source.

The five task fields are exactly `schema`, `scope`, `family`, `query`,
`instructions`. Schema is `evaluation-scoring/1`. Scope has exactly `project`,
`worktree`, `revision`, each `[A-Za-z0-9_-]{1,128}`. These labels are consistency
checks, **not authentication, authorization or verified Git provenance**.
Only `definition_directcall` and `conflictingrules_stale_wrongrevision` are
supported. Conformance/unknown families reject rather than count as successful
empty relevance cases. Query and instructions must be nonempty valid UTF-8
strings; both are unchanged, and instructions contribute no identifiers.
No gold/oracle, hash, private coverage or extra task fields are accepted.

Sources must be an immutable tuple of `(str path, bytes data)` tuples, strictly
ascending by path UTF-8 bytes, without duplicates. Paths are normalized relative
POSIX paths **including** the selected project root, e.g. `harbor/src/a.rs`.
Only `.rs`, `.py`, `.md` are accepted. Absolute/backslash paths, empty/dot/traversal
components, C0/DEL controls, invalid UTF-8, foreign roots and mutable/wrong types
reject the entire invocation. `harbor` and `harbour` are distinct in both
directions. Every source is validated, including no-match/no-query-identifier
cases; every Rust/Python file is recognized, including irrelevant ones. Markdown
is approved source input but contributes **no symbols**, even fenced code.

Callers must independently approve/prove the complete selected source set and
its project/worktree/revision provenance. Bytes themselves do not establish
identity. This API cannot detect caller omissions or stale bytes relabeled as
current, or semantically interpret a negation, instruction or permission claim.

## Frozen selection and physical lines

1. From the **original query only**, extract maximal ASCII
   `[A-Za-z_][A-Za-z0-9_]*` matches, unique in first-occurrence order and
   **case-sensitive**. Ordinary words are retained. No stopwords, stemming,
   expansion, aliases, oracle narrowing, or rewritten query. For example,
   `Foo foo Foo 9Bar` gives `Foo`, `foo`, `Bar`; Unicode query text follows the
   frozen ASCII regex (so `naïve` supplies `na`, `ve`).
2. LF-split sources, omit only the final empty segment, remove one terminal CR
   per line. Keep interior blank line numbers; any remaining CR rejects.
   Other Unicode separators do not advance physical LF line numbers.
3. Match supported declarations' **whole ASCII names**, not substrings or
   Unicode-to-ASCII normalization. Declaration keyword/name must share a physical
   LF line. Python `async def` anchors `async`, and all three tokens must share
   that line. Return the entire normalized line, preserving indentation/comments.
4. Emit each coordinate once using its best identifier rank. Rank earliest
   query-identifier position, UTF-8 path bytes ascending, then numeric line
   ascending. Identical lines at distinct coordinates remain distinct.
5. Keep the first eight incrementally (at most nine ranking entries on insert).
   Decoded source, tokens, delimiter map and Python AST are per-file, not retained
   for the whole corpus. Source tuple references are caller-owned immutable bytes.

Inclusive, **postallocation** limits (not hard RSS/CPU/transport containment):

| Unit | Ceiling |
| --- | --- |
| Sources | 2048 files / 32 MiB total / 65536 bytes per file |
| Canonical `{query,instructions}` JSON | 4096 UTF-8 bytes |
| Canonical selected anchor **list alone** | 8192 UTF-8 bytes / 8 items |

Canonical JSON uses sorted keys, compact separators, raw UTF-8, no NaN, no final
newline. If the frozen top eight overflow, reject the **whole** invocation;
never truncate, drop an expensive winner or substitute a cheaper ninth rank.
The list is **not a complete scorer candidate**. Future trusted integration must
independently validate exact source anchors/scope, assemble the separately
reviewed coverage/schema envelope, and check the **complete** canonical 8192-byte
candidate. List fitting proves neither envelope fitting nor complete coverage.

## Predeclared language coverage and precise gaps

### Python

Parse the entire normalized file with the running interpreter's `ast.parse`,
then map actual function/class AST locations back to stdlib `tokenize` NAME
tokens. This excludes comments, ordinary/triple/f-strings and call sites without
regex-grepping source. Include `def`, `async def`, `class`, decorated and nested
declarations. The raw source NAME token, not AST's NFKC-normalized name, must be
wholly ASCII: `def K()` never becomes a false `K` match, nor `resolveé` a
`resolve` match. Keyword/name split by explicit line continuation is excluded.

A syntax/tokenization failure anywhere rejects the entire invocation; there is
no prefix success. Grammar support depends on the **running Python version**,
not a pinned Python language server. Newer syntax unsupported by that interpreter
rejects. UTF-8 BOM text is unsupported by this string-parser path and rejects.
AST parsing does not perform compiler context/name/type checks: e.g. top-level
`return` can parse, but would fail compilation; no compilation is attempted.
Runtime-created definitions, imports/reexports/aliases, dynamic calls, Unicode
declaration names and multiline keyword/name layouts are not resolved.

### Rust

This is a **stdlib-only constrained lexer/textual recognizer, not rustc or a
complete Rust grammar certification**. Recognize named `fn`, `struct`, `enum`,
`trait`, `type`, `const`, `static`, `mod`; include visibility/async/unsafe/extern
modifiers, impl methods, associated types/constants, and `static mut` (skip
`mut`). Treat source-declared cfg branches textually, not by target selection.
Support raw ASCII names `r#resolve`, including raw reserved-word names; output
still preserves the original whole line. Unicode names are consumed atomically
and excluded, not split into false ASCII matches.

Skip line and nested block comments; escaped normal/byte/C strings; raw, raw-byte
and raw-C strings with zero or multiple hashes; scalar/escaped character and byte
character literals versus identifier lifetimes/labels. Opaque literal tokens
prevent accidental keyword/name joining. Exclude `macro_rules!` definitions and
all identifier/path macro invocation token-tree contents (`()`, `[]`, `{}`),
and attribute token trees. No macro expansion or macro-generated declarations.
Validate balanced delimiters even inside excluded macro groups. Unterminated
strings/escaped chars/comments and unbalanced groups reject with no partial
anchors; unsupported macro-2.0 `macro name` definitions reject explicitly.

Skip generic parameter lists following named fn/struct/enum/trait/type/union
headers and `impl`/`for`; `union` itself is **not** a supported declaration kind.
Nested angles and function return arrows are distinguished; grouped const
expressions are skipped. Const generic parameters are not declarations. Function
pointer `fn(...)` has no declared name and is excluded.

Remaining textual gaps/counterexamples are intentional limitations, **not a
claim that malformed Rust was validated**:

- No expression/item/type grammar, edition-aware keyword legality, binding
  resolution or type checking. Malformed `let fn resolve() {}` can yield a textual
  declaration; missing function parameter/body grammar is not diagnosed.
- An apostrophe plus identifier without a closing quote is lexically a lifetime
  (`'a`), including malformed expression contexts like `let x = 'a`; only a Rust
  grammar could decide whether that context intended an unterminated char.
- Generic-angle tracking is only for the declared header forms, not arbitrary
  expression comparisons, qualified paths or unrestricted const-expression
  grammar. Unsupported/unbalanced recognized generic layouts may reject a file;
  this is not complete type parsing.
- Escape/content recognition is sufficient to isolate literals, not to certify
  every escape's value/width, byte/C-string validity, raw-hash/edition limits,
  Unicode XID version, shebang or invalid-token grammar. For example, an out-of-
  range Unicode escape is not a compiler-validated character value.
- Attribute/procedural expansion, cfg evaluation, generated code, aliases,
  transitive/direct callers and cross-file semantics are absent. A declaration
  retained from a cfg-disabled branch is not evidence it exists in a build.

These gaps must travel in future coverage normalization. Success is limited
source-line conformance, not certified language or host support.

## Evidence and remaining gates

Tests assert independently authored expected whole anchors, not implementation
source text/AST shape. They cover both languages, ordering/deduplication, lexical
exclusions, failure after an earlier valid declaration, inclusive/overflow UTF-8
budgets, top-eight retention, nonmutation and fresh recovery. Mocked AST-parser
failure is an in-process dependency boundary, **not** worker cancellation or
process recovery. Inert repeated-byte resource fixtures test bounded arithmetic,
not retrieval performance or a medium/large corpus pilot.

One actual frozen **small** corpus conformance case uses all 16 selected `harbor`
sources from the 32-source paired fixture and independently lists eight expected
declaration anchors. Macro bodies/call sites are absent as required. The fixed
repository-owned generator module is imported only by this test; no private
cross-checkout path or algorithm copy. Oracle/hash/coverage data never enters
`retrieve`; no scorer metrics, quality comparison or full-corpus retrieval pilot
is run. Existing corpus/adapter regression tests separately exercise their own
tiers without invoking this retriever on medium/large inputs.

Other evaluation modules, algorithm pins and shared workflows are untouched.
The parent owns workflow integration after latest-main integration, independent
review, the exact committed tested SHA and matching remote CI evidence. See
[progress and checks](../../docs/progress/phase-1-evaluation-symbol.md).
