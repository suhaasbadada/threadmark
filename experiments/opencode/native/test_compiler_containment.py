"""PURE invented archives/Node inventories and mocked orchestration ONLY.

No compiler/Node/probe/sandbox/SDK execution, downloads or authentic artifacts.
Hash-pin patches below are TEST ONLY and are never production approval paths.
"""
import base64
from contextlib import contextmanager
import copy
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import tarfile
import time
import unittest
from unittest import mock

import compiler_containment as g
import test_node_containment as node_tests


def archive(files):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode='w:') as target:
        for name, data in files.items():
            member = tarfile.TarInfo('package/' + name)
            member.size = len(data)
            target.addfile(member, io.BytesIO(data))
    return gzip.compress(output.getvalue(), mtime=0)


class CompilerCandidate(unittest.TestCase):
    fixture = node_tests.SyntheticRuntime.fixture

    def setUp(self):
        node_tests.SyntheticRuntime.setUp(self)
        self.enterContext(mock.patch.object(g, 'PRIVATE_PARENT', self.root))
        self.files = {name: ('inert ' + role + '\n').encode() for name, role in g.ROLES.items()}
        self.files['package.json'] = g.n.encoded({
            'name': 'typescript', 'version': '6.0.3', 'license': 'Apache-2.0',
            'bin': {'tsc': './bin/tsc'}, 'scripts': {'not-executed': 'false'}})
        self.files.update({'lib/lib.synthetic' + str(i) + '.d.ts': b'// invented declaration\n'
                           for i in range(106)})
        self.files['lib/lib.esnext.full.d.ts'] = b'/// <reference lib="synthetic0" />\n'
        self.files['bin/tsc'] = b'NEVER SELECTED OR EXECUTED\n'
        self.bytes = archive(self.files)
        self.pin(self.bytes)
        self.node_bytes = g.n.encoded(self.review)
        self.node_digest = g.n.sha(self.node_bytes)
        self.compiler = self.root / 'compiler'
        data = g.prepare_review(self.bytes, self.node_bytes, self.node_digest, self.compiler)
        self.candidate = g.decoded(data)
        self.data = data
        self.enterContext(mock.patch.object(g.n, 'require_platform'))

    def pin(self, data):
        self.enterContext(mock.patch.object(g, 'ARCHIVE_SHA', g.n.sha(data)))
        integrity = 'sha512-' + base64.b64encode(hashlib.sha512(data).digest()).decode()
        self.enterContext(mock.patch.object(g.p, 'COMPILER_INTEGRITY', integrity))

    def approve(self, candidate=None):
        data = g.n.encoded(candidate or self.candidate)
        return g.read_review(data, g.n.sha(data))

    def test_inert_complete_selection_and_actual_notice_roles(self):
        self.assertEqual(len(self.approve()['files']), 112)
        self.assertFalse((self.compiler / 'bin').exists())
        self.assertEqual((self.compiler / 'package.json').read_bytes(), self.files['package.json'])
        for name, item in self.candidate['files'].items():
            self.assertEqual(item['sha256'], g.n.sha(self.files[name]))
            self.assertEqual((self.compiler / name).stat().st_mode & 0o777, 0o400)
        self.assertEqual(self.candidate['files']['LICENSE.txt']['role'], 'license')
        self.assertEqual(self.candidate['files']['ThirdPartyNoticeText.txt']['role'], 'third_party_notice')
        self.assertFalse((self.compiler / 'INCOMPLETE').exists())
        self.assertEqual(self.candidate['nodeReview'].encode('ascii'), self.node_bytes)

    def test_archive_hash_rejects_before_inspection_and_creation(self):
        with mock.patch.object(g.t, 'inspect', side_effect=AssertionError('must not inspect')):
            with self.assertRaises(ValueError):
                g.materialize(self.root / 'wrong', self.bytes + b'changed')
        self.assertFalse((self.root / 'wrong').exists())

    def test_sha512_independently_required_before_inspection(self):
        with mock.patch.object(g.p, 'COMPILER_INTEGRITY', 'sha512-wrong'), mock.patch.object(
                g.t, 'inspect', side_effect=AssertionError('must not inspect')):
            with self.assertRaises(ValueError):
                g.selected(self.bytes)

    def test_metadata_and_notice_missing_or_empty_close_precreation(self):
        for field in ('name', 'version', 'license', 'LICENSE.txt', 'ThirdPartyNoticeText.txt'):
            with self.subTest(field=field):
                changed = copy.deepcopy(self.files)
                if field.endswith('.txt'):
                    changed[field] = b''
                else:
                    metadata = json.loads(changed['package.json'])
                    metadata[field] = 'wrong'
                    changed['package.json'] = g.n.encoded(metadata)
                data = archive(changed)
                self.pin(data)
                with self.assertRaises(ValueError):
                    g.materialize(self.root / 'invalid', data)
                self.assertFalse((self.root / 'invalid').exists())

    def test_helper_missing_and_library_count_drift_reject(self):
        for name in ('lib/_tsc.js', 'lib/lib.synthetic0.d.ts', 'LICENSE.txt'):
            changed = dict(self.files)
            del changed[name]
            data = archive(changed)
            self.pin(data)
            with self.assertRaises((ValueError, KeyError)):
                g.selected(data)

    def test_no_overwrite_and_write_failure_stays_incomplete(self):
        with self.assertRaises(FileExistsError):
            g.materialize(self.compiler, self.bytes)
        original = g.t.write_file

        def fail(root, name, data):
            if name != 'INCOMPLETE':
                raise OSError('synthetic disk failure')
            return original(root, name, data)

        with mock.patch.object(g.t, 'write_file', side_effect=fail):
            with self.assertRaises(OSError):
                g.materialize(self.root / 'incomplete', self.bytes)
        self.assertTrue((self.root / 'incomplete' / 'INCOMPLETE').is_file())
        self.assertFalse((self.root / 'incomplete' / 'ledger.json').exists())

    def test_late_preparation_validation_failure_keeps_incomplete_and_launch_rejects(self):
        destination = self.root / 'late-failure'
        with mock.patch.object(g, 'validate_compiler', side_effect=OSError('synthetic validation I/O')):
            with self.assertRaises(OSError):
                g.materialize(destination, self.bytes)
        self.assertTrue((destination / 'INCOMPLETE').is_file())
        self.assertTrue((destination / 'ledger.json').is_file())
        _, records = g.selected(self.bytes)
        with self.assertRaises(ValueError):
            g.validate_compiler(str(destination), records)

    def test_digest_unknown_keys_duplicates_and_self_approval_reject(self):
        for digest in ('0' * 64, None, '', 'self'):
            with self.assertRaises(ValueError):
                g.read_review(self.data, digest)
        candidate = {**self.candidate, 'executionApproved': True}
        with self.assertRaises(ValueError):
            self.approve(candidate)
        data = self.data.replace(b'"schema": 1', b'"schema": 1, "schema": 1')
        with self.assertRaises(ValueError):
            g.read_review(data, g.n.sha(data))

    def test_role_size_and_notices_inventory_cannot_be_self_approved(self):
        for field, value in (('role', 'types'), ('size', 0), ('sha256', '0' * 64)):
            candidate = copy.deepcopy(self.candidate)
            candidate['files']['lib/_tsc.js'][field] = value
            with self.assertRaises(ValueError):
                self.approve(candidate)

    def test_extra_missing_symlink_hardlink_and_executable_reject(self):
        script = self.compiler / 'lib/tsc.js'
        original = script.read_bytes()
        for kind in ('extra', 'missing', 'symlink', 'hardlink', 'executable'):
            with self.subTest(kind=kind):
                extra = self.compiler / 'extra'
                if kind == 'extra':
                    extra.write_bytes(b'extra')
                elif kind == 'executable':
                    script.chmod(0o500)
                elif kind == 'hardlink':
                    os.link(script, extra)
                else:
                    script.unlink()
                    if kind == 'symlink':
                        script.symlink_to('_tsc.js')
                with self.assertRaises(ValueError):
                    self.approve()
                extra.unlink(missing_ok=True)
                if kind in ('missing', 'symlink'):
                    script.unlink(missing_ok=True)
                    script.write_bytes(original)
                script.chmod(0o400)

    def test_nested_node_alias_drift_rejects(self):
        self.lib_alias.unlink()
        self.lib_alias.symlink_to(self.libraries[1].name)
        with self.assertRaises(ValueError):
            self.approve()

    def test_compiler_unicode_collision_extra_directory_and_incomplete_reject(self):
        candidate = copy.deepcopy(self.candidate)
        candidate['files']['lib/LIB.synthetic0.d.ts'] = candidate['files']['lib/lib.synthetic0.d.ts']
        with self.assertRaises(ValueError):
            self.approve(candidate)
        for name, directory in (('extra-directory', True), ('INCOMPLETE', False)):
            path = self.compiler / name
            if directory:
                path.mkdir()
            else:
                path.write_bytes(b'unapproved')
            with self.assertRaises(ValueError):
                self.approve()
            path.rmdir() if directory else path.unlink()

    def test_review_sources_fixture_hash_and_config_generator_drift_reject(self):
        for kind in ('sources', 'fixtures', 'nodeReviewSha256'):
            candidate = copy.deepcopy(self.candidate)
            if kind == 'sources':
                candidate[kind] = {}
            elif kind == 'fixtures':
                candidate[kind]['positive'] = '0' * 64
            else:
                candidate[kind] = '0' * 64
            with self.assertRaises(ValueError):
                self.approve(candidate)

    def test_source_utf8_suppression_nul_reject(self):
        for data in (b'// @ts-expect-error\n', b'// @TS-NOCHECK', b'\x00', b'\xff'):
            with mock.patch.object(g.p, 'regular', return_value=data):
                with self.assertRaises((ValueError, UnicodeError)):
                    g.fixture('positive')

    def test_config_has_exact_semantic_contract_and_no_passthrough(self):
        config = g.decoded(g.config(self.root, 'positive'))
        self.assertEqual(config, {'compilerOptions': {'strict': True, 'noEmit': True,
            'skipLibCheck': False, 'skipDefaultLibCheck': False, 'types': [],
            'typeRoots': [str(self.root / 'workspace/empty-types')], 'target': 'ESNext',
            'module': 'ESNext', 'moduleResolution': 'Bundler', 'pretty': False, 'listFiles': True},
            'files': [str(self.root / 'workspace/compiler_positive.ts')], 'include': [], 'exclude': []})
        with self.assertRaises(ValueError):
            g.config(self.root, '--generateCpuProfile')
        env = g.n.clean_env(self.root)
        for name in ('NODE_ENV', 'NODE_OPTIONS', 'NODE_PATH', 'NODE_V8_COVERAGE', 'DYLD_INSERT_LIBRARIES',
                     'OPENSSL_CONF', 'SSL_CERT_FILE', 'ICU_DATA'):
            self.assertNotIn(name, env)
        self.assertEqual(env['NODE_DISABLE_COMPILE_CACHE'], '1')

    def test_nonrepresentable_paths_reject_before_preparation_or_launch(self):
        # Raw spellings must be checked before pathlib erases dot/empty parts.
        for tail in ('back\\slash', './dot', '../up', 'double//slash', 'trailing/',
                     'line\nbreak', 'nonascii-\u00e9'):
            bad = str(self.root) + '/' + tail
            with self.subTest(tail=tail):
                with mock.patch.object(g, 'selected', side_effect=AssertionError('archive inspected')):
                    with self.assertRaises(ValueError):
                        g.materialize(bad, self.bytes)
                candidate = {**self.candidate, 'compilerRoot': bad}
                with self.assertRaises(ValueError):
                    self.approve(candidate)
                for operation in (lambda: g.config(bad, 'positive'),
                                  lambda: g.policy(bad, self.candidate),
                                  lambda: g.command(bad, self.candidate, 'version'),
                                  lambda: g.policy(self.root, candidate),
                                  lambda: g.command(self.root, candidate, 'version')):
                    with self.assertRaises(ValueError):
                        operation()
                data = g.n.encoded(candidate)
                with self.assertRaises(g.c.Blocked):
                    g.run_guard(data, g.n.sha(data))

    def test_backslash_parent_rejects_before_artifact_creation(self):
        parent = self.root / 'back\\slash'
        parent.mkdir()
        with mock.patch.object(g, 'PRIVATE_PARENT', parent), mock.patch.object(
                g.c.tempfile, 'mkdtemp', side_effect=AssertionError('must not create')):
            with self.assertRaises(ValueError):
                with g.artifacts():
                    self.fail('unrepresentable artifact parent accepted')
        with mock.patch.object(g, 'PRIVATE_PARENT', parent):
            with self.assertRaises(ValueError):
                g.materialize(parent / 'compiler', self.bytes)
        self.assertFalse(list(parent.iterdir()))

    def test_compiler_artifact_prefix_representable_private_and_quoted(self):
        with g.artifacts() as root:
            self.assertEqual(root.parent, self.root)
            self.assertEqual(g.compiler_path(str(root)), root)
            self.assertNotIn('\\', str(root))
            self.assertIn('"(allow default)', root.name)
            self.assertEqual(stat.S_IMODE(root.stat().st_mode), 0o700)
            config = g.decoded(g.config(root, 'positive'))
            self.assertEqual(config['files'], [str(root / 'workspace/compiler_positive.ts')])
            rules, _ = node_tests.decoded_node_policy(g.policy(root, self.candidate))
            self.assertTrue(rules.allows('file-read*', root / 'workspace/positive.json'))
            self.assertFalse(rules.allows('file-read*', root / 'unapproved'))
        self.assertFalse(root.exists())

    def test_artifact_removal_failure_quarantines_and_retains(self):
        with mock.patch.object(g.c.shutil, 'rmtree', side_effect=OSError('synthetic removal failure')):
            with self.assertRaises(g.c.Blocked):
                with g.artifacts() as root:
                    pass
        self.assertTrue(root.is_dir())
        self.assertTrue(g.c._QUARANTINED)
        self.assertIn(root, g.c._RETAINED_ARTIFACTS)
        with self.assertRaises(g.c.Blocked):
            with g.artifacts():
                self.fail('quarantined artifacts reused')

    def test_policy_decoded_literals_only_no_phantom_or_js_map(self):
        root = self.root / 'quoted-"(allow default)'
        rules, sysctls = node_tests.decoded_node_policy(g.policy(root, self.candidate))
        self.assertEqual(sysctls, list(g.n.PAGE_SIZE_SYSCTLS + g.n.UNAME_SYSCTLS))
        compiler_js = self.compiler / 'lib/_tsc.js'
        self.assertTrue(rules.allows('file-read*', compiler_js))
        self.assertFalse(rules.allows('file-map-executable', compiler_js))
        for name in ('probe.cjs', 'read-canary'):
            self.assertFalse(rules.allows('file-read*', root / name))
        for operation in ('process-exec', 'file-write*', 'file-read*'):
            self.assertFalse(rules.allows(operation, self.compiler / 'unapproved'))
            self.assertFalse(rules.allows(operation, self.root / 'home/private'))
        self.assertTrue(rules.allows('file-write*', root / 'state/home/cache'))
        self.assertFalse(rules.allows('file-write*', root / 'workspace/positive.json'))

    def test_owned_cwd_read_is_literal_not_recursive_or_host_directory(self):
        root = self.root / 'run'
        rules, _ = node_tests.decoded_node_policy(g.policy(root, self.candidate))
        self.assertTrue(rules.allows('file-read*', root / 'workspace'))
        for path in (root / 'workspace/unapproved', root / 'workspace/nested/file',
                     root, self.root / 'home', self.compiler):
            self.assertFalse(rules.allows('file-read*', path))
        self.assertFalse(rules.allows('file-write*', root / 'workspace'))
        with self.assertRaises(ValueError):
            g.policy(Path('/bad\n(allow default)'), self.candidate)

    def test_fixed_commands_and_heap_not_rss(self):
        for mode in g.MODES:
            args = g.command(self.root, self.candidate, mode)
            self.assertEqual(args[:8], [str(g.c.SANDBOX), '-f', str(self.root / 'guard.sb'),
                str(g.n.NODE), '--max-old-space-size=1024',
                '--openssl-config=' + str(self.root / 'openssl.cnf'),
                str(self.compiler / 'lib/tsc.js'), '--version' if mode == 'version' else '--project'])
        with self.assertRaises(ValueError):
            g.command(self.root, self.candidate, '--require=evil')

    def output(self, mode, root=None):
        root = root or self.root
        lines = []
        if mode == 'negative':
            lines.append("compiler_negative.ts(1,7): error TS2322: Type 'string' is not assignable to type 'number'.")
        lines.extend(str(self.compiler / name) for name in sorted(g.expected_libraries(self.candidate)))
        lines.append(str(root / 'workspace' / ('compiler_' + mode + '.ts')))
        return ('\n'.join(lines) + '\n').encode()

    def test_separate_version_positive_and_intended_error_verdicts(self):
        self.assertEqual(g.observe('version', 0, b'Version 6.0.3\n', b'', self.root,
                                  self.candidate), {'version': '6.0.3'})
        for mode, code, codes in (('positive', 0, []), ('negative', 2, [2322])):
            observed = g.observe(mode, code, self.output(mode), b'', self.root, self.candidate)
            self.assertEqual(observed['diagnosticCodes'], codes)
            self.assertEqual(len(observed['programFiles']), 3)
            self.assertNotIn(str(self.root), json.dumps(observed))

    def test_noop_wrong_diagnostic_partial_duplicate_outside_and_missing_reject(self):
        positive = self.output('positive')
        negative = self.output('negative')
        cases = [('version', 0, b'v6.0.3\n'), ('positive', 0, b''),
                 ('negative', 0, negative), ('negative', 1, negative),
                 ('negative', 2, negative.replace(b'TS2322', b'TS9999')),
                 ('negative', 2, negative.replace(b"'string'", b"'any'")),
                 ('positive', 0, positive[:-1]), ('positive', 0, positive + b'/outside\n'),
                 ('positive', 0, positive + positive), ('positive', 1, positive),
                 ('positive', 0, b'\n'.join(positive.split(b'\n')[1:]))]
        for mode, code, output in cases:
            with self.subTest(mode=mode, code=code, output_hash=g.n.sha(output)):
                with self.assertRaises(ValueError):
                    g.observe(mode, code, output, b'', self.root, self.candidate)
        with self.assertRaises(ValueError):
            g.observe('positive', 0, positive, b'unexpected', self.root, self.candidate)

    @contextmanager
    def orchestration(self, effect=None):
        """Process boundary is mocked; compiler artifacts retention/cleanup is real."""
        owned = self.root / 'attempts'
        owned.mkdir(exist_ok=True)
        # tempfile API is patched ONLY to put fresh guard artifacts under test ownership.
        original = g.c.tempfile.mkdtemp

        def fresh(**kwargs):
            self.assertEqual(kwargs.pop('dir'), self.root)
            if kwargs['prefix'] == 'threadmark-compiler-evidence-':
                return original(dir=self.root, **kwargs)
            return original(dir=owned, **kwargs)

        self.calls = []

        def simulated(args, cwd, env, **kwargs):
            self.calls.append(kwargs)
            mode = g.MODES[len(self.calls) - 1]
            if effect:
                result = effect(mode, cwd.parent)
                if result is not None:
                    return result
            output = b'Version 6.0.3\n' if mode == 'version' else self.output(mode, cwd.parent)
            return (2 if mode == 'negative' else 0), output, b'', 0.01

        with mock.patch.object(g.c.tempfile, 'mkdtemp', side_effect=fresh), mock.patch.object(
                g.c.owner, 'bounded', side_effect=simulated):
            yield owned

    def test_mocked_orchestration_aggregate_budget_and_cleanup_not_compiler_proof(self):
        with self.orchestration() as owned:
            evidence = g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(evidence['result'], 'compiler-only-smoke-pass')
            self.assertEqual(list(owned.iterdir()), [])
            self.assertEqual(len(self.calls), 3)
            self.assertGreater(self.calls[0]['limit'], self.calls[1]['limit'])
            self.assertGreater(self.calls[1]['limit'], self.calls[2]['limit'])
            self.assertTrue(all(0 < call['timeout'] <= 110 for call in self.calls))

    def test_postcheck_drift_even_zero_exit_retains_and_never_retries(self):
        def drift(mode, root):
            (root / 'workspace' / 'positive.json').chmod(0o600)
            (root / 'workspace' / 'positive.json').write_bytes(b'changed')

        with self.orchestration(drift) as owned:
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(len(self.calls), 1)
            self.assertTrue(list(owned.iterdir()))
            self.assertEqual(raised.exception.evidence['cleanup'], 'unverified-retained')
            with self.assertRaises(g.c.Blocked):
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(len(self.calls), 1)

    def test_canceled_postvalidation_retains_instead_of_cleaning(self):
        original = g.revalidate
        attempts = 0

        def check(review):
            nonlocal attempts
            attempts += 1
            if attempts == 3:  # read_review, before attempt, after attempt
                raise g.c.Canceled()
            return original(review)

        with self.orchestration() as owned, mock.patch.object(g, 'revalidate', side_effect=check):
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertTrue(list(owned.iterdir()))
            self.assertEqual(len(self.calls), 1)
            self.assertEqual((self.retained() / 'version-stdout.bin').read_bytes(), b'Version 6.0.3\n')
            self.assertEqual(raised.exception.evidence['attempts']['version']['afterValidation'],
                             'failed-or-interrupted')

    def test_postlaunch_node_alias_or_directory_drift_retains(self):
        def drift(mode, root):
            self.lib_alias.unlink()
            self.lib_alias.symlink_to(self.libraries[1].name)
        with self.orchestration(drift) as owned:
            with self.assertRaises(g.c.Blocked):
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertTrue(list(owned.iterdir()))
            self.assertEqual(len(self.calls), 1)

    def test_owned_directory_mode_drift_retains(self):
        def drift(mode, root):
            (root / 'workspace').chmod(0o755)
        with self.orchestration(drift) as owned:
            with self.assertRaises(g.c.Blocked):
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertTrue(list(owned.iterdir()))

    def test_unknown_parser_output_stops_without_retry_after_verified_cleanup(self):
        def wrong(mode, root):
            return 0, b'unrecognized output\n', b'', 0.01
        with self.orchestration(wrong) as owned:
            with self.assertRaises(g.c.Blocked):
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(len(self.calls), 1)
            self.assertFalse(list(owned.iterdir()))

    def test_cancel_and_timeout_do_not_resume_or_infer_success(self):
        for failure in (g.c.Canceled(), g.c.Blocked('synthetic timeout')):
            def fail(mode, root):
                raise failure
            with self.orchestration(fail) as owned:
                with self.assertRaises(g.c.Blocked) as raised:
                    g.run_guard(self.data, g.n.sha(self.data))
                self.assertEqual(raised.exception.evidence['result'], 'blocked')
                self.assertEqual(len(self.calls), 1)
                self.assertFalse(list(owned.iterdir()))

    def test_unknown_owner_cleanup_retains(self):
        def fail(mode, root):
            raise g.c.owner.CleanupUnverified('synthetic unknown owner')
        with self.orchestration(fail) as owned:
            with self.assertRaises((g.c.Blocked, g.c.owner.CleanupUnverified)):
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertTrue(list(owned.iterdir()))
            self.assertTrue(g.c._QUARANTINED)

    def test_output_aggregate_exhaustion_and_deadline_before_launch(self):
        with self.orchestration(), mock.patch.object(g, 'OUTPUT_CAP', 4):
            with self.assertRaises(g.c.Blocked):
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(len(self.calls), 1)
        with self.orchestration():
            evidence = {'typescript_launched': False, 'attempts': {}}
            sink = g.PrivateEvidence(g.n.sha(self.data))
            self.addCleanup(sink.close)
            with self.assertRaises(g.c.Blocked):
                g._run(self.candidate, evidence, time.monotonic() - 1, sink)
            self.assertEqual(len(self.calls), 0)

    def retained(self):
        return g._PRIVATE_EVIDENCE[-1]

    def test_private_evidence_success_immutable_complete_and_policy_excluded(self):
        with self.orchestration() as owned:
            result = g.run_guard(self.data, g.n.sha(self.data))
            sink = self.retained()
            self.assertEqual(stat.S_IMODE(sink.stat().st_mode), 0o700)
            self.assertFalse(list(owned.iterdir()))
            record_bytes = (sink / 'result.json').read_bytes()
            record = g.decoded(record_bytes)
            self.assertEqual(record['result'], 'compiler-checks-passed-unconfirmed')
            self.assertEqual(record['stage'], 'awaiting-successful-return')
            self.assertEqual(record['requires'], 'successful-call-receipt')
            self.assertNotIn('successReceipt', record)
            self.assertEqual(result['successReceipt'], {
                'reviewSha256': g.n.sha(self.data), 'recordSha256': g.n.sha(record_bytes)})
            for mode in g.MODES:
                metadata = g.decoded((sink / (mode + '-capture.json')).read_bytes())
                self.assertEqual(metadata['exitCode'], 2 if mode == 'negative' else 0)
                self.assertFalse(metadata['truncated'])
                self.assertEqual(result['attempts'][mode]['afterValidation'], 'passed')
            for path in sink.iterdir():
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o400)
                self.assertEqual(path.stat().st_nlink, 1)
            rules, _ = node_tests.decoded_node_policy(g.policy(self.root / 'run', self.candidate))
            for op in ('file-read*', 'file-write*', 'file-map-executable'):
                self.assertFalse(rules.allows(op, sink / 'positive-stdout.bin'))
            self.assertNotIn(str(sink), json.dumps(result))

    def test_positive_failure_keeps_raw_only_privately_and_exact_exit_stage(self):
        private = b'PRIVATE source /private/synthetic/secret.ts error TS9999\n'
        def fail(mode, root):
            if mode == 'positive':
                return 17, private, b'', 0.01
        with self.orchestration(fail) as owned:
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            evidence = raised.exception.evidence
            self.assertEqual(evidence['stage'], 'positive-observe')
            self.assertEqual(evidence['failureCode'], 'compiler-output-rejected')
            self.assertEqual(evidence['attempts']['positive']['exitCode'], 17)
            self.assertEqual(evidence['checks']['negative'], 'NOT_RUN')
            self.assertEqual((self.retained() / 'positive-stdout.bin').read_bytes(), private)
            self.assertFalse(list(owned.iterdir()))
            self.assertNotIn('PRIVATE', repr(raised.exception) + json.dumps(evidence))
            self.assertEqual(len(self.calls), 2)

    def test_owner_raises_has_no_partial_api_and_exception_text_is_never_public(self):
        for error, code in ((ValueError('worker timeout'), 'owner-timeout'),
                            (RuntimeError('PRIVATE /private/secret.ts'), 'unrecognized-failure'),
                            (KeyboardInterrupt('PRIVATE'), 'canceled')):
            def fail(mode, root):
                raise error
            with self.orchestration(fail):
                with self.assertRaises(g.c.Blocked) as raised:
                    g.run_guard(self.data, g.n.sha(self.data))
                evidence = raised.exception.evidence
                self.assertEqual(evidence['stage'], 'version-owner')
                self.assertEqual(evidence['failureCode'], code)
                self.assertEqual(evidence['attempts']['version']['capture'], 'unavailable-owner-raised')
                self.assertIsNone(evidence['attempts']['version']['exitCode'])
                self.assertNotIn('PRIVATE', json.dumps(evidence) + repr(raised.exception))
                self.assertTrue((self.retained() / 'result.json').is_file())

    def test_evidence_prepare_failure_never_launches(self):
        with self.orchestration(), mock.patch.object(g.PrivateEvidence, 'write',
                side_effect=OSError('PRIVATE disk unavailable')):
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(len(self.calls), 0)
            self.assertEqual(raised.exception.evidence['stage'], 'evidence-preparation')
            self.assertNotIn('PRIVATE', repr(raised.exception))

    def test_evidence_retention_failure_quarantines_without_deleting(self):
        original = g.PrivateEvidence.write
        def fail(sink, name, data):
            if name == 'version-stderr.bin':
                raise OSError('PRIVATE disk failure')
            return original(sink, name, data)
        with self.orchestration() as owned, mock.patch.object(g.PrivateEvidence, 'write', fail):
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(len(self.calls), 1)
            self.assertTrue(list(owned.iterdir()))
            self.assertEqual(raised.exception.evidence['cleanup'], 'unverified-retained')
            self.assertEqual((self.retained() / 'version-stdout.bin').read_bytes(), b'Version 6.0.3\n')

    def test_evidence_cap_never_retains_more_than_aggregate_limit(self):
        def oversized(mode, root):
            return 0, b'A' * 8, b'B' * 8, 0.01
        with self.orchestration(oversized), mock.patch.object(g, 'OUTPUT_CAP', 10):
            with self.assertRaises(g.c.Blocked):
                g.run_guard(self.data, g.n.sha(self.data))
            sink = self.retained()
            self.assertEqual(sum(path.stat().st_size for path in sink.glob('*.bin')), 10)
            self.assertTrue(g.decoded((sink / 'version-capture.json').read_bytes())['truncated'])
            self.assertEqual(len(self.calls), 1)

    def test_evidence_exclusive_nofollow_and_failed_write_retains_pending(self):
        sink = g.PrivateEvidence(g.n.sha(self.data))
        self.addCleanup(sink.close)
        sink.write('version-before.json', b'original')
        with self.assertRaises(FileExistsError):
            sink.write('version-before.json', b'never replace')
        self.assertEqual((sink.path / 'version-before.json').read_bytes(), b'original')
        self.assertTrue((sink.path / 'version-before.json.pending').exists())
        (sink.path / 'version-after.json.pending').symlink_to(self.compiler / 'package.json')
        with self.assertRaises(FileExistsError):
            sink.write('version-after.json', b'never follow')
        self.assertEqual((self.compiler / 'package.json').read_bytes(), self.files['package.json'])

    def test_unknown_cleanup_and_postcheck_interruption_keep_capture_and_metadata(self):
        def fail(mode, root):
            raise g.c.owner.CleanupUnverified('PRIVATE')
        with self.orchestration(fail) as owned:
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(raised.exception.evidence['failureCode'], 'owner-cleanup-unverified')
            self.assertTrue(list(owned.iterdir()))
            self.assertTrue((self.retained() / 'version-after.json').exists())

    def test_final_metadata_failure_cannot_report_pass(self):
        original = g.PrivateEvidence.write
        def fail(sink, name, data):
            if name == 'result.json':
                raise OSError('PRIVATE')
            return original(sink, name, data)
        with self.orchestration(), mock.patch.object(g.PrivateEvidence, 'write', fail):
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(raised.exception.evidence['result'], 'blocked')
            self.assertEqual(raised.exception.evidence['stage'], 'evidence-finalization')
            self.assertEqual(len(list(self.retained().glob('*-capture.json'))), 3)

    def test_before_validation_failure_records_no_launch(self):
        original = g.revalidate
        calls = 0
        def fail(review):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError('PRIVATE prevalidation')
            return original(review)
        with self.orchestration(), mock.patch.object(g, 'revalidate', side_effect=fail):
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            evidence = raised.exception.evidence
            self.assertEqual(evidence['stage'], 'version-before-validation')
            self.assertEqual(evidence['attempts']['version']['beforeValidation'], 'failed-or-interrupted')
            self.assertEqual(evidence['cleanup'], 'not-launched')
            self.assertEqual(len(self.calls), 0)
            self.assertTrue((self.retained() / 'result.json').exists())

    def test_interrupted_retention_keeps_pending_and_quarantines(self):
        original = g.os.rename
        def interrupt(source, target, **kwargs):
            if source == 'version-stdout.bin.pending':
                raise KeyboardInterrupt('PRIVATE')
            return original(source, target, **kwargs)
        with self.orchestration() as owned, mock.patch.object(g.os, 'rename', side_effect=interrupt):
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(raised.exception.evidence['failureCode'], 'canceled')
            self.assertTrue(list(owned.iterdir()))
            self.assertEqual((self.retained() / 'version-stdout.bin.pending').read_bytes(),
                             b'Version 6.0.3\n')

    def test_evidence_identity_drift_or_arbitrary_name_rejects(self):
        sink = g.PrivateEvidence(g.n.sha(self.data))
        self.addCleanup(sink.close)
        for name in ('../outside', 'arbitrary', '/absolute'):
            with self.assertRaises(g.c.Blocked):
                sink.write(name, b'data')
        sink.path.chmod(0o755)
        with self.assertRaises(g.c.Blocked):
            sink.write('result.json', b'data')
        self.assertFalse((sink.path / 'result.json').exists())

    def test_sink_code_is_bound_and_diagnostic_rejection_remains_strict(self):
        self.assertIn(str(Path(g.__file__).resolve()), self.candidate['sources'])
        for mode, code in (('positive', 0), ('negative', 2)):
            with self.assertRaises(g.c.Blocked):
                g.observe(mode, code, self.output(mode) + b'error TS9999: PRIVATE\n',
                          b'', self.root, self.candidate)

    def test_sink_close_failure_is_sanitized_and_blocks_pass(self):
        original = g.PrivateEvidence.close
        def fail(sink):
            original(sink)
            raise OSError('PRIVATE close failure')
        with self.orchestration(), mock.patch.object(g.PrivateEvidence, 'close', fail):
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(raised.exception.evidence['result'], 'blocked')
            self.assertEqual(raised.exception.evidence['failureCode'], 'evidence-retention')
            self.assertNotIn('PRIVATE', repr(raised.exception))
            record = g.decoded((self.retained() / 'result.json').read_bytes())
            self.assertEqual(record['result'], 'compiler-checks-passed-unconfirmed')
            self.assertEqual(record['stage'], 'awaiting-successful-return')
            self.assertNotIn('successReceipt', raised.exception.evidence)

    def test_final_record_failure_after_rename_never_persists_terminal_success(self):
        original = g.PrivateEvidence.write
        def fail(sink, name, data):
            original(sink, name, data)
            if name == 'result.json':
                raise OSError('PRIVATE final directory fsync failure')
        with self.orchestration(), mock.patch.object(g.PrivateEvidence, 'write', fail):
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            record = g.decoded((self.retained() / 'result.json').read_bytes())
            self.assertEqual(record['result'], 'compiler-checks-passed-unconfirmed')
            self.assertEqual(record['stage'], 'awaiting-successful-return')
            self.assertEqual(raised.exception.evidence['result'], 'blocked')
            self.assertNotIn('successReceipt', raised.exception.evidence)

    def test_sink_fsync_failure_before_launch_retains_without_launch(self):
        with self.orchestration(), mock.patch.object(g.os, 'fsync', side_effect=OSError('PRIVATE')):
            with self.assertRaises(g.c.Blocked) as raised:
                g.run_guard(self.data, g.n.sha(self.data))
            self.assertEqual(len(self.calls), 0)
            self.assertEqual(raised.exception.evidence['stage'], 'evidence-preparation')
            self.assertTrue((self.retained() / 'prepared.json.pending').exists())


if __name__ == '__main__':
    unittest.main()
