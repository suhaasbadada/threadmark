"""Offline SDK discovery PREPARATION only; no approval or execution API.

Exact, explicit package/file selection, not a TypeScript resolver. Lexical facts
are review prompts, not consumed edges or proof of closure. No materializer is
provided: project_types cannot yet express nested metadata/notices in this plan.
"""
import base64
import json
import os
import re

import project_types as t

TYPE_SUFFIXES = ('.d.ts', '.d.mts', '.d.cts')
TOKEN = re.compile(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|'
                   r'[A-Za-z_$][A-Za-z0-9_$]*|[^\s]', re.S)
NOTICE = re.compile(r'^(LICENSE|LICENCE|NOTICE|COPYING|COPYRIGHT)(?:\..*)?$', re.I)
BOUNDS = {'wallSeconds': 120, 'outputBytes': 16 * 1024 * 1024,
          'heapMiB': 1024, 'cleanupSeconds': 2}
OPTIONS = {'strict': True, 'noEmit': True, 'skipLibCheck': False,
           'skipDefaultLibCheck': False, 'types': [], 'module': 'ESNext',
           'target': 'ESNext', 'moduleResolution': 'Bundler', 'jsx': 'react-jsx',
           'jsxImportSource': '@opentui/solid', 'typeRoots': ['__state/typeRoots']}
SCOPE = ['@opencode/client', '@opencode/plugin', '@opencode/plugin/tui',
         '@opencode/theme/tui', '@opentui/core', '@opentui/solid',
         '@opentui/solid/jsx-runtime', 'solid-js', 'web-tree-sitter']
FIXTURE_HASHES = {
    'sdk_positive.tsx': 'a7a7ebe87414879ff9d22a85b96c9da94d38a6353de1352db4138188ae36c234',
    'sdk_negative.ts': '447b106743122a7f75d7c98587bf40fe6d089f818b458f259a1f124909fb060a'}


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def path(value):
    t.safe_path(value)
    if not re.fullmatch(r'[A-Za-z0-9_@+./-]+', value):
        raise ValueError('TypeScript-representable ASCII path required')
    return value


def facts(data):
    """Bounded lexical import/reference evidence, NOT module resolution.

    Comments (including documentation examples) and string-literal type values
    are never scanned for embedded import syntax. Unknown import operands and
    escaped specifiers remain explicit review requirements; no fallback guessing.
    Triple-slash directives and suppression comments are retained as review facts.
    """
    text = data.decode('utf-8-sig', errors='strict')
    if '\0' in text:
        raise ValueError('NUL in type source')
    tokens, directives, suppressions = [], [], []
    for match in TOKEN.finditer(text):
        token = match[0]
        if token.startswith(('/*', '//')):
            if token.startswith('///') and '<reference' in token:
                directives.append({'offset': match.start(), 'text': token})
            for name in ('@ts-ignore', '@ts-nocheck', '@ts-expect-error'):
                if name in token:
                    suppressions.append({'offset': match.start(), 'directive': name})
            continue
        tokens.append((token, match.start()))
    imports, unknown = [], []
    for i, (token, offset) in enumerate(tokens):
        operand = None
        if token == 'from' and i + 1 < len(tokens):
            operand = tokens[i + 1][0]
            if not operand.startswith(('"', "'")):
                continue
        elif token in ('import', 'require') and i + 1 < len(tokens):
            # Declaration methods named require(id: string) are not imports.
            # Only TS import-equals require syntax is proposed here. Other
            # require uses in implementation sources still need separate review.
            if token == 'require' and (i == 0 or tokens[i - 1][0] != '='):
                continue
            nxt = tokens[i + 1][0]
            if nxt == '(' and i + 2 < len(tokens):
                operand = tokens[i + 2][0]
            elif token == 'import' and nxt.startswith(('"', "'")):
                operand = nxt
            else:
                continue
        if operand is None:
            continue
        if (not operand.startswith(('"', "'")) or '\\' in operand
                or '\n' in operand or '\r' in operand):
            unknown.append({'offset': offset, 'reason': 'nonliteral/escaped module operand'})
        else:
            imports.append({'offset': offset, 'specifier': operand[1:-1]})
    return {'imports': imports, 'unknownReferences': unknown,
            'referenceDirectives': directives, 'suppressionDirectives': suppressions}


