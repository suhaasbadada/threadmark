"""Offline consistency checks for inert planning, not SDK/compiler proof."""
import json
from pathlib import Path
import unittest

import project_types as t

HERE = Path(__file__).parent


class SelectionEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.evidence = json.loads((HERE / 'sdk-selection-discovery.json').read_bytes())
        cls.lock_bytes = (HERE / 'package-lock.json').read_bytes()
        cls.lock = json.loads(cls.lock_bytes)
        cls.packages = {p['name']: p for p in cls.evidence['packages']}

    def test_blocked_data_cannot_masquerade_as_descriptor(self):
        e = self.evidence
        self.assertEqual(e['kind'], 'inert-sdk-selection-planning')
        self.assertTrue(e['hasBlockingRequirements'])
        for field in ('executionApproved', 'selectionApproved', 'materialized'):
            self.assertIs(e[field], False)
        self.assertIsNone(e['compilerDescriptor'])
        self.assertNotIn('argvCandidate', e)
        self.assertNotIn('policy', e)
        self.assertEqual({x['id'] for x in e['knownMissing']}, {
            'SDK-NOTICE-REVIEW-1', 'SDK-GRAPH-1', 'SDK-AMBIENT-1',
            'SDK-FIXTURE-1', 'SDK-CONFIG-1', 'SDK-GUARD-1'})

    def test_all_nine_current_locked_identities(self):
        self.assertEqual(t.sha256(self.lock_bytes), self.evidence['lockSha256'])
        self.assertEqual(len(self.packages), 9)
        for p in self.packages.values():
            self.assertEqual(t.package_name(p['packagePath']), p['name'])
            entry = self.lock['packages'][p['packagePath']]
            for key in ('version', 'integrity', 'resolved'):
                self.assertEqual(entry[key], p[key])
            self.assertFalse(p['selectionApproved'])
            self.assertFalse(p['noticeMappingApproved'])
            self.assertEqual(p['graphClosure'], 'NOT established')

    def test_exact_relative_inventory_and_counts(self):
        e = self.evidence
        for p in self.packages.values():
            paths = {}
            for role in ('declarations', 'unselectedTypeSources', 'nestedMetadata', 'notices'):
                for path, record in p[role].items():
                    t.safe_path(path)
                    self.assertNotIn(path, paths)
                    paths[path] = False
                    self.assertRegex(record['sha256'], r'^[a-f0-9]{64}$')
                    self.assertGreater(record['bytes'], 0)
            t.check_paths(t.with_directories(paths))
        self.assertEqual(sum(len(p['declarations']) for p in self.packages.values()), 338)
        self.assertEqual(sum(len(p['unselectedTypeSources']) for p in self.packages.values()), 11)
        self.assertEqual(e['counts']['declarations'], 338)
        self.assertEqual(e['counts']['packagesWithArchiveNotices'], 6)
        for key in ('compressedBytes', 'expandedBytes', 'declaredBytes'):
            self.assertEqual(sum(p[key] for p in self.packages.values()), e['counts'][key])

    def test_notice_gap_is_package_specific_not_license_approval(self):
        source = (HERE / 'source-notice-evidence.json').read_bytes()
        self.assertEqual(t.sha256(source), self.evidence['sourceEvidenceSha256'])
        notice = next(x for x in json.loads(source)['sourceChecks']
                      if x.get('label') == 'OpenCode root MIT')
        self.assertEqual(t.sha256(notice['text'].encode()), self.evidence['rootNotice']['sha256'])
        self.assertTrue(self.evidence['rootNotice']['exactBytesPresentInNoticeBundle'])
        self.assertIn(notice['text'].encode(), (HERE / 'THIRD-PARTY-NOTICES.txt').read_bytes())
        missing = {p['name'] for p in self.packages.values() if not p['notices']}
        self.assertEqual(missing, {'@opencode/client', '@opencode/plugin', '@opencode/theme'})
        for name in missing:
            p = self.packages[name]
            self.assertEqual(p['repository']['directory'], 'packages/' + name.split('/')[-1])
            self.assertIsNone(p['archiveGitHead'])
            self.assertEqual(p['sourceCommitBinding'], '958f965d35ed44d32b018fd55b02a5357a7748fd')
            self.assertEqual(p['noticeMappingStatus'], 'EVIDENCE_COMPLETE_REVIEW_PENDING')

    def test_authentic_prerequisite_bindings_not_invented_ambient(self):
        receipt = json.loads((HERE / 'declaration-prerequisites.json').read_bytes())
        for record in receipt['records']:
            p = self.packages[record['name']]
            self.assertEqual(p['archiveSha256'], record['archiveSha256'])
            self.assertEqual(p['declarations']['index.d.ts'],
                             record['files'][record['typesPath']])
            self.assertEqual(p['notices']['LICENSE'], record['files'][record['noticePath']])
        self.assertEqual(self.evidence['explicitAmbientProposal'],
                         ['node_modules/@types/emscripten/index.d.ts'])
        options = self.evidence['optionsProposal']
        for name, value in {'strict': True, 'noEmit': True, 'skipLibCheck': False,
                            'skipDefaultLibCheck': False, 'types': [], 'moduleResolution': 'Bundler',
                            'module': 'ESNext', 'target': 'ESNext', 'jsx': 'react-jsx',
                            'jsxImportSource': '@opentui/solid'}.items():
            self.assertEqual(options[name], value)
        self.assertEqual(len(options), 10)

    def test_nested_metadata_and_full_surfaces_not_dropped(self):
        solid = self.packages['solid-js']
        self.assertIn('store/package.json', solid['nestedMetadata'])
        self.assertIn('web/package.json', solid['nestedMetadata'])
        self.assertIn('types/index.d.ts', solid['declarations'])
        self.assertIn('dist/tui/context.d.ts', self.packages['@opencode/plugin']['declarations'])
        self.assertIn('web-tree-sitter.d.ts', self.packages['web-tree-sitter']['declarations'])
        self.assertIn('@opencode/plugin/tui', self.evidence['scope'])
        self.assertIn('@opentui/solid/jsx-runtime', self.evidence['scope'])
        self.assertRegex(self.evidence['privateCandidateSha256'], r'^[a-f0-9]{64}$')
        # Public evidence is deliberately path/content-free; private artifacts are
        # not required by CI and this test must not read a developer's machine.
        text = json.dumps(self.evidence)
        self.assertNotIn('/private/', text)
        self.assertNotIn('Base64', text)


if __name__ == '__main__':
    unittest.main()
