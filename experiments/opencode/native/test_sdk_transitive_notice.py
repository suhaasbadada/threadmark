"""Synthetic consistency only; synthetic verification JSON is NOT crypto proof."""
import base64
import copy
import json
from pathlib import Path
import unittest

import sdk_compiler_candidate as c
import sdk_transitive_notice as n

HERE = Path(__file__).parent


class TransitiveNoticeTests(unittest.TestCase):
    def setUp(self):
        self.receipt = json.loads((HERE / 'sdk-transitive-notice-provenance.json').read_bytes())
        self.notices = (HERE / 'THIRD-PARTY-NOTICES.txt').read_bytes()
        block = self.receipt['noticeBlock']
        self.raw = {'LICENSE': self.notices[block['offset']:block['offset'] + block['bytes']],
                    '.github/workflows/release.yml': b'synthetic inert workflow'}
        self.raw.update({'packages/' + name.split('/')[-1] + '/package.json': c.encoded({
            'name': name, 'license': 'MIT', 'version': '0.0.0'}) for name in n.NAMES})
        self.tree = {'sha': n.r.COMMIT, 'truncated': False, 'tree': [
            {'path': p, 'type': 'blob', 'mode': '100644', 'sha': n.r.blob(b), 'size': len(b)}
            for p, b in self.raw.items()]}
        self.receipt['sourceFiles'] = {p: dict(self.info(b), gitBlobSha1=n.r.blob(b)) for p, b in self.raw.items()}
        self.packages, self.responses, self.bundles, self.verified, self.metadata = [], {}, {}, {}, {}
        cert = self.receipt['verifiedCertificatePolicy']
        for item in self.receipt['packages']:
            name = item['name']
            self.packages.append({k: item[k] for k in ('name', 'version', 'archiveSha256', 'integrity', 'resolved')})
            self.packages[-1]['repository'] = {'directory': item['sourcePackagePath']}
            self.metadata[name] = c.encoded({'name': name, 'version': item['version'],
                                             'dist': {'integrity': item['integrity'], 'tarball': item['resolved']}})
            item['registryMetadata'] = self.info(self.metadata[name])
            statement = {'predicateType': 'https://slsa.dev/provenance/v1', 'subject': [{
                'name': 'pkg:npm/%40opencode/' + name.split('/')[-1] + '@2.2.5', 'digest': {
                    'sha512': base64.b64decode(item['integrity'].split('-', 1)[1]).hex()}}],
                'predicate': {'buildDefinition': {'resolvedDependencies': [{'digest': {'gitCommit': n.r.COMMIT}}]}}}
            bundle = {'dsseEnvelope': {'payload': base64.b64encode(c.encoded(statement)).decode(),
                                       'signatures': [{'keyid': '', 'sig': 'SYNTHETIC-NOT-A-SIGNATURE'}]},
                      'verificationMaterial': {'timestampVerificationData': {'rfc3161Timestamps': []}}}
            normalized = copy.deepcopy(bundle)
            del normalized['dsseEnvelope']['signatures'][0]['keyid']
            del normalized['verificationMaterial']['timestampVerificationData']['rfc3161Timestamps']
            result = [{'verificationResult': {'statement': statement, 'signature': {'certificate': cert}},
                       'attestation': {'bundle': normalized}}]
            self.bundles[name] = c.encoded(bundle)
            self.verified[name] = c.encoded(result)
            self.responses[name] = c.encoded({'attestations': [{'bundle': bundle}]})
            for label, data in [('bundle', self.bundles[name]), ('verifiedOutput', self.verified[name]),
                                ('registryAttestations', self.responses[name])]:
                item[label] = self.info(data)

    def info(self, b): return {'bytes': len(b), 'sha256': n.r.sha(b)}

    def check(self):
        tree = c.encoded(self.tree)
        self.receipt['sourceTree']['sha256'] = n.r.sha(tree)
        return n.check(self.receipt, self.packages, tree_bytes=tree, raw=self.raw,
                       responses=self.responses, metadata=self.metadata, bundles=self.bundles, verified=self.verified,
                       notice_bundle=self.notices)

    def test_consistency_has_no_authority_result(self):
        self.assertIsNone(self.check())
        self.assertEqual(len(self.receipt['packages']), 4)

    def test_missing_provenance_cannot_be_replaced_with_digest(self):
        del self.bundles[n.NAMES[0]]
        with self.assertRaisesRegex(ValueError, 'verification scope'): self.check()

    def test_wrong_package_or_source_mapping(self):
        self.packages[0]['repository']['directory'] = 'packages/other'
        with self.assertRaisesRegex(ValueError, 'source directory'): self.check()

    def test_changed_archive_pin(self):
        self.packages[0]['archiveSha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'archive pin'): self.check()

    def test_changed_registry_metadata(self):
        self.metadata[n.NAMES[0]] += b'\n'
        with self.assertRaisesRegex(ValueError, 'registry metadata'): self.check()

    def test_incomplete_tree(self):
        self.tree['truncated'] = True
        with self.assertRaisesRegex(ValueError, 'source tree'): self.check()

    def test_closer_notice_case_extension_or_ancestor(self):
        for p in ('packages/NOTICE.md', 'packages/ai/nested/cOpYrIgHt.txt', 'packages/util/LICENCE'):
            tree = copy.deepcopy(self.tree)
            self.tree['tree'].append({'path': p, 'type': 'blob', 'mode': '100644'})
            with self.subTest(path=p), self.assertRaisesRegex(ValueError, 'additional'): self.check()
            self.tree = tree

    def test_source_symlink_or_submodule(self):
        for mode in ('120000', '160000'):
            tree = copy.deepcopy(self.tree)
            self.tree['tree'].append({'path': 'packages/schema/link', 'mode': mode})
            with self.subTest(mode=mode), self.assertRaisesRegex(ValueError, 'link/submodule'): self.check()
            self.tree = tree

    def test_changed_raw_source(self):
        self.raw['packages/ai/package.json'] += b'\n'
        with self.assertRaisesRegex(ValueError, 'source blob'): self.check()

    def test_wrong_subject_even_with_new_result_hash(self):
        name = n.NAMES[0]
        bundle = json.loads(self.bundles[name])
        statement = json.loads(base64.b64decode(bundle['dsseEnvelope']['payload']))
        statement['subject'][0]['name'] += '-wrong'
        bundle['dsseEnvelope']['payload'] = base64.b64encode(c.encoded(statement)).decode()
        self.bundles[name] = c.encoded(bundle)
        self.receipt['packages'][0]['bundle'] = self.info(self.bundles[name])
        with self.assertRaisesRegex(ValueError, 'subject binding'): self.check()

    def test_wrong_certificate_workflow_even_with_new_result_hash(self):
        name = n.NAMES[0]
        result = json.loads(self.verified[name])
        result[0]['verificationResult']['signature']['certificate']['subjectAlternativeName'] += '-wrong'
        self.verified[name] = c.encoded(result)
        self.receipt['packages'][0]['verifiedOutput'] = self.info(self.verified[name])
        with self.assertRaisesRegex(ValueError, 'certificate policy'): self.check()

    def test_failure_measurement_or_self_approved_receipt(self):
        self.receipt['packages'][0]['ghExitCode'] = 1
        with self.assertRaisesRegex(ValueError, 'measurement'): self.check()
        self.receipt['packages'][0]['ghExitCode'] = 0
        self.receipt['independentReview'] = 'APPROVED'
        with self.assertRaisesRegex(ValueError, 'purpose/review'): self.check()

    def test_notice_prefix_and_exact_notice_bytes(self):
        self.notices = b'x' + self.notices[1:]
        with self.assertRaisesRegex(ValueError, 'notice prefix'): self.check()
        self.notices = b''
        with self.assertRaisesRegex(ValueError, 'notice block'): self.check()


if __name__ == '__main__': unittest.main()
