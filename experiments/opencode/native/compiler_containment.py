"""Fixed compiler-only candidate. Import/preparation are inert; execution CLOSED.

No CLI or arbitrary executable/config/source inputs. Review authority is external,
not authenticated by this API. No SDK graph is selected or represented as proved.
"""
import base64
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import time

import compiler_plan as p
import node_containment as n
import project_types as t

c = n.c
ARCHIVE_SHA = '33cd0ee1beaa8c9e9d15a9da836c62ddea4c34a42d7c2d349dbc80d94165d22a'
PRIVATE_PARENT = Path('/private/var/folders/2y/n6f_6bjj2q1_3byq_z4dk9640000gn/T/opencode')
ROLES = {'lib/tsc.js': 'compiler_entrypoint', 'lib/_tsc.js': 'compiler_implementation',
         'package.json': 'complete_metadata', 'LICENSE.txt': 'license',
         'ThirdPartyNoticeText.txt': 'third_party_notice'}
MODES = ('version', 'positive', 'negative')
OUTPUT_CAP = 16 * 1024 * 1024
HERE = Path(__file__).parent
_PRIVATE_EVIDENCE = []  # Operator-only discovery; NEVER include paths in public evidence.


class PrivateEvidence:
    """One fresh retained sink outside ALL target read/write allowances.

    Same-UID parent trust matches the existing artifact contract. Atomic exclusive
    nofollow 0400 writes; never overwrite/delete failed or interrupted evidence.
    No caller-selected destination or general target-output logging interface.
    """
    def __init__(self, review_digest):
        parent = p.absolute(str(compiler_path(PRIVATE_PARENT)), directory=True)
        self.path = Path(c.tempfile.mkdtemp(prefix='threadmark-compiler-evidence-', dir=parent))
        _PRIVATE_EVIDENCE.append(self.path)
        self.fd = None
        self.remaining = OUTPUT_CAP
        self.identity = self.path.lstat()
        if (not stat.S_ISDIR(self.identity.st_mode)
                or stat.S_IMODE(self.identity.st_mode) != 0o700
                or self.identity.st_uid != os.getuid()):
            raise c.Blocked('private evidence preparation failed')
        self.fd = os.open(self.path, t.DIR_FLAGS)
        try:
            self.write('prepared.json', n.encoded({'schema': 1, 'state': 'prepared',
                       'reviewSha256': review_digest, 'outputCap': OUTPUT_CAP}))
        except BaseException:
            self.close()
            raise

    def write(self, name, data):
        allowed = {'prepared.json', 'result.json'} | {
            mode + '-' + suffix for mode in MODES for suffix in (
                'before.json', 'after.json', 'stdout.bin', 'stderr.bin',
                'capture.json', 'verdict.json')}
        if name not in allowed:
            raise c.Blocked('fixed private evidence name required')
        current = self.path.lstat()
        opened = os.fstat(self.fd)
        if ((current.st_dev, current.st_ino) != (opened.st_dev, opened.st_ino)
                or (current.st_dev, current.st_ino) !=
                (self.identity.st_dev, self.identity.st_ino)
                or stat.S_IMODE(current.st_mode) != 0o700):
            raise c.Blocked('private evidence identity drift')
        # Both names are internal fixed names, never derived from output/errors.
        pending = name + '.pending'
        t.write_file(self.fd, pending, data)
        # Reserve final name exclusively before atomic replacement; an existing
        # final name fails closed rather than silently replacing old evidence.
        t.write_file(self.fd, name, b'')
        os.rename(pending, name, src_dir_fd=self.fd, dst_dir_fd=self.fd)
        os.fsync(self.fd)

    def capture(self, mode, code, output, diagnostics):
        if (mode not in MODES or type(code) is not int or not isinstance(output, bytes)
                or not isinstance(diagnostics, bytes)):
            raise c.Blocked('invalid owner capture')
        size = len(output) + len(diagnostics)
        out = output[:self.remaining]
        err = diagnostics[:max(0, self.remaining - len(out))]
        self.write(mode + '-stdout.bin', out)
        self.write(mode + '-stderr.bin', err)
        self.remaining -= len(out) + len(err)
        self.write(mode + '-capture.json', n.encoded({
            'exitCode': code, 'stdoutBytes': len(output), 'stderrBytes': len(diagnostics),
            'retainedBytes': len(out) + len(err), 'truncated': size > len(out) + len(err)}))
        if size > len(out) + len(err):
            raise c.Blocked('aggregate compiler budget exceeded')

    def close(self):
        if self.fd is not None:
            descriptor = self.fd
            self.fd = None
            os.close(descriptor)  # Never retry close on a possibly reused fd.


