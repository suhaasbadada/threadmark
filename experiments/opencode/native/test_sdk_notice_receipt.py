"""Synthetic negative tests and public receipt consistency; no crypto claims."""
import copy
import json
from pathlib import Path
import unittest

import sdk_notice_receipt as n

HERE = Path(__file__).parent


class NoticeReceiptTests(unittest.TestCase):
    def setUp(self):
        self.receipt = json.loads((HERE / 'sdk-notice-provenance.json').read_bytes())
        self.selection = json.loads((HERE / 'sdk-selection-discovery.json').read_bytes())
        self.notices = (HERE / 'THIRD-PARTY-NOTICES.txt').read_bytes()

    def check(self):
        return n.check_receipt(self.receipt, self.selection, self.notices)

    def test_public_receipt_consistent_but_returns_no_authority(self):
        self.assertIsNone(self.check())
        self.assertEqual(n.sha((HERE / 'sdk-notice-provenance.json').read_bytes()),
                         self.selection['noticeProvenanceSha256'])

    def test_wrong_archive(self):
        self.receipt['packages'][0]['archiveSha512'] = '00' * 64
        with self.assertRaisesRegex(ValueError, 'archive identity'):
            self.check()

    def test_wrong_raw_notice_record(self):
        self.receipt['sourceFiles']['LICENSE']['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'raw notice record'):
            self.check()

    def test_wrong_subject(self):
        self.receipt['packages'][0]['subject']['name'] += '-wrong'
        with self.assertRaisesRegex(ValueError, 'subject identity'):
            self.check()

    def test_wrong_source_commit(self):
        self.receipt['packages'][0]['certificate']['sourceRepositoryDigest'] = '0' * 40
        with self.assertRaisesRegex(ValueError, 'certificate identity'):
            self.check()

    def test_wrong_package_path(self):
        self.receipt['packages'][0]['sourcePackagePath'] = 'packages/other'
        with self.assertRaisesRegex(ValueError, 'package path'):
            self.check()

    def test_missing_notice_bytes(self):
        self.notices = self.notices[:self.receipt['noticeBlock']['offset']]
        with self.assertRaisesRegex(ValueError, 'notice block'):
            self.check()

    def test_stale_opaque_digest_cannot_self_approve(self):
        self.selection['privateCandidateSha256'] = '0' * 64
        self.selection['selectionApproved'] = True
        with self.assertRaisesRegex(ValueError, 'closed selection gates'):
            self.check()

    def tree_fixture(self):
        block = self.receipt['noticeBlock']
        raw = {'LICENSE': self.notices[block['offset']:block['offset'] + block['bytes']],
               '.github/workflows/release.yml': b'synthetic inert workflow'}
        raw.update({'packages/' + x + '/package.json': json.dumps({
            'name': '@opencode/' + x, 'license': 'MIT', 'version': '0.0.0'}).encode()
                    for x in ('client', 'plugin', 'theme')})
        tree = {'sha': n.COMMIT, 'truncated': False, 'tree': [
            {'path': p, 'mode': '100644', 'type': 'blob', 'sha': n.blob(b), 'size': len(b)}
            for p, b in raw.items()]}
        return tree, raw

    def test_complete_synthetic_tree_scope(self):
        tree, raw = self.tree_fixture()
        self.assertEqual(n.check_tree(tree, raw), ['LICENSE'])
        tree['truncated'] = True
        with self.assertRaisesRegex(ValueError, 'source tree'):
            n.check_tree(tree, raw)

    def test_nearer_notice_case_extension_and_ancestor(self):
        for path in ('packages/client/lIcEnSe.md', 'packages/NOTICE',
                     'packages/theme/nested/COPYRIGHT.txt'):
            tree, raw = self.tree_fixture()
            tree['tree'].append({'path': path, 'mode': '100644', 'type': 'blob'})
            with self.assertRaisesRegex(ValueError, 'additional source notice'):
                n.check_tree(tree, raw)

    def test_source_blob_missing_or_changed(self):
        tree, raw = self.tree_fixture()
        changed = copy.deepcopy(raw)
        del changed['LICENSE']
        with self.assertRaisesRegex(ValueError, 'missing source raw'):
            n.check_tree(tree, changed)
        raw['LICENSE'] += b'changed'
        with self.assertRaisesRegex(ValueError, 'source blob binding'):
            n.check_tree(tree, raw)

    def test_source_symlink_rejected(self):
        tree, raw = self.tree_fixture()
        tree['tree'].append({'path': 'packages/client/link', 'mode': '120000'})
        with self.assertRaisesRegex(ValueError, 'source symlink'):
            n.check_tree(tree, raw)


if __name__ == '__main__':
    unittest.main()
