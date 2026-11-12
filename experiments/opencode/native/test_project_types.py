"""Pure inert synthetic fixtures; no SDK imports, compiler or network."""

import base64
import copy
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import project_types as p


def archive(files, extra=(), root="package", fmt=tarfile.PAX_FORMAT):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w:gz", format=fmt) as target:
        for name, data in files.items():
            info = tarfile.TarInfo(root + "/" + name)
            info.size = len(data)
            info.mode = 0o777  # Output must never inherit executable modes.
            target.addfile(info, io.BytesIO(data))
        for info, data in extra:
            target.addfile(info, io.BytesIO(data))
    return stream.getvalue()


def fixture(version="1.0.0", path="node_modules/synthetic", root="package"):
    metadata = (json.dumps({"name": "synthetic", "version": version, "license": "MIT",
                           "exports": {"./private": None, "./*": {"types": "./*.d.ts"}},
                           "typesVersions": {"*": {"*": ["*.d.ts"]}},
                           "scripts": {"install": "NEVER EXECUTE"}}, indent=3) + "\n").encode()
    files = {"package.json": metadata, "index.d.ts": b"export interface Synthetic {}\n",
             "jsx.tsx": b"export interface JSX {}\n", "import.d.mts": b"export {};\n",
             "require.d.cts": b"export {};\n", "source.ts": b"export type X = string;\n"}
    data = archive(files, root=root)
    integrity = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
    entry = {"version": version, "integrity": integrity, "resolved": "https://registry.npmjs.org/synthetic/-/fixture.tgz"}
    approval = {"path": path, "name": "synthetic", **entry, "archiveRoot": root,
                "license": "MIT", "licenseStatus": "approved", "noticeStatus": "approved",
                "noticeEvidence": "reviewed synthetic fixture ONLY", "metadataSha256": p.sha256(metadata),
                "files": {name: p.sha256(content) for name, content in files.items()}}
    lock = json.dumps({"packages": {path: entry}}).encode()
    plan = {"status": "reviewed", "lockSha256": p.sha256(lock), "packages": [approval],
            "missing": [], "unresolved": []}
    return lock, plan, {integrity: data}, files


class ProjectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="threadmark-projection-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.destination = Path(self.temp.name) / "fresh"
        self.lock, self.plan, self.archives, self.files = fixture()

    def project(self):
        return p.project(self.destination, self.lock, self.plan, self.archives)

    def test_exact_full_metadata_and_sources_no_resolution_claim(self):
        ledger = self.project()
        self.assertEqual(ledger["state"], "prepared_not_compiled")
        self.assertEqual(ledger["typeGraphClosure"], "NOT established")
        self.assertEqual(ledger["runtimeDependencyClosure"], "NOT established")
        self.assertFalse((self.destination / "INCOMPLETE").exists())
        self.assertTrue((self.destination / "ledger.json").is_file())
        self.assertEqual(self.destination.stat().st_mode & 0o777, 0o700)
        for name, content in self.files.items():
            target = self.destination / "node_modules/synthetic" / name
            self.assertEqual(target.read_bytes(), content)
            self.assertEqual(target.stat().st_mode & 0o777, 0o400)

    def test_nested_versions_preserved(self):
        lock2, plan2, archives2, files2 = fixture("2.0.0", "node_modules/parent/node_modules/synthetic", "synthetic")
        lock = json.loads(self.lock)
        lock["packages"].update(json.loads(lock2)["packages"])
        self.lock = json.dumps(lock).encode()
        self.plan["lockSha256"] = p.sha256(self.lock)
        self.plan["packages"].extend(plan2["packages"])
        self.archives.update(archives2)
        self.project()
        self.assertEqual((self.destination / "node_modules/parent/node_modules/synthetic/package.json").read_bytes(), files2["package.json"])
        self.assertEqual((self.destination / "node_modules/synthetic/package.json").read_bytes(), self.files["package.json"])

    def test_approval_lock_and_identity_fail_closed(self):
        for key, value in [("name", "other"), ("version", "2"), ("noticeStatus", "BLOCKED"),
                           ("noticeEvidence", ""), ("licenseStatus", "pending"), ("license", "ISC"),
                           ("metadataSha256", "wrong"), ("resolved", "other")]:
            with self.subTest(key=key):
                plan = copy.deepcopy(self.plan)
                plan["packages"][0][key] = value
                with self.assertRaises(ValueError):
                    p.project(self.destination, self.lock, plan, self.archives)
                self.assertFalse(self.destination.exists())
        for plan in [{"status": "BLOCKED"}, {**self.plan, "lockSha256": "wrong"},
                     {**self.plan, "missing": ["mandatory @types/emscripten"]},
                     {**self.plan, "unresolved": ["JS-only requested module"]}]:
            with self.assertRaises(ValueError):
                p.project(self.destination, self.lock, plan, self.archives)

    def test_actual_sdk_audit_is_not_approval(self):
        actual = json.loads(Path(__file__).with_name("dependency-audit-conditional.json").read_bytes())
        with self.assertRaises(ValueError):
            p.prepare_files(self.lock, actual, {})

    def test_missing_metadata_selected_file_and_tamper(self):
        for name, digest in [("missing.d.ts", "a"), ("index.d.ts", "wrong")]:
            plan = copy.deepcopy(self.plan)
            plan["packages"][0]["files"][name] = digest
            with self.assertRaises(ValueError):
                p.project(self.destination, self.lock, plan, self.archives)
        del self.plan["packages"][0]["files"]["package.json"]
        with self.assertRaisesRegex(ValueError, "package.json required"):
            self.project()

    def test_runtime_bin_native_and_nested_package_denied(self):
        for name in ["runtime.js", "bin/tool.ts", "native.node", "types.wasm", "node_modules/other/a.d.ts"]:
            plan = copy.deepcopy(self.plan)
            plan["packages"][0]["files"][name] = "any"
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "denied"):
                p.project(self.destination, self.lock, plan, self.archives)

    def test_nested_metadata_identity_requires_separate_package(self):
        files = {**self.files, "sub/package.json": b'{"name":"different"}', "sub/a.d.ts": b"export {};"}
        data = archive(files)
        integrity = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
        plan = copy.deepcopy(self.plan)
        plan["packages"][0]["integrity"] = integrity
        plan["packages"][0]["files"]["sub/a.d.ts"] = p.sha256(files["sub/a.d.ts"])
        lock = json.loads(self.lock)
        lock["packages"]["node_modules/synthetic"]["integrity"] = integrity
        lock_bytes = json.dumps(lock).encode()
        plan["lockSha256"] = p.sha256(lock_bytes)
        with self.assertRaisesRegex(ValueError, "nested package identity"):
            p.project(self.destination, lock_bytes, plan, {integrity: data})

    def test_pending_manifest_corruption_is_incomplete(self):
        original = p.write_file

        def corrupt(root, name, content):
            return original(root, name, b"bad" if name == "ledger.pending" else content)

        with patch.object(p, "write_file", side_effect=corrupt), self.assertRaisesRegex(ValueError, "hash mismatch"):
            self.project()
        self.assertTrue((self.destination / "INCOMPLETE").exists())
        self.assertFalse((self.destination / "ledger.json").exists())

    def test_wrong_integrity_before_parser(self):
        with patch.object(p.tarfile, "open", side_effect=AssertionError("must not parse")):
            with self.assertRaisesRegex(ValueError, "integrity"):
                p.inspect(b"tampered", next(iter(self.archives)))

    def test_preexisting_directory_and_link_never_overwritten(self):
        self.destination.mkdir()
        with self.assertRaises(FileExistsError):
            self.project()
        self.destination.rmdir()
        self.destination.symlink_to(Path(self.temp.name), target_is_directory=True)
        with self.assertRaises(FileExistsError):
            self.project()

    def test_interrupt_keeps_incomplete_no_usable_ledger(self):
        original = p.write_file

        def interrupt(root, name, content):
            if name.endswith("index.d.ts"):
                raise InterruptedError("synthetic interruption")
            return original(root, name, content)

        with patch.object(p, "write_file", side_effect=interrupt), self.assertRaises(InterruptedError):
            self.project()
        self.assertTrue((self.destination / "INCOMPLETE").exists())
        self.assertFalse((self.destination / "ledger.json").exists())
        with self.assertRaises(FileExistsError):
            self.project()

    def test_copied_hash_mismatch_keeps_incomplete(self):
        original = p.write_file

        def corrupt(root, name, content):
            return original(root, name, b"bad" if name.endswith("index.d.ts") else content)

        with patch.object(p, "write_file", side_effect=corrupt), self.assertRaisesRegex(ValueError, "copied file hash"):
            self.project()
        self.assertTrue((self.destination / "INCOMPLETE").exists())
        self.assertFalse((self.destination / "ledger.json").exists())

    def test_child_link_race_not_followed(self):
        original = p.write_file

        def inject(root, name, content):
            if name == "INCOMPLETE":
                original(root, name, content)
                os.symlink(self.temp.name, "node_modules", dir_fd=root)
            else:
                original(root, name, content)

        with patch.object(p, "write_file", side_effect=inject), self.assertRaises(OSError):
            self.project()
        self.assertFalse((Path(self.temp.name) / "synthetic").exists())
        self.assertTrue((self.destination / "INCOMPLETE").exists())

    def test_destination_bound_inclusive(self):
        output, ledger = p.prepare_files(self.lock, self.plan, self.archives)
        size = sum(map(len, output.values())) + len((json.dumps(ledger, sort_keys=True, indent=2) + "\n").encode()) + len(b"incomplete; not usable\n")
        with patch.object(p, "DESTINATION_LIMIT", size - 1), self.assertRaisesRegex(ValueError, "bound"):
            self.project()
        self.assertFalse(self.destination.exists())
        with patch.object(p, "DESTINATION_LIMIT", size):
            self.project()