def failure_code(error):
    """Closed vocabulary only; never stringify arbitrary exceptions or output."""
    if isinstance(error, (c.Canceled, KeyboardInterrupt)):
        return 'canceled'
    if isinstance(error, c.owner.CleanupUnverified):
        return 'owner-cleanup-unverified'
    recognized = {
        'worker timeout': 'owner-timeout',
        'worker output budget exceeded': 'owner-output-cap',
        'worker launch or I/O failed': 'owner-launch-io',
        'unexpected compiler stderr': 'compiler-stderr',
        'compiler version failed': 'compiler-version',
        'partial compiler output': 'compiler-partial-output',
        'unrecognized/duplicate/outside compiler output': 'compiler-output-rejected',
        'compiler semantics/consumed root failed': 'compiler-semantics-closure',
        'aggregate compiler budget exhausted': 'aggregate-budget',
        'aggregate compiler budget exceeded': 'aggregate-budget',
        'postvalidation incomplete; retained': 'postvalidation-incomplete',
        'owned artifact cleanup unverified': 'artifact-cleanup-unverified',
    }
    if type(error) in (ValueError, c.Blocked) and len(error.args) == 1 and type(error.args[0]) is str:
        return recognized.get(error.args[0], 'unrecognized-failure')
    return 'unrecognized-failure'


def compiler_path(value):
    """Exact POSIX spelling shared by config, policy and TypeScript normalizePath.

    Check before Path can erase dot/empty components. No backslash-to-slash or
    other canonicalization is allowed; SBPL paths additionally require ASCII.
    """
    text = str(value)
    if not text.startswith('/') or text == '/':
        raise c.Blocked('compiler path must be absolute and non-root')
    t.safe_path(text[1:])
    c.quoted(text)
    return Path(text)


@contextmanager
def artifacts():
    """Compiler-local naming; preserve shared retained-owner lifecycle verbatim.

    The measured C/Node prefix intentionally includes a POSIX backslash, which
    TypeScript normalizes into a separator. Never change those measured sources
    or nest under their unrepresentable root. Share their quarantine/retention.
    """
    if c._QUARANTINED or c.owner._QUARANTINED:
        raise c.Blocked('cleanup unverified; experiment quarantined')
    parent = p.absolute(str(compiler_path(PRIVATE_PARENT)), directory=True)
    root = Path(c.tempfile.mkdtemp(prefix='threadmark-compiler-"(allow default)-', dir=parent))
    try:
        compiler_path(root)
        yield root
    except c.owner.CleanupUnverified:
        c._QUARANTINED = True
        raise
    finally:
        if c._QUARANTINED or c.owner._QUARANTINED:
            c._RETAINED_ARTIFACTS.append(root)
        else:
            mask = c.signal.pthread_sigmask(c.signal.SIG_BLOCK, {c.signal.SIGTERM, c.signal.SIGINT})
            try:
                c.shutil.rmtree(root)
            except OSError:
                c._QUARANTINED = True
                c._RETAINED_ARTIFACTS.append(root)
                raise c.Blocked('owned artifact cleanup unverified') from None
            finally:
                c.signal.pthread_sigmask(c.signal.SIG_SETMASK, mask)


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise c.Blocked('duplicate JSON key')
        result[key] = value
    return result


