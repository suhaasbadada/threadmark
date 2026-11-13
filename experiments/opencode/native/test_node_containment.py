"""PURE synthetic files/models and mocked process boundary; NEVER runs Node.

These checks do not establish macOS/Node containment, cache semantics or version.
The independent emitted-policy oracle is shared with existing C model tests.
"""
from contextlib import ExitStack
import copy
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import node_containment as n
from test_synthetic_containment import decoded_rules


def decoded_node_policy(text):
    """Parse emitted file rules and the named-read subset, not implementation text."""
    filesystem, sysctls = [], []
    quoted = r'"(?:[^"\\]|\\["\\])*"'
    for line in text.splitlines():
        if line.startswith('(allow sysctl-read'):
            match = re.fullmatch(r'\(allow sysctl-read \(sysctl-name (' + quoted + r'(?: ' + quoted + r')*)\)\)', line)
            if not match:
                raise AssertionError('unexpected sysctl policy syntax')
            sysctls.extend(json.loads(value) for value in re.findall(quoted, match[1]))
        else:
            filesystem.append(line)
    return decoded_rules('\n'.join(filesystem)), sysctls


class SyntheticRuntime(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='threadmark-node-pure-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.cellar = self.root / 'Cellar'
        self.node = self.cellar / 'node/24.10.0/bin/node'
        self.node.parent.mkdir(parents=True)
        self.node.write_bytes(b'NOT AN EXECUTABLE; synthetic Node bytes\n')
        self.node.chmod(0o500)
        self.libraries = []
        for index in range(17):
            p = self.cellar / 'synthetic/1/lib' / f'libsynthetic{index}.dylib'
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(f'inert synthetic library {index}\n'.encode())
            p.chmod(0o444)
            self.libraries.append(p)
        self.alias = self.root / 'opt/synthetic'
        self.alias.parent.mkdir()
        self.alias.symlink_to('../Cellar/synthetic/1')
        self.lib_alias = self.libraries[0].parent / 'libalias.dylib'
        self.lib_alias.symlink_to(self.libraries[0].name)
        self.system = {'kernel': 'synthetic', 'build': 'synthetic',
            'systemVersion': {'sha256': '0' * 64}, 'dyld': {'sha256': '1' * 64},
            'baseline': list(n.BASELINE), 'directories': {},
            'sharedCacheIdentity': 'OS-build-bound; virtual images NOT individually hashed'}
        self.sources = {'synthetic-source': {'sha256': '2' * 64}}
        stack = self.enterContext(ExitStack())
        stack.enter_context(mock.patch.object(n, 'NODE', self.node))
        stack.enter_context(mock.patch.object(n, 'CELLAR', self.cellar))
        stack.enter_context(mock.patch.object(n, 'NODE_SHA', n.sha(self.node.read_bytes())))
        stack.enter_context(mock.patch.object(n, 'system_record', lambda: copy.deepcopy(self.system)))
        stack.enter_context(mock.patch.object(n, 'source_records', lambda: copy.deepcopy(self.sources)))
        stack.enter_context(mock.patch.object(n, 'require_platform'))
        # No possible target process or receiver in any test, even accidentally.
        stack.enter_context(mock.patch.object(n.c.owner, 'bounded', side_effect=AssertionError('real launch')))
        stack.enter_context(mock.patch.object(n.socket, 'socket', side_effect=AssertionError('real socket')))
        stack.enter_context(mock.patch.object(n.c, '_QUARANTINED', False))
        stack.enter_context(mock.patch.object(n.c, '_RETAINED_ARTIFACTS', []))
        stack.enter_context(mock.patch.object(n.c.owner, '_QUARANTINED', False))
        self.review = self.fixture()

    def fixture(self):
        aliases, directories = {}, {}
        files = {}
        for p in [self.node, *self.libraries]:
            self.assertEqual(n.resolve(p, aliases, directories), p)
            files[str(p)] = n.file_record(p)
        lookups = [self.alias / 'lib' / (self.lib_alias.name if i == 0 else p.name)
                   for i, p in enumerate(self.libraries)]
        for lookup in lookups:
            n.resolve(lookup, aliases, directories)
        loads = {str(self.node): [{'lookup': str(lookup), 'canonical': str(p)}
                                 for lookup, p in zip(lookups, self.libraries)]}
        loads.update({str(p): [{'lookup': '/usr/lib/libSystem.B.dylib', 'canonical': None}]
                      for p in self.libraries})
        return {'schema': 1, 'kind': 'fixed-node-only-discovery', 'version': '24.10.0',
                'node': str(self.node), 'runtime': {'files': files, 'aliases': aliases,
                   'directories': directories, 'loads': loads},
                'system': copy.deepcopy(self.system), 'sources': copy.deepcopy(self.sources)}

    def approve_fixture(self, review=None):
        # TEST ONLY digest. A caller must never mistake this for external review.
        data = n.encoded(self.review if review is None else review)
        return n.read_review(data, n.sha(data))

    def test_synthetic_preflight_has_no_launch_and_no_implicit_approval(self):
        self.assertEqual(self.approve_fixture(), self.review)
        data = n.encoded(self.review)
        for digest in ('0' * 64, '', 'self', None, 'F' * 64, n.sha(data) + '\n'):
            with self.assertRaises(n.c.Blocked):
                n.read_review(data, digest)
        self.assertNotIn('executionApproved', self.review)

    def test_unknown_duplicate_missing_and_wrong_kind_reject(self):
        for key, value in (('extraCLI', ['--eval']), ('schema', True), ('version', '25.0.0'),
                           ('kind', 'compiler'), ('node', '/bin/sh')):
            review = copy.deepcopy(self.review)
            review[key] = value
            with self.subTest(key=key), self.assertRaises(n.c.Blocked):
                self.approve_fixture(review)
        data = b'{"schema":1,"schema":1}'
        with self.assertRaises(n.c.Blocked):
            n.read_review(data, n.sha(data))
        review = copy.deepcopy(self.review)
        del review['runtime']['files'][str(self.libraries[0])]
        with self.assertRaises(n.c.Blocked):
            self.approve_fixture(review)

    def test_dylib_hash_mode_size_inode_and_nlink_drift(self):
        p = self.libraries[0]
        for change in ('bytes', 'mode', 'inode', 'hardlink'):
            with self.subTest(change=change):
                self.review = self.fixture()
                original = p.read_bytes()
                if change == 'bytes':
                    p.chmod(0o600)
                    p.write_bytes(b'changed\n')
                    p.chmod(0o444)
                elif change == 'mode':
                    p.chmod(0o644)
                elif change == 'inode':
                    p.unlink()
                    p.write_bytes(original)
                    p.chmod(0o444)
                else:
                    os.link(p, p.parent / 'hardlink')
                with self.assertRaises(n.c.Blocked):
                    self.approve_fixture()
                (p.parent / 'hardlink').unlink(missing_ok=True)
                p.chmod(0o600)
                p.write_bytes(original)
                p.chmod(0o444)

    def test_alias_target_and_ancestor_drift(self):
        self.alias.unlink()
        self.alias.symlink_to('../Cellar/synthetic/1/lib/..')
        with self.assertRaises(n.c.Blocked):
            self.approve_fixture()
        self.review = self.fixture()
        self.node.parent.chmod(0o700)
        with self.assertRaises(n.c.Blocked):
            self.approve_fixture()

    def test_noncanonical_file_link_and_alias_cycle_reject(self):
        self.libraries[1].unlink()
        self.libraries[1].symlink_to(self.libraries[0])
        with self.assertRaises(n.c.Blocked):
            self.approve_fixture()
        self.alias.unlink()
        self.alias.symlink_to('synthetic')
        with self.assertRaises(n.c.Blocked):
            n.resolve(self.alias, {}, {})

    def test_missing_extra_unreachable_dependencies_and_unknown_system_load_reject(self):
        for variant in ('missing', 'extra', 'unreachable', 'system', 'duplicate'):
            review = copy.deepcopy(self.review)
            edges = review['runtime']['loads'][str(self.node)]
            if variant == 'missing':
                edges[0]['canonical'] = str(self.cellar / 'absent.dylib')
            elif variant == 'extra':
                review['runtime']['files'][str(self.cellar / 'extra.dylib')] = copy.deepcopy(
                    review['runtime']['files'][str(self.libraries[0])])
            elif variant == 'unreachable':
                edges.pop()
            elif variant == 'system':
                edges.append({'lookup': '/System/Library/PrivateFrameworks/extra', 'canonical': None})
            else:
                edges.append(copy.deepcopy(edges[0]))
            with self.subTest(variant=variant), self.assertRaises(n.c.Blocked):
                self.approve_fixture(review)

    def test_bounds_paths_and_case_collisions(self):
        for value in ('/', '', '/a\n(allow default)', '/a/../b', '/a//b', '/a/./b', '/é', '/a\t'):
            with self.subTest(value=value), self.assertRaises(n.c.Blocked):
                n.path(value)
        for variant in ('file', 'total', 'alias', 'root', 'collision'):
            review = copy.deepcopy(self.review)
            if variant == 'file':
                review['runtime']['files'][str(self.node)]['identity'][5] = n.FILE_CAP + 1
            elif variant == 'total':
                for record in review['runtime']['files'].values():
                    record['identity'][5] = n.FILE_CAP
            elif variant == 'alias':
                review['runtime']['aliases'] = {f'/alias{i}': {} for i in range(257)}
            elif variant == 'root':
                review['runtime']['directories']['/'] = []
            else:
                review['runtime']['directories'][str(self.cellar).upper()] = []
            with self.subTest(variant=variant), self.assertRaises(n.c.Blocked):
                self.approve_fixture(review)

    def test_source_system_and_shared_cache_identity_are_bound_honestly(self):
        for section in ('sources', 'system'):
            review = copy.deepcopy(self.review)
            review[section]['invented-image-sha256'] = '0' * 64
            with self.assertRaises(n.c.Blocked):
                self.approve_fixture(review)
        self.sources['synthetic-source']['sha256'] = '3' * 64
        with self.assertRaises(n.c.Blocked):
            self.approve_fixture()

    def test_file_open_race_and_exclusive_private_creation(self):
        original = n.identity
        calls = 0

        def race(info):
            nonlocal calls
            calls += 1
            result = original(info)
            if calls == 2:
                result[1] += 1
            return result
        with mock.patch.object(n, 'identity', race), self.assertRaises(n.c.Blocked):
            n.file_record(self.node)
        target = self.root / 'new'
        n.create(target, b'owned')
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        with self.assertRaises(FileExistsError):
            n.create(target, b'overwrite')
        self.assertEqual(target.read_bytes(), b'owned')

    def test_serialized_policy_has_only_explicit_discovery_baseline_and_literal_runtime(self):
        root = Path('/private/synthetic/"\\(allow default)')
        model = n.policy(root, self.review)
        decoded, sysctls = decoded_node_policy(n.serialized_policy(root, self.review))
        self.assertEqual(decoded, model)
        self.assertEqual(sysctls, ['hw.pagesize', 'hw.pagesize_compat', 'kern.ostype',
                                  'kern.hostname', 'kern.osrelease', 'kern.version', 'hw.machine'])
        self.assertTrue(decoded.allows('process-exec', self.node))
        self.assertFalse(decoded.allows('process-exec', root / 'exec-marker'))
        for p in [self.node, *self.libraries]:
            self.assertTrue(decoded.allows('file-read*', p))
            self.assertFalse(decoded.allows('file-write*', p))
        for p in (Path('/System/Library/PrivateFrameworks/unapproved'),
                  Path('/opt/homebrew/other'), Path('/Users/synthetic/.ssh/key'),
                  root / 'outside/home/.config/opencode/config.json', root / 'workspace/check'):
            self.assertFalse(decoded.allows('file-read*', p))
            self.assertFalse(decoded.allows('file-write*', p))
        self.assertTrue(decoded.allows('file-read-data', Path('/')))
        self.assertFalse(decoded.allows('file-read-data', Path('/private')))
        self.assertTrue(decoded.allows('file-read*', root / 'openssl.cnf'))
        self.assertFalse(decoded.allows('file-map-executable', root / 'openssl.cnf'))
        self.assertFalse(decoded.allows('file-write*', root / 'openssl.cnf'))
        self.assertFalse(decoded.allows('file-read*', Path('/opt/homebrew/etc/openssl@3/openssl.cnf')))
        recursive = {str(rule.path) for rule in decoded.rules if rule.kind == 'subpath'
                     and 'file-map-executable' in rule.operations}
        self.assertEqual(recursive, set(n.BASELINE))
        for name in n.c.STATE:
            self.assertTrue(decoded.allows('file-write*', root / 'state' / name / 'positive'))
            self.assertFalse(decoded.allows('file-write*', root / 'state' / (name + '-other')))
        for op in ('network-outbound', 'network-inbound', 'process-fork', 'mach-lookup', 'sysctl-read'):
            self.assertFalse(any(op in rule.operations for rule in decoded.rules))

    def test_named_os_metadata_policy_has_no_unrestricted_sysctl_or_duplicate_reads(self):
        _, names = decoded_node_policy(n.serialized_policy(Path('/owned/synthetic'), self.review))
        self.assertEqual(names, ['hw.pagesize', 'hw.pagesize_compat', 'kern.ostype',
                                'kern.hostname', 'kern.osrelease', 'kern.version', 'hw.machine'])
        self.assertEqual(len(names), len(set(names)))
        self.assertNotIn('hw.memsize', names)
        for invalid in ('(allow sysctl-read)', '(allow sysctl-read (sysctl-name-regex ".*"))'):
            with self.assertRaises(AssertionError):
                decoded_node_policy(invalid)

    def evidence(self):
        return {'checks': {name: 'NOT_RUN' for name in n.REQUIRED}, 'node_launched': False}

    def test_mock_boundary_version_failure_removes_artifacts_and_has_fixed_command(self):
        roots = []

        def target(command, cwd, env, **bounds):
            roots.append(cwd.parent)
            self.assertEqual(command, [str(n.c.SANDBOX), '-f', str(cwd.parent / 'guard.sb'),
                                      str(self.node), '--max-old-space-size=64',
                                      '--openssl-config=' + str(cwd.parent / 'openssl.cnf'), '--version'])
            self.assertEqual((cwd.parent / 'openssl.cnf').read_bytes(),
                             b'# Fixed empty Threadmark discovery configuration; no host settings.\n')
            self.assertLessEqual(bounds['timeout'], 5)
            self.assertEqual(bounds['limit'], 16 * 1024)
            self.assertEqual(env, n.clean_env(cwd.parent))
            return 0, b'v24.10.1\n', b'PRIVATE-SYNTHETIC /private/fixture', 0.1
        evidence = self.evidence()
        with mock.patch.object(n.c.owner, 'bounded', target), self.assertRaises(n.c.Blocked):
            n._run(self.review, evidence)
        self.assertFalse(roots[0].exists())
        self.assertEqual(evidence['checks']['version'], 'NOT_RUN')
        self.assertNotIn('PRIVATE-SYNTHETIC', json.dumps(evidence))

    def test_mock_boundary_checks_script_output_separately_and_never_accepts_partial(self):
        calls = []

        def target(command, cwd, env, **bounds):
            calls.append(command)
            if command[-1] == '--version':
                return 0, n.VERSION, b'', 0.1
            self.assertEqual(command[-3:], [str(cwd.parent / 'probe.cjs'), 'filesystem', str(cwd.parent)])
            self.assertEqual((cwd.parent / 'probe.cjs').read_bytes(), n.SOURCE.read_bytes())
            return 0, b'approved-read:PASS\n', b'', 0.1
        evidence = self.evidence()
        with mock.patch.object(n.c.owner, 'bounded', target), self.assertRaises(n.c.Blocked):
            n._run(self.review, evidence)
        self.assertEqual(len(calls), 2)
        self.assertEqual(evidence['checks']['version'], 'observed-pass')
        self.assertEqual(evidence['checks']['approved-read'], 'failed-or-unverified')

    def test_mock_openssl_config_drift_quarantines_and_retains(self):
        roots = []

        def target(command, cwd, env, **bounds):
            roots.append(cwd.parent)
            (cwd.parent / 'openssl.cnf').write_bytes(b'changed synthetic config\n')
            return 0, n.VERSION, b'', 0.1

        try:
            with mock.patch.object(n.c.owner, 'bounded', target), self.assertRaises(n.c.Blocked):
                n._run(self.review, self.evidence())
            self.assertTrue(n.c._QUARANTINED)
            self.assertEqual(n.c._RETAINED_ARTIFACTS, roots)
            self.assertTrue(roots[0].is_dir())
        finally:
            for root in roots:
                if root.exists():
                    shutil.rmtree(root)

    def test_mock_zero_exit_after_drift_quarantines_and_retains(self):
        roots = []

        def target(command, cwd, env, **bounds):
            roots.append(cwd.parent)
            self.libraries[0].chmod(0o644)
            return 0, n.VERSION, b'', 0.1
        try:
            with mock.patch.object(n.c.owner, 'bounded', target), self.assertRaises(n.c.Blocked):
                n._run(self.review, self.evidence())
            self.assertTrue(n.c._QUARANTINED)
            self.assertEqual(n.c._RETAINED_ARTIFACTS, roots)
            self.assertTrue(roots[0].exists())
            with self.assertRaises(n.c.Blocked):
                with n.c.artifacts():
                    self.fail('quarantine reused')
        finally:
            # Only synthetic tree, and mocked boundary could not start a process.
            for root in roots:
                shutil.rmtree(root)

    def postcheck_interruption(self, interruption):
        roots = []
        original = n.revalidate

        def target(command, cwd, env, **bounds):
            roots.append(cwd.parent)
            return 0, n.VERSION, b'', 0.1

        def validate(review):
            if roots:
                raise interruption
            return original(review)

        try:
            with mock.patch.object(n.c.owner, 'bounded', target), \
                    mock.patch.object(n, 'revalidate', validate):
                with self.assertRaises(n.c.Blocked) as caught:
                    data = n.encoded(self.review)
                    n.run_guard(data, n.sha(data))
            self.assertTrue(caught.exception.evidence['node_launched'])
            self.assertEqual(caught.exception.evidence['cleanup'], 'unverified-retained')
            self.assertTrue(n.c._QUARANTINED)
            self.assertEqual(n.c._RETAINED_ARTIFACTS, roots)
            self.assertEqual(len(roots), 1)
            self.assertTrue(roots[0].is_dir())
            with self.assertRaises(n.c.Blocked):
                with n.c.artifacts():
                    self.fail('incomplete postcheck allowed reuse')
        finally:
            # Mocked target could not create a process; exact owned test tree only.
            for root in roots:
                if root.exists():
                    shutil.rmtree(root)

    def test_cancel_during_postcheck_quarantines_and_retains(self):
        self.postcheck_interruption(n.c.Canceled())

    def test_interrupt_during_postcheck_quarantines_and_retains(self):
        self.postcheck_interruption(KeyboardInterrupt())

    def test_mock_unknown_cleanup_retains_and_content_free_wrapper(self):
        roots = []

        def target(command, cwd, env, **bounds):
            roots.append(cwd.parent)
            raise n.c.owner.CleanupUnverified('PRIVATE-SYNTHETIC')
        try:
            with mock.patch.object(n.c.owner, 'bounded', target):
                with self.assertRaises(n.c.Blocked) as caught:
                    data = n.encoded(self.review)
                    n.run_guard(data, n.sha(data))
            self.assertEqual(caught.exception.evidence['cleanup'], 'unverified-retained')
            self.assertNotIn('PRIVATE-SYNTHETIC', str(caught.exception))
            self.assertTrue(roots[0].exists())
        finally:
            for root in roots:
                shutil.rmtree(root)

    def test_stale_review_rejects_before_artifacts_receivers_or_launch(self):
        data = n.encoded(self.review)
        self.node.chmod(0o700)
        with mock.patch.object(n.c, 'artifacts') as artifacts, self.assertRaises(n.c.Blocked) as caught:
            n.run_guard(data, n.sha(data))
        artifacts.assert_not_called()
        self.assertFalse(caught.exception.evidence['node_launched'])

    def mock_complete(self, traffic=False, failure=None):
        """Orchestration oracle ONLY, never a claim about CJS/OS behavior."""
        roots = []
        calls = []
        class Receiver:
            def __enter__(self):
                return self
            def __exit__(self, *_):
                pass
            def setsockopt(self, *_):
                pass
            def bind(self, address):
                self.address = address
            def listen(self, *_):
                pass
            def setblocking(self, *_):
                pass
            def getsockname(self):
                return self.address[0], 12345
            def accept(self):
                if traffic:
                    return self, ('synthetic', 12345)
                raise BlockingIOError()
            def recvfrom(self, *_):
                if traffic:
                    return b'synthetic', ('synthetic', 12345)
                raise BlockingIOError()
            def close(self):
                pass

        def target(command, cwd, env, **bounds):
            roots.append(cwd.parent)
            calls.append(command)
            if failure:
                raise failure
            if command[-1] == '--version':
                return 0, n.VERSION, b'', 0.1
            mode = command[command.index(str(cwd.parent / 'probe.cjs')) + 1]
            labels = n._FS if mode == 'filesystem' else n._NET[mode]
            return 0, ''.join(label + ':PASS\n' for label in sorted(labels)).encode(), b'', 0.1

        with mock.patch.object(n.socket, 'socket', side_effect=lambda *_: Receiver()), \
                mock.patch.object(n.c.owner, 'bounded', target):
            data = n.encoded(self.review)
            try:
                return n.run_guard(data, n.sha(data)), calls
            finally:
                self.assertTrue(roots)
                self.assertTrue(all(not root.exists() for root in roots))

    def test_mock_complete_orchestration_and_empty_receivers(self):
        evidence, calls = self.mock_complete()
        self.assertEqual(len(calls), 4)
        self.assertEqual(set(evidence['checks']), n.REQUIRED)
        self.assertTrue(all(value == 'observed-pass' for value in evidence['checks'].values()))
        self.assertEqual(evidence['cleanup'], 'verified-owned-artifacts-removed')
        self.assertFalse(evidence['typescript_launched'])
        self.assertFalse(evidence['host_launched'])

    def test_mock_receiver_traffic_fails_closed_even_after_all_target_passes(self):
        with self.assertRaises(n.c.Blocked) as caught:
            self.mock_complete(traffic=True)
        self.assertEqual(caught.exception.evidence['result'], 'blocked')
        self.assertEqual(caught.exception.evidence['checks']['no-receiver-traffic'], 'NOT_RUN')

    def test_mock_cancel_timeout_dependency_failure_allow_clean_fresh_recovery(self):
        for error in (n.c.Canceled(), ValueError('worker timeout'), OSError('synthetic dependency')):
            with self.subTest(error=type(error).__name__), self.assertRaises(n.c.Blocked) as caught:
                self.mock_complete(failure=error)
            self.assertEqual(caught.exception.evidence['cleanup'], 'verified-or-not-launched')
            self.assertFalse(n.c._QUARANTINED)
        result, _ = self.mock_complete()
        self.assertEqual(result['cleanup'], 'verified-owned-artifacts-removed')

    def test_collect_is_static_bounded_and_revalidation_never_rediscovers(self):
        def inspect(p):
            if p == self.node:
                return [str(self.alias / 'lib' / lib.name) for lib in self.libraries], []
            return ['/usr/lib/libSystem.B.dylib'], []
        with mock.patch.object(n, 'inspect', inspect):
            runtime = n.collect_runtime()
        self.assertEqual(set(runtime['files']), set(self.review['runtime']['files']))
        self.assertEqual(len(runtime['aliases']), 1)
        with mock.patch.object(n, 'collect_runtime', side_effect=AssertionError('rediscovery')), \
                mock.patch.object(n, 'inspect', side_effect=AssertionError('rediscovery')):
            self.approve_fixture()
        with mock.patch.object(n, 'FILE_CAP', 1), self.assertRaises(n.c.Blocked):
            n.file_record(self.node)
        with mock.patch.object(n, 'TOTAL_CAP', 1), self.assertRaises(n.c.Blocked):
            n.collect_runtime()


class PortableModels(unittest.TestCase):
    def test_import_is_inert(self):
        spec = importlib.util.spec_from_file_location('_inert_node_candidate', Path(n.__file__))
        module = importlib.util.module_from_spec(spec)
        with mock.patch.object(subprocess, 'run', side_effect=AssertionError('static execution')), \
                mock.patch.object(n.c.owner, 'bounded', side_effect=AssertionError('launch')):
            spec.loader.exec_module(module)

    def test_environment_is_replacement_with_explicit_cache_disable(self):
        with mock.patch.dict(os.environ, {'NODE_OPTIONS': '--require=bad', 'NODE_ENV': 'development',
                'NODE_PATH': '/bad', 'NODE_COMPILE_CACHE': '/bad', 'NODE_DISABLE_COMPILE_CACHE': '0',
                'DYLD_INSERT_LIBRARIES': '/bad', 'OPENSSL_CONF': '/bad', 'NODE_ICU_DATA': '/bad',
                'NODE_V8_COVERAGE': '/bad', 'SYNTHETIC_SECRET': 'bad'}):
            env = n.clean_env(Path('/owned'))
        self.assertEqual(env, {**n.c.clean_env(Path('/owned')), 'NODE_DISABLE_COMPILE_CACHE': '1'})

    def test_version_protocol_is_exact_ascii_single_line(self):
        n.parse_version(0, b'v24.10.0\n', b'')
        for code, out, err in ((1, n.VERSION, b''), (0, b'v24.10.0', b''),
            (0, b'v24.10.0\r\n', b''), (0, n.VERSION * 2, b''), (0, b'\xff', b''),
            (0, n.VERSION, b'warning'), (0, b' v24.10.0\n', b'')):
            with self.assertRaises(n.c.Blocked):
                n.parse_version(code, out, err)

    def test_strict_observation_protocol_includes_all_actual_candidate_labels(self):
        for labels in (n._FS, *n._NET.values()):
            data = ''.join(label + ':PASS\n' for label in sorted(labels)).encode()
            self.assertEqual(set(n.c.parse_checks(data, labels)), labels)
            for invalid in (data[:-1], data + b'extra:PASS\n', b'', data + data,
                            data.replace(b':PASS', b':FAIL', 1)):
                with self.assertRaises(n.c.Blocked):
                    n.c.parse_checks(invalid, labels)

    def test_static_parser_ignores_dylib_id_and_resolves_closed_rpath_subset(self):
        text = '''synthetic:
Load command 0
          cmd LC_ID_DYLIB
         name /not/a/load (offset 24)
Load command 1
          cmd LC_LOAD_DYLIB
         name @rpath/libcommon.dylib (offset 24)
Load command 2
          cmd LC_RPATH
         path @loader_path/../lib (offset 12)
'''
        loads, rpaths = n.macho_commands(text)
        self.assertEqual(loads, ['@rpath/libcommon.dylib'])
        self.assertEqual(n.linked_path(loads[0], Path('/synthetic/lib'), rpaths),
                         Path('/synthetic/lib/libcommon.dylib'))
        self.assertEqual(n.linked_path('@loader_path/data.dylib', Path('/synthetic/lib'), []),
                         Path('/synthetic/lib/data.dylib'))
        for name, paths in (('@executable_path/a', []), ('@rpath/a', []),
                            ('@rpath/a', ['@loader_path/../lib', '/unapproved'])):
            with self.assertRaises(n.c.Blocked):
                n.linked_path(name, Path('/synthetic/lib'), paths)
        with self.assertRaises(n.c.Blocked):
            n.macho_commands(text + 'Load command 3\n          cmd LC_DYLD_ENVIRONMENT\n')

    def test_unsupported_platform_missing_tool_and_no_cli_fail_closed(self):
        for system, machine in (('Linux', 'arm64'), ('Darwin', 'x86_64')):
            with mock.patch.object(n.platform, 'system', return_value=system), \
                    mock.patch.object(n.platform, 'machine', return_value=machine), \
                    mock.patch.object(n.c, 'artifacts') as artifacts:
                with self.assertRaises(n.c.Blocked):
                    n.run_guard(b'{}', '0' * 64)
                artifacts.assert_not_called()
        with mock.patch.object(n.platform, 'system', return_value='Darwin'), \
                mock.patch.object(n.platform, 'machine', return_value='arm64'), \
                mock.patch.object(n.c, 'SANDBOX', Path('/synthetic/missing')):
            with self.assertRaises(n.c.Blocked):
                n.require_platform()
        # API accepts two authority inputs only: no executable/profile/CLI/budget.
        with self.assertRaises(TypeError):
            n.run_guard(b'{}', '0' * 64, executable='/bin/sh')


if __name__ == '__main__':
    unittest.main()