class ArchiveBoundaryTests(unittest.TestCase):
    def inspect(self, data):
        integrity = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
        return p.inspect(data, integrity)

    def test_paths_effective_pax_and_gnu_names(self):
        for name in ["/absolute", "package/../escape", "package//empty", "package/./dot",
                     "package/back\\slash", "package/control\n", "package/\x00null"]:
            # NUL in a traditional tar name terminates rather than names a NUL;
            # PAX supplies the effective name including the control character.
            for fmt in [tarfile.PAX_FORMAT, tarfile.GNU_FORMAT]:
                if "\x00" in name and fmt == tarfile.GNU_FORMAT:
                    continue
                info = tarfile.TarInfo(name)
                if fmt == tarfile.PAX_FORMAT:
                    info.pax_headers = {"path": name}
                with self.subTest(name=name, fmt=fmt), self.assertRaises(ValueError):
                    self.inspect(archive({}, [(info, b"")], fmt=fmt))

    def test_special_links_sparse(self):
        for kind in [tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.FIFOTYPE,
                     tarfile.CHRTYPE, tarfile.BLKTYPE, tarfile.GNUTYPE_SPARSE]:
            info = tarfile.TarInfo("package/special")
            info.type, info.linkname = kind, "outside"
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                self.inspect(archive({}, [(info, b"")]))
        info = tarfile.TarInfo("package/sparse")
        info.pax_headers = {"GNU.sparse.size": "0"}
        with self.assertRaises(ValueError):
            self.inspect(archive({}, [(info, b"")]))

    def test_gnu_longname_traversal_is_effective_path(self):
        info = tarfile.TarInfo("package/" + "x" * 150 + "/../../escape")
        with self.assertRaises(ValueError):
            self.inspect(archive({}, [(info, b"")], fmt=tarfile.GNU_FORMAT))

    def test_duplicates_case_nfc_and_ancestor_conflicts(self):
        for names in [("a", "a"), ("A.d.ts", "a.d.ts"), ("é.d.ts", "e\u0301.d.ts"),
                      ("a", "a/b.d.ts"), ("Dir/a.d.ts", "dir/b.d.ts")]:
            entries = []
            for name in names:
                info = tarfile.TarInfo("package/" + name)
                entries.append((info, b""))
            with self.subTest(names=names), self.assertRaises(ValueError):
                self.inspect(archive({}, entries))

    def test_archive_bounds_inclusive_and_overflow(self):
        data = archive({"a.d.ts": b"x" * 32})
        expanded = len(gzip.decompress(data))
        for symbol, limit in [("ARCHIVE_LIMIT", len(data)), ("EXPANDED_LIMIT", expanded), ("MEMBER_LIMIT", 1)]:
            with patch.object(p, symbol, limit):
                self.inspect(data)
            with patch.object(p, symbol, limit - 1), self.assertRaisesRegex(ValueError, "bound"):
                self.inspect(data)

    def test_total_archive_limits(self):
        lock, plan, archives, _ = fixture()
        data = next(iter(archives.values()))
        with patch.object(p, "COMPRESSED_LIMIT", len(data) - 1), self.assertRaisesRegex(ValueError, "compressed bound"):
            p.prepare_files(lock, plan, archives)
        with patch.object(p, "COMPRESSED_LIMIT", len(data)):
            p.prepare_files(lock, plan, archives)

    def test_total_expanded_and_declared_overflow(self):
        lock, plan, archives, _ = fixture()
        lock2, plan2, archives2, _ = fixture("2.0.0", "node_modules/parent/node_modules/synthetic")
        combined = json.loads(lock)
        combined["packages"].update(json.loads(lock2)["packages"])
        lock = json.dumps(combined).encode()
        plan["lockSha256"] = p.sha256(lock)
        plan["packages"].extend(plan2["packages"])
        archives.update(archives2)
        original = p.inspect
        for declared in [False, True]:
            def bounded(data, integrity):
                files, _, _ = original(data, integrity)
                return files, 1 if declared else 600000, 600000 if declared else 1

            with patch.object(p, "EXPANDED_LIMIT", 1000000), patch.object(p, "inspect", side_effect=bounded):
                with self.assertRaisesRegex(ValueError, "total expanded/declared"):
                    p.prepare_files(lock, plan, archives)


if __name__ == "__main__":
    unittest.main()