def record(data, role):
    return {'bytes': len(data), 'sha256': t.sha256(data), 'role': role}


def inspect_package(lock, selection, data):
    """Bind one explicit selection to complete authentic metadata and archive.

    Every declaration is a potential read, not necessarily consumed. TS/TSX
    implementation bytes require individual export/type-target evidence supplied
    in the input plan; export semantics still require independent review.
    """
    package = path(selection['path'])
    name = t.package_name(package)
    entry = lock['packages'][package]
    if (selection['name'] != name or selection['version'] != entry['version']
            or selection['integrity'] != entry['integrity']
            or selection['resolved'] != entry['resolved']
            or selection['archiveSha256'] != t.sha256(data)):
        raise ValueError('dependency identity mismatch')
    files, expanded, declared = t.inspect(data, entry['integrity'])
    root = path(selection['archiveRoot'])
    prefix = root + '/'
    if any(not n.startswith(prefix) for n in files):
        raise ValueError('archive root mismatch')
    relative = {path(n[len(prefix):]): b for n, b in files.items()}
    metadata = relative['package.json']
    manifest = json.loads(metadata)
    if (manifest.get('name') != name or manifest.get('version') != entry['version']
            or t.sha256(metadata) != selection['metadataSha256']):
        raise ValueError('complete metadata identity mismatch')
    expected = selection['files']
    if not isinstance(expected, dict) or not expected:
        raise ValueError('explicit files required')
    required = {'package.json'} | {n for n in relative if n.endswith(TYPE_SUFFIXES)
                                  or n.endswith('/package.json')
                                  or NOTICE.fullmatch(n.rsplit('/', 1)[-1])}
    # Export condition selection is TypeScript's job, not a home-grown resolver.
    # In particular a custom "source" condition is not automatically consumed by
    # Bundler resolution. Retain omitted implementation targets as BLOCKING review
    # facts rather than copying them speculatively or claiming they are resolved.
    unselected_targets = sorted({target for target in exported_targets(manifest)
        if isinstance(target, str) and target.endswith(('.ts', '.tsx', '.mts', '.cts'))
        and not target.endswith(TYPE_SUFFIXES)
        and target.removeprefix('./') not in expected})
    if not required.issubset(expected):
        raise ValueError('missing declaration/whole metadata/notice selection')
    output, evidence, excluded = {}, {}, {}
    for n, b in sorted(relative.items()):
        if n not in expected:
            if n.endswith(('.ts', '.tsx', '.mts', '.cts')):
                excluded[n] = record(b, 'excluded_implementation_source')
            continue
        r = expected[n]
        if r['sha256'] != t.sha256(b) or r['bytes'] != len(b):
            raise ValueError('selected file binding mismatch')
        role = ('complete_metadata' if n == 'package.json' or n.endswith('/package.json')
                else 'authentic_notice' if NOTICE.fullmatch(n.rsplit('/', 1)[-1])
                else 'declaration' if n.endswith(TYPE_SUFFIXES) else 'typing_source')
        if r['role'] != role:
            raise ValueError('selected file role mismatch')
        if role == 'typing_source':
            if not n.endswith(('.ts', '.tsx', '.mts', '.cts')):
                raise ValueError('runtime selection forbidden')
            # Exact literal target in actual complete metadata, no invented alias.
            target = './' + n
            if target not in exported_targets(manifest) and n not in exported_targets(manifest):
                raise ValueError('typing source not an actual export/type target')
        output[package + '/' + n] = b
        if role in ('declaration', 'typing_source'):
            evidence[n] = facts(b)
    if set(expected) != {n[len(package) + 1:] for n in output}:
        raise ValueError('missing selected file')
    t.check_paths(t.with_directories({n: False for n in output}))
    return output, {'path': package, 'name': name, 'version': entry['version'],
                    'integrity': entry['integrity'], 'resolved': entry['resolved'],
                    'archiveSha256': t.sha256(data), 'archiveRoot': root,
                    'compressedBytes': len(data), 'expandedBytes': expanded,
                    'declaredBytes': declared, 'files': expected,
                    'repository': manifest.get('repository'),
                    'metadataBytesBase64': {n: base64.b64encode(b).decode()
                                            for n, b in relative.items()
                                            if n == 'package.json' or n.endswith('/package.json')},
                    'noticeBytesBase64': {n: base64.b64encode(b).decode() for n, b in relative.items()
                                         if NOTICE.fullmatch(n.rsplit('/', 1)[-1])},
                    'typeReferenceFacts': evidence, 'excludedTypeSources': excluded,
                    'unselectedExportTypeSourceTargets': unselected_targets,
                    'noticeStatus': 'EVIDENCE_PRESENT_REVIEW_PENDING' if any(
                        r['role'] == 'authentic_notice' for r in expected.values()) else 'ARCHIVE_NOTICE_ABSENT',
                    'typeGraphClosure': 'NOT established'}