def decoded(data):
    return json.loads(data.decode('utf-8', errors='strict'), object_pairs_hook=unique)


def fixture(mode):
    if mode not in ('positive', 'negative'):
        raise c.Blocked('fixed fixture required')
    data = p.regular(HERE / ('compiler_' + mode + '.ts'))
    text = data.decode('utf-8-sig', errors='strict')
    if '\0' in text or re.search(r'@ts-(?:ignore|nocheck|expect-error)', text, re.I):
        raise c.Blocked('source suppression/encoding rejected')
    return data


def sources():
    return {str(path.resolve()): n.file_record(path.resolve()) for path in (
        Path(__file__), Path(t.__file__), Path(p.__file__),
        HERE / 'compiler_positive.ts', HERE / 'compiler_negative.ts')}


def selected(archive):
    """Separate exact compiler pin, NOT a relaxed declaration projector.

    Full tar preflight precedes selection. JS is immutable data, never chmod exec.
    Compressed SHA-256 AND SHA-512 are checked before even entering the inspector.
    """
    if (not isinstance(archive, bytes) or len(archive) > t.ARCHIVE_LIMIT
            or n.sha(archive) != ARCHIVE_SHA
            or 'sha512-' + base64.b64encode(hashlib.sha512(archive).digest()).decode()
            != p.COMPILER_INTEGRITY):
        raise c.Blocked('compiler archive pin mismatch')
    files, _, _ = t.inspect(archive, p.COMPILER_INTEGRITY)
    metadata = decoded(files['package/package.json'])
    if (metadata.get('name'), metadata.get('version'), metadata.get('license')) != (
            'typescript', '6.0.3', 'Apache-2.0'):
        raise c.Blocked('compiler metadata mismatch')
    libs = {name.removeprefix('package/') for name in files
            if re.fullmatch(r'package/lib/lib\.[a-z0-9.]+\.d\.ts', name)}
    if len(libs) != 107:
        raise c.Blocked('default library inventory drift')
    roles = {**ROLES, **{name: 'default_library' for name in libs}}
    output = {name: files['package/' + name] for name in sorted(roles)}
    if any(not data for data in output.values()):
        raise c.Blocked('empty compiler artifact')
    records = {name: {'sha256': n.sha(data), 'role': roles[name], 'size': len(data)}
               for name, data in output.items()}
    return output, records


def materialize(destination, archive):
    """Already-owned authentic archive only; no acquisition or execution.

    Fresh 0700 root; exclusive dirfd/nofollow 0400 writes; marker spans validation.
    Parents are trusted against same-UID races. Never mutate the archive.
    """
    destination = compiler_path(destination)
    destination = p.absolute(str(destination))
    if destination.parent != PRIVATE_PARENT:
        raise c.Blocked('fresh compiler root must be inside approved private parent')
    output, records = selected(archive)
    ledger = n.encoded({'state': 'prepared_not_compiled', 'archiveSha256': ARCHIVE_SHA,
                        'integrity': p.COMPILER_INTEGRITY, 'files': records})
    parent = os.open(destination.parent, t.DIR_FLAGS)
    try:
        os.mkdir(destination.name, mode=0o700, dir_fd=parent)
        root = os.open(destination.name, t.DIR_FLAGS, dir_fd=parent)
    finally:
        os.close(parent)
    try:
        t.write_file(root, 'INCOMPLETE', b'incomplete; not usable\n')
        for name, data in output.items():
            t.write_file(root, name, data)
        t.verify_files(root, {'files': [{'path': name, 'sha256': item['sha256']}
                                      for name, item in records.items()]})
        t.write_file(root, 'ledger.pending', ledger)
        t.verify_files(root, {'files': [{'path': 'ledger.pending', 'sha256': n.sha(ledger)}]})
        os.rename('ledger.pending', 'ledger.json', src_dir_fd=root, dst_dir_fd=root)
        os.fsync(root)
        validate_compiler(str(destination), records, preparing=True)
        # Final commit step. A stale marker after interruption remains closed;
        # execution independently validates the entire prepared tree regardless.
        os.unlink('INCOMPLETE', dir_fd=root)
    finally:
        os.close(root)
    return records


