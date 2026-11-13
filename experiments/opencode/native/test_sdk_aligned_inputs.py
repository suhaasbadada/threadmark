"""Invented inert archive negatives and public aligned-selection checks only."""
import copy
import gzip
import io
import json
from pathlib import Path
import tarfile
import unittest

import sdk_aligned_inputs as x
import sdk_projection as q

HERE = Path(__file__).parent


def synthetic():
    # Synthetic data is NOT upstream provenance or a compiler fixture.
    root = 'node v24.12'
    contents = {'package.json': b'{"name":"@types/node","version":"24.12.2"}',
                'LICENSE': b'Synthetic inert notice', 'index.d.ts': b'export {};\n',
                'ts5.6/index.d.ts': b'export {};\n', 'README.md': b'invented'}
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w') as archive:
        for name, data in contents.items():
            info = tarfile.TarInfo(root + '/' + name); info.size = len(data)
            archive.addfile(info, io.BytesIO(data))
    data = gzip.compress(stream.getvalue(), mtime=0)
    import base64
    import hashlib
    integrity = 'sha512-' + base64.b64encode(hashlib.sha512(data).digest()).decode()
    record = {'name': '@types/node', 'version': '24.12.2', 'archiveRoot': root,
        'archiveSha256': x.s.t.sha256(data), 'integrity': integrity, 'resolved': 'https://example.invalid/synthetic',
        'metadataSha256': x.s.t.sha256(contents['package.json']), 'manifest': json.loads(contents['package.json']),
        'files': {n: {'bytes': len(b), 'sha256': x.s.t.sha256(b)} for n, b in contents.items()}}
    selection = {k: record[k] for k in ('name', 'version', 'archiveRoot', 'archiveSha256', 'integrity', 'resolved', 'metadataSha256')}
    selection['path'] = 'node_modules/@types/node'
    selection['files'] = {n: x.s.record(b, 'complete_metadata' if n == 'package.json' else
        'authentic_notice' if n == 'LICENSE' else 'declaration') for n, b in contents.items() if n != 'README.md'}
    lock = {'packages': {selection['path']: {k: record[k] for k in ('version', 'integrity', 'resolved')}}}
    return lock, selection, data, {'archives': [record]}


class AlignedTests(unittest.TestCase):
    def test_archive_space_root_never_becomes_projection_path_or_alias(self):
        output, evidence = x.inspect_package(*synthetic())
        self.assertEqual(evidence['archiveRoot'], 'node v24.12')
        self.assertEqual(len(output), 4)
        self.assertFalse(any(' ' in name for name in output))
        self.assertIn('node_modules/@types/node/ts5.6/index.d.ts', output)

    def test_all_declarations_metadata_and_notice_required(self):
        for name in ('LICENSE', 'index.d.ts', 'ts5.6/index.d.ts', 'package.json'):
            lock, selection, data, receipt = synthetic()
            del selection['files'][name]
            with self.subTest(name=name), self.assertRaises(ValueError): x.inspect_package(lock, selection, data, receipt)

    def test_wrong_archive_identity_root_location_and_metadata_rejected(self):
        for key, value in [('version', '26.6.6'), ('archiveRoot', '../node'), ('archiveRoot', 'node'),
                           ('path', 'node_modules/nested/@types/node'), ('metadataSha256', '0' * 64)]:
            lock, selection, data, receipt = synthetic(); selection[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                x.inspect_package(lock, selection, data, receipt)

    def test_corrupt_archive_and_invented_file_role_rejected(self):
        lock, selection, data, receipt = synthetic()
        with self.assertRaises(ValueError): x.inspect_package(lock, selection, data + b'corrupt', receipt)
        selection['files']['index.d.ts']['role'] = 'runtime'
        with self.assertRaises(ValueError): x.inspect_package(lock, selection, data, receipt)

    def test_full_archive_inventory_and_whole_metadata_bound(self):
        for mutate in ('inventory', 'metadata'):
            lock, selection, data, receipt = synthetic()
            record = receipt['archives'][0]
            if mutate == 'inventory': del record['files']['README.md']
            else: record['manifest']['invented'] = True
            with self.subTest(mutate=mutate), self.assertRaises(ValueError): x.inspect_package(lock, selection, data, receipt)

    def test_public_aligned_selection_closed_scope_and_fixtures(self):
        summary = json.loads((HERE / 'sdk-aligned-discovery.json').read_bytes())
        self.assertEqual(summary['selectionSha256'], q.SELECTION_SHA)
        self.assertEqual(summary['inputPlanSha256'], q.PLAN_SHA)
        self.assertNotEqual(q.SELECTION_SHA, q.HISTORICAL_SELECTION_SHA)
        self.assertNotEqual(q.PLAN_SHA, q.HISTORICAL_PLAN_SHA)
        self.assertEqual(summary['counts'], {'packages': 22, 'declarations': 1444, 'potentialReadFiles': 1492, 'typingSources': 0})
        self.assertEqual(summary['scope'], x.s.SCOPE)
        self.assertEqual(summary['fixtureHashes'], x.s.FIXTURE_HASHES)
        self.assertEqual({p['name'] for p in summary['replacedPackages']}, set(x.a.PINS))
        self.assertEqual(summary['nestedMetadata'], 9)
        self.assertEqual(summary['archiveNotices'], 15)
        self.assertEqual(summary['upstreamLexicalReview'], {'referenceDirectives': 214,
            'suppressionMentionsInEffectComments': 6, 'unknownImportOperandsInRecognizedSyntax': 0,
            'semanticClosure': 'NOT established'})
        self.assertEqual(summary['historicalIntentHeapMiB'], 1024)
        self.assertEqual(summary['outerResourceExperimentHeapMiB'], 2048)
        self.assertIs(summary['executionApproved'], False)
        self.assertNotIn('/private/', json.dumps(summary))

    def test_current_source_evidence_and_historical_planner_bytes_stay_bound(self):
        summary = json.loads((HERE / 'sdk-aligned-discovery.json').read_bytes())
        for group in ('sourceBindings', 'evidenceBindings'):
            for name, digest in summary[group].items():
                self.assertEqual(x.s.t.sha256((HERE / name).read_bytes()), digest, name)
        historical = json.loads((HERE / 'sdk-transitive-discovery.json').read_bytes())
        self.assertEqual(summary['sourceBindings']['sdk_compiler_candidate.py'], historical['sourceBindings']['sdk_compiler_candidate.py'])
        names = {Path(name).name for name in q.source_bindings()}
        self.assertTrue({'typings_alignment.py', 'sdk_aligned_inputs.py', 'typings-alignment.json', 'sdk-aligned-discovery.json'}.issubset(names))


if __name__ == '__main__': unittest.main()
