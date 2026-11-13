"""Pure transition regressions and public evidence; no private files or runtimes."""
import copy
import json
from pathlib import Path
import unittest

import typings_alignment as a

HERE = Path(__file__).parent


class AlignmentTests(unittest.TestCase):
    def setUp(self):
        self.receipt = json.loads((HERE / 'typings-alignment.json').read_bytes())
        self.manifest_bytes = (HERE / 'package.json').read_bytes()
        self.lock_bytes = (HERE / 'package-lock.json').read_bytes()
        historical_manifest, historical_lock = a.current(self.manifest_bytes, self.lock_bytes, self.receipt)
        self.old_manifest, self.old_lock = json.loads(historical_manifest), json.loads(historical_lock)
        self.manifest, self.lock = json.loads(self.manifest_bytes), json.loads(self.lock_bytes)

    def check(self):
        a.transition(self.old_manifest, self.manifest, self.old_lock, self.lock, self.receipt)

    def test_exact_actual_transition_and_historical_receipt_binding(self):
        self.assertIsNone(self.check())
        self.assertEqual(len(self.old_lock['packages']), 378)
        self.assertEqual(len(self.lock['packages']), 384)
        self.assertEqual(set(self.receipt['packageDelta']), a.CHANGED | a.REDIS)
        old = json.loads((HERE / 'declaration-prerequisites.json').read_bytes())
        self.assertEqual(old['packageLockSha256'], a.OLD_LOCK)
        self.assertNotEqual(old['packageLockSha256'], a.NEW_LOCK)

    def test_current_wrong_hash_and_old_candidate_inputs_rejected(self):
        for manifest, lock in ((self.manifest_bytes + b' ', self.lock_bytes),
                               (self.manifest_bytes, self.lock_bytes + b' '),
                               (a.encoded(self.old_manifest), a.encoded(self.old_lock))):
            with self.assertRaises(ValueError): a.current(manifest, lock, self.receipt)

    def test_receipt_cannot_silently_change_transition_or_claims(self):
        for key, value in [('oldLockSha256', '0' * 64), ('newLockSha256', '0' * 64),
                           ('executionApproved', True), ('packageDelta', {})]:
            receipt = dict(self.receipt, **{key: value})
            with self.subTest(key=key), self.assertRaises(ValueError):
                a.current(self.manifest_bytes, self.lock_bytes, receipt)

    def test_exact_dev_pins_no_ranges_or_undeclared_changes(self):
        for key, value in [('@types/node', '^24.12.2'), ('undici-types', '8.9.0'), ('unexpected', '1')]:
            old = copy.deepcopy(self.manifest)
            self.manifest['devDependencies'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): self.check()
            self.manifest = old

    def test_all_unchanged_records_and_top_level_are_closed(self):
        self.lock['lockfileVersion'] = 4
        with self.assertRaises(ValueError): self.check()
        self.lock['lockfileVersion'] = self.old_lock['lockfileVersion']
        key = 'node_modules/solid-js'
        self.lock['packages'][key]['version'] = '0.0.0'
        with self.assertRaises(ValueError): self.check()

    def test_no_new_or_removed_packages_beyond_exact_six(self):
        for mutation in ('extra', 'missing'):
            lock = copy.deepcopy(self.lock)
            if mutation == 'extra': self.lock['packages']['node_modules/invented'] = {'version': '1'}
            else: del self.lock['packages']['node_modules/redis']
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): self.check()
            self.lock = lock

    def test_every_redis_field_integrity_and_edge_is_bound(self):
        for key in a.REDIS:
            original = copy.deepcopy(self.lock['packages'][key])
            for field, value in [('integrity', 'invented'), ('resolved', 'https://example.invalid'),
                                 ('peer', False), ('version', '6.3.2'), ('dependencies', {'extra': '*'})]:
                self.lock['packages'][key][field] = value
                with self.subTest(key=key, field=field), self.assertRaises(ValueError): self.check()
                self.lock['packages'][key] = copy.deepcopy(original)

    def test_only_reviewed_emscripten_and_typescript_flag_changes(self):
        for key in ('node_modules/@types/emscripten', 'node_modules/typescript'):
            original = copy.deepcopy(self.lock['packages'][key])
            self.lock['packages'][key]['dev'] = True
            with self.subTest(key=key), self.assertRaises(ValueError): self.check()
            self.lock['packages'][key] = original

    def test_full_typings_records_bind_not_just_versions(self):
        for name in a.PINS:
            key = 'node_modules/' + name
            original = copy.deepcopy(self.lock['packages'][key])
            self.lock['packages'][key]['integrity'] = 'invented'
            with self.subTest(name=name), self.assertRaises(ValueError): self.check()
            self.lock['packages'][key] = original

    def test_synthetic_prior_and_new_graph_still_require_every_unchanged_record(self):
        # Invented data exercises structure, not archive authenticity or resolver semantics.
        self.old_lock['packages']['node_modules/synthetic'] = {'version': 'invented', 'nested': {'kept': True}}
        self.lock['packages']['node_modules/synthetic'] = copy.deepcopy(self.old_lock['packages']['node_modules/synthetic'])
        self.check()
        self.lock['packages']['node_modules/synthetic']['nested']['kept'] = False
        with self.assertRaises(ValueError): self.check()

    def test_actual_notice_append_preserves_entire_historical_prefix(self):
        data = (HERE / 'THIRD-PARTY-NOTICES.txt').read_bytes()
        a.check_notices(data, self.receipt)
        for block in [self.receipt['priorNoticeBundle'], *[r['noticeBlock'] for r in self.receipt['archives']]]:
            offset = block.get('offset', 0)
            mutated = bytearray(data); mutated[offset] ^= 1
            with self.assertRaises(ValueError): a.check_notices(bytes(mutated), self.receipt)

    def test_actual_metadata_notices_and_signature_facts_are_data_only(self):
        records = {r['name']: r for r in self.receipt['archives']}
        self.assertEqual(records['@types/node']['manifest']['dependencies'], {'undici-types': '~7.16.0'})
        self.assertEqual(records['undici-types']['manifest'].get('dependencies', {}), {})
        for item in records.values():
            self.assertEqual(item['manifest']['license'], 'MIT')
            self.assertEqual(item['manifest']['types'], 'index.d.ts')
            self.assertFalse(item['manifest'].get('scripts'))
            self.assertEqual(item['files']['LICENSE']['sha256'], item['noticeBlock']['sha256'])
        comparison = self.receipt['signatureComparison']
        self.assertNotEqual(comparison['node24']['sha256'], comparison['node26']['sha256'])
        self.assertEqual(comparison['openTuiKeyHandler']['line'], 57)
        self.assertIn('not proof', comparison['interpretation'])
        self.assertIs(self.receipt['executionApproved'], False)


if __name__ == '__main__': unittest.main()