def validate_compiler(name, records, *, preparing=False):
    root = p.absolute(str(compiler_path(name)), directory=True)
    if root.parent != PRIVATE_PARENT or stat.S_IMODE(root.stat().st_mode) != 0o700:
        raise c.Blocked('compiler root mismatch')
    p.inventory({name: value['sha256'] for name, value in records.items()})
    if (len(records) != 112 or set(ROLES) - set(records)
            or sum(value['role'] == 'default_library' for value in records.values()) != 107):
        raise c.Blocked('compiler selection mismatch')
    for name, item in records.items():
        n.keys(item, {'sha256', 'role', 'size'})
        expected = ROLES.get(name, 'default_library' if re.fullmatch(
            r'lib/lib\.[a-z0-9.]+\.d\.ts', name) else None)
        if (expected is None or item['role'] != expected or type(item['size']) is not int
                or not 0 < item['size'] <= n.FILE_CAP):
            raise c.Blocked('compiler role mismatch')
    ledger = n.encoded({'state': 'prepared_not_compiled', 'archiveSha256': ARCHIVE_SHA,
                        'integrity': p.COMPILER_INTEGRITY, 'files': records})
    expected = {name: item['sha256'] for name, item in records.items()}
    if preparing:
        expected['INCOMPLETE'] = n.sha(b'incomplete; not usable\n')
    p.tree(root, {**expected, 'ledger.json': n.sha(ledger)})
    for name in (*expected, 'ledger.json'):
        info = (root / name).lstat()
        if (stat.S_IMODE(info.st_mode) != 0o400 or info.st_nlink != 1
                or name in records and info.st_size != records[name]['size']):
            raise c.Blocked('compiler inert mode/size mismatch')
    for parent, directories, _ in os.walk(root):
        if any(stat.S_IMODE((Path(parent) / d).lstat().st_mode) != 0o700 for d in directories):
            raise c.Blocked('compiler directory mode mismatch')
    metadata = decoded(p.regular(root / 'package.json'))
    if (metadata.get('name'), metadata.get('version'), metadata.get('license')) != (
            'typescript', '6.0.3', 'Apache-2.0'):
        raise c.Blocked('compiler metadata mismatch')


def prepare_review(archive, node_bytes, node_digest, destination):
    """Inert candidate only. Returned hash is NOT independent review/approval."""
    n.read_review(node_bytes, node_digest)
    fixture('positive')
    fixture('negative')
    records = materialize(destination, archive)
    review = {'schema': 1, 'kind': 'fixed-compiler-only', 'compilerRoot': str(destination),
              'archiveSha256': ARCHIVE_SHA, 'integrity': p.COMPILER_INTEGRITY,
              'files': records, 'nodeReview': node_bytes.decode('ascii'),
              'nodeReviewSha256': node_digest, 'sources': sources(),
              'fixtures': {mode: n.sha(fixture(mode)) for mode in MODES[1:]}}
    data = n.encoded(review)
    read_review(data, n.sha(data))  # Validation, explicitly NOT authorization.
    return data