def exported_targets(manifest):
    def strings(value):
        if isinstance(value, str):
            return [value]
        if isinstance(value, dict):
            return [s for v in value.values() for s in strings(v)]
        if isinstance(value, list):
            return [s for v in value for s in strings(v)]
        return []
    return strings(manifest.get('exports', {})) + [
        manifest.get('types'), manifest.get('typings')]


def prepare(lock_bytes, plan, archives, fixtures):
    """Return inert review DATA. Even complete inputs cannot self-approve.

    archives: already-owned integrity -> bytes. No paths or acquisition callbacks.
    No descriptor, argv, executable policy or physical projection is returned.
    """
    if (plan.get('schema') != 1 or plan.get('kind') != 'sdk-type-input-plan'
            or plan.get('lockSha256') != t.sha256(lock_bytes)
            or plan.get('scope') != SCOPE):
        raise ValueError('fixed plan/lock/scope mismatch')
    if any(k in plan for k in ('approved', 'reviewedSha256', 'executionApproved')):
        raise ValueError('input cannot grant approval')
    lock = json.loads(lock_bytes)
    if not plan.get('packages') or not isinstance(plan.get('knownMissing'), list):
        raise ValueError('explicit selection and requirements required')
    output, packages = {}, []
    for selection in plan['packages']:
        selected, evidence = inspect_package(lock, selection, archives[selection['integrity']])
        if set(selected) & set(output):
            raise ValueError('duplicate package/file selection')
        output.update(selected)
        packages.append(evidence)
    required_names = {'/'.join(n.split('/')[:2]) if n.startswith('@') else n.split('/')[0]
                      for n in SCOPE} | {'@types/node', '@types/emscripten', '@types/json-schema'}
    if not required_names.issubset({p['name'] for p in packages}):
        raise ValueError('full SDK scope and authentic prerequisites required')
    for key, bound in (('compressedBytes', t.COMPRESSED_LIMIT),
                       ('expandedBytes', t.EXPANDED_LIMIT), ('declaredBytes', t.EXPANDED_LIMIT)):
        if sum(p[key] for p in packages) > bound:
            raise ValueError('aggregate archive bound')
    t.check_paths(t.with_directories({n: False for n in output}))
    if sum(map(len, output.values())) > t.DESTINATION_LIMIT:
        raise ValueError('destination bound')
    required_roots = ['node_modules/@types/emscripten/index.d.ts',
                      'node_modules/@types/node/index.d.ts']
    if any(n not in output for n in required_roots):
        raise ValueError('explicit authentic ambient root missing')
    names = {'sdk_positive.tsx', 'sdk_negative.ts'}
    if set(fixtures) != names or plan['fixtureHashes'] != FIXTURE_HASHES:
        raise ValueError('fixed positive/negative fixtures required')
    for n, b in fixtures.items():
        path(n)
        text = b.decode('utf-8', errors='strict')
        nonimports = '\n'.join(line for line in text.splitlines()
                               if not line.startswith('import type '))
        if (t.sha256(b) != plan['fixtureHashes'][n] or '\0' in text
                or re.search(r'\bany\b|@ts-|<reference', text)
                or re.search(r'\bas\b', nonimports)):
            raise ValueError('fixture binding/escape mismatch')
        output['__compiler_roots/' + n] = b
    # Requirements are never erased by this preparation. Notice evidence mapping
    # is a separate independent-review input, not a license string or self-hash.
    missing = list(plan['knownMissing'])
    for p in packages:
        if p['unselectedExportTypeSourceTargets']:
            missing.append({'id': 'EXPORT_SOURCE_REVIEW:' + p['path'],
                            'requirement': 'Review actual export/type source conditions before projection; not statically resolved',
                            'targets': p['unselectedExportTypeSourceTargets']})
        if p['noticeStatus'] == 'ARCHIVE_NOTICE_ABSENT':
            missing.append({'id': 'NOTICE:' + p['path'],
                            'requirement': 'Separate package-specific source notice receipt requires independent review; archive contains no notice'})
        for n, f in p['typeReferenceFacts'].items():
            if f['unknownReferences']:
                missing.append({'id': 'UNKNOWN:' + p['path'] + '/' + n,
                                'requirement': 'Review unrecognized module operands before projection'})
    # Potential reads remain individualized even where they are never consumed.
    reads = {n: t.sha256(b) for n, b in sorted(output.items())}
    configs = {mode: {'compilerOptions': dict(OPTIONS),
                     'files': ['__compiler_roots/sdk_' + mode + ('.tsx' if mode == 'positive' else '.ts')]
                              + required_roots, 'include': [], 'exclude': []}
               for mode in ('positive', 'negative')}
    return {'schema': 1, 'kind': 'inert-fixed-sdk-discovery-candidate',
            'lockSha256': t.sha256(lock_bytes), 'inputPlanSha256': t.sha256(encoded(plan)),
            'scope': list(SCOPE), 'packages': packages, 'potentialReadFileHashes': reads,
            'counts': {'packages': len(packages), 'potentialReadFiles': len(reads),
                       'declarations': sum(r['role'] == 'declaration' for p in packages for r in p['files'].values()),
                       'typingSources': sum(r['role'] == 'typing_source' for p in packages for r in p['files'].values())},
            'configIntent': configs, 'boundsIntent': dict(BOUNDS),
            'policyIntent': {'default': 'deny', 'network': 'deny', 'targetChildSpawn': 'deny',
                             'recursiveReadRoots': [], 'readFiles': list(reads),
                             'metadataAncestors': sorted({a for n in reads for a in ancestors(n)}),
                             'writes': ['__state/home', '__state/tmp', '__state/config',
                                        '__state/cache', '__state/data', '__state/state'],
                             'cwd': '__projection', 'compilerDefaultLibraries': 'separate authentic standalone inventory only',
                             'systemAndOwnerInventory': 'PENDING independent review'},
            'negativeExpectation': {'code': 'TS2345', 'status': 'UNOBSERVED',
                                    'api': '@opencode/theme/tui rgbToOklch numeric first argument'},
            'knownMissing': missing, 'hasBlockingRequirements': True,
            'requiredGates': ['independent actual-byte selection/notice/fixture/config review',
                              'explicit primary execution authorization',
                              'exact compiler/Node/system/retained-owner read inventory',
                              'launch-time before/after binding receipts and private evidence',
                              'measured SDK containment controls and cleanup proof',
                              'official compiler diagnostics and consumed-file review'],
            'projectionStatus': 'NOT MATERIALIZED: independent review required; project_types API insufficient',
            'compilerDescriptor': None, 'executionApproved': False, 'selectionApproved': False,
            'materialized': False, 'typeGraphClosure': 'NOT established',
            'runtimeDependencyClosure': 'NOT established'}


