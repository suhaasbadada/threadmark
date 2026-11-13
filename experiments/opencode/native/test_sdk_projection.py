"""PURE synthetic projections; no genuine SDK, compiler, Node or sandbox runs."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import sdk_projection as q


def synthetic():
    output = {'node_modules/synthetic/package.json': b'{"name":"synthetic","version":"1.0.0","exports":{"./*":null},"imports":{"#x":"./nested/x.d.ts"}}',
        'node_modules/synthetic/nested/package.json': b'{"type":"module","version":"2.0.0"}',
        'node_modules/synthetic/nested/x.d.ts': b'export type X = string;\n',
        '__compiler_roots/sdk_positive.tsx': b'export {};\n',
        '__compiler_roots/sdk_negative.ts': b'export {};\n',
        q.AMBIENT[0]: b'declare interface EmscriptenModule {}\n',
        q.AMBIENT[1]: b'declare namespace NodeJS {}\n',
        '__notices/synthetic/LICENSE': b'Synthetic notice\n'}
    roles = {name: ('complete_metadata' if name.endswith('.json') else
        'external_authentic_source_notice' if name.endswith('LICENSE') else
        'owned_fixture' if name.startswith('__compiler_roots/') else 'declaration') for name in output}
    return output, roles, {'synthetic': '__notices/synthetic/LICENSE'}, {}


class ProjectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.parent = Path(self.temp.name).resolve()
        self.root = self.parent / 'sdk-"(allow default)-root'
        self.addCleanup(patch.stopall)
        patch.object(q, 'PRIVATE_PARENT', self.parent).start()
        patch.object(q, 'selected', return_value=synthetic()).start()

    def prepare(self):
        self.projection = q.materialize(self.root, {})
        return self.projection

    def validate(self, **kwargs):
        q.validate(self.root, self.projection['files'], self.projection['sourceNoticeMappings'], **kwargs)

    def test_preserves_whole_nested_metadata_and_exact_notice_location(self):
        self.prepare()
        for name, data in synthetic()[0].items():
            self.assertEqual((self.root / name).read_bytes(), data)
        self.assertFalse((self.root / 'node_modules/synthetic/LICENSE').exists())
        self.validate()
        self.assertFalse((self.root / 'INCOMPLETE').exists())
        self.assertEqual(json.loads((self.root / 'ledger.json').read_bytes())['executionApproved'], False)

    def test_configs_are_fixed_absolute_and_no_escape_options(self):
        self.prepare()
        for mode in ('positive', 'negative'):
            config = json.loads((self.root / (mode + '.json')).read_bytes())
            self.assertEqual(config['compilerOptions'], {**q.s.OPTIONS, 'listFiles': True,
                'pretty': False, 'typeRoots': [str(self.root / q.EMPTY)]})
            self.assertEqual(len(config['files']), 3)
            self.assertTrue(all(name.startswith(str(self.root) + '/') for name in config['files']))
            self.assertFalse(any(key in config for key in ('extends', 'references')))
            self.assertEqual(list((self.root / q.EMPTY).iterdir()), [])

    def test_fresh_only_no_overwrite(self):
        self.prepare()
        before = (self.root / 'ledger.json').read_bytes()
        with self.assertRaises(FileExistsError): self.prepare()
        self.assertEqual((self.root / 'ledger.json').read_bytes(), before)

    def test_direct_approved_parent_only(self):
        other = self.parent / 'nested'
        other.mkdir()
        with self.assertRaises(q.c.Blocked): q.materialize(other / 'sdk', {})

    def test_backslash_parent_and_dot_spelling_rejected(self):
        for path in (str(self.root) + '\\x', str(self.parent) + '/./sdk', str(self.parent) + '//sdk'):
            with self.subTest(path=path), self.assertRaises((ValueError, q.c.Blocked)):
                q.materialize(path, {})

    def test_symlink_ancestor_rejected(self):
        link = self.parent / 'link'
        link.symlink_to(self.parent, target_is_directory=True)
        with self.assertRaises(ValueError): q.materialize(link / 'sdk', {})

    def test_all_files_0400_directories_0700(self):
        self.prepare()
        for parent, dirs, files in os.walk(self.root):
            for name in dirs: self.assertEqual((Path(parent) / name).stat().st_mode & 0o777, 0o700)
            for name in files: self.assertEqual((Path(parent) / name).stat().st_mode & 0o777, 0o400)

    def test_extra_file_directory_ambient_or_collision_rejected(self):
        self.prepare()
        for name, directory in [('extra', False), ('extra', True), (q.EMPTY + '/ambient.d.ts', False)]:
            path = self.root / name
            if directory: path.mkdir()
            else: path.write_bytes(b'export {};')
            try:
                with self.subTest(name=name), self.assertRaises(q.c.Blocked): self.validate()
            finally:
                if directory: path.rmdir()
                else: path.unlink()

    def test_file_and_directory_modes_rejected(self):
        self.prepare()
        for path, bad, good in [(self.root, 0o755, 0o700),
                (self.root / 'node_modules', 0o755, 0o700),
                (self.root / 'positive.json', 0o500, 0o400)]:
            path.chmod(bad)
            try:
                with self.subTest(path=path.name), self.assertRaises(q.c.Blocked): self.validate()
            finally: path.chmod(good)

    def test_hardlink_and_symlink_rejected(self):
        self.prepare()
        original = self.root / 'positive.json'
        data = original.read_bytes()
        outside = self.parent / 'outside'
        outside.write_bytes(data)
        outside.chmod(0o400)
        original.unlink()
        os.link(outside, original)
        with self.assertRaises(q.c.Blocked): self.validate()
        original.unlink()
        original.symlink_to(outside)
        with self.assertRaises(q.c.Blocked): self.validate()

    def test_metadata_fixture_notice_and_config_tampering_rejected(self):
        self.prepare()
        names = ['node_modules/synthetic/nested/package.json', '__compiler_roots/sdk_positive.tsx',
                 '__notices/synthetic/LICENSE', 'positive.json', 'ledger.json']
        for name in names:
            path = self.root / name
            data = path.read_bytes()
            path.chmod(0o600)
            path.write_bytes(data + b' ')
            path.chmod(0o400)
            try:
                with self.subTest(name=name), self.assertRaises(q.c.Blocked): self.validate()
            finally:
                path.chmod(0o600); path.write_bytes(data); path.chmod(0o400)

    def test_marker_remains_during_last_whole_validation(self):
        real = q.validate
        def late(root, records, mappings, **kwargs):
            self.assertTrue((root / 'INCOMPLETE').exists())
            self.assertTrue((root / 'ledger.json').exists())
            real(root, records, mappings, **kwargs)
            raise KeyboardInterrupt()
        with patch.object(q, 'validate', side_effect=late), self.assertRaises(KeyboardInterrupt): self.prepare()
        self.assertTrue((self.root / 'INCOMPLETE').exists())

    def test_cancel_during_copy_retains_marker_no_ledger(self):
        write = q.t.write_file
        def interrupted(root, name, data):
            if name != 'INCOMPLETE': raise KeyboardInterrupt()
            write(root, name, data)
        with patch.object(q.t, 'write_file', side_effect=interrupted), self.assertRaises(KeyboardInterrupt): self.prepare()
        self.assertTrue((self.root / 'INCOMPLETE').exists())
        self.assertFalse((self.root / 'ledger.json').exists())

    def test_incomplete_marker_never_accepted_for_launch(self):
        self.prepare()
        (self.root / 'INCOMPLETE').write_bytes(q.MARKER)
        (self.root / 'INCOMPLETE').chmod(0o400)
        with self.assertRaises(q.c.Blocked): self.validate()
        self.validate(preparing=True)

    def test_fsync_failure_after_marker_unlink_restores_incomplete(self):
        real = os.fsync
        def failing(fd):
            if self.root.exists() and (self.root / 'ledger.json').exists() and not (self.root / 'INCOMPLETE').exists():
                raise OSError('synthetic late fsync failure')
            real(fd)
        with patch.object(q.os, 'fsync', side_effect=failing), self.assertRaises(OSError): self.prepare()
        self.assertTrue((self.root / 'INCOMPLETE').exists())

    def test_close_failure_after_commit_restores_incomplete_without_retry(self):
        real = os.close
        failed = []
        def failing(fd):
            if not failed and self.root.exists() and (self.root / 'ledger.json').exists() and not (self.root / 'INCOMPLETE').exists():
                failed.append(fd)
                real(fd)
                raise OSError('synthetic close failure after close')
            real(fd)
        with patch.object(q.os, 'close', side_effect=failing), self.assertRaises(OSError): self.prepare()
        self.assertEqual(len(failed), 1)
        self.assertTrue((self.root / 'INCOMPLETE').exists())

    def test_unsafe_selected_paths_rejected_before_creation(self):
        for name in ('../escape', 'node_modules/X/index.d.ts', 'bad\\path'):
            output, roles, mappings, observed = synthetic()
            output[name] = b'export {};'
            roles[name] = 'declaration'
            if name.startswith('node_modules/X'): output['node_modules/x/index.d.ts'] = b'x'; roles['node_modules/x/index.d.ts'] = 'declaration'
            with patch.object(q, 'selected', return_value=(output, roles, mappings, observed)):
                with self.subTest(name=name), self.assertRaises(ValueError): self.prepare()
            self.assertFalse(self.root.exists())

    def test_invalid_config_mode(self):
        with self.assertRaises(q.c.Blocked): q.config(self.root, 'arbitrary')

    def test_fixed_inputs_require_exact_external_selection_and_plan_bytes(self):
        directory = self.parent / 'inputs'; directory.mkdir()
        (directory / 'input-plan.json').write_bytes(b'{}')
        (directory / 'candidate.json').write_bytes(b'{}')
        with patch.object(q, 'INPUT_ROOT', directory), self.assertRaises(q.c.Blocked): q.fixed_inputs()

    def test_source_bindings_include_all_new_helpers_and_authenticity_inputs(self):
        names = {Path(name).name for name in q.source_bindings()}
        self.assertTrue({'sdk_projection.py', 'sdk_compiler_containment.py', 'sdk_notice_receipt.py',
            'sdk_transitive_notice.py', 'package-lock.json', 'package.json', 'sdk_positive.tsx',
            'sdk_negative.ts', 'sdk-notice-provenance.json', 'sdk-transitive-notice-provenance.json'}.issubset(names))


if __name__ == '__main__': unittest.main()