def read_review(data, approved_digest):
    if (not isinstance(data, bytes) or len(data) > 4 * 1024 * 1024
            or not isinstance(approved_digest, str)
            or not re.fullmatch('[0-9a-f]{64}', approved_digest)
            or n.sha(data) != approved_digest):
        raise c.Blocked('external compiler review digest mismatch')
    review = decoded(data)
    n.keys(review, {'schema', 'kind', 'compilerRoot', 'archiveSha256', 'integrity',
                    'files', 'nodeReview', 'nodeReviewSha256', 'sources', 'fixtures'})
    if (type(review['schema']) is not int or review['schema'] != 1
            or review['kind'] != 'fixed-compiler-only' or review['archiveSha256'] != ARCHIVE_SHA
            or review['integrity'] != p.COMPILER_INTEGRITY):
        raise c.Blocked('fixed compiler identity required')
    revalidate(review)
    return review


def revalidate(review):
    n.read_review(review['nodeReview'].encode('ascii'), review['nodeReviewSha256'])
    validate_compiler(review['compilerRoot'], review['files'])
    if review['sources'] != sources() or review['fixtures'] != {
            mode: n.sha(fixture(mode)) for mode in MODES[1:]}:
        raise c.Blocked('compiler source drift')


def config(root, mode):
    root = compiler_path(root)
    if mode not in MODES[1:]:
        raise c.Blocked('fixed config required')
    return n.encoded({'compilerOptions': {'strict': True, 'noEmit': True,
        'skipLibCheck': False, 'skipDefaultLibCheck': False, 'types': [],
        'typeRoots': [str(root / 'workspace' / 'empty-types')], 'target': 'ESNext',
        'module': 'ESNext', 'moduleResolution': 'Bundler', 'listFiles': True, 'pretty': False},
        'files': [str(root / 'workspace' / ('compiler_' + mode + '.ts'))],
        'include': [], 'exclude': []})


def policy(root, review):
    root = compiler_path(root)
    compiler_path(review['compilerRoot'])
    node = decoded(review['nodeReview'].encode('ascii'))
    baseline = n.policy(root, node)
    phantom = {root / 'probe.cjs', root / 'read-canary'}
    rules = [rule for rule in baseline.rules if rule.path not in phantom]
    # Measured positive attempt failed at Node uv_cwd. Permit reading ONLY the
    # owned cwd directory itself, not its descendants or any host directory.
    rules.append(c.Rule(('file-read*',), 'literal', root / 'workspace'))
    reads = {Path(review['compilerRoot']) / name for name in review['files']}
    reads.update(root / 'workspace' / name for name in (
        'compiler_positive.ts', 'compiler_negative.ts', 'positive.json', 'negative.json'))
    # Complete metadata/notices are preserved and literal-readable, not map-exec JS.
    rules.extend(c.Rule(('file-read*',), 'literal', path) for path in sorted(reads))
    metadata = {root / 'workspace' / 'empty-types'}
    for path in reads:
        metadata.update(path.parents)
    rules.extend(c.Rule(('file-read-metadata',), 'literal', path) for path in sorted(metadata))
    filesystem = c.Policy(tuple(rules)).serialize().replace(
        '; SYNTHETIC C baseline only; no Node/runtime inventory claim.',
        '; Measured Node public-system baseline; NOT minimum compiler/system closure.')
    names = ' '.join(c.quoted(name) for name in n.PAGE_SIZE_SYSCTLS + n.UNAME_SYSCTLS)
    return filesystem + '(allow sysctl-read (sysctl-name ' + names + '))\n'


def command(root, review, mode):
    root = compiler_path(root)
    compiler_path(review['compilerRoot'])
    if mode not in MODES:
        raise c.Blocked('fixed compiler attempt required')
    tail = ['--version'] if mode == 'version' else [
        '--project', str(root / 'workspace' / (mode + '.json'))]
    return [str(c.SANDBOX), '-f', str(root / 'guard.sb'), str(n.NODE),
            '--max-old-space-size=1024', '--openssl-config=' + str(root / 'openssl.cnf'),
            str(Path(review['compilerRoot']) / 'lib/tsc.js'), *tail]


