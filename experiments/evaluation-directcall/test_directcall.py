"""Independent literal fixtures; no fixture source execution, compiler or worker."""
from dataclasses import FrozenInstanceError, asdict, replace
from importlib import import_module
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import directcall as d


SCOPE = {"project": "p", "worktree": "w", "revision": "r"}


def sources(text, suffix="py", path=None):
    return ((path or "p/a." + suffix, text.encode("utf-8")),)


def task(query="target", instructions="Do not execute."):
    return {"schema": "evaluation-scoring/1", "scope": dict(SCOPE),
            "family": "definition_directcall", "query": query, "instructions": instructions}


def anchors(value):
    return [(a.path, a.line, a.text) for a in value]


def edges(extraction):
    return [(c.line, c.target[-1]) for c in extraction.resolvedcalls]


class DirectcallTests(unittest.TestCase):
    def test_python_literal_edges_ids_anchors(self):
        source = sources("def target(): pass\ndef caller():\n    target()\n    target()\n")
        result = d.extract(source, SCOPE)
        target = ("p", "w", "r", "p/a.py", "python", (("python_module", 0, 58),), 0, "def", "target")
        self.assertEqual(result.declarations[0].id, target)
        self.assertEqual([(c.target, c.span, c.line) for c in result.resolvedcalls],
                         [(target, (37, 43), 3), (target, (50, 56), 4)])
        self.assertEqual(result.resolvedcalls[0].id,
                         ("p", "w", "r", "p/a.py", "python",
                          (("python_module", 0, 58), ("python_function", 19, 58)), 37, 43))
        self.assertEqual(anchors(d.retrieve(source, task())), [
            ("p/a.py", 1, "def target(): pass"), ("p/a.py", 3, "    target()"), ("p/a.py", 4, "    target()")])

    def test_rust_literal_edges_ids_anchors(self):
        source = sources("fn target() {}\nfn caller() {\n target();\n target();\n}\n", "rs")
        result = d.extract(source, SCOPE)
        target = ("p", "w", "r", "p/a.rs", "rust", (("rust_file", 0, 52),), 0, "fn", "target")
        self.assertEqual(result.declarations[0].id, target)
        self.assertEqual([(c.target, c.span, c.line) for c in result.resolvedcalls],
                         [(target, (30, 36), 3), (target, (41, 47), 4)])
        self.assertEqual(result.resolvedcalls[0].id,
                         ("p", "w", "r", "p/a.rs", "rust",
                          (("rust_file", 0, 52), ("rust_function", 27, 52)), 30, 36))
        self.assertEqual(anchors(d.retrieve(source, task())), [
            ("p/a.rs", 1, "fn target() {}"), ("p/a.rs", 3, " target();"), ("p/a.rs", 4, " target();")])

    def test_distinct_calls_same_line_and_two_lines(self):
        for suffix, text in (("py", "def target(): pass\ndef caller():\n target(); target()\n target()"),
                             ("rs", "fn target() {}\nfn caller() {\n target(); target();\n target();\n}")):
            with self.subTest(suffix=suffix):
                source = sources(text, suffix)
                result = d.extract(source, SCOPE)
                self.assertEqual(edges(result), [(3, "target"), (3, "target"), (4, "target")])
                self.assertEqual(len({c.id for c in result.resolvedcalls}), 3)
                self.assertEqual([a.line for a in d.retrieve(source, task())], [1, 3, 4])

    def test_renamed_files_names_declaration_order(self):
        for suffix, text in (("py", "def caller():\n return aubergine()\ndef aubergine(): pass"),
                             ("rs", "fn caller() { aubergine(); }\nfn aubergine() {}")):
            with self.subTest(suffix=suffix):
                source = sources(text, suffix, "p/renamed." + suffix)
                self.assertEqual(edges(d.extract(source, SCOPE)), [(2 if suffix == "py" else 1, "aubergine")])
                self.assertEqual([a.line for a in d.retrieve(source, task("aubergine"))],
                                 [3, 2] if suffix == "py" else [2, 1])

    def test_python_assignment_return_nested_keyword_calls(self):
        result = d.extract(sources("def target(): pass\ndef wrap(x=None): pass\ndef caller():\n x = target()\n return wrap(target(), x=target())"), SCOPE)
        self.assertEqual(edges(result), [(4, "target"), (5, "wrap"), (5, "target"), (5, "target")])

    def test_python_initialized_local_and_shadow(self):
        result = d.extract(sources("def target(): pass\ndef caller():\n def target(): pass\n target()"), SCOPE)
        self.assertEqual(edges(result), [(4, "target")])
        self.assertEqual(result.resolvedcalls[0].target[-3:], (34, "def", "target"))
        self.assertEqual(result.resolvedcalls[0].target[-4],
                         (("python_module", 0, 62), ("python_function", 19, 62)))

    def test_python_local_not_initialized(self):
        result = d.extract(sources("def target(): pass\ndef caller():\n target()\n def target(): pass"), SCOPE)
        self.assertEqual(edges(result), [])
        self.assertEqual(result.observedcoverage[0].unresolved[0].reason, "local_function_not_initialized")

    def test_python_whole_function_masks(self):
        bodies = ["target = 1", "target += 1", "target: int", "del target", "import target",
                  "import other as target", "from other import target", "from other import x as target",
                  "for target in []:\n  pass", "with other() as target:\n  pass",
                  "try:\n  pass\n except Exception as target:\n  pass", "(target := other)",
                  "match other:\n  case target:\n   pass", "global target", "nonlocal target"]
        for body in bodies:
            with self.subTest(body=body):
                result = d.extract(sources("def target(): pass\ndef caller():\n target()\n " + body), SCOPE)
                self.assertNotIn((3, "target"), edges(result))
                self.assertTrue(result.observedcoverage[0].unresolved)

    def test_python_parameters_mask_all_forms(self):
        for args in ("target", "target, /", "*, target", "*target", "**target"):
            with self.subTest(args=args):
                self.assertEqual(edges(d.extract(sources(
                    "def target(): pass\ndef caller(" + args + "):\n target()"), SCOPE)), [])

    def test_python_duplicates_conditional_and_decorators(self):
        for text in ("def target(): pass\ndef target(): pass\ntarget()",
                     "if flag:\n def target(): pass\ntarget()",
                     "@replacement\ndef target(): pass\ntarget()",
                     "def caller():\n if flag:\n  def target(): pass\n target()"):
            with self.subTest(text=text):
                result = d.extract(sources(text), SCOPE)
                self.assertEqual(edges(result), [])
                self.assertTrue(any(item.name == "target" for item in result.declarations))

    def test_python_class_not_method_closure(self):
        result = d.extract(sources("def target(): pass\nclass C:\n def target(): pass\n def caller(self):\n  target()\n  self.target()"), SCOPE)
        self.assertEqual(edges(result), [(5, "target")])
        self.assertEqual(result.resolvedcalls[0].target[-3:], (0, "def", "target"))
        self.assertEqual(result.observedcoverage[0].unresolved[0].reason, "non_bare_or_non_ascii_callee")

    def test_python_class_forward_binding_never_targets_later_method(self):
        source = sources("def target(): pass\nclass C:\n target()\n def target(): pass\n target()")
        result = d.extract(source, SCOPE)
        self.assertEqual(edges(result), [(5, "target")])
        method = next(x for x in result.declarations if x.kind == "def" and x.line == 4)
        self.assertEqual(result.resolvedcalls[0].target, method.id)
        self.assertEqual(result.observedcoverage[0].unresolved[0].reason,
                         "class_binding_not_initialized")
        self.assertEqual([a.line for a in d.retrieve(source, task())], [1, 4, 5])

    def test_python_constructor_unsupported(self):
        result = d.extract(sources("class target: pass\ntarget()"), SCOPE)
        self.assertEqual(edges(result), [])
        self.assertEqual(result.declarations[0].kind, "class")

    def test_python_comprehensions_masks_and_first_iterable(self):
        result = d.extract(sources("def target(): pass\nx = [target() for target in []]\ny = [n for n in target()]\nz = target()"), SCOPE)
        self.assertEqual(edges(result), [(3, "target"), (4, "target")])

    def test_python_comprehension_walrus_masks_outer(self):
        result = d.extract(sources("def target(): pass\ndef caller():\n target()\n x = [(target := n) for n in []]"), SCOPE)
        self.assertEqual(edges(result), [])

    def test_python_match_mapping_rest_masks(self):
        result = d.extract(sources("def target(): pass\ndef caller():\n target()\n match x:\n  case {'x': y, **target}: pass"), SCOPE)
        self.assertEqual(edges(result), [])

    def test_python_alias_dynamic_member_subscript_not_basename(self):
        result = d.extract(sources("def target(): pass\na = target\na()\nobj.target()\nitems[0]()\nglobals()['target']()"), SCOPE)
        self.assertEqual(edges(result), [])
        self.assertEqual(len(result.observedcoverage[0].unresolved), 5)

    def test_python_definition_execution_context_not_body_walked(self):
        result = d.extract(sources("def target(): pass\n@target()\ndef caller(x=target(), y: target()=0) -> target():\n target()"), SCOPE)
        self.assertEqual(edges(result), [(4, "target")])
        self.assertIn("definition_defaults_annotations_decorators_bases_not_resolved", result.observedcoverage[0].gaps)

    def test_python_definition_time_namedexpr_masks_outer(self):
        for context in ("def caller(x=(target := 0)): pass", "class C((target := base)): pass",
                        "@decorate(target := replacement)\ndef caller(): pass"):
            with self.subTest(context=context):
                result = d.extract(sources("def target(): pass\n" + context + "\ntarget()"), SCOPE)
                self.assertEqual(edges(result), [])

    def test_python_annotation_namedexpr_masks_module_and_class(self):
        for text in ("def target(): pass\nx: (target := replacement)\ntarget()",
                     "def target(): pass\nclass C:\n def target(): pass\n x: (target := replacement)\n target()"):
            with self.subTest(text=text):
                result = d.extract(sources(text), SCOPE)
                self.assertEqual(edges(result), [])
                self.assertIn("annotation_execution_not_resolved", result.observedcoverage[0].gaps)
                self.assertEqual(result.observedcoverage[0].unresolved[0].reason,
                                 "masked_or_ambiguous_binding")

    def test_python_lambda_parameters(self):
        result = d.extract(sources("def target(): pass\nx = lambda target: target()\ny = lambda: target()"), SCOPE)
        self.assertEqual(edges(result), [(3, "target")])

    def test_python_star_import_scope_poison(self):
        result = d.extract(sources("def target(): pass\nfrom unknown import *\ntarget()"), SCOPE)
        self.assertEqual(edges(result), [])
        self.assertEqual(result.observedcoverage[0].unresolved[0].reason, "scope_poisoned")

    def test_python_async_declaration_keyword(self):
        source = sources("async def target(): pass\ndef caller():\n target()")
        self.assertEqual(edges(d.extract(source, SCOPE)), [(3, "target")])
        self.assertEqual(anchors(d.retrieve(source, task()))[0], ("p/a.py", 1, "async def target(): pass"))

    def test_python_unknown_binding_construct_poison(self):
        if sys.version_info < (3, 12):
            return  # Runtime grammar policy declares this unavailable; no fixture execution.
        result = d.extract(sources("def target(): pass\ntype Alias = int\ntarget()"), SCOPE)
        self.assertEqual(edges(result), [])
        self.assertIn("unknown_statement_scope_poisoned", result.observedcoverage[0].gaps)

    def test_python_unicode_raw_names_not_ascii_prefix(self):
        for name in ("target́", "ｔａｒｇｅｔ", "targetλ"):
            with self.subTest(name=name):
                result = d.extract(sources("def " + name + "(): pass\n" + name + "()"), SCOPE)
                self.assertEqual(result.declarations, ())
                self.assertEqual(edges(result), [])

    def test_utf8_callee_offsets_not_token_char_columns(self):
        result = d.extract(sources("def target(): pass\nx = 'é'; target()"), SCOPE)
        self.assertEqual([(c.span, c.line) for c in result.resolvedcalls], [((29, 35), 2)])
        self.assertEqual(anchors(d.retrieve(sources("def target(): pass\nx = 'é'; target()"), task())),
                         [("p/a.py", 1, "def target(): pass"), ("p/a.py", 2, "x = 'é'; target()")])

    def test_rust_assignment_tail_nested_arguments(self):
        result = d.extract(sources("fn target() {}\nfn wrap(x: i32) {}\nfn caller() {\n let x = target();\n wrap(target());\n target()\n}", "rs"), SCOPE)
        self.assertEqual(edges(result), [(4, "target"), (5, "wrap"), (5, "target"), (6, "target")])

    def test_rust_module_and_block_ownership(self):
        result = d.extract(sources("fn target() {}\npub mod garden {\n fn caller() { target(); }\n fn target() {}\n}\nfn outer() {\n { target(); fn target() {} }\n target();\n}", "rs"), SCOPE)
        self.assertEqual(edges(result), [(3, "target"), (7, "target"), (8, "target")])
        self.assertEqual([c.target[-3] for c in result.resolvedcalls], [60, 103, 0])
        self.assertNotEqual(result.resolvedcalls[0].target[-4], result.resolvedcalls[1].target[-4])

    def test_rust_nested_function_shadows_outer_before_declaration(self):
        result = d.extract(sources("fn target() {}\nfn caller() {\n target();\n fn target() {}\n}", "rs"), SCOPE)
        self.assertEqual(edges(result), [(3, "target")])
        self.assertEqual(result.resolvedcalls[0].target[-3], 41)

    def test_rust_parameter_and_whole_block_local_masks(self):
        for text in ("fn target() {}\nfn caller(target: fn()) { target(); }",
                     "fn target() {}\nfn caller() { target(); let target = other; }"):
            with self.subTest(text=text):
                result = d.extract(sources(text, "rs"), SCOPE)
                self.assertEqual(edges(result), [])
                self.assertEqual(result.observedcoverage[0].unresolved[0].reason, "masked_or_ambiguous_binding")

    def test_rust_unknown_parameter_patterns_poison_function_only(self):
        result = d.extract(sources("fn target() {}\nfn bad((target, x): (fn(), i32)) { target(); }\nfn good() { target(); }", "rs"), SCOPE)
        self.assertEqual(edges(result), [(3, "target")])
        self.assertIn("parameter_pattern_scope_poisoned", result.observedcoverage[0].gaps)

    def test_rust_duplicates_ambiguous(self):
        self.assertEqual(edges(d.extract(sources("fn target() {}\nfn target() {}\nfn caller() { target(); }", "rs"), SCOPE)), [])

    def test_rust_impl_methods_are_not_bare_bindings(self):
        for modifier in ("", "unsafe "):
            with self.subTest(modifier=modifier):
                result = d.extract(sources(modifier + "impl C {\n fn target() {}\n fn caller() { target(); self.target(); Self::target(); }\n}", "rs"), SCOPE)
                self.assertEqual(edges(result), [])
                self.assertFalse(next(x for x in result.declarations if x.name == "target").callable)
                self.assertEqual(len(result.observedcoverage[0].unresolved), 3)

    def test_rust_method_can_reference_file_free_fn(self):
        result = d.extract(sources("fn target() {}\nimpl C {\n fn target() {}\n fn caller() { target(); }\n}", "rs"), SCOPE)
        self.assertEqual(edges(result), [(4, "target")])
        self.assertEqual(result.resolvedcalls[0].target[-3], 0)

    def test_rust_scope_poison_patterns_macros_imports_controls(self):
        statements = ["use a::target;", "use a::*;", "let (target, x) = other;",
                      "let C {target} = other;", "introduce!();", "try!{}", "macro_rules! make { () => {} }",
                      "for target in values {}", "if let target = value {}", "match x { target => {} }",
                      "let f = |target| target();"]
        for statement in statements:
            with self.subTest(statement=statement):
                result = d.extract(sources("fn target() {}\nfn caller() {\n target();\n " + statement + "\n}", "rs"), SCOPE)
                self.assertEqual(edges(result), [])
                self.assertIn("scope_poisoned", [u.reason for u in result.observedcoverage[0].unresolved])

    def test_rust_poison_does_not_cross_unrelated_scope_or_file(self):
        source = (("p/a.rs", b"fn target() {}\nfn bad() { unknown!(); target(); }\nfn good() { target(); }"),
                  ("p/b.rs", b"fn target() {}\nfn good() { target(); }"))
        self.assertEqual([(c.path, c.line) for c in d.extract(source, SCOPE).resolvedcalls],
                         [("p/a.rs", 3), ("p/b.rs", 2)])

    def test_rust_standalone_files_not_basename_merged(self):
        result = d.extract((("p/a.rs", b"fn target() {}"), ("p/b.rs", b"fn caller() { target(); }")), SCOPE)
        self.assertEqual(edges(result), [])

    def test_rust_module_does_not_implicitly_import_parent(self):
        result = d.extract(sources("fn target() {}\nmod inner { fn caller() { target(); } }", "rs"), SCOPE)
        self.assertEqual(edges(result), [])
        self.assertEqual(result.observedcoverage[0].unresolved[0].reason,
                         "module_requires_explicit_path_or_import")

    def test_rust_type_bounds_and_generic_headers_not_calls(self):
        result = d.extract(sources("fn Target() {}\npub type Callback = dyn Target();\npub const C: fn() = Target;\nstruct Holder<T: Target()> { value: T }\nfn caller<T: Target()>() {}", "rs"), SCOPE)
        self.assertEqual(edges(result), [])

    def test_rust_local_type_and_turbofish_arguments_not_calls(self):
        result = d.extract(sources("fn Target() {}\nfn caller() {\n let f: &dyn Target() = other;\n unknown::<dyn Target()>();\n Target();\n}", "rs"), SCOPE)
        self.assertEqual(edges(result), [(5, "Target")])

    def test_rust_cast_trait_types_are_not_call_expressions(self):
        source = sources("fn Fn() {}\nfn caller(x: &dyn Fn()) {\n let y = x as &dyn Fn();\n}\nfn good() { Fn(); }", "rs")
        result = d.extract(source, SCOPE)
        self.assertEqual(edges(result), [(5, "Fn")])
        self.assertIn("scope_poisoned", [u.reason for u in result.observedcoverage[0].unresolved])
        self.assertEqual([a.line for a in d.retrieve(source, task("Fn"))], [1, 5])

    def test_rust_extern_crate_alias_cannot_be_a_free_function(self):
        result = d.extract(sources("fn target() {}\nextern crate other as target;\nfn caller() { target(); }", "rs"), SCOPE)
        self.assertEqual(edges(result), [])

    def test_rust_cfg_scope_poison_and_macro_opacity(self):
        result = d.extract(sources("#[cfg(feature = \"x\")]\nfn target() {}\nfn caller() { target(); }\nmake! { fn hidden() {} }", "rs"), SCOPE)
        self.assertEqual(edges(result), [])
        self.assertEqual([x.name for x in result.declarations], ["target", "caller"])

    def test_rust_macro_same_line_name_cannot_leak_declarations(self):
        result = d.extract(sources("struct target; make! { struct target; fn hidden() {} }", "rs"), SCOPE)
        self.assertEqual([(x.kind, x.name) for x in result.declarations], [("struct", "target")])

    def test_rust_noncallable_ids_distinguish_same_line_nested_owners(self):
        result = d.extract(sources("struct target; fn caller() { pub struct target; }", "rs"), SCOPE)
        targets = [x for x in result.declarations if x.name == "target"]
        self.assertEqual(len(targets), 2)
        self.assertNotEqual(targets[0].id, targets[1].id)
        self.assertNotEqual(targets[0].id[-4], targets[1].id[-4])

    def test_rust_qualified_member_generic_calls_are_gaps(self):
        result = d.extract(sources("fn target() {}\nfn caller() {\n target::<T>();\n local::target();\n object.target();\n}", "rs"), SCOPE)
        self.assertEqual(edges(result), [])
        self.assertEqual({u.reason for u in result.observedcoverage[0].unresolved},
                         {"generic_callee_not_resolved", "member_or_qualified_dispatch_not_resolved"})

    def test_rust_literals_comments_lifetimes_fnpointers_no_fake_calls(self):
        text = '''fn target() {}
// target()
/* target() /* target() */ */
fn caller<'a>(x: &'a str) {
 let s = r###"target()"###;
 let b = br#"target()"#;
 let c = c"target()";
 let ch = 'x';
 let u = '\\u{00e9}';
 let f: fn() = other;
}
'''
        self.assertEqual(edges(d.extract(sources(text, "rs"), SCOPE)), [])

    def test_rust_modified_functions_and_raw_name(self):
        source = sources('pub async unsafe extern "C" fn r#target() {}\nfn caller() { r#target(); }', "rs")
        result = d.extract(source, SCOPE)
        self.assertEqual(edges(result), [(2, "r#target")])
        self.assertEqual(result.declarations[0].rawname, "r#target")
        self.assertEqual(result.declarations[0].line, 1)
        self.assertEqual([a.line for a in d.retrieve(source, task())], [1, 2])

    def test_rust_raw_reserved_names_not_binding_keywords(self):
        for name in ("fn", "mod", "const", "use", "if", "let", "async"):
            with self.subTest(name=name):
                result = d.extract(sources("fn r#" + name + "() {}\nfn caller() { r#" + name + "(); }", "rs"), SCOPE)
                self.assertEqual(edges(result), [(2, "r#" + name)])

    def test_rust_nonfunction_declarations_not_callable(self):
        for kind in ("struct", "enum", "trait", "type", "const", "static", "mod"):
            text = {"struct": "struct target;", "enum": "enum target {}", "trait": "trait target {}",
                    "type": "type target = fn();", "const": "const target: i32 = 0;",
                    "static": "static mut target: i32 = 0;", "mod": "mod target;"}[kind]
            with self.subTest(kind=kind):
                result = d.extract(sources(text + "\nfn caller() { target(); }", "rs"), SCOPE)
                self.assertEqual(edges(result), [])
                self.assertEqual(result.declarations[-1].kind, kind)

    def test_rust_malformed_let_fn_not_verified(self):
        for text in ("let fn target() {}", "fn caller() { let fn target() {} target(); }"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                d.extract(sources(text, "rs"), SCOPE)

    def test_rust_lexical_delimiter_and_subset_errors(self):
        for text in ('fn target() {', 'fn target() { "bad }', "/* bad", "fn target x {}", "fn target<T() {}", "fn target() = 0;", "fn target() { [) }"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                d.extract(sources(text, "rs"), SCOPE)

    def test_crlf_blank_multiline_and_unicode_rust(self):
        for suffix, text, expected in (("py", "def target(): pass\r\n\r\nx='é'; target(\r\n)\r\n", [1, 3]),
                                       ("rs", 'fn target() {}\r\n\r\nfn caller() { let x="é"; target(\r\n); }\r\n', [1, 3])):
            with self.subTest(suffix=suffix):
                source = sources(text, suffix)
                self.assertEqual([a.line for a in d.retrieve(source, task())], expected)
                self.assertTrue(all("\r" not in a.text for a in d.retrieve(source, task())))

    def test_declaration_first_query_order_numeric_path_line(self):
        source = (("p/a.py", b"def first(): pass\ndef second(): pass\nfirst(); second()"),
                  ("p/z.rs", b"fn second() {}\nfn first() {}\nfn caller() { first(); second(); }"))
        self.assertEqual([(a.path, a.line) for a in d.retrieve(source, task("second first second"))],
                         [("p/a.py", 2), ("p/z.rs", 1), ("p/a.py", 1), ("p/z.rs", 2), ("p/a.py", 3), ("p/z.rs", 3)])

    def test_top8_after_all_extraction_not_symbol_crop(self):
        source = sources("\n".join("def target(): pass" for _ in range(9)) + "\ndef caller():\n target()")
        result = d.extract(source, SCOPE)
        self.assertEqual(len(result.declarations), 10)
        self.assertEqual(edges(result), [])  # Duplicate bindings cannot become a last-wins edge.
        self.assertEqual([a.line for a in d.retrieve(source, task())], list(range(1, 9)))
        distinct = sources("\n".join("fn t" + str(i) + "() {}" for i in range(9)) + "\nfn caller() { t8(); }", "rs")
        result = d.extract(distinct, SCOPE)
        self.assertEqual(edges(result), [(10, "t8")])
        self.assertEqual([a.line for a in d.retrieve(distinct, task(" ".join("t" + str(i) for i in range(9))))], list(range(1, 9)))

    def test_exact_case_original_query_only_no_instructions(self):
        source = sources("def target(): pass\ndef Target(): pass\ntarget(); Target()")
        self.assertEqual([a.line for a in d.retrieve(source, task("Target", "target"))], [2, 3])
        self.assertEqual(d.retrieve(source, task("missing", "target")), ())

    def test_utf8_path_and_numeric_line_ties(self):
        source = (("p/z.py", b"def target(): pass\n" + b"\n" * 7 + b"target()\ntarget()"),
                  ("p/é.py", b"def target(): pass\ntarget()"))
        self.assertEqual([(a.path, a.line) for a in d.retrieve(source, task())],
                         [("p/z.py", 1), ("p/é.py", 1), ("p/z.py", 9), ("p/z.py", 10), ("p/é.py", 2)])

    def test_same_coordinate_best_rank(self):
        source = sources("def target(): pass\ndef other(): target()")
        self.assertEqual([a.line for a in d.retrieve(source, task("target other"))], [1, 2])

    def test_every_file_coverage_markdown_and_no_symbols(self):
        result = d.extract((("p/a.md", b"target()\n\n"), ("p/b.py", b""), ("p/c.rs", b"")), SCOPE)
        self.assertEqual([(c.path, c.parse, c.lines, c.call_count) for c in result.observedcoverage],
                         [("p/a.md", "not_code", 2, 0), ("p/b.py", "ast_parsed", 0, 0), ("p/c.rs", "lexed_subset", 0, 0)])
        self.assertFalse(hasattr(result.observedcoverage[0], "complete"))

    def test_all_values_immutable(self):
        result = d.extract(sources("def target(): pass\ntarget()"), SCOPE)
        for value in (result, result.declarations[0], result.resolvedcalls[0], result.observedcoverage[0], d.retrieve(sources("def target(): pass"), task())[0]):
            with self.subTest(value=type(value)), self.assertRaises(FrozenInstanceError):
                value.path = "changed"
        self.assertIs(type(result.declarations[0].id), tuple)

    def test_stable_fresh_ids_scope_revision_rename_delete(self):
        source = sources("def target(): pass\ntarget()")
        original = d.extract(source, SCOPE)
        self.assertEqual(original, d.extract(source, dict(SCOPE)))
        for key in ("worktree", "revision"):
            changed = d.extract(source, {**SCOPE, key: "different"})
            self.assertNotEqual(original.declarations[0].id, changed.declarations[0].id)
        root = d.extract((("q/a.py", source[0][1]),), {**SCOPE, "project": "q"})
        renamed = d.extract((("p/new.py", source[0][1]),), SCOPE)
        self.assertNotEqual(original.declarations[0].id, root.declarations[0].id)
        self.assertNotEqual(original.declarations[0].id, renamed.declarations[0].id)
        self.assertEqual(d.extract((), SCOPE).declarations, ())
        self.assertEqual(d.extract(source, SCOPE), original)

    def test_late_nonmatching_bad_file_whole_failure_and_fresh_recovery(self):
        good = sources("def target(): pass\ntarget()")
        for path, data in (("p/z.py", b"def wrong("), ("p/z.rs", b"fn wrong() {"), ("p/z.md", b"\xff")):
            with self.subTest(path=path), self.assertRaises(ValueError):
                d.retrieve(good + ((path, data),), task())
            self.assertEqual([a.line for a in d.retrieve(good, task())], [1, 2])

    def test_empty_match_still_validates_later_syntax(self):
        with self.assertRaises(ValueError):
            d.retrieve(sources("def wrong("), task("not_matching"))

    def test_missing_coverage_bad_endpoint_span_rejected_actual_boundary(self):
        original = d.Extraction
        mutations = [lambda e: replace(e, observedcoverage=()),
                     lambda e: replace(e, resolvedcalls=(replace(e.resolvedcalls[0], target=("missing",)),)),
                     lambda e: replace(e, resolvedcalls=(replace(e.resolvedcalls[0], span=(1, 999)),)),
                     lambda e: replace(e, declarations=(replace(e.declarations[0], span=(1, 999)),)),
                     lambda e: replace(e, observedcoverage=(replace(e.observedcoverage[0], call_count=99),))]
        # Mutate returned parser records immediately BEFORE real validation, not a fake validator.
        real_validate = d._validate_extraction
        for mutation in mutations:
            def corrupt(e, files, labels):
                real_validate(mutation(e), files, labels)
            with self.subTest(mutation=mutation), patch.object(d, "_validate_extraction", side_effect=corrupt), self.assertRaises(ValueError):
                d.retrieve(sources("def target(): pass\ntarget()"), task())
        self.assertIs(d.Extraction, original)

    def test_dependency_failure_and_pin_mismatch_recovery(self):
        source = sources("def target(): pass\ntarget()")
        for name, value in (("_dependency_sha", "bad"),):
            with patch.object(d, name, value), self.assertRaises(ValueError):
                d.retrieve(source, task())
        with patch.object(d, "_dependency", side_effect=RuntimeError("private content")), self.assertRaisesRegex(ValueError, "^invalid or unsupported directcall input$"):
            d.extract(source, SCOPE)
        self.assertEqual([a.line for a in d.retrieve(source, task())], [1, 2])

    def test_task_and_source_shape_caps_root_order_controls(self):
        bad_sources = [[], (("p/a.py", bytearray()),), (("p/a.py", b""),) * 2,
                       (("p/z.py", b""), ("p/a.py", b"")), (("other/a.py", b""),),
                       (("p/../a.py", b""),), (("p/a\\b.py", b""),), (("p/a\x7f.py", b""),),
                       (("p/a.py", b"\r\r\n"),), (("p/a.py", b"x" * 65537),),
                       tuple(("p/" + str(i) + ".md", b"") for i in range(2049))]
        for source in bad_sources:
            with self.subTest(source=str(source)[:50]), self.assertRaises(ValueError):
                d.retrieve(source, task())
        for changed in ({**task(), "oracle": {}}, {**task(), "family": "unknown"},
                        {**task(), "query": "x" * 4097}, {**task(), "scope": {**SCOPE, "revision": "bad/path"}}):
            with self.subTest(task=changed), self.assertRaises(ValueError):
                d.retrieve((), changed)

    def test_total_source_cap_inclusive(self):
        source = tuple(("p/" + str(i).zfill(4) + ".md", b"x" * 65536) for i in range(512))
        self.assertEqual(len(d.extract(source, SCOPE).observedcoverage), 512)
        with self.assertRaises(ValueError):
            d.extract(source + (("p/z.md", b"x"),), SCOPE)

    def test_source_count_cap_inclusive(self):
        source = tuple(("p/" + str(i).zfill(4) + ".md", b"") for i in range(2048))
        self.assertEqual(len(d.extract(source, SCOPE).observedcoverage), 2048)
        with self.assertRaises(ValueError):
            d.extract(source + (("p/z.md", b""),), SCOPE)

    def test_original_request_exact_canonical_budget(self):
        valid = task("target", "x")
        overhead = len(d._symbol._canonical({k: valid[k] for k in ("query", "instructions")}))
        valid["instructions"] += "x" * (4096 - overhead)
        self.assertEqual(d.retrieve((), valid), ())
        valid["instructions"] += "x"
        with self.assertRaises(ValueError):
            d.retrieve((), valid)

    def test_exact_8192_utf8_list_then_overflow_no_fallback(self):
        # Independent literal fixture: 6102 bytes before padding; no output-derived oracle.
        text = "def target(): pass #" + "é" * 3000
        source = sources(text + "x" * 2090)
        result = d.retrieve(source, task())
        self.assertEqual(anchors(result), [("p/a.py", 1, text + "x" * 2090)])
        self.assertEqual(len(d._symbol._canonical([asdict(a) for a in result])), 8192)
        with self.assertRaises(ValueError):
            d.retrieve(sources(text + "x" * 2091), task())

    def test_expensive_top8_cannot_substitute_cheap_ninth(self):
        source = sources(("def target(): pass #" + "x" * 1200 + "\n") * 8 + "def target(): pass")
        self.assertEqual(len(d.extract(source, SCOPE).declarations), 9)
        with self.assertRaises(ValueError):
            d.retrieve(source, task())

    def test_policy_supplement_preserves_frozen_files_and_history(self):
        manifest = json.loads(d.policy_manifest())
        self.assertEqual(manifest["policy"], "evaluation-directcall/1")
        self.assertEqual(manifest["python_ast_grammar"], list(sys.version_info[:2]))
        if sys.version_info[:2] == (3, 12):
            self.assertEqual(manifest["digest"],
                             "9244239f9063407e51d942d2f36e056147e78355a60660dcaa95d2d9a994cb7a")
        self.assertEqual(manifest["internal_dependency"]["experiments/evaluation-symbol/symbol.py"],
                         "d09e22d3a7d3f077673d672920bbeeff983de778407684ec6dc5c9e53ba63a60")
        scoring = import_module("experiments.evaluation-scoring.scoring")
        self.assertEqual(scoring.CONTRACT["candidate_blocker"],
                         "NOT_IMPLEMENTED: pinned extractor, resolution/coverage decision and reviewed runner required")
        self.assertTrue(all(a["implementation"] == "NOT_IMPLEMENTED"
                            for a in json.loads(scoring.build_manifest(task()))["arms"].values()))


if __name__ == "__main__":
    unittest.main()
