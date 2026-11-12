"""Inert synthetic fixtures only: these do not certify a compiler or sandbox."""

import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import compiler_plan as c
import project_types as p
from test_project_types import fixture


class CompilerPlanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="threadmark-plan-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.projection = self.base / "projection"
        self.lock, self.plan, self.archives, _ = fixture()
        p.project(self.projection, self.lock, self.plan, self.archives)
        self.sources = self.projection / "__compiler_roots"
        self.sources.mkdir()
        (self.sources / "positive.ts").write_bytes(b"import type { Synthetic } from 'synthetic';\nexport type Proof = Synthetic;\n")
        self.compiler = self.base / "compiler"
        self.compiler.mkdir()
        # Not the real compiler. External review authority is synthetic too.
        files = {"lib/tsc.js": b"NEVER EXECUTE synthetic entrypoint",
                 "lib/_tsc.js": b"NEVER EXECUTE synthetic helper",
                 "lib/lib.esnext.d.ts": b"export interface SyntheticLibrary {}",
                 "package.json": b'{"name":"typescript","version":"6.0.3","license":"Apache-2.0"}',
                 "LICENSE.txt": b"Synthetic Apache-2.0 notice evidence; not upstream",
                 "ThirdPartyNoticeText.txt": b"Synthetic third party notice; not upstream"}
        for name, data in files.items():
            path = self.compiler / name
            path.parent.mkdir(exist_ok=True)
            path.write_bytes(data)
        self.node = self.base / "node-synthetic"
        self.node.write_bytes(b"NOT A NODE EXECUTABLE")
        self.node.chmod(0o500)
        self.workspace = self.base / "workspace"
        self.workspace.mkdir(mode=0o700)
        self.review = {
            "schema": 1, "reviewId": "synthetic-review-only", "platform": "macos",
            "lockSha256": p.sha256(self.lock),
            "projectionPlanSha256": p.sha256(json.dumps(self.plan, sort_keys=True).encode()),
            "projection": str(self.projection),
            "ledgerSha256": p.sha256((self.projection / "ledger.json").read_bytes()),
            "sources": {"directory": str(self.sources), "files": {"positive.ts": p.sha256((self.sources / "positive.ts").read_bytes())}},
            "roots": ["positive.ts"],
            "compiler": {"directory": str(self.compiler), "name": "typescript", "version": "6.0.3",
                         "archiveIntegrity": c.COMPILER_INTEGRITY, "archiveVerified": True,
                         "license": "Apache-2.0", "entrypoint": "lib/tsc.js",
                         "files": {name: p.sha256(data) for name, data in files.items()},
                         "roles": {"entrypoint": ["lib/tsc.js"], "helpers": ["lib/_tsc.js"],
                                   "libraries": ["lib/lib.esnext.d.ts"], "metadata": ["package.json"],
                                   "notices": ["LICENSE.txt", "ThirdPartyNoticeText.txt"]},
                         "noticeHashes": {name: p.sha256(files[name]) for name in ("LICENSE.txt", "ThirdPartyNoticeText.txt")}},
            "node": {"path": str(self.node), "version": "24.10.0", "sha256": p.sha256(self.node.read_bytes()),
                     "inventoryId": "synthetic-reviewed-inventory"},
            "workspace": str(self.workspace), "jsx": None, "knownMissing": []}

    def build(self, review=None):
        raw = c.encoded(self.review if review is None else review)
        return c.build_descriptor(raw, p.sha256(raw), lock_bytes=self.lock,
                                  projection_plan=self.plan, archives=self.archives)

    def rejected(self, review=None):
        with self.assertRaises(ValueError):
            self.build(review)

    def test_public_descriptor_exact_config_and_bounds(self):
        d = self.build()
        self.assertEqual(d["kind"], "inert-compiler-candidate")
        self.assertIs(d["executionApproved"], False)
        self.assertIs(d["containmentVerified"], False)
        self.assertEqual(d["typeGraphClosure"], "NOT established")
        self.assertEqual(d["runtimeDependencyClosure"], "NOT established")
        self.assertTrue(d["preparationOnly"])
        self.assertEqual(d["bounds"], {"wallSeconds": 120, "outputBytes": 16777216,
                                       "heapMiB": 1024, "cleanupSeconds": 2})
        self.assertEqual(d["argvCandidate"], [str(self.node), "--max-old-space-size=1024",
                                             str(self.compiler / "lib/tsc.js"), "--project",
                                             str(self.workspace / "tsconfig.json")])
        self.assertEqual(d["config"], {"compilerOptions": {
            "noEmit": True, "strict": True, "skipLibCheck": False, "skipDefaultLibCheck": False,
            "types": [], "typeRoots": [str(self.workspace / "typeRoots")], "module": "ESNext",
            "moduleResolution": "Bundler", "target": "ESNext"},
            "files": [str(self.sources / "positive.ts")], "include": [], "exclude": []})
        self.assertEqual(d["configSha256"], p.sha256(c.encoded(d["config"])))
        self.assertEqual(d["rootHashes"], self.review["sources"]["files"])
        self.assertEqual(list(self.workspace.iterdir()), [])  # builder wrote nothing

    def test_environment_is_complete_allowlist_not_inherited(self):
        with patch.dict(os.environ, {"NODE_OPTIONS": "--require=/forbidden", "NODE_PATH": "/forbidden",
                                     "TS_NODE_PROJECT": "/forbidden", "SECRET_FIXTURE": "not inherited"}):
            d = self.build()
        self.assertFalse(d["inheritEnvironment"])
        self.assertEqual(d["environment"], {"HOME": str(self.workspace / "home"),
            "TMPDIR": str(self.workspace / "tmp"), "XDG_CONFIG_HOME": str(self.workspace / "config"),
            "XDG_CACHE_HOME": str(self.workspace / "cache"), "XDG_DATA_HOME": str(self.workspace / "data"),
            "XDG_STATE_HOME": str(self.workspace / "state"), "LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin"})

    def test_policy_is_typed_pending_no_broad_read_roots(self):
        d = self.build()
        policy = d["policy"]
        self.assertEqual((policy["default"], policy["network"], policy["childSpawn"]), ("deny",) * 3)
        self.assertEqual(policy["recursiveReadRoots"], [])
        self.assertEqual(policy["systemReadFiles"], [])
        self.assertEqual(policy["linux"], "unsupported")
        self.assertIn("PENDING", policy["status"])
        expected = {str(self.projection / "node_modules/synthetic" / name)
                    for name in self.plan["packages"][0]["files"]}
        expected.update(str(self.compiler / name) for name in self.review["compiler"]["files"])
        expected.update([str(self.sources / "positive.ts"), str(self.node), str(self.workspace / "tsconfig.json")])
        self.assertEqual(set(policy["readFiles"]), expected)
        self.assertEqual(set(d["readFileHashes"]), expected)
        for name, expected_hash in d["readFileHashes"].items():
            actual = c.encoded(d["config"]) if name == d["configPath"] else Path(name).read_bytes()
            self.assertEqual(p.sha256(actual), expected_hash)
        self.assertEqual(d["projectionLedgerSha256"], self.review["ledgerSha256"])
        self.assertIn("quarantine", d["cleanup"]["unknown"])

    def test_external_review_hash_cannot_self_approve(self):
        raw = c.encoded(self.review)
        with self.assertRaises(ValueError):
            c.build_descriptor(raw, "0" * 64, lock_bytes=self.lock, projection_plan=self.plan, archives=self.archives)

    def test_unknown_keys_options_and_injection_are_rejected(self):
        for key, value in {"compilerOptions": {"plugins": []}, "extends": "ambient",
                           "paths": {}, "extraCLI": ["--watch"], "environment": {"NODE_OPTIONS": "injected"},
                           "allowJs": True, "checkJs": True, "skipLibCheck": True,
                           "noResolve": True, "build": True, "incremental": True,
                           "composite": True, "customResolver": "evil", "configPath": "ambient"}.items():
            with self.subTest(key=key):
                self.rejected({**self.review, key: value})
        for section in ("compiler", "node", "sources"):
            review = copy.deepcopy(self.review)
            review[section]["unexpected"] = "not allowed"
            self.rejected(review)

    def test_duplicate_manifest_keys_rejected(self):
        raw = c.encoded(self.review).replace(b'"schema": 1', b'"schema": 1, "schema": 1')
        with self.assertRaises(ValueError):
            c.build_descriptor(raw, p.sha256(raw), lock_bytes=self.lock, projection_plan=self.plan, archives=self.archives)

    def test_known_missing_and_platform_closed(self):
        self.rejected({**self.review, "knownMissing": ["@types/emscripten"]})
        self.rejected({**self.review, "platform": "linux"})
        self.rejected({**self.review, "reviewId": "bad\nreview"})

    def test_lock_plan_archive_actual_bindings(self):
        self.rejected({**self.review, "lockSha256": "0" * 64})
        self.rejected({**self.review, "projectionPlanSha256": "0" * 64})
        key = next(iter(self.archives))
        self.archives[key] += b"tamper"
        self.rejected()

    def test_missing_notice_or_types_not_waived_by_new_review(self):
        for field, value in [("missing", ["authentic requested types"]), ("unresolved", ["known missing module"])]:
            plan = copy.deepcopy(self.plan)
            plan[field] = value
            with patch.object(self, "plan", plan):
                review = {**self.review, "projectionPlanSha256": p.sha256(json.dumps(plan, sort_keys=True).encode())}
                self.rejected(review)
        self.plan["packages"][0]["noticeStatus"] = "blocked"
        self.review["projectionPlanSha256"] = p.sha256(json.dumps(self.plan, sort_keys=True).encode())
        self.rejected()

    def test_ledger_hash_bytes_and_state_are_exact(self):
        ledger_path = self.projection / "ledger.json"
        original = ledger_path.read_bytes()
        for data in (original + b" ", original.replace(b"prepared_not_compiled", b"compiled"),
                     original.replace(b"NOT established", b"established")):
            ledger_path.chmod(0o600)
            ledger_path.write_bytes(data)
            self.review["ledgerSha256"] = p.sha256(data)  # copied ledger still cannot approve
            self.rejected()

    def test_incomplete_and_extra_files_or_directories_rejected(self):
        for name, directory in [("INCOMPLETE", False), ("ledger.pending", False),
                                ("node_modules/synthetic/evil.js", False), ("empty-extra", True)]:
            with self.subTest(name=name):
                path = self.projection / name
                path.mkdir() if directory else path.write_bytes(b"inert")
                self.rejected()
                path.rmdir() if directory else path.unlink()

    def test_every_projected_file_including_full_metadata_verified(self):
        for name in self.plan["packages"][0]["files"]:
            path = self.projection / "node_modules/synthetic" / name
            original = path.read_bytes()
            path.chmod(0o600)
            path.write_bytes(original + b" ")
            self.rejected()
            path.write_bytes(original)

    def test_unsafe_relative_traversal_control_paths_and_root_duplicates(self):
        for field in ("projection", "workspace"):
            for bad in ("relative", "/", str(self.base) + "/../other", str(self.base) + "/x\n", str(self.base) + "//x"):
                self.rejected({**self.review, field: bad})
        for roots in (["positive.ts", "positive.ts"], ["../positive.ts"], ["POSITIVE.ts"], []):
            self.rejected({**self.review, "roots": roots})
        for bad in ("../positive.ts", "/positive.ts", "a\\b.ts", "bad\x00.ts"):
            review = copy.deepcopy(self.review)
            review["sources"]["files"] = {bad: "a" * 64}
            review["roots"] = [bad]
            self.rejected(review)

    def test_case_and_unicode_aliases_rejected(self):
        for names in (("positive.ts", "POSITIVE.ts"), ("é.ts", "e\u0301.ts")):
            review = copy.deepcopy(self.review)
            review["sources"]["files"] = {name: "a" * 64 for name in names}
            review["roots"] = list(names)
            self.rejected(review)

    def test_symlink_root_parent_file_and_hardlink_rejected(self):
        alias = self.base / "alias"
        alias.symlink_to(self.projection, target_is_directory=True)
        self.rejected({**self.review, "projection": str(alias)})
        self.rejected({**self.review, "projection": str(alias / "node_modules")})
        path = self.sources / "positive.ts"
        saved = self.base / "saved"
        path.rename(saved)
        path.symlink_to(saved)
        self.rejected()
        path.unlink()
        os.link(saved, path)
        self.rejected()

    def test_special_member_rejected_without_open(self):
        os.mkfifo(self.projection / "fifo")
        self.rejected()

    def test_source_hash_js_and_suppressions_rejected(self):
        root = self.sources / "positive.ts"
        root.write_bytes(b"export type Changed = number;")
        self.rejected()
        self.review["sources"]["files"]["positive.ts"] = p.sha256(root.read_bytes())
        self.build()  # independently reviewed new inert bytes, not compiler proof
        for content in (b"// @ts-ignore\n", b"// @ts-nocheck\n", b"// @ts-expect-error\n"):
            root.write_bytes(content)
            self.review["sources"]["files"]["positive.ts"] = p.sha256(content)
            self.rejected()
        root.rename(self.sources / "positive.js")
        self.review["roots"] = ["positive.js"]
        self.review["sources"]["files"] = {"positive.js": p.sha256(content)}
        self.rejected()

    def test_encoded_suppressions_and_invalid_utf8_rejected(self):
        root = self.sources / "positive.ts"
        for encoding, bom in [("utf-16-le", b"\xff\xfe"), ("utf-16-be", b"\xfe\xff")]:
            for directive in ("@ts-ignore", "@ts-nocheck", "@ts-expect-error"):
                content = bom + ("// " + directive + "\n").encode(encoding)
                root.write_bytes(content)
                self.review["sources"]["files"]["positive.ts"] = p.sha256(content)
                with self.subTest(encoding=encoding, directive=directive):
                    self.rejected()
        for content in (b"\xffinvalid", b"\x00/\x00/\x00 ", b"\xef\xbb\xbf// @ts-ignore\n"):
            root.write_bytes(content)
            self.review["sources"]["files"]["positive.ts"] = p.sha256(content)
            with self.subTest(content=content):
                self.rejected()

    def test_utf8_owned_sources_with_optional_bom_preserve_byte_hash(self):
        root = self.sources / "positive.ts"
        for bom in (b"", b"\xef\xbb\xbf"):
            content = bom + "export type Résultat = string;\n".encode("utf-8")
            root.write_bytes(content)
            self.review["sources"]["files"]["positive.ts"] = p.sha256(content)
            descriptor = self.build()
            self.assertEqual(descriptor["readFileHashes"][str(root)], p.sha256(content))
            self.assertEqual(root.read_bytes(), content)
            self.assertFalse(descriptor["executionApproved"])

    def test_jsx_explicit_and_no_alias(self):
        root = self.sources / "positive.ts"
        root.rename(self.sources / "positive.tsx")
        self.review["roots"] = ["positive.tsx"]
        self.review["sources"]["files"] = {"positive.tsx": p.sha256((self.sources / "positive.tsx").read_bytes())}
        self.rejected()
        self.review["jsx"] = "preserve"
        self.assertEqual(self.build()["config"]["compilerOptions"]["jsx"], "preserve")
        self.review["jsx"] = "invented-jsx-alias"
        self.rejected()

    def test_compiler_pin_entrypoint_archive_license_closed(self):
        for field, value in [("name", "wrapper"), ("version", "6.0.2"), ("archiveIntegrity", "wrong"),
                             ("archiveVerified", False), ("license", "MIT"), ("entrypoint", "bin/tsc")]:
            review = copy.deepcopy(self.review)
            review["compiler"][field] = value
            self.rejected(review)
        self.assertEqual(self.review["compiler"]["archiveIntegrity"],
            "sha512-y2TvuxSZPDyQakkFRPZHKFm+KKVqIisdg9/CZwm9ftvKXLP8NRWj38/ODjNbr43SsoXqNuAisEf1GdCxqWcdBw==")

    def test_all_compiler_helper_library_notice_bytes_verified(self):
        for name in self.review["compiler"]["files"]:
            path = self.compiler / name
            original = path.read_bytes()
            path.write_bytes(original + b" tamper")
            self.rejected()
            path.write_bytes(original)

    def test_compiler_inventory_roles_notice_and_extra_library_closed(self):
        for role in ("helpers", "libraries", "notices"):
            review = copy.deepcopy(self.review)
            review["compiler"]["roles"][role] = []
            self.rejected(review)
        review = copy.deepcopy(self.review)
        review["compiler"]["noticeHashes"] = {}
        self.rejected(review)
        (self.compiler / "lib/unapproved.d.ts").write_bytes(b"export {}")
        self.rejected()

    def test_node_review_identity_mode_hash_no_path_discovery(self):
        for field, value in [("path", "node"), ("version", "caller claimed"),
                             ("inventoryId", ""), ("sha256", "0" * 64)]:
            review = copy.deepcopy(self.review)
            review["node"][field] = value
            self.rejected(review)
        self.node.chmod(0o400)
        self.rejected()

    def test_compiler_mode_links_and_node_links_rejected(self):
        path = self.compiler / "lib/tsc.js"
        path.chmod(0o755)
        self.rejected()
        path.chmod(0o644)
        saved = self.base / "saved-entry"
        path.rename(saved)
        path.symlink_to(saved)
        self.rejected()
        path.unlink()
        os.link(saved, path)
        self.rejected()
        path.unlink()
        saved.rename(path)
        saved_node = self.base / "saved-node"
        self.node.rename(saved_node)
        self.node.symlink_to(saved_node)
        self.rejected()
        self.node.unlink()
        os.link(saved_node, self.node)
        self.rejected()

    def test_workspace_private_fresh_no_config_discovery(self):
        (self.workspace / "tsconfig.json").write_bytes(b'{"extends":"ambient"}')
        self.rejected()
        (self.workspace / "tsconfig.json").unlink()
        self.workspace.chmod(0o755)
        self.rejected()
        self.workspace.chmod(0o700)
        self.rejected({**self.review, "workspace": str(self.compiler)})

    def test_quoted_paths_are_data_not_policy_or_shell_source(self):
        new = self.base / 'owned " (allow network*)'
        self.workspace.rename(new)
        self.review["workspace"] = str(new)
        d = json.loads(json.dumps(self.build()))
        self.assertEqual(d["argvCandidate"][-1], str(new / "tsconfig.json"))
        self.assertEqual(d["environment"]["HOME"], str(new / "home"))

    def test_dynamic_source_and_compiler_bytes_never_loaded_or_executed(self):
        path = self.sources / "positive.ts"
        path.write_bytes(b"import('node:child_process').then(x => x.execSync('NEVER'));\n")
        self.review["sources"]["files"]["positive.ts"] = p.sha256(path.read_bytes())
        with patch("subprocess.Popen", side_effect=AssertionError("no process")), \
                patch("socket.socket", side_effect=AssertionError("no network")), \
                patch("urllib.request.urlopen", side_effect=AssertionError("no acquisition")):
            d = self.build()
        self.assertFalse(d["executionApproved"])
        self.assertEqual(d["typeGraphClosure"], "NOT established")


if __name__ == "__main__":
    unittest.main()