def observe(mode, code, output, diagnostics, root, review):
    """Strict reported-program closure, not a trace of every metadata/system read."""
    if diagnostics:
        raise c.Blocked('unexpected compiler stderr')
    if mode == 'version':
        if code != 0 or output != b'Version 6.0.3\n':
            raise c.Blocked('compiler version failed')
        return {'version': '6.0.3'}
    if mode not in MODES[1:]:
        raise c.Blocked('unknown compiler result')
    text = output.decode('utf-8', errors='strict')
    if not text.endswith('\n') or '\r' in text or '\0' in text:
        raise c.Blocked('partial compiler output')
    source = root / 'workspace' / ('compiler_' + mode + '.ts')
    permitted = {str(Path(review['compilerRoot']) / name): name
                 for name, item in review['files'].items() if item['role'] == 'default_library'}
    permitted[str(source)] = 'owned-' + mode
    # tsc's default nonpretty diagnostic uses a cwd-relative filename.
    error = "compiler_negative.ts(1,7): error TS2322: Type 'string' is not assignable to type 'number'."
    consumed, errors = [], []
    for line in text.splitlines():
        if mode == 'negative' and line == error and not consumed and not errors:
            errors.append(2322)
        elif line in permitted and permitted[line] not in consumed:
            consumed.append(permitted[line])
        else:
            raise c.Blocked('unrecognized/duplicate/outside compiler output')
    expected_errors = [] if mode == 'positive' else [2322]
    if (code != (0 if mode == 'positive' else 2) or errors != expected_errors
            or set(consumed) != expected_libraries(review) | {'owned-' + mode}):
        raise c.Blocked('compiler semantics/consumed root failed')
    return {'diagnosticCodes': errors, 'programFiles': [
        {'role': name if name.startswith('owned-') else 'default_library',
         'relative': name, 'sha256': review['fixtures'][mode] if name.startswith('owned-')
         else review['files'][name]['sha256']} for name in consumed]}


def expected_libraries(review):
    """Fixed ESNext default roots' literal lib references, NOT generic TS resolution.

    This independent audit oracle covers only these import-free owned fixtures.
    Compiler output must match every expected library, not an arbitrary subset.
    """
    pending, seen = ['lib/lib.esnext.full.d.ts'], set()
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        item = review['files'].get(name)
        if not item or item['role'] != 'default_library':
            raise c.Blocked('missing default library reference')
        data = p.regular(Path(review['compilerRoot']) / name)
        if n.sha(data) != item['sha256']:
            raise c.Blocked('default library oracle drift')
        text = data.decode('utf-8-sig', errors='strict')
        pending.extend('lib/lib.' + ref + '.d.ts' for ref in
                       re.findall(r'^/// <reference lib="([a-z0-9.]+)"\s*/>\s*$', text, re.M))
        seen.add(name)
    return seen


