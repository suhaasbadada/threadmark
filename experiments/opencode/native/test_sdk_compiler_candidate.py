"""Synthetic archives/pure preparation only. No compiler, SDK or network."""
import base64
import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import sdk_compiler_candidate as c
from test_project_types import archive

HERE = Path(__file__).parent


def package(name='synthetic', location=None, extra=None, exports=None):
    location = location or 'node_modules/' + name
    metadata = c.encoded({'name': name, 'version': '1.0.0', 'license': 'MIT',
                          'exports': exports or {'.': {'types': './index.d.ts'}},
                          'scripts': {'install': 'NEVER EXECUTE'}})
    files = {'package.json': metadata, 'index.d.ts': b'export type Synthetic = string;\n',
             'LICENSE': b'Synthetic test notice\n', **(extra or {})}
    data = archive(files)
    integrity = 'sha512-' + base64.b64encode(hashlib.sha512(data).digest()).decode()
    selection = {'path': location, 'name': name, 'version': '1.0.0', 'integrity': integrity,
                 'resolved': 'https://registry.npmjs.org/synthetic/-/synthetic-1.0.0.tgz',
                 'archiveSha256': c.t.sha256(data), 'archiveRoot': 'package',
                 'metadataSha256': c.t.sha256(metadata), 'files': {}}
    for n, b in files.items():
        role = ('complete_metadata' if n == 'package.json' or n.endswith('/package.json')
                else 'authentic_notice' if c.NOTICE.fullmatch(n.rsplit('/', 1)[-1])
                else 'declaration' if n.endswith(c.TYPE_SUFFIXES) else 'typing_source')
        if role != 'typing_source':
            selection['files'][n] = c.record(b, role)
    entry = {k: selection[k] for k in ('version', 'integrity', 'resolved')}
    return {'packages': {location: entry}}, selection, data, files


def preparation():
    names = ['@opencode/client', '@opencode/plugin', '@opencode/theme', '@opentui/core',
             '@opentui/solid', 'solid-js', 'web-tree-sitter', '@types/node',
             '@types/emscripten', '@types/json-schema']
    lock, packages, archives = {'packages': {}}, [], {}
    for name in names:
        part, selected, data, _ = package(name)
        lock['packages'].update(part['packages'])
        packages.append(selected)
        archives[selected['integrity']] = data
    lock_bytes = c.encoded(lock)
    fixtures = {n: (HERE / n).read_bytes() for n in c.FIXTURE_HASHES}
    plan = {'schema': 1, 'kind': 'sdk-type-input-plan', 'scope': list(c.SCOPE),
            'lockSha256': c.t.sha256(lock_bytes), 'packages': packages,
            'fixtureHashes': dict(c.FIXTURE_HASHES),
            'knownMissing': [{'id': 'synthetic-unresolved', 'requirement': 'synthetic block'}]}
    return lock_bytes, plan, archives, fixtures


class FactsTests(unittest.TestCase):
    def test_actual_syntax_not_documentation_or_string_values(self):
        result = c.facts(b'''/** import("fictional") */
type Text = "import('fictional')";
import type { X } from "real";
export { Y } from 'real/subpath';
type T = import("real/type").T;
import Equals = require("real/equal");
import "real/ambient";
interface Method { require(id: string): unknown; }
''')
        self.assertEqual([x['specifier'] for x in result['imports']],
                         ['real', 'real/subpath', 'real/type', 'real/equal', 'real/ambient'])
        self.assertEqual(result['unknownReferences'], [])

    def test_dynamic_and_escaped_operands_remain_unknown(self):
        result = c.facts(b'type T = import(computed); type U = import("escaped\\x2fname");')
        self.assertEqual(len(result['unknownReferences']), 2)
        self.assertEqual(result['imports'], [])

    def test_reference_and_suppression_review_not_erased(self):
        result = c.facts(b'/// <reference types="node" />\n// @ts-expect-error\nexport {};')
        self.assertEqual(len(result['referenceDirectives']), 1)
        self.assertEqual(len(result['suppressionDirectives']), 1)

    def test_ambient_module_is_not_an_external_import(self):
        self.assertEqual(c.facts(b'declare module "node:stream" {}')['imports'], [])

    def test_invalid_encoding_and_nul(self):
        for b in (b'\xff', b'export {};\0'):
            with self.subTest(data=b), self.assertRaises(ValueError): c.facts(b)