def ancestors(name):
    parts = name.split('/')
    return ['/'.join(parts[:i]) for i in range(1, len(parts))]


def compiler_binding(archive, inventory):
    """Verify the EXISTING 112-file standalone inventory against owned archive.

    Compiler JS is never projected into SDK node_modules, imported or executed.
    This binding is not reuse of standalone execution authorization.
    """
    if (t.sha256(archive) != '33cd0ee1beaa8c9e9d15a9da836c62ddea4c34a42d7c2d349dbc80d94165d22a'
            or inventory['archiveSha256'] != t.sha256(archive)):
        raise ValueError('authentic fixed compiler archive required')
    files, _, _ = t.inspect(archive, inventory['integrity'])
    expected = inventory['files']
    libs = {n for n, r in expected.items() if r['role'] == 'default_library'}
    other = {'lib/tsc.js', 'lib/_tsc.js', 'package.json', 'LICENSE.txt', 'ThirdPartyNoticeText.txt'}
    if len(libs) != 107 or len(expected) != 112 or set(expected) != libs | other:
        raise ValueError('fixed compiler inventory roles/count mismatch')
    for n, r in expected.items():
        path(n)
        b = files['package/' + n]
        if r['sha256'] != t.sha256(b) or r['size'] != len(b):
            raise ValueError('compiler archive-file binding mismatch')
        if n in libs and not re.fullmatch(r'lib/lib\.[a-z0-9.]+\.d\.ts', n):
            raise ValueError('non-library compiler inventory entry')
    return {'archiveSha256': t.sha256(archive), 'integrity': inventory['integrity'],
            'files': expected, 'defaultLibraryCount': 107, 'fileCount': 112,
            'sourceInventorySha256': t.sha256(encoded(inventory)),
            'sdkProjectionContainsCompilerJS': False, 'executionAuthorizationReused': False}