def run_guard(review_bytes, approved_digest):
    """FUTURE reviewed fixed measurement; explicit parent authorization also required.

    Do not call from tests/CI. No automatic review, retry or permission broadening.
    """
    evidence = {'result': 'blocked', 'checks': {mode: 'NOT_RUN' for mode in MODES},
                'stage': 'preflight', 'attempts': {},
                'typescript_launched': False, 'host_launched': False,
                'programFileClosure': 'NOT established',
                'limitations': ['SDK/type/runtime closure NOT established',
                    'listFiles is NOT all metadata/system reads', 'old-space is NOT total RSS',
                    'same-UID parents and no concurrent Homebrew updates trusted']}
    deadline = time.monotonic() + 110
    sink = None
    try:
        n.require_platform()
        review = read_review(review_bytes, approved_digest)
        evidence['stage'] = 'evidence-preparation'
        sink = PrivateEvidence(approved_digest)  # Failure MUST precede any target launch.
        evidence['stage'] = 'artifact-preparation'
        _run(review, evidence, deadline, sink)
    except (Exception, KeyboardInterrupt) as error:
        evidence['failureCode'] = failure_code(error)
        evidence['cleanup'] = ('unverified-retained' if c._QUARANTINED or c.owner._QUARANTINED
                                else 'verified-owned-artifacts-removed' if evidence['typescript_launched']
                                else 'not-launched')
        if sink is not None:
            try:
                sink.write('result.json', n.encoded(evidence))
            except (Exception, KeyboardInterrupt):
                evidence['retention'] = 'incomplete-retained'
            finally:
                try:
                    sink.close()
                except (Exception, KeyboardInterrupt):
                    evidence['retention'] = 'incomplete-retained'
        failure = c.Blocked('fixed compiler guard blocked')
        failure.evidence = evidence
        raise failure from None
    # A persisted record cannot prove that its own final fsync/close succeeded.
    # Keep it explicitly provisional; only a successful return supplies a receipt
    # binding this record and the approved candidate to terminal success.
    provisional = dict(evidence, result='compiler-checks-passed-unconfirmed',
                       stage='awaiting-successful-return',
                       requires='successful-call-receipt')
    provisional_bytes = n.encoded(provisional)
    try:
        sink.write('result.json', provisional_bytes)
        sink.close()
    except (Exception, KeyboardInterrupt):
        evidence.update(result='blocked', stage='evidence-finalization',
                        failureCode='evidence-retention', retention='incomplete-retained')
        failure = c.Blocked('fixed compiler guard blocked')
        failure.evidence = evidence
        raise failure from None
    finally:
        try:
            sink.close()
        except (Exception, KeyboardInterrupt):
            # A preceding write/close failure is already a sanitized blocked
            # result; closing must never replace it with raw exception repr.
            pass
    evidence['successReceipt'] = {'reviewSha256': approved_digest,
                                  'recordSha256': n.sha(provisional_bytes)}
    return evidence


