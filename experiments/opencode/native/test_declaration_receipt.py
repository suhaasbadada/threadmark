"""Offline receipt identities and explicitly synthetic inert archive negatives."""

import base64
import copy
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile
import unittest
from unittest.mock import patch

import declaration_receipt as d

ROOT = Path(__file__).parent


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((ROOT / "package.json").read_bytes())
        self.lock = json.loads((ROOT / "package-lock.json").read_bytes())

    def test_exact_owned_pins_and_public_receipt(self):
        receipt = json.loads((ROOT / "declaration-prerequisites.json").read_bytes())
        self.assertEqual(receipt["packageLockSha256"], hashlib.sha256((ROOT / "package-lock.json").read_bytes()).hexdigest())
        self.assertEqual(receipt["packageManifestSha256"], hashlib.sha256((ROOT / "package.json").read_bytes()).hexdigest())
        self.assertEqual({r["name"] for r in receipt["records"]}, set(d.PINS))
        notices = (ROOT / "THIRD-PARTY-NOTICES.txt").read_bytes()
        for record in receipt["records"]:
            version, root, integrity, url = d.identity(self.manifest, self.lock, record["name"])
            self.assertEqual((record["version"], record["integrity"], record["resolved"]), (version, integrity, url))
            self.assertEqual(record["typesPath"], root + "/index.d.ts")
            self.assertEqual(record["noticePath"], root + "/LICENSE")
            self.assertEqual(len(record["files"]), 4)
            self.assertFalse(record["manifest"]["dependencies"])
            self.assertFalse(record["manifest"]["scripts"])
            self.assertEqual(record["externalImportOrReferenceLines"], [])
            marker = (record["noticePath"] + " SHA-256 " + record["files"][record["noticePath"]]["sha256"] + "\n").encode()
            notice = notices.split(marker)[1][:record["files"][record["noticePath"]]["bytes"]]
            self.assertEqual(hashlib.sha256(notice).hexdigest(), record["files"][record["noticePath"]]["sha256"])

    def test_missing_wrong_version_integrity_source_and_root_rejected(self):
        for field, value in [("version", "0.0.0"), ("integrity", "sha512-invalid"), ("resolved", "https://example.invalid/archive")]:
            with self.subTest(field=field):
                lock = copy.deepcopy(self.lock)
                lock["packages"]["node_modules/@types/emscripten"][field] = value
                with self.assertRaises(ValueError):
                    d.identity(self.manifest, lock, "@types/emscripten")
        for location in ("entry", "root", "manifest"):
            lock, manifest = copy.deepcopy(self.lock), copy.deepcopy(self.manifest)
            if location == "entry":
                del lock["packages"]["node_modules/@types/emscripten"]
            elif location == "root":
                del lock["packages"][""]["devDependencies"]["@types/emscripten"]
            else:
                manifest["devDependencies"]["@types/emscripten"] = "^1.40.0"
            with self.assertRaises(ValueError):
                d.identity(manifest, lock, "@types/emscripten")

    def synthetic(self, changes=None, omit=None):
        # Invented bytes/notice, not authentic upstream evidence or SDK stubs.
        metadata = {"name": "@types/emscripten", "version": "1.40.0", "license": "MIT", "types": "index.d.ts", "dependencies": {}, "scripts": {}}
        metadata.update(changes or {})
        files = {"package.json": json.dumps(metadata).encode(), "index.d.ts": b"// synthetic inert declaration\n", "LICENSE": b"MIT License\nCopyright synthetic fixture\n", "README.md": b"synthetic\n"}
        if omit:
            del files[omit]
        output = io.BytesIO()
        with tarfile.open(fileobj=output, mode="w") as archive:
            for name, content in files.items():
                entry = tarfile.TarInfo("emscripten/" + name)
                entry.size = len(content)
                archive.addfile(entry, io.BytesIO(content))
        data = gzip.compress(output.getvalue(), mtime=0)
        integrity = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
        lock = copy.deepcopy(self.lock)
        lock["packages"]["node_modules/@types/emscripten"]["integrity"] = integrity
        return data, integrity, lock

    def check_synthetic(self, changes=None, omit=None, corrupt=False):
        data, integrity, lock = self.synthetic(changes, omit)
        pins = {**d.PINS, "@types/emscripten": ("1.40.0", "emscripten", integrity)}
        with patch.object(d, "PINS", pins):
            return d.inspect(self.manifest, lock, "@types/emscripten", data + b"corrupt" if corrupt else data)

    def test_synthetic_valid_full_metadata_retained(self):
        record, files = self.check_synthetic({"syntheticExtra": {"preserved": True}})
        self.assertEqual(record["manifest"]["syntheticExtra"], {"preserved": True})
        self.assertEqual(len(files), 4)

    def test_corrupt_integrity_rejected_before_archive_parse(self):
        with self.assertRaisesRegex(ValueError, "integrity"):
            self.check_synthetic(corrupt=True)

    def test_missing_notice_or_declaration_rejected(self):
        for name in ("LICENSE", "index.d.ts"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.check_synthetic(omit=name)

    def test_small_bounds_before_shared_archive_parser(self):
        data = gzip.compress(b"\0" * (1024 * 1024 + 1), mtime=0)
        integrity = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
        lock = copy.deepcopy(self.lock)
        lock["packages"]["node_modules/@types/emscripten"]["integrity"] = integrity
        pins = {**d.PINS, "@types/emscripten": ("1.40.0", "emscripten", integrity)}
        with patch.object(d, "PINS", pins), patch.object(d.project_types, "inspect") as parser:
            with self.assertRaisesRegex(ValueError, "small expanded bound"):
                d.inspect(self.manifest, lock, "@types/emscripten", data)
            parser.assert_not_called()
        with patch.object(d.project_types, "inspect") as parser:
            with self.assertRaisesRegex(ValueError, "small archive bound"):
                d.inspect(self.manifest, self.lock, "@types/emscripten", b"\0" * (512 * 1024 + 1))
            parser.assert_not_called()

    def test_actual_metadata_identity_and_extra_dependencies_rejected(self):
        for changes in ({"name": "wrong"}, {"version": "0.0.0"}, {"dependencies": {"extra": "*"}}, {"peerDependencies": {"extra": "*"}}, {"optionalDependencies": {"extra": "*"}}, {"devDependencies": {"extra": "*"}}, {"scripts": {"install": "false"}}, {"license": "ISC"}, {"types": "other.d.ts"}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.check_synthetic(changes)


if __name__ == "__main__":
    unittest.main()
