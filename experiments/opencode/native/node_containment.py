"""Fixed Node-only discovery candidate; first execution CLOSED pending review.

prepare_review reads only known Node's Mach-O closure with Apple's otool. Its
output is UNAPPROVED. run_guard requires an independently approved digest;
caller authority is out of band, not authenticated here. Import is inert. No CLI,
compiler descriptor, arbitrary executable, script, flags or budgets accepted.
"""
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import socket
import stat
import subprocess
import time

import synthetic_containment as c

NODE = Path('/opt/homebrew/Cellar/node/24.10.0/bin/node')
CELLAR = Path('/opt/homebrew/Cellar')
NODE_SHA = 'e7daf91e350dcfc19c3f67bef0a463c1269e98e084606c2e38edf2c349e3842a'
VERSION = b'v24.10.0\n'
SOURCE = Path(__file__).with_name('node_containment_probe.cjs')
OPENSSL_CONFIG = b'# Fixed empty Threadmark discovery configuration; no host settings.\n'
BASELINE = ('/usr/lib', '/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld',
            '/System/Library/Frameworks/CoreFoundation.framework',
            '/System/Library/Frameworks/Security.framework')
SYSTEM_VERSION = Path('/System/Library/CoreServices/SystemVersion.plist')
DYLD = Path('/usr/lib/dyld')
FILE_CAP = 128 * 1024 * 1024
TOTAL_CAP = 512 * 1024 * 1024
_FS = {'approved-read', 'cache-disabled', 'deny-spawn',
       *('write-' + name for name in c.STATE),
       *('deny-' + name for name in ('sibling', 'home', 'repo', 'config',
          'symlink-read', 'symlink-write', 'workspace-write', 'probe-write',
           'policy-write', 'inventory-write', 'openssl-write'))}
_NET = {family: {family + '-' + name for name in ('connect', 'udp', 'bind', 'listen')}
        for family in ('v4', 'v6')}