def _run(review, evidence, deadline, sink):
    # Preflight/launch/init/IO counted; 10 s reserved in the 120 s envelope.
    remaining_output = OUTPUT_CAP
    with artifacts() as root, c.cancellation():
        (root / 'state').mkdir(mode=0o700)
        for name in c.STATE:
            (root / 'state' / name).mkdir(mode=0o700)
        (root / 'workspace').mkdir(mode=0o700)
        (root / 'workspace' / 'empty-types').mkdir(mode=0o700)
        protected = {'openssl.cnf': n.OPENSSL_CONFIG,
                     'guard.sb': policy(root, review).encode('ascii')}
        for mode in MODES[1:]:
            protected['workspace/compiler_' + mode + '.ts'] = fixture(mode)
            protected['workspace/' + mode + '.json'] = config(root, mode)
        for name, data in protected.items():
            n.create(root / name, data)
            (root / name).chmod(0o400)
        identities = {name: n.file_record(root / name) for name in protected}
        expected_tree = t.with_directories({name: False for name in protected})
        expected_tree.update({'state': True, **{'state/' + name: True for name in c.STATE},
                              'workspace/empty-types': True})
        protected_dirs = [root, *(root / name for name, is_dir in expected_tree.items() if is_dir)]

        def directory_identity(path):
            info = path.lstat()
            return [info.st_dev, info.st_ino, info.st_mode, info.st_uid]

        directory_records = {path: directory_identity(path) for path in protected_dirs}

        def validate_artifacts():
            revalidate(review)
            if any(directory_identity(path) != record for path, record in directory_records.items()):
                raise c.Blocked('artifact directory identity drift')
            actual = {}
            for parent, directories, files in os.walk(root, followlinks=False):
                for name in directories + files:
                    path = Path(parent) / name
                    relative = str(path.relative_to(root))
                    # Only state subtrees are writable; never follow links.
                    if relative.startswith('state/') and relative.split('/')[1] in c.STATE:
                        if relative.count('/') > 1:
                            continue
                    if stat.S_ISLNK(path.lstat().st_mode):
                        raise c.Blocked('artifact link drift')
                    actual[relative] = stat.S_ISDIR(path.lstat().st_mode)
            if actual != expected_tree or any(n.file_record(root / name) != record
                                              for name, record in identities.items()):
                raise c.Blocked('compiler artifact drift')

        def unchanged():
            try:
                validate_artifacts()
            except BaseException:
                if evidence['typescript_launched']:
                    c._QUARANTINED = True
                raise

        for mode in MODES:
            attempt = {'beforeValidation': 'pending', 'afterValidation': 'NOT_RUN',
                       'capture': 'NOT_RETURNED', 'exitCode': None, 'ownerCleanup': 'unknown'}
            evidence['attempts'][mode] = attempt
            evidence['stage'] = mode + '-before-validation'
            try:
                unchanged()
                attempt['beforeValidation'] = 'passed'
            except BaseException as error:
                attempt['beforeValidation'] = 'failed-or-interrupted'
                attempt['beforeValidationFailureCode'] = failure_code(error)
                raise
            sink.write(mode + '-before.json', n.encoded(attempt))
            remaining = deadline - time.monotonic()
            if remaining <= 0 or remaining_output <= 0:
                raise c.Blocked('aggregate compiler budget exhausted')
            evidence['typescript_launched'] = True  # Attempt, not bootstrap proof.
            evidence['stage'] = mode + '-owner'
            evidence['checks'][mode] = 'BLOCKED'
            try:
                try:
                    code, output, diagnostics, _ = c.owner.bounded(command(root, review, mode),
                        root / 'workspace', n.clean_env(root), timeout=remaining,
                        limit=remaining_output)
                except BaseException as error:
                    # Existing measured helper exposes NO partial-capture API on
                    # raises. Do not invent exit status or scrape exception text.
                    attempt['ownerFailureCode'] = failure_code(error)
                    attempt['capture'] = 'unavailable-owner-raised'
                    attempt['ownerCleanup'] = ('unknown' if isinstance(error, c.owner.CleanupUnverified)
                                               else 'verified-by-owner-finally')
                    raise
                attempt.update(exitCode=code if type(code) is int else None,
                               capture='returned', ownerCleanup='verified')
                evidence['stage'] = mode + '-evidence-retention'
                try:
                    sink.capture(mode, code, output, diagnostics)
                    attempt['capture'] = 'retained'
                except BaseException:
                    attempt['capture'] = 'incomplete-retained'
                    c._QUARANTINED = True
                    raise
                remaining_output -= len(output) + len(diagnostics)
            finally:
                try:
                    unchanged()
                    attempt['afterValidation'] = 'passed'
                except BaseException as error:
                    attempt['afterValidation'] = 'failed-or-interrupted'
                    attempt['afterValidationFailureCode'] = failure_code(error)
                    evidence['stage'] = mode + '-after-validation'
                    c._QUARANTINED = True
                    raise c.Blocked('postvalidation incomplete; retained') from None
                finally:
                    try:
                        sink.write(mode + '-after.json', n.encoded(attempt))
                    except BaseException:
                        c._QUARANTINED = True
                        raise
            if remaining_output < 0 or time.monotonic() > deadline:
                raise c.Blocked('aggregate compiler budget exceeded')
            evidence['stage'] = mode + '-observe'
            evidence['checks'][mode] = observe(mode, code, output, diagnostics, root, review)
            sink.write(mode + '-verdict.json', n.encoded(evidence['checks'][mode]))
        evidence['stage'] = 'final-validation'
        unchanged()
        if time.monotonic() > deadline:
            raise c.Blocked('compiler final validation deadline exceeded')
        evidence['stage'] = 'artifact-cleanup'
    evidence.update(result='compiler-only-smoke-pass',
                    stage='complete',
                    programFileClosure='reported program files bound to approved bytes',
                    cleanup='verified-owned-artifacts-removed')
    return evidence
