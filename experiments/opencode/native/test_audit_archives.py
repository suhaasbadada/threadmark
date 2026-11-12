"""Offline synthetic archive gate tests; never import dependency packages."""

import gzip
import base64
import hashlib
import io
import json
import tarfile
import unittest
import tempfile
from pathlib import Path
from unittest.mock import patch

import audit_archives as audit


def archive(entries=(), root="package"):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w:gz") as target:
        manifest = json.dumps({"name": "synthetic", "version": "1.0.0", "license": "MIT"}).encode()
        for name, content, kind in [(root + "/package.json", manifest, tarfile.REGTYPE), *entries]:
            info = tarfile.TarInfo(name)
            info.type = kind
            info.size = len(content) if kind == tarfile.REGTYPE else 0
            info.linkname = "outside" if kind in (tarfile.SYMTYPE, tarfile.LNKTYPE) else ""
            target.addfile(info, io.BytesIO(content))
    return output.getvalue()


class ArchiveTests(unittest.TestCase):
    def test_manifest_and_actual_notices(self):
        result = audit.inspect_archive(archive([("package/LICENSE", b"synthetic notice", tarfile.REGTYPE)]))
        self.assertEqual(result[0]["name"], "synthetic")
        self.assertEqual(result[1]["package/LICENSE"]["text"], "synthetic notice")

    def test_definitely_typed_root_is_not_traversal(self):
        self.assertEqual(audit.inspect_archive(archive(root="node"))[0]["name"], "synthetic")

    def test_paths_and_special_members_rejected(self):
        for name in ["/absolute", "package/../escape", "package/a/../../escape", "package\\escape", "package//empty"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                audit.inspect_archive(archive([(name, b"", tarfile.REGTYPE)]))
        for kind in [tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.FIFOTYPE, tarfile.CHRTYPE, tarfile.BLKTYPE]:
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                audit.inspect_archive(archive([("package/special", b"", kind)]))

    def test_multiple_roots_rejected(self):
        with self.assertRaises(ValueError):
            audit.inspect_archive(archive([("another/file", b"", tarfile.REGTYPE)]))

    def test_identical_canonical_duplicate_is_inert_and_counted(self):
        result = audit.inspect_archive(archive([
            ("package/./index.js", b"abc", tarfile.REGTYPE),
            ("package/index.js", b"abc", tarfile.REGTYPE),
        ]))
        self.assertEqual(result[5], 3)
        self.assertGreaterEqual(result[4], 6)

    def test_conflicting_canonical_duplicate_rejected(self):
        with self.assertRaises(ValueError):
            audit.inspect_archive(archive([
                ("package/./index.js", b"abc", tarfile.REGTYPE),
                ("package/index.js", b"xyz", tarfile.REGTYPE),
            ]))

    def test_archive_compressed_bound(self):
        data = archive()
        with patch.object(audit, "ARCHIVE_LIMIT", len(data) - 1), self.assertRaises(ValueError):
            audit.inspect_archive(data)

    def test_decompression_bomb_bound_before_tar_processing(self):
        data = gzip.compress(b"x" * 4096)
        with patch.object(audit, "EXTRACTED_LIMIT", 1024), self.assertRaisesRegex(ValueError, "decompressed bound"):
            audit.inspect_archive(data)

    def test_executable_and_wasm_reported_not_executed(self):
        result = audit.inspect_archive(archive([("package/synthetic.wasm", b"not wasm", tarfile.REGTYPE)]))
        self.assertEqual(result[3], ["package/synthetic.wasm"])

    def test_pax_override_traversal_rejected(self):
        output = io.BytesIO()
        with tarfile.open(fileobj=output, mode="w:gz", format=tarfile.PAX_FORMAT) as target:
            info = tarfile.TarInfo("package/inert")
            info.pax_headers = {"path": "package/../escape"}
            target.addfile(info, io.BytesIO())
        with self.assertRaises(ValueError):
            audit.inspect_archive(output.getvalue())


class AcquisitionTests(unittest.TestCase):
    def test_redirect_denied_before_follow(self):
        with self.assertRaisesRegex(ValueError, "before follow"):
            audit.RejectRedirects().redirect_request(None, None, 302, "", {}, "https://other.invalid/")

    def test_redirect_handler_wired(self):
        original = audit.urllib.request.build_opener
        seen = []

        def check(*handlers):
            seen.extend(handlers)
            return original(*handlers)

        with patch.object(audit.urllib.request, "build_opener", side_effect=check):
            audit.acquire({"packages": {}}, None, {"records": []})
        self.assertTrue(any(isinstance(h, audit.RejectRedirects) for h in seen))

    def setUp(self):
        self.data = archive()
        self.url = "https://registry.npmjs.org/synthetic/-/synthetic-1.0.0.tgz"
        self.entry = {"version": "1.0.0", "resolved": self.url,
                      "integrity": "sha512-" + base64.b64encode(hashlib.sha512(self.data).digest()).decode()}

    def run_gate(self, entry=None, response_url=None):
        response = io.BytesIO(self.data)
        response.url = response_url or self.url
        opener = unittest.mock.Mock()
        opener.open.return_value = response
        result = {"records": []}
        lock = {"packages": {"node_modules/synthetic": entry or self.entry}}
        with tempfile.TemporaryDirectory(prefix="threadmark-archive-test-") as root:
            with patch.object(audit.urllib.request, "build_opener", return_value=opener):
                return audit.acquire(lock, Path(root), result)

    def test_notice_gap_is_blocked_not_install_permission(self):
        result = self.run_gate()
        self.assertIn("BLOCKED", result["status"])
        self.assertEqual(len(result["noticeBlockers"]), 1)
        self.assertEqual(result["execution"], "NONE; no extraction or dependency execution")

    def test_optional_explicitly_excluded_without_fetch(self):
        result = self.run_gate({**self.entry, "optional": True})
        self.assertIn("EXCLUDED", result["records"][0]["status"])
        self.assertNotIn("computedIntegrity", result["records"][0])

    def test_integrity_mismatch(self):
        with self.assertRaisesRegex(ValueError, "integrity mismatch"):
            self.run_gate({**self.entry, "integrity": "sha512-" + "A" * 86 + "=="})

    def test_redirect_is_not_accepted(self):
        with self.assertRaisesRegex(ValueError, "redirected"):
            self.run_gate(response_url="https://other.invalid/archive")

    def test_private_registry_is_not_accepted(self):
        with self.assertRaisesRegex(ValueError, "provenance"):
            self.run_gate({**self.entry, "resolved": "https://other.invalid/archive"})

    def test_manifest_mismatch(self):
        with self.assertRaisesRegex(ValueError, "identity mismatch"):
            self.run_gate({**self.entry, "version": "2.0.0"})

    def test_unknown_actual_license_stops(self):
        with patch.object(audit, "ALLOWED", set()), self.assertRaisesRegex(ValueError, "unapproved actual manifest license"):
            self.run_gate()

    def test_total_compressed_bound(self):
        with patch.object(audit, "COMPRESSED_LIMIT", 1), self.assertRaisesRegex(ValueError, "total compressed bound"):
            self.run_gate()

    def two_archives(self, limit):
        # Real tar padding/headers count even when declared file bytes are tiny.
        data2 = archive(root="synthetic")
        entry2 = {**self.entry, "name": "synthetic",
                  "resolved": "https://registry.npmjs.org/synthetic/-/second.tgz",
                  "integrity": "sha512-" + base64.b64encode(hashlib.sha512(data2).digest()).decode()}
        lock = {"packages": {"node_modules/synthetic": self.entry,
                             "node_modules/parent/node_modules/synthetic": entry2}}
        responses = []
        # acquire sorts nested path first.
        for data, url in [(data2, entry2["resolved"]), (self.data, self.url)]:
            response = io.BytesIO(data)
            response.url = url
            responses.append(response)
        opener = unittest.mock.Mock()
        opener.open.side_effect = responses
        evidence = {"records": []}
        with tempfile.TemporaryDirectory(prefix="threadmark-archive-test-") as root:
            with patch.object(audit.urllib.request, "build_opener", return_value=opener), patch.object(audit, "EXTRACTED_LIMIT", limit):
                return audit.acquire(lock, Path(root), evidence)

    def test_total_actual_expansion_bound_inclusive(self):
        expanded = len(gzip.decompress(self.data)) + len(gzip.decompress(archive(root="synthetic")))
        result = self.two_archives(expanded)
        self.assertEqual(result["expandedBytes"], expanded)
        self.assertEqual(sum(r["expandedBytes"] for r in result["records"]), expanded)
        self.assertLess(result["declaredExtractedBytes"], expanded)

    def test_total_actual_expansion_overflow(self):
        expanded = len(gzip.decompress(self.data)) + len(gzip.decompress(archive(root="synthetic")))
        with self.assertRaisesRegex(ValueError, "total expanded bound"):
            self.two_archives(expanded - 1)


if __name__ == "__main__":
    unittest.main()