REQUIRED = _FS | set.union(*_NET.values()) | {'version', 'no-receiver-traffic'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode('ascii')


def keys(value, names):
    if not isinstance(value, dict) or set(value) != set(names):
        raise c.Blocked('review schema mismatch')


def path(value):
    if not isinstance(value, str) or not value.startswith('/') or value == '/':
        raise c.Blocked('invalid inventory path')
    c.quoted(value)
    p = Path(value)
    if str(p) != value or any(part in ('.', '..') for part in value.split('/')):
        raise c.Blocked('noncanonical inventory path')
    return p


def identity(info):
    return [info.st_dev, info.st_ino, info.st_mode, info.st_nlink, info.st_uid,
            info.st_size, info.st_mtime_ns, info.st_ctime_ns]


def file_record(p):
    """Bounded O_NOFOLLOW read with before/open/after identity comparison."""
    path(str(p))
    before = p.lstat()
    if (not stat.S_ISREG(before.st_mode) or before.st_nlink != 1
            or not 0 < before.st_size <= FILE_CAP or before.st_mode & 0o022):
        raise c.Blocked('invalid runtime file')
    fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as source:
        if identity(os.fstat(source.fileno())) != identity(before):
            raise c.Blocked('runtime identity race')
        h = hashlib.sha256()
        count = 0
        while data := source.read(1024 * 1024):
            count += len(data)
            if count > FILE_CAP:
                raise c.Blocked('runtime file bound')
            h.update(data)
        if (identity(os.fstat(source.fileno())) != identity(before)
                or identity(p.lstat()) != identity(before) or count != before.st_size):
            raise c.Blocked('runtime identity race')
    return {'identity': identity(before), 'sha256': h.hexdigest()}


def resolve(p, aliases, directories):
    """Record actual symlink edges, including directory aliases. No search."""
    p = path(str(p))
    for _ in range(64):
        current = Path('/')
        for index, part in enumerate(p.parts[1:], 1):
            current /= part
            info = current.lstat()
            if stat.S_ISLNK(info.st_mode):
                target = os.readlink(current)
                c.quoted(target)
                record = {'target': target, 'identity': identity(info)}
                if str(current) in aliases and aliases[str(current)] != record:
                    raise c.Blocked('runtime alias race')
                aliases[str(current)] = record
                next_path = Path(target) if target.startswith('/') else current.parent / target
                p = Path(os.path.normpath(next_path.joinpath(*p.parts[index + 1:])))
                path(str(p))
                break
            if index < len(p.parts) - 1:
                if not stat.S_ISDIR(info.st_mode):
                    raise c.Blocked('invalid runtime ancestor')
                record = [info.st_dev, info.st_ino, info.st_mode, info.st_uid]
                if str(current) in directories and directories[str(current)] != record:
                    raise c.Blocked('runtime ancestor race')
                directories[str(current)] = record
        else:
            return p
    raise c.Blocked('runtime alias bound')


def system_load(name):
    return any(name.startswith(root + '/') for root in BASELINE)


def macho_commands(text):
    """Only this reviewed LC subset. LC_ID_DYLIB is NOT a dependency."""
    loads, rpaths = [], []
    for block in text.split('Load command ')[1:]:
        cmd = re.search(r'^\s+cmd (LC_[A-Z0-9_]+)$', block, re.M)
        if not cmd:
            raise c.Blocked('malformed Mach-O inspection')
        kind = cmd[1]
        if kind == 'LC_DYLD_ENVIRONMENT':
            raise c.Blocked('unsupported loader environment')
        if kind in ('LC_LOAD_DYLIB', 'LC_LOAD_WEAK_DYLIB', 'LC_REEXPORT_DYLIB',
                    'LC_LOAD_UPWARD_DYLIB', 'LC_LAZY_LOAD_DYLIB', 'LC_RPATH'):
            field = 'path' if kind == 'LC_RPATH' else 'name'
            match = re.search(r'^\s+' + field + r' (.+) \(offset [0-9]+\)$', block, re.M)
            if not match:
                raise c.Blocked('malformed Mach-O load')
            (rpaths if kind == 'LC_RPATH' else loads).append(match[1])
    if not loads or len(loads) != len(set(loads)):
        raise c.Blocked('missing/duplicate Mach-O loads')
    return loads, rpaths


def linked_path(name, parent, rpaths):
    if name.startswith('/'):
        return path(name)
    if name.startswith('@loader_path/'):
        return path(os.path.normpath(str(parent / name[len('@loader_path/'):])))
    if name.startswith('@rpath/') and rpaths == ['@loader_path/../lib']:
        return path(os.path.normpath(str(parent / '../lib' / name[len('@rpath/'):])))
    raise c.Blocked('unsupported dynamic library lookup')


def inspect(p):
    result = subprocess.run(['/usr/bin/otool', '-l', str(p)], capture_output=True,
                            timeout=5, check=False, env={'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'})
    if result.returncode or len(result.stdout) + len(result.stderr) > 2 * 1024 * 1024:
        raise c.Blocked('static runtime inspection failed')
    return macho_commands(result.stdout.decode('ascii'))


def source_records():
    return {str(p.resolve()): file_record(p.resolve()) for p in (
        SOURCE, Path(__file__), Path(c.__file__), c._HELPER, c.owner.SUPERVISOR, c.SANDBOX)}


def system_record():
    directories = {}
    for name in BASELINE:
        info = Path(name).lstat()
        if not stat.S_ISDIR(info.st_mode):
            raise c.Blocked('system baseline directory drift')
        directories[name] = [info.st_dev, info.st_ino, info.st_mode, info.st_uid]
    return {'kernel': platform.release(), 'build': platform.version(),
            'systemVersion': file_record(SYSTEM_VERSION), 'dyld': file_record(DYLD),
            'baseline': list(BASELINE), 'directories': directories,
            'sharedCacheIdentity': 'OS-build-bound; virtual images NOT individually hashed'}


def collect_runtime():
    """Explicit preparation only. Never called by run_guard after approval."""
    files, aliases, directories, loads = {}, {}, {}, {}
    queue = [NODE]
    total = 0
    while queue:
        p = resolve(queue.pop(), aliases, directories)
        if not p.is_relative_to(CELLAR):
            raise c.Blocked('non-system runtime outside fixed Cellar')
        if str(p) in files:
            continue
        if len(files) >= 64:
            raise c.Blocked('runtime count bound')
        files[str(p)] = file_record(p)
        total += files[str(p)]['identity'][5]
        if total > TOTAL_CAP:
            raise c.Blocked('runtime total bound')
        names, rpaths = inspect(p)
        destinations = []
        for name in names:
            if system_load(name):
                destinations.append({'lookup': name, 'canonical': None})
            else:
                lookup = linked_path(name, p.parent, rpaths)
                canonical = resolve(lookup, aliases, directories)
                destinations.append({'lookup': str(lookup), 'canonical': str(canonical)})
                queue.append(lookup)
        loads[str(p)] = destinations
    return {'files': files, 'aliases': aliases, 'directories': directories, 'loads': loads}


def prepare_review():
    """Return candidate bytes only. Caller may save privately; NOT approval."""
    require_platform()
    runtime = collect_runtime()
    review = {'schema': 1, 'kind': 'fixed-node-only-discovery', 'version': '24.10.0',
              'node': str(NODE), 'runtime': runtime, 'system': system_record(),
              'sources': source_records()}
    validate_shape(review)
    revalidate(review)
    return encoded(review)


def validate_shape(review):
    keys(review, {'schema', 'kind', 'version', 'node', 'runtime', 'system', 'sources'})
    if (type(review['schema']) is not int or review['schema'] != 1
            or review['kind'] != 'fixed-node-only-discovery' or review['version'] != '24.10.0'
            or review['node'] != str(NODE)):
        raise c.Blocked('fixed Node identity required')
    runtime = review['runtime']
    keys(runtime, {'files', 'aliases', 'directories', 'loads'})
    if (not isinstance(runtime['aliases'], dict) or len(runtime['aliases']) > 256
            or not isinstance(runtime['directories'], dict) or len(runtime['directories']) > 256
            or not isinstance(runtime['loads'], dict)):
        raise c.Blocked('runtime metadata bound')
    files = runtime['files']
    # Specifically the reviewed Node + seventeen dylibs, not a general launcher.
    if (not isinstance(files, dict) or len(files) != 18 or len(files) > 64
            or str(NODE) not in files or files[str(NODE)]['sha256'] != NODE_SHA
            or set(runtime['loads']) != set(files)):
        raise c.Blocked('runtime closure mismatch')
    total = 0
    for name, record in files.items():
        p = path(name)
        keys(record, {'identity', 'sha256'})
        ident = record['identity']
        if (not isinstance(ident, list) or len(ident) != 8
                or any(type(n) is not int or n < 0 for n in ident)
                or not stat.S_ISREG(ident[2]) or ident[3] != 1 or ident[2] & 0o022
                or not 0 < ident[5] <= FILE_CAP
                or not re.fullmatch('[0-9a-f]{64}', record['sha256'])
                or p != NODE and (not p.is_relative_to(CELLAR)
                                  or not p.name.endswith('.dylib'))):
            raise c.Blocked('runtime record mismatch')
        total += ident[5]
    if total > TOTAL_CAP or not files[str(NODE)]['identity'][2] & stat.S_IXUSR:
        raise c.Blocked('runtime bounds/mode mismatch')
    all_names = set(files) | set(runtime['aliases']) | set(runtime['directories'])
    for name in all_names:
        path(name)
    if len({name.casefold() for name in all_names}) != len(all_names):
        raise c.Blocked('runtime path collision')
    reachable, pending = set(), [str(NODE)]
    while pending:
        name = pending.pop()
        if name in reachable:
            continue
        reachable.add(name)
        edges = runtime['loads'][name]
        if not isinstance(edges, list) or not edges or len(edges) > 64:
            raise c.Blocked('invalid runtime loads')
        seen = set()
        for edge in edges:
            keys(edge, {'lookup', 'canonical'})
            lookup = str(path(edge['lookup']))
            if lookup in seen:
                raise c.Blocked('duplicate runtime load')
            seen.add(lookup)
            if edge['canonical'] is None:
                if not system_load(lookup):
                    raise c.Blocked('unknown system load')
            elif edge['canonical'] in files:
                pending.append(edge['canonical'])
            else:
                raise c.Blocked('missing runtime dependency')
    if reachable != set(files):
        raise c.Blocked('extra runtime dependency')
    keys(review['system'], {'kernel', 'build', 'systemVersion', 'dyld', 'baseline',
                            'directories', 'sharedCacheIdentity'})
    if review['system'] != system_record() or review['sources'] != source_records():
        raise c.Blocked('system/source binding mismatch')


def revalidate(review):
    """No new discovery: reproduce only the exact approved alias/path closure."""
    runtime = review['runtime']
    aliases, directories = {}, {}
    for name, record in runtime['files'].items():
        if resolve(path(name), aliases, directories) != Path(name) or file_record(Path(name)) != record:
            raise c.Blocked('runtime bytes/identity drift')
    for edges in runtime['loads'].values():
        for edge in edges:
            if edge['canonical'] is not None:
                if str(resolve(path(edge['lookup']), aliases, directories)) != edge['canonical']:
                    raise c.Blocked('runtime lookup drift')
    if aliases != runtime['aliases'] or directories != runtime['directories']:
        raise c.Blocked('runtime aliases/ancestors drift')
    if review['system'] != system_record() or review['sources'] != source_records():
        raise c.Blocked('system/source drift')


def read_review(data, approved_sha):
    if (not isinstance(data, bytes) or len(data) > 2 * 1024 * 1024
            or not isinstance(approved_sha, str) or not re.fullmatch('[0-9a-f]{64}', approved_sha)
            or sha(data) != approved_sha):
        raise c.Blocked('external review digest mismatch')

    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise c.Blocked('duplicate review key')
            result[key] = value
        return result
    review = json.loads(data, object_pairs_hook=unique)
    validate_shape(review)
    revalidate(review)
    return review


def require_platform():
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise c.Blocked('requires reviewed ARM64 macOS')
    for tool in (c.SANDBOX, Path('/usr/bin/otool')):
        if not tool.is_file() or not os.access(tool, os.X_OK):
            raise c.Blocked('required Apple tool unavailable')


def policy(root, review):
    path(str(root))
    rules = [c.Rule(('process-exec',), 'literal', NODE),
             c.Rule(('file-read-data',), 'literal', Path('/'))]
    data_reads = {root / 'probe.cjs', root / 'read-canary', root / 'openssl.cnf'}
    reads = {NODE, *data_reads}
    reads.update(Path(name) for name in review['runtime']['files'])
    reads.update(Path(edge['lookup']) for edges in review['runtime']['loads'].values()
                 for edge in edges if edge['canonical'] is not None)
    reads.update(Path(name) for name in review['runtime']['aliases'])
    for p in sorted(reads):
        operations = ('file-read*', 'file-map-executable') if p not in data_reads else ('file-read*',)
        rules.append(c.Rule(operations, 'literal', p))
    for name in c.STATE:
        rules.append(c.Rule(('file-read*', 'file-write*'), 'subpath', root / 'state' / name))
    for name in BASELINE:
        rules.append(c.Rule(('file-read*', 'file-map-executable'), 'subpath', Path(name)))
    metadata = {root, root / 'state', root / 'guard.sb', root / 'workspace'}
    for p in reads | {Path(name) for name in BASELINE}:
        metadata.update(p.parents)
        metadata.add(p)
    metadata.update(Path(name) for name in review['runtime']['directories'])
    rules.extend(c.Rule(('file-read-metadata',), 'literal', p) for p in sorted(metadata))
    return c.Policy(tuple(rules))


def clean_env(root):
    return {**c.clean_env(root), 'NODE_DISABLE_COMPILE_CACHE': '1'}


def serialized_policy(root, review):
    # Reuse the independently tested serializer, replacing only its C-only label.
    return policy(root, review).serialize().replace(
        '; SYNTHETIC C baseline only; no Node/runtime inventory claim.',
        '; Node public-system discovery baseline; NOT minimum system closure.')


def parse_version(code, output, diagnostics):
    if code != 0 or output != VERSION or diagnostics:
        raise c.Blocked('fixed Node version observation failed')


def create(p, data):
    """Fresh private owned artifacts only; no overwrite or config discovery."""
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as target:
        target.write(data)


def run_guard(review_bytes, approved_sha256):
    """Future separately authorized measurement only. Never TypeScript/SDK."""
    evidence = {'result': 'blocked', 'checks': {name: 'NOT_RUN' for name in sorted(REQUIRED)},
                'node_launched': False, 'typescript_launched': False, 'host_launched': False,
                'reviewSha256': approved_sha256 if isinstance(approved_sha256, str)
                    and re.fullmatch('[0-9a-f]{64}', approved_sha256) else None,
                'limitations': ['DNS/IPC/JIT NOT proved', 'full system closure NOT proved',
                    'V8 old-space is NOT total RSS', 'compiler/native NOT RUN',
                    'observed version is NOT publisher provenance']}
    try:
        require_platform()
        review = read_review(review_bytes, approved_sha256)  # Before artifacts/sockets.
        return _run(review, evidence)
    except (ValueError, OSError, TypeError, KeyError, c.Canceled, KeyboardInterrupt):
        evidence['cleanup'] = ('unverified-retained' if c._QUARANTINED or c.owner._QUARANTINED
                               else 'verified-or-not-launched')
        failure = c.Blocked('fixed Node guard blocked')
        failure.evidence = evidence
        raise failure from None


def _run(review, evidence):
    deadline = time.monotonic() + 110  # Reserve 10 s of the 120 s envelope for final cleanup.
    checks = evidence['checks']
    with c.artifacts() as root, c.cancellation(), ExitStack() as stack:
        for name in c.STATE:
            (root / 'state' / name).mkdir(parents=True, mode=0o700)
        (root / 'workspace').mkdir(mode=0o700)
        names = ('read-canary', 'sibling', 'outside/home/.config/opencode/config.json',
                 'outside/repository/AGENTS.md', 'outside/config/settings.json',
                 'workspace/check', 'config-inventory/settings.json', 'exec-marker')
        protected = []
        for name in names:
            p = root / name
            p.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            create(p, b'synthetic-unchanged\n')
            protected.append(p)
        (root / 'exec-marker').chmod(0o700)  # ENOEXEC is NOT denial proof.
        (root / 'state/home/outside-link').symlink_to(root / 'sibling')
        create(root / 'probe.cjs', SOURCE.read_bytes())
        create(root / 'openssl.cnf', OPENSSL_CONFIG)
        create(root / 'guard.sb', serialized_policy(root, review).encode('ascii'))
        protected.extend((root / 'probe.cjs', root / 'guard.sb', root / 'openssl.cnf'))
        hashes = {p: file_record(p) for p in protected}
        evidence['identities_sha256'] = {'source': sha(SOURCE.read_bytes()),
                                        'policy': c.digest(root / 'guard.sb')}

        def unchanged():
            try:
                if any(file_record(p) != record for p, record in hashes.items()):
                    raise c.Blocked('protected artifact drift')
                revalidate(review)
            except (ValueError, OSError, TypeError, KeyError, c.Canceled, KeyboardInterrupt):
                if evidence['node_launched']:
                    c._QUARANTINED = True
                raise

        def launch(mode, arguments):
            unchanged()
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise c.Blocked('fixed Node overall timeout')
            evidence['node_launched'] = True  # Attempted, not necessarily bootstrapped.
            try:
                code, output, diagnostics, _ = c.owner.bounded([
                    str(c.SANDBOX), '-f', str(root / 'guard.sb'), str(NODE),
                    '--max-old-space-size=64', '--openssl-config=' + str(root / 'openssl.cnf'),
                    *arguments], root / 'workspace',
                    clean_env(root), timeout=min(5, remaining), limit=16 * 1024)
                evidence['lastAttempt'] = {'mode': mode, 'exitStatus': code,
                    'stdoutBytes': len(output), 'stderrBytes': len(diagnostics),
                    'stderrSha256': sha(diagnostics)}
                return code, output, diagnostics
            finally:
                try:
                    unchanged()
                except (ValueError, OSError, TypeError, KeyError, c.Canceled, KeyboardInterrupt):
                    c._QUARANTINED = True
                    raise c.Blocked('runtime/artifact validation incomplete; retained for review') from None

        parse_version(*launch('version', ['--version']))
        checks['version'] = 'observed-pass'

        def probe(mode, extra, expected):
            checks.update({name: 'failed-or-unverified' for name in expected})
            code, output, diagnostics = launch(mode, [str(root / 'probe.cjs'), mode, str(root), *extra])
            if code or diagnostics:
                raise c.Blocked('fixed Node observations failed')
            checks.update(c.parse_checks(output, expected))

        probe('filesystem', [], _FS)
        receivers = []
        for family, address, label in ((socket.AF_INET, '127.0.0.1', 'v4'),
                                        (socket.AF_INET6, '::1', 'v6')):
            ports = []
            for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
                endpoint = stack.enter_context(socket.socket(family, kind))
                if family == socket.AF_INET6:
                    endpoint.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
                endpoint.bind((address, 0))
                if kind == socket.SOCK_STREAM:
                    endpoint.listen(1)
                endpoint.setblocking(False)
                ports.append(str(endpoint.getsockname()[1]))
                receivers.append((endpoint, kind))
            probe(label, ports, _NET[label])
        for endpoint, kind in receivers:
            try:
                if kind == socket.SOCK_STREAM:
                    connection, _ = endpoint.accept()
                    connection.close()
                else:
                    endpoint.recvfrom(64)
            except BlockingIOError:
                continue
            raise c.Blocked('owned receiver observed traffic')
        checks['no-receiver-traffic'] = 'observed-pass'
        unchanged()
        if set(checks) != REQUIRED or any(value != 'observed-pass' for value in checks.values()):
            raise c.Blocked('incomplete Node controls')
    evidence.update(result='node-only-discovery-pass', cleanup='verified-owned-artifacts-removed')
    return evidence
