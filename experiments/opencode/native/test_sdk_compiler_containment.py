"""PURE mocked-owner SDK discovery tests. NEVER invoke Node/TS/sandbox/SDK."""
from contextlib import contextmanager
import copy
import json
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

import sdk_compiler_containment as k
from test_sdk_projection import synthetic

q, g, c = k.q, k.g, k.c
REAL_COMPILER_REVIEW = k.compiler_review


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.parent = Path(self.temp.name).resolve()
        self.addCleanup(patch.stopall)
        self.old_quarantine = (c._QUARANTINED, c.owner._QUARANTINED)
        c._QUARANTINED = c.owner._QUARANTINED = False
        self.addCleanup(self.restore)
        patch.object(q, 'PRIVATE_PARENT', self.parent).start()
        patch.object(g, 'PRIVATE_PARENT', self.parent).start()
        output, roles, mappings, raw = synthetic()
        for name in q.s.FIXTURE_HASHES:
            output['__compiler_roots/' + name] = (q.HERE / name).read_bytes()
        name = 'node_modules/@opencode/theme/dist/tui/color.d.ts'
        output[name] = b'export declare function rgbToOklch(r: number, g: number, b: number): {l: number};\n'
        roles[name] = 'declaration'
        output['node_modules/synthetic/unconsumed.d.ts'] = b'export type PotentialOnly = string;\n'
        roles['node_modules/synthetic/unconsumed.d.ts'] = 'declaration'
        patch.object(q, 'selected', return_value=(output, roles, mappings, raw)).start()
        self.projection = q.materialize(self.parent / 'projection-"(deny default)', {})
        notice_names = {name for name, role in roles.items() if role == 'external_authentic_source_notice'}
        potential = {name: q.t.sha256(data) for name, data in output.items() if name not in notice_names}
        packages = []
        for package in ('node_modules/synthetic', 'node_modules/@types/emscripten',
                        'node_modules/@types/node', 'node_modules/@opencode/theme'):
            packages.append({'path': package, 'files': {
                name[len(package) + 1:]: q.s.record(data, roles[name])
                for name, data in output.items() if name.startswith(package + '/')}})
        self.candidate = {'potentialReadFileHashes': potential, 'packages': packages,
            'fixtureApiBindings': {'synthetic': {'nested/x.d.ts': {}}, '@opencode/theme': {'dist/tui/color.d.ts': {}}}}
        patch.object(q, 'fixed_inputs', return_value=({}, self.candidate)).start()
        patch.object(q, 'notice_evidence', return_value=(
            {name: output[name] for name in notice_names}, mappings, raw)).start()
        patch.object(q, 'source_bindings', return_value={'synthetic-source': 'bound'}).start()
        self.compiler = {'compilerRoot': str(self.parent / 'compiler'),
            'files': {'lib/lib.esnext.full.d.ts': {'role': 'default_library', 'sha256': '1' * 64},
                      'lib/lib.dom.d.ts': {'role': 'default_library', 'sha256': '2' * 64}},
            'nodeReview': '{}'}
        patch.object(k, 'compiler_review', return_value=self.compiler).start()
        patch.object(g, 'expected_libraries', return_value=set(self.compiler['files'])).start()
        self.review = {'schema': 1, 'kind': k.RESOURCE_KIND,
            'projection': self.projection, 'compilerReview': q.n.encoded(self.compiler).decode('ascii'),
            'compilerReviewSha256': k.COMPILER_SHA, 'sources': q.source_bindings(),
            'projectionIdentity': k.projection_identity(self.projection['root']),
            'selectionSha256': q.SELECTION_SHA, 'inputPlanSha256': q.PLAN_SHA,
            'bounds': dict(k.RESOURCE_BOUNDS), 'executionApproved': False,
            'typeGraphClosure': 'NOT established', 'runtimeDependencyClosure': 'NOT established'}

    def restore(self):
        c._QUARANTINED, c.owner._QUARANTINED = self.old_quarantine

    def observe(self, mode='positive', code=None, output=None, stderr=b''):
        return k.observe(mode, (0 if mode == 'positive' else 2) if code is None else code,
            self.program(mode) if output is None else output, stderr, self.review,
            self.parent / 'execution/workspace')

    def program(self, mode='positive'):
        root = Path(self.projection['root'])
        names = [str(Path(self.compiler['compilerRoot']) / name) for name in self.compiler['files']]
        names += [str(root / name) for name in q.AMBIENT]
        names += [str(root / '__compiler_roots' / ('sdk_positive.tsx' if mode == 'positive' else 'sdk_negative.ts'))]
        names += [str(root / 'node_modules/@opencode/theme/dist/tui/color.d.ts')]
        if mode == 'positive': names += [str(root / 'node_modules/synthetic/nested/x.d.ts')]
        if mode == 'negative':
            names.insert(0, os.path.relpath(root / '__compiler_roots/sdk_negative.ts',
                self.parent / 'execution/workspace') +
                "(4,9): error TS2345: Argument of type 'string' is not assignable to parameter of type 'number'.")
        return ('\n'.join(names) + '\n').encode()

    def test_negative_diagnostic_requires_exact_cwd_relative_spelling(self):
        output = self.program('negative')
        relative = os.path.relpath(Path(self.projection['root']) / '__compiler_roots/sdk_negative.ts',
                                   self.parent / 'execution/workspace').encode()
        absolute = str(Path(self.projection['root']) / '__compiler_roots/sdk_negative.ts').encode()
        self.assertEqual(self.observe('negative')['diagnosticCodes'], [2345])
        for alias in (absolute, b'./' + relative, relative.replace(b'sdk_negative.ts', b'other.ts'),
                      relative.replace(b'__compiler_roots/', b'__compiler_roots/../__compiler_roots/')):
            with self.subTest(alias=alias), self.assertRaises(c.Blocked):
                self.observe('negative', output=output.replace(relative, alias, 1))
        with self.assertRaises(c.Blocked):
            k.observe('negative', 2, output, b'', self.review)
        with self.assertRaises(c.Blocked):
            k.observe('negative', 2, output, b'', self.review, self.parent / 'different/depth/workspace')

    def test_read_review_external_digest_required(self):
        data = q.n.encoded(self.review)
        self.assertEqual(k.read_review(data, q.t.sha256(data)), self.review)
        for digest in ('0' * 64, None, 'yes'):
            with self.subTest(digest=digest), self.assertRaises((c.Blocked, ValueError)):
                k.read_review(data, digest)

    def test_fixed_review_fields_cannot_self_authorize_or_change_bounds(self):
        for key, value in [('executionApproved', True), ('compilerReviewSha256', '0' * 64),
                ('selectionSha256', '0' * 64), ('inputPlanSha256', '0' * 64),
                ('bounds', {'wallSeconds': 9999}), ('kind', 'arbitrary'), ('schema', True),
                ('typeGraphClosure', 'proved'), ('argv', ['anything'])]:
            review = dict(self.review, **{key: value}); data = q.n.encoded(review)
            with self.subTest(key=key), self.assertRaises((c.Blocked, ValueError)):
                k.read_review(data, q.t.sha256(data))

    def test_resource_discovery_cannot_inherit_original_budget_or_candidate_kind(self):
        for key, value in [('bounds', dict(q.s.BOUNDS)),
                           ('kind', 'fixed-sdk-compiler-discovery')]:
            review = dict(self.review, **{key: value})
            data = q.n.encoded(review)
            with self.subTest(key=key), self.assertRaises(c.Blocked):
                k.read_review(data, q.t.sha256(data))
        self.assertEqual(q.s.BOUNDS['heapMiB'], 1024)
        self.assertEqual(k.RESOURCE_BOUNDS, {**q.s.BOUNDS, 'heapMiB': 2048})

    def test_nested_metadata_fixture_config_notice_role_size_drift(self):
        for name in ('node_modules/synthetic/nested/package.json', '__compiler_roots/sdk_positive.tsx',
                     'positive.json', '__notices/synthetic/LICENSE'):
            for field, value in [('sha256', '0' * 64), ('role', 'runtime'), ('bytes', 0)]:
                review = copy.deepcopy(self.review)
                review['projection']['files'][name][field] = value
                with self.subTest(name=name, field=field), self.assertRaises(c.Blocked): k.revalidate(review)

    def test_old_node26_resource_candidate_cannot_inherit_alignment_authority(self):
        for field, value in [('selectionSha256', q.HISTORICAL_SELECTION_SHA),
                             ('inputPlanSha256', q.HISTORICAL_PLAN_SHA)]:
            review = dict(self.review, **{field: value})
            data = q.n.encoded(review)
            with self.subTest(field=field), self.assertRaises(c.Blocked):
                k.read_review(data, q.t.sha256(data))

    def test_sources_raw_evidence_and_notice_map_drift(self):
        for field, value in [('sources', {}), ('projectionIdentity', {})]:
            with self.subTest(field=field), self.assertRaises(c.Blocked): k.revalidate(dict(self.review, **{field: value}))
        for field in ('privateEvidence', 'sourceNoticeMappings'):
            review = copy.deepcopy(self.review); review['projection'][field] = {'invented': {}}
            with self.subTest(field=field), self.assertRaises(c.Blocked): k.revalidate(review)

    def test_runtime_alias_or_compiler_hash_failure_propagates(self):
        with patch.object(k, 'compiler_review', side_effect=c.Blocked('alias mismatch')):
            with self.assertRaises(c.Blocked): k.revalidate(self.review)

    def test_historical_compiler_sources_require_same_bytes_not_old_inodes(self):
        review = {'nodeReview': '{}', 'nodeReviewSha256': '1' * 64,
            'compilerRoot': '/synthetic', 'files': {}, 'sources': {
                'source': {'sha256': '2' * 64, 'identity': ['old-inode']}},
            'fixtures': {'positive': q.n.sha(g.fixture('positive')),
                         'negative': q.n.sha(g.fixture('negative'))}}
        data = q.n.encoded(review)
        with patch.object(k, 'COMPILER_SHA', q.t.sha256(data)), \
                patch.object(q.n, 'read_review') as node, patch.object(g, 'validate_compiler') as compiler, \
                patch.object(g, 'sources', return_value={'source': {'sha256': '2' * 64, 'identity': ['new-inode']}}):
            self.assertEqual(REAL_COMPILER_REVIEW(data), review)
            node.assert_called_once(); compiler.assert_called_once()
            with patch.object(g, 'sources', return_value={'source': {'sha256': '3' * 64}}):
                with self.assertRaises(c.Blocked): REAL_COMPILER_REVIEW(data)
            with patch.object(q.n, 'read_review', side_effect=c.Blocked('alias drift')):
                with self.assertRaises(c.Blocked): REAL_COMPILER_REVIEW(data)

    def test_historical_compiler_digest_cannot_be_replaced(self):
        with self.assertRaises(c.Blocked): REAL_COMPILER_REVIEW(b'{}')

    def test_valid_potential_superset_need_not_all_be_consumed(self):
        result = self.observe()
        self.assertEqual(result['diagnosticCodes'], [])
        self.assertNotIn('sdk/node_modules/synthetic/unconsumed.d.ts', [x['relative'] for x in result['programFiles']])
        self.assertTrue(result['potentialReadsNeedNotAllBeConsumed'])

    def test_negative_exact_single_intended_2345(self):
        result = self.observe('negative')
        self.assertEqual(result['diagnosticCodes'], [2345])

    def test_version_exact(self):
        self.assertEqual(k.observe('version', 0, b'Version 6.0.3\n', b'', self.review), {'version': '6.0.3'})
        for code, out, err in [(1, b'Version 6.0.3\n', b''), (0, b'Version 6.0.4\n', b''),
                               (0, b'Version 6.0.3\n', b'warning'), (False, b'Version 6.0.3\n', b'')]:
            with self.subTest(code=code, out=out), self.assertRaises(c.Blocked):
                k.observe('version', code, out, err, self.review)

    def test_positive_nonzero_or_negative_unexpected_success(self):
        for mode, code in [('positive', 1), ('positive', 2), ('negative', 0), ('negative', 1), ('positive', False)]:
            with self.subTest(mode=mode, code=code), self.assertRaises(c.Blocked): self.observe(mode, code)

    def test_unknown_diagnostics_any_stream_rejected(self):
        for data in [b'error TS2307: missing dependency\n' + self.program(),
                     self.program() + b'warning\n', self.program() + b'\n']:
            with self.subTest(data=data[:20]), self.assertRaises(c.Blocked): self.observe(output=data)
        with self.assertRaises(c.Blocked): self.observe(stderr=b'error TS2345: wrong\n')

    def test_negative_wrong_location_code_message_or_duplicate_rejected(self):
        original = self.program('negative')
        for output in [original.replace(b'(4,9)', b'(3,9)'), original.replace(b'TS2345', b'TS2322'),
                       original.replace(b"'number'", b"'boolean'"), original + original.splitlines()[0] + b'\n']:
            with self.subTest(output=output[:30]), self.assertRaises(c.Blocked): self.observe('negative', output=output)

    def test_partial_cr_nul_unknown_encoding_and_duplicate_output_rejected(self):
        output = self.program()
        for value in [output[:-1], output + b'\r\n', output + b'\0\n', output + b'\xff\n',
                      output + output.splitlines()[0] + b'\n']:
            with self.subTest(value=value[-20:]), self.assertRaises((c.Blocked, UnicodeDecodeError)): self.observe(output=value)

    def test_unapproved_path_metadata_other_fixture_and_path_alias_rejected(self):
        root = self.projection['root']
        for path in ['/private/unapproved.d.ts', root + '/positive.json',
                     root + '/__compiler_roots/sdk_negative.ts', root + '/node_modules/synthetic/../synthetic/nested/x.d.ts']:
            with self.subTest(path=path), self.assertRaises(c.Blocked): self.observe(output=self.program() + path.encode() + b'\n')

    def test_each_explicit_root_default_library_and_surface_required(self):
        lines = self.program().splitlines()
        for i in range(len(lines)):
            with self.subTest(line=i), self.assertRaises(c.Blocked):
                self.observe(output=b'\n'.join(lines[:i] + lines[i + 1:]) + b'\n')

    def test_command_is_fixed_no_sdk_runtime_and_quotes_are_data(self):
        root = self.parent / 'compiler-"(allow default)'
        command = k.command(root, self.review, 'positive')
        self.assertEqual(command[-2:], ['--project', self.projection['root'] + '/positive.json'])
        self.assertIn('--max-old-space-size=2048', command)
        self.assertEqual(command[0], str(c.SANDBOX))
        self.assertNotIn('node_modules', command[-3])
        with self.assertRaises(c.Blocked): k.command(root, self.review, '--eval')

    def test_policy_literal_sdk_only_and_injection_safe(self):
        root = self.parent / 'compiler-"(allow default)'
        with patch.object(q.n, 'policy', return_value=c.Policy(())):
            text = k.policy(root, self.review)
        self.assertIn('(deny default)', text)
        self.assertNotIn('(subpath ', text)
        self.assertNotIn('(allow network', text)
        self.assertNotIn('(allow process-exec', text)
        self.assertIn('\\"(deny default)', text)
        for name in self.projection['files']:
            self.assertIn(c.quoted(str(Path(self.projection['root']) / name)), text)

    def run_mock(self, *, owner=None, observer=None, sink_factory=None):
        @contextmanager
        def artifacts():
            root = self.parent / 'execution'
            root.mkdir(mode=0o700)
            yield root
        def bounded(argv, cwd, environment, **kwargs):
            self.assertLessEqual(kwargs['timeout'], 110)
            self.assertLessEqual(kwargs['limit'], g.OUTPUT_CAP)
            self.assertEqual(environment['NODE_DISABLE_COMPILE_CACHE'], '1')
            self.assertNotIn('NODE_OPTIONS', environment)
            mode = argv[-1]
            if owner is not None: return owner(mode, cwd)
            return (0, b'Version 6.0.3\n', b'', {}) if mode == 'version' else (
                0 if mode == 'positive' else 2, self.program(mode), b'', {})
        with patch.object(q.n, 'require_platform'), patch.object(g, 'artifacts', artifacts), \
                patch.object(k, 'policy', return_value='(deny default)\n'), \
                patch.object(k, 'command', side_effect=lambda root, review, mode: ['MOCK-NO-EXEC', mode]), \
                patch.object(c.owner, 'bounded', side_effect=bounded) as called:
            with patch.object(k, 'observe', wraps=observer or k.observe), \
                    patch.object(g, 'PrivateEvidence', side_effect=sink_factory or g.PrivateEvidence):
                data = q.n.encoded(self.review)
                result = k.run_guard(data, q.t.sha256(data))
        return result, called

    def last_evidence(self):
        roots = sorted(self.parent.glob('threadmark-compiler-evidence-*'))
        self.assertEqual(len(roots), 1)
        return roots[0]

    def test_mocked_end_to_end_success_has_provisional_private_record_and_return_receipt(self):
        result, called = self.run_mock()
        self.assertEqual(called.call_count, 3)
        self.assertEqual(result['result'], 'sdk-resource-discovery-pass')
        self.assertEqual(result['experimentBounds']['heapMiB'], 2048)
        self.assertIn('FAILED', result['original1024MiBGate'])
        path = self.last_evidence()
        record = (path / 'result.json').read_bytes()
        self.assertEqual(json.loads(record)['result'], 'sdk-discovery-checks-passed-unconfirmed')
        self.assertEqual(result['successReceipt']['recordSha256'], q.t.sha256(record))
        for mode in k.MODES:
            self.assertTrue((path / (mode + '-after.json')).exists())
            self.assertTrue((path / (mode + '-stdout.bin')).exists())
        self.assertTrue(Path(self.projection['root']).exists())

    def test_actual_diagnostic_bytes_retained_before_unknown_semantics_rejected(self):
        private = b'private/path/source.ts(1,1): error TS9999: PRIVATE-SOURCE\n'
        def owner(mode, cwd): return 2, private, b'', {}
        with self.assertRaises(c.Blocked) as caught: self.run_mock(owner=owner)
        self.assertEqual((self.last_evidence() / 'version-stdout.bin').read_bytes(), private)
        public = json.dumps(caught.exception.evidence)
        self.assertNotIn('PRIVATE-SOURCE', public)
        self.assertNotIn('private/path', public)
        self.assertNotIn('successReceipt', public)

    def test_postvalidation_runs_on_timeout_cancel_and_owner_failure_quarantines(self):
        for error in [c.Blocked('worker timeout'), c.Canceled(), c.owner.CleanupUnverified('unknown')]:
            with self.subTest(error=type(error).__name__):
                # Each attempt needs a fresh self-owned test workspace/evidence.
                case = self.parent / ('case-' + str(time.monotonic_ns())); case.mkdir()
                with patch.object(g, 'PRIVATE_PARENT', case):
                    def owner(mode, cwd, error=error): raise error
                    with self.assertRaises(c.Blocked) as caught: self.run_mock(owner=owner)
                self.assertTrue(c._QUARANTINED)
                attempt = caught.exception.evidence['attempts']['version']
                self.assertEqual(attempt['afterValidation'], 'passed')
                self.assertEqual(attempt['capture'], 'unavailable-owner-raised')
                c._QUARANTINED = c.owner._QUARANTINED = False
                # Test-owned ephemeral execution directory, no application data.
                import shutil
                shutil.rmtree(self.parent / 'execution')

    def test_late_projection_mutation_quarantines_and_retains_capture(self):
        def owner(mode, cwd):
            (Path(self.projection['root']) / 'extra').write_bytes(b'late')
            return 0, b'Version 6.0.3\n', b'', {}
        with self.assertRaises(c.Blocked) as caught: self.run_mock(owner=owner)
        self.assertTrue(c._QUARANTINED)
        self.assertEqual(caught.exception.evidence['attempts']['version']['afterValidation'], 'failed-or-interrupted')
        self.assertTrue((self.last_evidence() / 'version-stdout.bin').exists())

    def test_output_cap_retention_failure_quarantines(self):
        def owner(mode, cwd): return 0, b'x' * (g.OUTPUT_CAP + 1), b'', {}
        with self.assertRaises(c.Blocked) as caught: self.run_mock(owner=owner)
        self.assertTrue(c._QUARANTINED)
        self.assertEqual(caught.exception.evidence['attempts']['version']['capture'], 'incomplete-retained')
        self.assertEqual((self.last_evidence() / 'version-stdout.bin').stat().st_size, g.OUTPUT_CAP)

    def test_final_evidence_fsync_failure_never_false_pass(self):
        real = g.PrivateEvidence
        def factory(digest):
            sink = real(digest); write = sink.write
            def failing(name, data):
                if name == 'result.json': raise OSError('PRIVATE FSYNC DETAILS')
                write(name, data)
            sink.write = failing
            return sink
        with self.assertRaises(c.Blocked) as caught: self.run_mock(sink_factory=factory)
        self.assertEqual(caught.exception.evidence['result'], 'blocked')
        self.assertNotIn('successReceipt', caught.exception.evidence)
        self.assertNotIn('PRIVATE FSYNC', json.dumps(caught.exception.evidence))
        self.assertTrue(c._QUARANTINED)

    def test_final_close_failure_record_is_only_provisional(self):
        real = g.PrivateEvidence
        def factory(digest):
            sink = real(digest); close = sink.close
            def failing(): close(); raise OSError('private close')
            sink.close = failing
            return sink
        with self.assertRaises(c.Blocked) as caught: self.run_mock(sink_factory=factory)
        self.assertNotIn('successReceipt', caught.exception.evidence)
        record = json.loads((self.last_evidence() / 'result.json').read_bytes())
        self.assertEqual(record['result'], 'sdk-discovery-checks-passed-unconfirmed')

    def test_preflight_failure_never_calls_owner(self):
        with patch.object(q.n, 'require_platform'), patch.object(c.owner, 'bounded') as owner:
            with self.assertRaises(c.Blocked): k.run_guard(b'{}', '0' * 64)
            owner.assert_not_called()


if __name__ == '__main__': unittest.main()