def retain(destination, plan, candidate):
    """Fresh private review artifacts only, NEVER a package projection.

    INCOMPLETE remains through whole-tree validation (including the ledger).
    Any cancellation/error preserves artifacts, and cannot grant execution.
    Trusted parent/same-UID assumption matches project_types. No replacement.
    """
    from pathlib import Path
    import stat
    destination = Path(destination)
    if candidate.get('executionApproved') is not False or candidate.get('materialized') is not False:
        raise ValueError('closed candidate required')
    if candidate['inputPlanSha256'] != t.sha256(encoded(plan)):
        raise ValueError('partial/mismatching plan')
    content = {'input-plan.json': encoded(plan), 'candidate.json': encoded(candidate)}
    ledger = encoded({'state': 'inert_review_data_only', 'files': {
        n: record(b, 'review_data') for n, b in content.items()}})
    content['ledger.json'] = ledger
    if sum(map(len, content.values())) > t.DESTINATION_LIMIT:
        raise ValueError('retained artifact bound')
    parent = os.open(destination.parent, t.DIR_FLAGS)
    try:
        os.mkdir(destination.name, 0o700, dir_fd=parent)
        root = os.open(destination.name, t.DIR_FLAGS, dir_fd=parent)
    finally:
        os.close(parent)
    try:
        if stat.S_IMODE(os.fstat(root).st_mode) != 0o700:
            raise ValueError('private artifact directory required')
        t.write_file(root, 'INCOMPLETE', b'inert review data incomplete\n')
        for n, b in content.items():
            t.write_file(root, n, b)
        validate_retained(root, content)
        os.fsync(root)
        os.unlink('INCOMPLETE', dir_fd=root)
        os.fsync(root)
    finally:
        os.close(root)
    return t.sha256(content['candidate.json'])


def validate_retained(root, content):
    import stat
    if set(os.listdir(root)) != set(content) | {'INCOMPLETE'}:
        raise ValueError('whole artifact inventory mismatch')
    for n, b in {**content, 'INCOMPLETE': b'inert review data incomplete\n'}.items():
        fd = os.open(n, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=root)
        with os.fdopen(fd, 'rb') as source:
            info = os.fstat(source.fileno())
            if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1
                    or stat.S_IMODE(info.st_mode) != 0o400 or info.st_uid != os.getuid()
                    or info.st_size != len(b) or source.read(len(b) + 1) != b):
                raise ValueError('private retained file identity/hash mismatch')
