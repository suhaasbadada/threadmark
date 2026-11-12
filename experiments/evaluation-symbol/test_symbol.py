"""Authored expected source anchors; never execute the synthetic source strings."""
import copy
from dataclasses import FrozenInstanceError, asdict
import importlib.util
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import weakref

from symbol import Anchor, retrieve


def task(query="resolve", family="definition_directcall"):
    return {"schema": "evaluation-scoring/1",
            "scope": {"project": "harbor", "worktree": "tree", "revision": "rev"},
            "family": family, "query": query, "instructions": "Do not execute.\nKeep scope."}


def sources(text, ext="rs"):
    return (("harbor/a." + ext, text.encode("utf-8")),)


def size(value):
    return len(json.dumps(value, sort_keys=True, separators=(",", ":"),
                          ensure_ascii=False, allow_nan=False).encode("utf-8"))


class SymbolTests(unittest.TestCase):
    def test_exact_immutable_six_fields(self):
        result = retrieve(sources("pub fn resolve() {}"), task())
        self.assertEqual(result, (Anchor("harbor", "tree", "rev", "harbor/a.rs", 1,
                                         "pub fn resolve() {}"),))
        self.assertIs(type(result), tuple)
        self.assertEqual(set(asdict(result[0])),
                         {"project", "worktree", "revision", "path", "line", "text"})
        with self.assertRaises(FrozenInstanceError):
            result[0].text = "changed"

    def test_rust_every_kind_modified_impl_associated_textual_cfg(self):
        text = ("pub async unsafe extern \"C\" fn Resolve() {}\n"
                "pub(crate) struct Record<T> { value: T }\n"
                "enum Mode { On }\n"
                "unsafe trait Contract { type Item; const LIMIT: u8; }\n"
                "type Alias = Record<u8>;\n"
                "const LIMIT: u8 = 1;\n"
                "static mut CACHE: u8 = 0;\n"
                "mod nested;\n"
                "impl Record<u8> { pub fn resolve(&self) {} }\n"
                "#[cfg(any())]\nfn resolve() {}\n"
                "#[cfg(not(any()))]\nfn resolve() {}")
        # Each expected coordinate/text is independently authored, not parsed to
        # synthesize a declaration oracle from the implementation's decisions.
        result = retrieve(sources(text), task("Resolve Record Mode Contract Item Alias CACHE nested"))
        self.assertEqual([(a.line, a.text) for a in result], [
            (1, 'pub async unsafe extern "C" fn Resolve() {}'),
            (2, 'pub(crate) struct Record<T> { value: T }'),
            (3, 'enum Mode { On }'),
            (4, 'unsafe trait Contract { type Item; const LIMIT: u8; }'),
            (5, 'type Alias = Record<u8>;'), (7, 'static mut CACHE: u8 = 0;'), (8, 'mod nested;')])
        self.assertEqual([a.line for a in retrieve(sources(text), task("LIMIT resolve"))],
                         [4, 6, 9, 11, 13])

    def test_python_normal_async_class_nested_and_decorators(self):
        text = ("@decorate\nasync def resolve():\n"
                "    def inner(): pass\n"
                "    class Nested: pass\n"
                "class Outer:\n    async def method(self): pass\n"
                "def plain(): pass\n")
        result = retrieve(sources(text, "py"), task("method inner Nested Outer resolve plain"))
        self.assertEqual([(a.line, a.text) for a in result], [
            (6, '    async def method(self): pass'), (3, '    def inner(): pass'),
            (4, '    class Nested: pass'), (5, 'class Outer:'),
            (2, 'async def resolve():'), (7, 'def plain(): pass')])

    def test_query_exact_case_first_occurrence_ascii_maximal(self):
        data = sources("fn foo() {}\nfn Foo() {}\nfn _X2() {}\nfn Bar() {}\n"
                       "fn na() {}\nfn ve() {}\nfn caf() {}\nfn Locate() {}\nfn resolve() {}")
        value = task("Foo foo Foo 9Bar _X2 naïve café Locate 123")
        value["instructions"] = "resolve foo _X2"  # Never query expansion.
        self.assertEqual([a.line for a in retrieve(data, value)], [2, 1, 4, 3, 5, 6, 7, 8])
        self.assertEqual(retrieve(data, task("FOO resolving res")), ())
        self.assertEqual(retrieve(data, task("123 é 中")), ())

    def test_ties_utf8_paths_then_numeric_lines_both_languages(self):
        data = (("harbor/Z.rs", b"fn resolve() {}"),
                ("harbor/a.py", b"def resolve(): pass"),
                ("harbor/é.rs", b"fn resolve() {}"))
        self.assertEqual([(a.path, a.line) for a in retrieve(data, task())],
                         [("harbor/Z.rs", 1), ("harbor/a.py", 1), ("harbor/é.rs", 1)])
        for ext, text in (("rs", "fn resolve() {}\n"), ("py", "def resolve(): pass\n")):
            result = retrieve(sources(text * 12, ext), task())
            self.assertEqual([a.line for a in result], list(range(1, 9)))

    def test_line_once_with_best_identifier_and_distinct_coordinates(self):
        data = sources("fn later() {} fn first() {}\nfn later() {}\nfn first() {}")
        self.assertEqual([(a.line, a.text) for a in retrieve(data, task("first later"))],
                         [(1, 'fn later() {} fn first() {}'), (3, 'fn first() {}'),
                          (2, 'fn later() {}')])

    def test_rust_comments_nested_comments_and_strings(self):
        text = '''// fn resolve() {}
/* outer /* fn resolve() {} */ fn resolve() {} */
const S: &str = "fn resolve() {} \\\" fn resolve() {}";
const B: &[u8] = b"fn resolve() {}";
const C: &CStr = c"fn resolve() {}";
const R: &str = r###"fn resolve() {} \"## still raw"###;
const BR: &[u8] = br##"fn resolve() {}"##;
const CR: &CStr = cr#"fn resolve() {}"#;
fn resolve() {}
'''
        self.assertEqual([(a.line, a.text) for a in retrieve(sources(text), task())],
                         [(9, 'fn resolve() {}')])

    def test_rust_chars_escapes_and_lifetimes(self):
        text = r"""const A: char = '\'';
const B: u8 = b'"';
const C: char = '\u{7b}';
const D: u8 = b'\x7d';
const E: char = 'é';
fn resolve<'a>(x: &'a str) -> &'a str { x }
fn borrow(x: &'static str) { 'label: loop { break 'label; } }
"""
        self.assertEqual([(a.line, a.text) for a in retrieve(sources(text), task())],
                         [(6, "fn resolve<'a>(x: &'a str) -> &'a str { x }")])

    def test_rust_macros_all_groups_paths_and_attributes_excluded(self):
        text = '''macro_rules! create_symbol { () => { fn resolve() {} }; }
create_symbol!();
crate::emit! { fn resolve() {} nested!([{}]); }
emit!(fn resolve() {});
emit![fn resolve() {}];
#[attribute(fn resolve() {})]
fn actual() { resolve(); }
fn resolve() {}
'''
        self.assertEqual([(a.line, a.text) for a in retrieve(sources(text), task())],
                          [(8, 'fn resolve() {}')])

    def test_rust_not_and_inequality_are_not_macro_invocations(self):
        for expression in ("if !ready() {}", "while !ready() {}",
                           "let different = left != right;", "return !ready();"):
            text = "fn outer() -> bool {\n " + expression + "\n fn inner() {}\n}"
            with self.subTest(expression=expression):
                self.assertEqual([(a.line, a.text) for a in
                                  retrieve(sources(text), task("inner outer"))],
                                 [(3, " fn inner() {}"), (1, "fn outer() -> bool {")])
        # Raw keyword identifiers can still name macros; their bodies stay opaque.
        self.assertEqual([a.line for a in retrieve(
            sources("r#if! { fn resolve() {} }\nfn resolve() {}"), task())], [2])

    def test_rust_generics_and_function_pointer_types_not_declarations(self):
        text = ("struct Holder<const resolve: usize, T> { item: T }\n"
                "fn generic<const resolve: usize>() {}\n"
                "trait Rule<const resolve: usize> {}\n"
                "type Alias<const resolve: usize> = Holder<resolve, u8>;\n"
                "enum Kind<const resolve: usize> { On }\n"
                "impl<const resolve: usize> Holder<resolve, u8> { fn method() {} }\n"
                "type Pointer = for<'a> unsafe extern \"C\" fn(&'a str);\n"
                "static PTR: fn() = target;\n"
                "const fn resolve() {}\n")
        self.assertEqual([(a.line, a.text) for a in retrieve(sources(text), task("resolve fn"))],
                          [(9, 'const fn resolve() {}')])

    def test_rust_edition_2015_macro_names_keep_token_trees_opaque(self):
        for name in ("try", "async", "await", "dyn"):
            for body in ("({ fn resolve() {} Ok(()) })", "{ fn resolve() {} }",
                         "[fn resolve() {}]"):
                with self.subTest(name=name, body=body):
                    text = "fn actual() {\n " + name + "!" + body + ";\n}\nfn resolve() {}\n"
                    self.assertEqual([a.line for a in retrieve(sources(text), task())], [4])

    def test_generic_function_type_return_arrows_and_union_parameters(self):
        text = ("union Storage<const resolve: usize> { bytes: [u8; resolve] }\n"
                "fn generic<T: Fn() -> u8, const resolve: usize>() {}\n"
                "struct Wrapped<T: Fn() -> Vec<u8>, const resolve: usize>(T);\n"
                "impl<T: Fn() -> u8, const resolve: usize> Wrapped<T, resolve> {}\n"
                "fn resolve() {}")
        self.assertEqual([(a.line, a.text) for a in retrieve(sources(text), task())],
                         [(5, 'fn resolve() {}')])

    def test_rust_literal_forms_and_comment_token_separation(self):
        for literal in ('"fn resolve() {}"', 'b"fn resolve() {}"', 'c"fn resolve() {}"',
                        'r"fn resolve() {}"', 'br"fn resolve() {}"', 'cr"fn resolve() {}"',
                        'r#####"fn resolve() {} \\"####"#####',
                        '"first\nfn resolve() {}\nlast"'):
            text = "let text = " + literal + ";\nfn /* between */ resolve() {}"
            expected_line = 4 if "\n" in literal else 2
            with self.subTest(literal=literal):
                self.assertEqual([(a.line, a.text) for a in retrieve(sources(text), task())],
                                 [(expected_line, 'fn /* between */ resolve() {}')])
        self.assertEqual([a.line for a in retrieve(sources("static /*c*/ mut resolve: u8 = 0;"), task())],
                         [1])
        self.assertEqual(retrieve(sources("fn /*\n*/ resolve() {}"), task()), ())

    def test_rust_raw_ascii_names_keywords_and_unicode_not_split(self):
        text = ("fn r#resolve() {}\nstruct r#type;\nfn résolve() {}\nfn resolveé() {}\n"
                "fn K() {}\nfn resolve\u0301() {}\nfn resolve() {}")
        self.assertEqual([a.line for a in retrieve(sources(text), task("resolve type K"))], [1, 7, 2])
        self.assertEqual(retrieve(sources(text), task("r")), ())

    def test_python_strings_comments_fstrings_not_regex(self):
        text = '''# def resolve(): pass
"""class resolve: pass
async def resolve(): pass"""
s = "def resolve(): pass"
s = f"def resolve(): {1}"
def caller(): return resolve()
def resolve(): pass
'''
        self.assertEqual([(a.line, a.text) for a in retrieve(sources(text, "py"), task())],
                         [(7, 'def resolve(): pass')])

    def test_python_unicode_names_no_nfkc_or_ascii_split(self):
        text = "def résolve(): pass\ndef resolveé(): pass\ndef K(): pass\ndef resolve\u0301(): pass\ndef resolve(): pass"
        self.assertEqual([a.line for a in retrieve(sources(text, "py"), task("resolve K"))], [5])

    def test_python_split_unicode_name_prefixes_all_declaration_kinds(self):
        for declaration in ("def {name}(): pass", "async def {name}(): pass",
                            "class {name}: pass"):
            for name in ("resolve\u0301", "resolve\u0327", "resolveé", "K"):
                with self.subTest(declaration=declaration, name=name):
                    text = declaration.format(name=name) + "\ndef resolve(): pass\n"
                    self.assertEqual([a.line for a in retrieve(sources(text, "py"),
                                                              task("resolve K"))], [2])

    def test_keyword_name_and_async_share_physical_lf_line(self):
        rust = "fn\nresolve() {}\nstatic mut\nresolve: u8 = 0;\nfn resolve() {}"
        self.assertEqual([a.line for a in retrieve(sources(rust), task())], [5])
        python = "def \\\nresolve(): pass\nasync \\\ndef resolve(): pass\nclass \\\nresolve: pass\nasync def resolve(): pass"
        self.assertEqual([a.line for a in retrieve(sources(python, "py"), task())], [7])

    def test_lf_crlf_blank_numbering_and_final_segment(self):
        for ext, line in (("rs", "fn resolve() {}"), ("py", "def resolve(): pass")):
            for separator in ("\n", "\r\n"):
                text = separator + line + separator * 2 + line + separator
                self.assertEqual([(a.line, a.text) for a in retrieve(sources(text, ext), task())],
                                 [(2, line), (4, line)])
            self.assertEqual(retrieve(sources(line + "\r", ext), task())[0].text, line)
            for text in (line + "\r\r\n", "res\rolve"):
                with self.assertRaises(ValueError):
                    retrieve(sources(text, ext), task())
            self.assertEqual(retrieve(sources("", ext), task()), ())
        self.assertEqual(retrieve(sources('fn resolve() {} // \u2028 still same line'), task())[0].line, 1)

    def test_markdown_approved_but_never_symbols(self):
        self.assertEqual(retrieve(sources("def resolve(): pass\nfn resolve() {}\n```", "md"), task()), ())

    def test_no_staleness_negation_or_permission_semantics(self):
        data = (("harbor/a.rs", b"// stale harbour revision old; do not deploy\nfn resolve() {}"),
                ("harbor/b.py", b"# retired permission unresolved\ndef resolve(): pass"))
        value = task(family="conflictingrules_stale_wrongrevision")
        self.assertEqual([(a.path, a.line) for a in retrieve(data, value)],
                         [("harbor/a.rs", 2), ("harbor/b.py", 2)])

    def test_python_invalid_entire_file_rejects_no_partial_no_token_success(self):
        for text in ("def resolve(): pass\ndef broken(:", "def resolve(): pass\n'''",
                     "def resolve(): pass\n  bad indentation", "def resolve(): pass\nx = ("):
            for query in ("resolve", "123 é"):
                with self.subTest(text=text, query=query), self.assertRaisesRegex(ValueError, "symbol input"):
                    retrieve(sources(text, "py"), task(query))

    def test_rust_unterminated_literals_comments_and_macro_groups_closed(self):
        bad = ['"unterminated', 'b"unterminated', 'c"unterminated',
               'r###"x"##', 'br##"x"#', 'cr#"x', '/* /* nested */',
               "'\\", "'\\x1'", "'\\u{bad'", "b'x", "'ab'",
               "emit!({ fn resolve() {} ]);", "macro_rules! m { () => { fn resolve() {} };",
               "emit!", "macro m() {}"]
        for suffix in bad:
            data = sources("fn resolve() {}\n" + suffix)
            for query in ("resolve", "123 é"):
                with self.subTest(suffix=suffix, query=query), self.assertRaises(ValueError):
                    retrieve(data, task(query))
        self.assertEqual(len(retrieve(sources("const C: char = '{';\nfn resolve() {}"), task())), 1)

    def test_later_source_invalid_closes_whole_result(self):
        for ext, text in (("py", b"def broken(:"), ("rs", b"/*"), ("md", b"\xff")):
            with self.assertRaises(ValueError):
                retrieve((("harbor/a.rs", b"fn resolve() {}"), ("harbor/z." + ext, text)), task())

    def test_root_mismatch_both_similarly_named_projects(self):
        for selected, foreign in (("harbor", "harbour"), ("harbour", "harbor")):
            value = task()
            value["scope"]["project"] = selected
            with self.assertRaises(ValueError):
                retrieve(((foreign + "/a.rs", b"fn resolve() {}"),), value)
            self.assertEqual(retrieve(((selected + "/a.rs", b"fn resolve() {}"),), value)[0].project,
                             selected)

    def test_bad_paths_and_validate_even_no_matches(self):
        for path in ("", "/harbor/a.rs", "a.rs", "harbor//a.rs", "harbor/./a.rs", "harbor/../a.rs",
                     "harbor/a\\b.rs", "harbor/a\x00.rs", "harbor/a\x7f.rs", "harbor/a\n.rs",
                     "harbor/a.txt", "harbor/a.RS", "harbor/", "harbor/\ud800.rs", None, 1):
            with self.subTest(path=repr(path)), self.assertRaises(ValueError):
                retrieve(((path, b""),), task("123 é"))

    def test_source_containers_types_order_duplicates_utf8(self):
        for data in ([], [("harbor/a.rs", b"")], (["harbor/a.rs", b""],),
                     (("harbor/a.rs",),), (("harbor/a.rs", ""),),
                     (("harbor/a.rs", bytearray()),), (("harbor/a.rs", None),),
                     (("harbor/a.rs", b"\xff"),), (("harbor/a.rs", b"", "extra"),),
                     (("harbor/a.rs", b""), ("harbor/a.rs", b"")),
                     (("harbor/z.rs", b""), ("harbor/a.rs", b""))):
            with self.subTest(data=repr(data)), self.assertRaises(ValueError):
                retrieve(data, task("123 é"))

    def test_exact_task_schema_types_utf8_scope(self):
        bad = [None, [], {}]
        for key in task():
            value = task()
            del value[key]
            bad.append(value)
            for replacement in (None, [], {}, 1, True, b"resolve"):
                value = task()
                value[key] = replacement
                bad.append(value)
        for key in ("oracle", "gold", "hash", "coverage", "target_files"):
            value = task()
            value[key] = "forbidden"
            bad.append(value)
        for key in ("query", "instructions", "family", "schema"):
            for replacement in ("", "\ud800"):
                value = task()
                value[key] = replacement
                bad.append(value)
        for key in ("project", "worktree", "revision"):
            for replacement in (None, True, "", "../x", "x/y", "x\\y", "x\n", "é", "x" * 129):
                value = task()
                value["scope"][key] = replacement
                bad.append(value)
            value = task()
            del value["scope"][key]
            bad.append(value)
        value = task()
        value["scope"]["extra"] = "no"
        bad.append(value)
        for value in bad:
            with self.subTest(value=repr(value)), self.assertRaises(ValueError):
                retrieve((), value)
        for family in ("negations_permission", "rename_delete_malformed_interruption_recovery", "other"):
            with self.assertRaises(ValueError):
                retrieve((), task(family=family))
        value = task()
        value["schema"] = "evaluation-scoring/2"
        with self.assertRaises(ValueError):
            retrieve((), value)

    def test_source_count_inclusive_and_overflow(self):
        data = tuple((f"harbor/{n:04}.rs", b"") for n in range(2048))
        self.assertEqual(retrieve(data, task()), ())
        with self.assertRaises(ValueError):
            retrieve(data + (("harbor/2048.rs", b""),), task())

    def test_file_multibyte_inclusive_and_overflow(self):
        block = "//" + "é" * 32767
        self.assertEqual(retrieve(sources(block), task()), ())
        with self.assertRaises(ValueError):
            retrieve(sources(block + "x"), task())

    def test_aggregate_inclusive_and_overflow(self):
        # Owned inert arithmetic fixtures, not medium/large retrieval or a pilot.
        data = tuple((f"harbor/{n:04}.md", b" " * 65536) for n in range(512))
        self.assertEqual(retrieve(data, task("123 é")), ())
        with self.assertRaises(ValueError):
            retrieve(data + (("harbor/0512.md", b"x"),), task("123 é"))

    def test_request_canonical_utf8_inclusive_overflow(self):
        value = task("é")
        value["instructions"] = "x"
        value["instructions"] += "x" * (4096 - size({k: value[k] for k in ("query", "instructions")}))
        self.assertEqual(retrieve((), value), ())
        value["instructions"] += "x"
        with self.assertRaises(ValueError):
            retrieve((), value)
        value["instructions"] = value["instructions"][:-1] + "é"
        with self.assertRaises(ValueError):
            retrieve((), value)

    def test_anchor_list_canonical_utf8_8192_and_whole_overflow(self):
        for ext, base in (("rs", "fn resolve() {} //"), ("py", "def resolve(): pass #")):
            anchor = Anchor("harbor", "tree", "rev", "harbor/a." + ext, 1, base)
            remaining = 8192 - size([asdict(anchor)])
            text = base + "é" * (remaining // 2) + "x" * (remaining % 2)
            result = retrieve(sources(text, ext), task())
            self.assertEqual(size([asdict(a) for a in result]), 8192)
            for suffix in ("x", "é"):
                with self.assertRaises(ValueError):
                    retrieve(sources(text + suffix, ext), task())
            # No cheaper ninth replacement, dropping winners or truncating text.
            with self.assertRaises(ValueError):
                retrieve(sources(text + "x\n" + (base + "\n") * 8, ext), task())

    def test_incremental_top_eight_retention_both_languages(self):
        for ext, line in (("rs", "fn resolve() {}\n"), ("py", "def resolve(): pass\n")):
            live, peak = weakref.WeakSet(), 0

            def tracked(*args):
                nonlocal peak
                anchor = Anchor(*args)
                live.add(anchor)
                peak = max(peak, len(live))
                return anchor

            with patch("symbol.Anchor", side_effect=tracked):
                result = retrieve(sources(line * 1024, ext), task())
            self.assertEqual([a.line for a in result], list(range(1, 9)))
            self.assertLessEqual(peak, 9)

    def test_deterministic_nonmutating_fresh_recovery_dependency_failure(self):
        value = task()
        data = sources("def resolve(): pass", "py")
        before = copy.deepcopy((data, value))
        expected = retrieve(data, value)
        with patch("symbol.ast.parse", side_effect=ValueError("unavailable")):
            with self.assertRaises(ValueError):
                retrieve(data, value)
        with self.assertRaises(ValueError):
            retrieve(sources("def resolve(:", "py"), value)
        for _ in range(3):
            self.assertEqual(retrieve(data, value), expected)
        self.assertEqual((data, value), before)
        value["scope"]["revision"] = "changed"
        self.assertEqual(expected[0].revision, "rev")
        self.assertEqual(retrieve(data, value)[0].revision, "changed")
        self.assertEqual(retrieve(sources("def renamed(): pass", "py"), task()), ())
        self.assertEqual(retrieve((), task()), ())

    def test_actual_small_frozen_corpus_declarations_not_macros_or_calls(self):
        # Fixed repository-owned import, no private cross-checkout modules. This
        # tiny case uses all selected-root small sources and never reads oracle
        # fields to build the retrieval input or compute expected answers.
        path = Path(__file__).resolve().parents[1] / "evaluation-corpus" / "corpus.py"
        spec = importlib.util.spec_from_file_location("symbol_test_corpus", path)
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        corpus = module.build("small")
        self.assertEqual(module.validate(corpus),
                         "c497a577eb9699d15da30b02a215784df36bafeafcb643c83c983ba540e6c9e8")
        value = task("Locate resolve and its direct callers in this scope.")
        value["scope"] = module.scope("harbor")
        selected = tuple((p, b) for p, b in corpus.sources if p.startswith("harbor/"))
        result = retrieve(selected, value)
        self.assertEqual([(a.path, a.line, a.text) for a in result], [
            ("harbor/src/unit_0000.rs", 2, "pub fn resolve() -> u32 { 0 }"),
            ("harbor/src/unit_0001.py", 2, "def resolve():"),
            ("harbor/src/unit_0004.rs", 2, "pub fn resolve() -> u32 { 4 }"),
            ("harbor/src/unit_0005.py", 2, "def resolve():"),
            ("harbor/src/unit_0008.rs", 2, "pub fn resolve() -> u32 { 8 }"),
            ("harbor/src/unit_0009.py", 2, "def resolve():"),
            ("harbor/src/unit_0012.rs", 2, "pub fn resolve() -> u32 { 12 }"),
            ("harbor/src/unit_0013.py", 2, "def resolve():")])


if __name__ == "__main__":
    unittest.main()
