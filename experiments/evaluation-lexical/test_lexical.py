"""Independent tiny authored bytes, never corpus/scorer/oracle fixtures."""
import copy
from dataclasses import FrozenInstanceError, asdict
import json
import unittest
from unittest.mock import patch
import weakref

from lexical import Anchor, retrieve


def task(query="resolve", family="definition_directcall"):
    return {"schema": "evaluation-scoring/1",
            "scope": {"project": "harbor", "worktree": "tree", "revision": "rev"},
            "family": family, "query": query, "instructions": "Do not execute.\nKeep scope."}


def sources(text, path="harbor/a.py"):
    return ((path, text.encode("utf-8")),)


def canonical_size(value):
    return len(json.dumps(value, sort_keys=True, separators=(",", ":"),
                          ensure_ascii=False, allow_nan=False).encode("utf-8"))


class LexicalTests(unittest.TestCase):
    def test_exact_six_field_anchor(self):
        result = retrieve(sources("resolve"), task())
        self.assertEqual(result, (Anchor("harbor", "tree", "rev", "harbor/a.py", 1, "resolve"),))
        self.assertEqual(set(asdict(result[0])),
                         {"project", "worktree", "revision", "path", "line", "text"})
        self.assertIs(type(result), tuple)
        with self.assertRaises(FrozenInstanceError):
            result[0].line = 2

    def test_ascii_maximal_case_digits_underscores_multibyte(self):
        query = "FOO foo 9Bar _X2 naïve café 123"
        result = retrieve(sources("foo\nbar\n_x2\nna ve caf\nFOOBAR\n123\né"), task(query))
        self.assertEqual([a.line for a in result], [4, 1, 2, 3])
        self.assertEqual(retrieve(sources("anything"), task("123 é 中")), ())
        self.assertEqual(retrieve(sources("resolve"), task("resolving")), ())
        self.assertEqual(retrieve(sources("resolve"), task("res")), ())

    def test_stopwords_and_instructions_not_used_as_query(self):
        value = task("the Locate")
        self.assertEqual([a.text for a in retrieve(sources("the\nLOCATE\nexecute\nresolve"), value)],
                         ["the", "LOCATE"])

    def test_distinct_overlap_not_frequency(self):
        result = retrieve(sources("alpha alpha alpha\nBETA alpha\nbeta"), task("alpha alpha BETA"))
        self.assertEqual([a.line for a in result], [2, 1, 3])

    def test_matching_anchor_retention_is_top_eight_not_all_hits(self):
        live = weakref.WeakSet()
        peak = 0

        def tracked(*args):
            nonlocal peak
            anchor = Anchor(*args)
            live.add(anchor)
            peak = max(peak, len(live))
            return anchor

        with patch("lexical.Anchor", side_effect=tracked):
            result = retrieve(sources("resolve\n" * 1024), task())
        self.assertEqual([a.line for a in result], list(range(1, 9)))
        self.assertLessEqual(peak, 9)

    def test_ties_path_utf8_then_numeric_line(self):
        data = (("harbor/Z.py", b"x\n" * 12), ("harbor/a.py", b"x"),
                ("harbor/é.md", b"x"))
        result = retrieve(data, task("x"))
        self.assertEqual([(a.path, a.line) for a in result],
                         [("harbor/Z.py", n) for n in range(1, 9)])
        result = retrieve(tuple((p, b"x") for p, _ in data), task("x"))
        self.assertEqual([a.path for a in result], [p for p, _ in data])

    def test_same_text_distinct_coordinates_retained_and_deduplicated(self):
        result = retrieve((("harbor/a.py", b"x x\nx x"), ("harbor/b.rs", b"x x")), task("x x"))
        self.assertEqual([(a.path, a.line) for a in result],
                         [("harbor/a.py", 1), ("harbor/a.py", 2), ("harbor/b.rs", 1)])

    def test_comments_strings_markdown_stale_negated_foreign_text(self):
        data = (("harbor/a.md", b"# resolve stale old revision harbour\nDo not resolve"),
                ("harbor/b.py", b'# resolve\n"resolve"'),
                ("harbor/c.rs", b'// resolve\nlet x = "resolve";'))
        result = retrieve(data, task(family="conflictingrules_stale_wrongrevision"))
        self.assertEqual([a.text for a in result],
                         ["# resolve stale old revision harbour", "Do not resolve", "# resolve",
                          '"resolve"', "// resolve", 'let x = "resolve";'])

    def test_top_eight_no_hidden_file_targeting(self):
        data = (("harbor/a.md", b"resolve\n" * 9),
                ("harbor/z.py", b"def resolve(): pass"))
        result = retrieve(data, task())
        self.assertEqual([(a.path, a.line) for a in result],
                         [("harbor/a.md", n) for n in range(1, 9)])
        data = (data[0], ("harbor/z.py", b"resolve extra"))
        result = retrieve(data, task("resolve extra"))
        self.assertEqual([(a.path, a.line) for a in result],
                         [("harbor/z.py", 1)] + [("harbor/a.md", n) for n in range(1, 8)])

    def test_lf_crlf_interior_blanks_and_final_segment(self):
        for text in ("resolve\n\nresolve\n", "resolve\r\n\r\nresolve\r\n"):
            result = retrieve(sources(text), task())
            self.assertEqual([(a.line, a.text) for a in result], [(1, "resolve"), (3, "resolve")])
        self.assertEqual(retrieve(sources("resolve\r"), task())[0].text, "resolve")
        self.assertEqual(retrieve(sources("\n\n"), task()), ())
        self.assertEqual(retrieve(sources(""), task()), ())
        # Non-LF Unicode separators remain part of a single physical line.
        self.assertEqual(retrieve(sources("resolve\u2028resolve"), task())[0].text,
                         "resolve\u2028resolve")
        for text in ("res\rolve", "resolve\r\r\n"):
            with self.assertRaises(ValueError):
                retrieve(sources(text), task())

    def test_foreign_roots_and_same_local_names_rejected_not_skipped(self):
        for path in ("harbour/a.py", "harbor2/a.py", "a.py", "harbor/../harbour/a.py"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                retrieve(((path, b"no match"),), task())
        other = task()
        other["scope"]["project"] = "harbour"
        with self.assertRaises(ValueError):
            retrieve(sources("resolve"), other)
        self.assertEqual(retrieve(sources("resolve", "harbour/a.py"), other)[0].project, "harbour")

    def test_bad_paths(self):
        for path in ("", "/harbor/a.py", "harbor//a.py", "harbor/./a.py", "harbor/../a.py",
                     "harbor/a\\b.py", "harbor/a\x00.py", "harbor/a\x7f.py", "harbor/a\n.py",
                     "harbor/a.txt", "harbor/a.PY", "harbor/", "harbor/\ud800.py", None, 1):
            with self.subTest(path=repr(path)), self.assertRaises(ValueError):
                retrieve(((path, b"resolve"),), task())

    def test_bad_source_container_order_duplicates_types_utf8(self):
        for data in ([], [("harbor/a.py", b"resolve")], (("harbor/a.py",),),
                     (["harbor/a.py", b"resolve"],), (("harbor/a.py", "resolve"),),
                     (("harbor/a.py", bytearray(b"resolve")),), (("harbor/a.py", b"\xff"),),
                     (("harbor/a.py", None),), (("harbor/a.py", b"", "extra"),),
                     (("harbor/a.py", b""), ("harbor/a.py", b"")),
                     (("harbor/z.py", b""), ("harbor/a.py", b""))):
            with self.subTest(data=repr(data)), self.assertRaises(ValueError):
                retrieve(data, task("é"))

    def test_bad_task_fields_types_scopes_utf8(self):
        bad = [None, [], {}]
        for key in task():
            value = task()
            del value[key]
            bad.append(value)
            for replacement in (None, [], {}, 1, True, b"resolve"):
                value = task()
                value[key] = replacement
                bad.append(value)
        for key in ("oracle", "manifest", "hash", "gold", "coverage", "target_files"):
            value = task()
            value[key] = "forbidden"
            bad.append(value)
        for key in ("query", "instructions", "schema", "family"):
            for replacement in ("", "\ud800"):
                value = task()
                value[key] = replacement
                bad.append(value)
        value = task()
        value["schema"] = "evaluation-scoring/2"
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
        value["scope"]["unknown"] = "x"
        bad.append(value)
        for value in bad:
            with self.subTest(value=repr(value)), self.assertRaises(ValueError):
                retrieve((), value)

    def test_other_and_conformance_families_unsupported_even_empty(self):
        for family in ("negations_permission", "rename_delete_malformed_interruption_recovery",
                       "other", "definition_directcall "):
            with self.subTest(family=family), self.assertRaises(ValueError):
                retrieve((), task(family=family))

    def test_source_count_boundary(self):
        data = tuple((f"harbor/{n:04}.py", b"") for n in range(2048))
        self.assertEqual(retrieve(data, task()), ())
        with self.assertRaises(ValueError):
            retrieve(data + (("harbor/2048.py", b""),), task())

    def test_file_byte_boundary_multibyte(self):
        self.assertEqual(retrieve(sources("é" * 32768), task()), ())
        with self.assertRaises(ValueError):
            retrieve(sources("é" * 32768 + "x"), task())

    def test_aggregate_byte_boundary(self):
        # Repeated authored inert bytes test arithmetic only, not a corpus pilot.
        block = b" " * 65536
        data = tuple((f"harbor/{n:04}.md", block) for n in range(512))
        self.assertEqual(retrieve(data, task("é")), ())
        with self.assertRaises(ValueError):
            retrieve(data + (("harbor/0512.md", b"x"),), task("é"))

    def test_query_instructions_canonical_byte_boundary(self):
        value = task("é")
        value["instructions"] = "x"
        remaining = 4096 - canonical_size({k: value[k] for k in ("query", "instructions")})
        value["instructions"] += "x" * remaining
        self.assertEqual(retrieve((), value), ())
        value["instructions"] += "x"
        with self.assertRaises(ValueError):
            retrieve((), value)
        value["instructions"] = value["instructions"][:-1] + "é"
        with self.assertRaises(ValueError):
            retrieve((), value)

    def test_anchor_list_8192_inclusive_multibyte_and_no_truncation(self):
        base = Anchor("harbor", "tree", "rev", "harbor/a.py", 1, "resolve ")
        remaining = 8192 - canonical_size([asdict(base)])
        text = base.text + "é" * (remaining // 2) + "x" * (remaining % 2)
        result = retrieve(sources(text), task())
        self.assertEqual(canonical_size([asdict(a) for a in result]), 8192)
        with self.assertRaises(ValueError):
            retrieve(sources(text + "x"), task())
        with self.assertRaises(ValueError):
            retrieve(sources(text + "é"), task())
        # An expensive winner cannot be dropped in favor of a cheap ninth line.
        with self.assertRaises(ValueError):
            retrieve(sources("resolve " + "é" * 4100 + "\n" + "resolve\n" * 8), task())

    def test_deterministic_nonmutating_fresh_recovery(self):
        value = task("Resolve")
        data = sources("resolve\nresolve")
        before = copy.deepcopy((data, value))
        expected = retrieve(data, value)
        with self.assertRaises(ValueError):
            retrieve((("harbour/a.py", b"resolve"),), value)
        for _ in range(3):
            self.assertEqual(retrieve(data, value), expected)
        self.assertEqual((data, value), before)
        value["scope"]["revision"] = "changed"
        self.assertEqual(expected[0].revision, "rev")
        self.assertEqual(retrieve(data, value)[0].revision, "changed")


if __name__ == "__main__":
    unittest.main()