class PackageTests(unittest.TestCase):
    def test_whole_metadata_notices_and_nested_metadata_preserved(self):
        lock, selection, data, files = package(extra={'nested/package.json': b'{"type":"module"}',
                                                     'nested/types.d.ts': b'export {};\n'})
        selected, evidence = c.inspect_package(lock, selection, data)
        self.assertEqual(selected['node_modules/synthetic/package.json'], files['package.json'])
        self.assertEqual(base64.b64decode(evidence['metadataBytesBase64']['nested/package.json']),
                         files['nested/package.json'])
        self.assertEqual(base64.b64decode(evidence['noticeBytesBase64']['LICENSE']), files['LICENSE'])
        self.assertEqual(evidence['typeGraphClosure'], 'NOT established')

    def test_missing_complete_metadata_notice_or_declaration_rejected(self):
        for n in ('package.json', 'LICENSE', 'index.d.ts', 'nested/package.json'):
            lock, selection, data, _ = package(extra={'nested/package.json': b'{}'})
            del selection['files'][n]
            with self.subTest(path=n), self.assertRaises(ValueError):
                c.inspect_package(lock, selection, data)

    def test_wrong_dependency_identity_and_hash(self):
        for field, value in [('version', '9.0.0'), ('name', 'other'), ('archiveSha256', '0' * 64),
                             ('metadataSha256', '0' * 64), ('resolved', 'https://invalid/')]:
            lock, selection, data, _ = package()
            selection[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                c.inspect_package(lock, selection, data)

    def test_wrong_file_role_or_hash(self):
        for field, value in [('role', 'compiler_js'), ('sha256', '0' * 64), ('bytes', 0)]:
            lock, selection, data, _ = package()
            selection['files']['index.d.ts'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                c.inspect_package(lock, selection, data)

    def test_nested_version_identity_preserved_no_hoisting(self):
        location = 'node_modules/parent/node_modules/synthetic'
        lock, selection, data, _ = package(location=location)
        selected, evidence = c.inspect_package(lock, selection, data)
        self.assertEqual(evidence['path'], location)
        self.assertIn(location + '/index.d.ts', selected)
        self.assertNotIn('node_modules/synthetic/index.d.ts', selected)

    def test_implementation_source_excluded_until_actual_export_target(self):
        lock, selection, data, files = package(extra={'source.ts': b'export type X = string;'})
        selected, evidence = c.inspect_package(lock, selection, data)
        self.assertIn('source.ts', evidence['excludedTypeSources'])
        selection['files']['source.ts'] = c.record(files['source.ts'], 'typing_source')
        with self.assertRaisesRegex(ValueError, 'actual export'):
            c.inspect_package(lock, selection, data)

    def test_actual_exported_ts_source_has_typing_role_not_execution(self):
        lock, selection, data, files = package(extra={'source.ts': b'export type X = string;'},
                                              exports={'.': {'types': './source.ts'}})
        selection['files']['source.ts'] = c.record(files['source.ts'], 'typing_source')
        selected, _ = c.inspect_package(lock, selection, data)
        self.assertEqual(selected['node_modules/synthetic/source.ts'], files['source.ts'])

    def test_missing_actual_exported_typing_source_retains_blocking_fact(self):
        lock, selection, data, _ = package(extra={'source.ts': b'export type X = string;'},
                                           exports={'.': {'types': './source.ts'}})
        _, evidence = c.inspect_package(lock, selection, data)
        self.assertEqual(evidence['unselectedExportTypeSourceTargets'], ['./source.ts'])

    def test_js_selection_rejected_even_if_exported(self):
        lock, selection, data, files = package(extra={'runtime.js': b'NEVER EXECUTE'},
                                              exports={'.': './runtime.js'})
        selection['files']['runtime.js'] = c.record(files['runtime.js'], 'typing_source')
        with self.assertRaisesRegex(ValueError, 'runtime selection'):
            c.inspect_package(lock, selection, data)

    def test_typescript_path_aliases_and_non_ascii_reject(self):
        for name in ('a\\b', 'a//b', '/a', 'a/./b', 'a/../b', 'a\u00e9', 'a:b', 'a"b'):
            with self.subTest(path=name), self.assertRaises(ValueError): c.path(name)


class PreparationTests(unittest.TestCase):
    def setUp(self): self.lock, self.plan, self.archives, self.fixtures = preparation()

    def prepare(self): return c.prepare(self.lock, self.plan, self.archives, self.fixtures)

    def test_fixed_intent_has_no_descriptor_approval_or_resolution_claim(self):
        result = self.prepare()
        self.assertEqual(result['kind'], 'inert-fixed-sdk-discovery-candidate')
        self.assertEqual(result['knownMissing'], self.plan['knownMissing'])
        self.assertIsNone(result['compilerDescriptor'])
        for field in ('executionApproved', 'selectionApproved', 'materialized'):
            self.assertIs(result[field], False)
        for field in ('argv', 'argvCandidate', 'policy', 'run_guard'):
            self.assertNotIn(field, result)
        self.assertEqual(result['typeGraphClosure'], 'NOT established')
        self.assertEqual(result['negativeExpectation']['status'], 'UNOBSERVED')

    def test_explicit_emscripten_node_and_empty_automatic_ambient(self):
        for config in self.prepare()['configIntent'].values():
            self.assertEqual(config['compilerOptions'], c.OPTIONS)
            self.assertEqual(config['compilerOptions']['types'], [])
            self.assertEqual(config['compilerOptions']['typeRoots'], ['__state/typeRoots'])
            self.assertIn('node_modules/@types/emscripten/index.d.ts', config['files'])
            self.assertIn('node_modules/@types/node/index.d.ts', config['files'])
            self.assertNotIn('paths', config['compilerOptions'])

    def test_full_product_and_ambient_scope_cannot_be_reduced(self):
        self.plan['packages'] = self.plan['packages'][1:]
        with self.assertRaisesRegex(ValueError, 'full SDK scope'): self.prepare()

    def test_missing_archive_and_wrong_lock_fail(self):
        original = self.lock
        self.lock += b'\n'
        with self.assertRaises(ValueError): self.prepare()
        self.lock = original
        self.archives.clear()
        with self.assertRaises(KeyError): self.prepare()

    def test_duplicate_package_selection_rejected(self):
        self.plan['packages'].append(copy.deepcopy(self.plan['packages'][0]))
        with self.assertRaisesRegex(ValueError, 'duplicate'): self.prepare()

    def test_manifest_cannot_supply_its_own_approval(self):
        for field in ('approved', 'reviewedSha256', 'executionApproved'):
            self.plan[field] = True
            with self.subTest(field=field), self.assertRaises(ValueError): self.prepare()
            del self.plan[field]

    def test_changed_negative_plan_or_fixture_cannot_self_approve(self):
        self.fixtures['sdk_negative.ts'] = b'export {};\n'
        self.plan['fixtureHashes']['sdk_negative.ts'] = c.t.sha256(self.fixtures['sdk_negative.ts'])
        with self.assertRaises(ValueError): self.prepare()

    def test_config_and_budget_constants(self):
        result = self.prepare()
        self.assertEqual(result['boundsIntent'], {'wallSeconds': 120, 'outputBytes': 16777216,
                                                'heapMiB': 1024, 'cleanupSeconds': 2})
        self.assertEqual(c.OPTIONS['jsxImportSource'], '@opentui/solid')
        self.assertEqual(c.OPTIONS['jsx'], 'react-jsx')
        self.assertEqual(result['policyIntent']['recursiveReadRoots'], [])
        self.assertEqual(result['policyIntent']['targetChildSpawn'], 'deny')

    def test_counterfeit_compiler_inventory_cannot_self_approve(self):
        with self.assertRaises(ValueError):
            c.compiler_binding(b'synthetic compiler bytes', {'archiveSha256': c.t.sha256(b'synthetic compiler bytes')})


class RetentionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='threadmark-sdk-synthetic-')
        self.addCleanup(self.temp.cleanup)
        self.destination = Path(self.temp.name) / 'fresh'
        lock, self.plan, archives, fixtures = preparation()
        self.candidate = c.prepare(lock, self.plan, archives, fixtures)

    def retain(self): return c.retain(self.destination, self.plan, self.candidate)

    def test_private_exclusive_inert_artifacts_whole_hash_ledger(self):
        digest = self.retain()
        self.assertEqual(digest, c.t.sha256((self.destination / 'candidate.json').read_bytes()))
        self.assertEqual(self.destination.stat().st_mode & 0o777, 0o700)
        self.assertEqual(set(p.name for p in self.destination.iterdir()),
                         {'input-plan.json', 'candidate.json', 'ledger.json'})
        for p in self.destination.iterdir():
            self.assertEqual(p.stat().st_mode & 0o777, 0o400)
            self.assertEqual(p.stat().st_nlink, 1)
        with self.assertRaises(FileExistsError): self.retain()

    def test_cancelled_preparation_keeps_incomplete_marker(self):
        original = c.t.write_file
        def cancel(root, name, data):
            if name == 'candidate.json': raise KeyboardInterrupt()
            return original(root, name, data)
        with patch.object(c.t, 'write_file', cancel), self.assertRaises(KeyboardInterrupt): self.retain()
        self.assertTrue((self.destination / 'INCOMPLETE').is_file())

    def test_late_validation_failure_keeps_incomplete_marker(self):
        with patch.object(c, 'validate_retained', side_effect=ValueError('synthetic late failure')):
            with self.assertRaises(ValueError): self.retain()
        self.assertTrue((self.destination / 'INCOMPLETE').is_file())
        self.assertTrue((self.destination / 'ledger.json').is_file())

    def test_partial_ledger_and_symlink_or_hardlink_rejected(self):
        original = c.validate_retained
        for mutation in ('extra', 'missing', 'symlink', 'hardlink'):
            self.destination = Path(self.temp.name) / mutation
            def mutate(root, content):
                if mutation == 'extra': c.t.write_file(root, 'extra', b'no')
                else:
                    os.unlink('ledger.json', dir_fd=root)
                    if mutation == 'symlink': os.symlink('candidate.json', 'ledger.json', dir_fd=root)
                    if mutation == 'hardlink': os.link('candidate.json', 'ledger.json', src_dir_fd=root, dst_dir_fd=root)
                original(root, content)
            with self.subTest(mutation=mutation), patch.object(c, 'validate_retained', mutate):
                with self.assertRaises((ValueError, OSError)): self.retain()
            self.assertTrue((self.destination / 'INCOMPLETE').is_file())

    def test_partial_or_open_candidate_rejects_before_writing(self):
        for field, value in [('inputPlanSha256', '0' * 64), ('materialized', True), ('executionApproved', True)]:
            candidate = copy.deepcopy(self.candidate)
            candidate[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                c.retain(self.destination, self.plan, candidate)
        self.assertFalse(self.destination.exists())


class PublicEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.summary = json.loads((HERE / 'sdk-transitive-discovery.json').read_bytes())
        self.old = json.loads((HERE / 'sdk-selection-discovery.json').read_bytes())

    def test_all_twenty_two_locked_paths_and_exact_delta_counts(self):
        lock = json.loads((HERE / 'package-lock.json').read_bytes())['packages']
        extra = self.summary['additionalPackages']
        paths = [p['path'] for p in extra] + [p['packagePath'] for p in self.old['packages']]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertEqual(len(paths), 22)
        for p in extra:
            self.assertEqual(p['version'], lock[p['path']]['version'])
            for key in ('archiveSha256', 'metadataSha256', 'selectionInventorySha256'):
                self.assertRegex(p[key], r'^[0-9a-f]{64}$')
        self.assertEqual(sum(p['declarations'] for p in extra) + 338, 1464)
        self.assertEqual(sum(p['excludedTypeSources'] for p in extra) + 11, 737)

    def test_recorded_sources_receipts_and_notice_bytes_stay_bound(self):
        for group in ('sourceBindings', 'evidenceBindings'):
            for name, digest in self.summary[group].items():
                self.assertEqual(c.t.sha256((HERE / name).read_bytes()), digest, name)
        self.assertEqual({n: c.t.sha256((HERE / n).read_bytes()) for n in c.FIXTURE_HASHES},
                         c.FIXTURE_HASHES)

    def test_no_private_paths_or_execution_claims(self):
        self.assertNotIn('/private/', json.dumps(self.summary))
        self.assertNotIn('Base64', json.dumps(self.summary))
        for field in ('executionApproved', 'selectionApproved', 'materialized'):
            self.assertIs(self.summary[field], False)
        self.assertIsNone(self.summary['compilerDescriptor'])
        self.assertTrue(self.summary['knownMissing'])
        self.assertEqual(self.summary['configIntent']['negativeExpectation']['status'], 'UNOBSERVED')

    def test_new_receipt_does_not_broaden_old_fixed_three(self):
        new = json.loads((HERE / 'sdk-transitive-notice-provenance.json').read_bytes())
        old = json.loads((HERE / 'sdk-notice-provenance.json').read_bytes())
        self.assertEqual(len(new['packages']), 4)
        self.assertEqual(len(old['packages']), 3)
        self.assertFalse({p['name'] for p in new['packages']} & {p['name'] for p in old['packages']})


if __name__ == '__main__': unittest.main()
