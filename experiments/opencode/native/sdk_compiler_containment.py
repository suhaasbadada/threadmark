"""Fixed SDK COMPILER DISCOVERY guard candidate. No import-time work or CLI.

Actual execution remains CLOSED pending independent review of exact bytes and a
new explicit primary decision. A matching digest cannot authenticate authority.
No SDK/runtime-host execution, generic options, argv, source or selection API.
"""
import os
from pathlib import Path
import stat
import time

import sdk_projection as q

g, s, t, p, n, c = q.g, q.s, q.t, q.p, q.n, q.c
COMPILER_SHA = 'aea72b77d1cacbcd2daf30aa5b555f6b52b94e8e7c336d3970b8235702039caf'
COMPILER_REVIEW = q.PRIVATE_PARENT / 'threadmark-compiler-cwd-review-dm4yhxvq/compiler-review-candidate.json'
MODES = g.MODES
RESOURCE_KIND = 'fixed-sdk-compiler-resource-discovery-2048'
RESOURCE_BOUNDS = {**s.BOUNDS, 'heapMiB': 2048}
# Separate resource-discovery experiment. The 1024 MiB attempt FAILED; this
# neither changes its verdict nor establishes a product memory acceptance budget.


def compiler_review(data):
    """Exact historical runtime/compiler bytes; NEW source-identity review needed.

    Git integration replaced three same-byte source inodes. Do not modify the
    historical candidate, sources, validator or fingerprint. Check all historical
    source *hashes* here; the outer SDK candidate binds fresh full identities for
    independent review. Node's 18 files/24 aliases and compiler tree still use
    their existing strict validators, not an identity-refresh exception.
    """
    if q.t.sha256(data) != COMPILER_SHA:
        raise c.Blocked('exact historical compiler review required')
    review = g.decoded(data)
    n.read_review(review['nodeReview'].encode('ascii'), review['nodeReviewSha256'])
    g.validate_compiler(review['compilerRoot'], review['files'])
    current = g.sources()
    if ({name: item['sha256'] for name, item in review['sources'].items()} !=
            {name: item['sha256'] for name, item in current.items()}
            or review['fixtures'] != {mode: n.sha(g.fixture(mode)) for mode in MODES[1:]}):
        raise c.Blocked('historical compiler source bytes drift')
    return review


def projection_identity(root):
    root = Path(root)
    paths = [root]
    for parent, directories, files in os.walk(root, followlinks=False):
        paths.extend(Path(parent) / name for name in directories + files)
    return {str(path.relative_to(root)): [path.lstat().st_dev, path.lstat().st_ino,
             path.lstat().st_mode, path.lstat().st_uid, path.lstat().st_nlink]
            for path in paths}


def prepare_review(destination, archives):
    """Already-owned bytes only. Materialize immutable declarations, NOT compiler."""
    compiler_bytes = p.regular(COMPILER_REVIEW)
    compiler = compiler_review(compiler_bytes)
    _, candidate = q.fixed_inputs()
    if t.sha256(s.encoded(candidate['compilerBinding'])) != g.decoded(
            p.regular(q.INPUT_ROOT / 'input-plan.json'))['compilerBindingSha256']:
        raise c.Blocked('compiler selection binding mismatch')
    if candidate['compilerBinding']['files'] != compiler['files']:
        raise c.Blocked('reviewed compiler file inventory mismatch')
    projection = q.materialize(destination, archives)
    review = {'schema': 1, 'kind': RESOURCE_KIND,
        'projection': projection, 'compilerReview': compiler_bytes.decode('ascii'),
        'compilerReviewSha256': COMPILER_SHA, 'sources': q.source_bindings(),
        'projectionIdentity': projection_identity(destination),
        'selectionSha256': q.SELECTION_SHA, 'inputPlanSha256': q.PLAN_SHA,
        'bounds': dict(RESOURCE_BOUNDS), 'executionApproved': False,
        'typeGraphClosure': 'NOT established', 'runtimeDependencyClosure': 'NOT established'}
    data = n.encoded(review)
    read_review(data, t.sha256(data))  # Consistency ONLY, never external approval.
    return data


def read_review(data, approved_digest):
    if not isinstance(data, bytes) or len(data) > 16 * 1024 * 1024 or t.sha256(data) != p.digest(approved_digest):
        raise c.Blocked('external SDK review digest mismatch')
    review = g.decoded(data)
    n.keys(review, {'schema', 'kind', 'projection', 'compilerReview', 'compilerReviewSha256',
        'sources', 'projectionIdentity', 'selectionSha256', 'inputPlanSha256', 'bounds',
        'executionApproved', 'typeGraphClosure', 'runtimeDependencyClosure'})
    if (type(review['schema']) is not int or review['schema'] != 1
            or review['kind'] != RESOURCE_KIND
            or review['compilerReviewSha256'] != COMPILER_SHA
            or review['selectionSha256'] != q.SELECTION_SHA or review['inputPlanSha256'] != q.PLAN_SHA
            or review['bounds'] != RESOURCE_BOUNDS or review['executionApproved'] is not False
            or review['typeGraphClosure'] != 'NOT established'
            or review['runtimeDependencyClosure'] != 'NOT established'):
        raise c.Blocked('fixed SDK review required')
    revalidate(review)
    return review


def revalidate(review):
    compiler_review(review['compilerReview'].encode('ascii'))
    projection = review['projection']
    n.keys(projection, {'root', 'files', 'sourceNoticeMappings', 'privateEvidence',
                        'selectionSha256', 'inputPlanSha256'})
    if (projection['selectionSha256'] != q.SELECTION_SHA or projection['inputPlanSha256'] != q.PLAN_SHA
            or review['sources'] != q.source_bindings()):
        raise c.Blocked('SDK source/plan drift')
    _, candidate = q.fixed_inputs()
    notices, mappings, raw = q.notice_evidence(candidate)
    expected = dict(candidate['potentialReadFileHashes'])
    expected.update({name: t.sha256(data) for name, data in notices.items()})
    expected.update({mode + '.json': t.sha256(q.config(projection['root'], mode)) for mode in MODES[1:]})
    if (expected != {name: item['sha256'] for name, item in projection['files'].items()}
            or mappings != projection['sourceNoticeMappings'] or raw != projection['privateEvidence']):
        raise c.Blocked('SDK projection/evidence binding drift')
    # Role and size are not caller-controlled metadata, even under a self-hash.
    roles = {package['path'] + '/' + name: item for package in candidate['packages']
             for name, item in package['files'].items()}
    roles.update({'__compiler_roots/' + name: s.record(p.regular(q.HERE / name), 'owned_fixture')
                  for name in s.FIXTURE_HASHES})
    roles.update({name: s.record(data, 'external_authentic_source_notice') for name, data in notices.items()})
    roles.update({mode + '.json': s.record(q.config(projection['root'], mode), 'fixed_config') for mode in MODES[1:]})
    if projection['files'] != roles:
        raise c.Blocked('SDK projection roles/size drift')
    q.validate(projection['root'], projection['files'], mappings)
    if projection_identity(projection['root']) != review['projectionIdentity']:
        raise c.Blocked('SDK projection identity drift')


def policy(root, review):
    """Measured Node/C baseline plus ONLY individually selected SDK/compiler reads."""
    root = g.compiler_path(root)
    compiler = g.decoded(review['compilerReview'].encode('ascii'))
    node = g.decoded(compiler['nodeReview'].encode('ascii'))
    baseline = n.policy(root, node)
    phantom = {root / 'probe.cjs', root / 'read-canary'}
    rules = [rule for rule in baseline.rules if rule.path not in phantom]
    reads = {Path(compiler['compilerRoot']) / name for name in compiler['files']}
    projection = Path(review['projection']['root'])
    reads.update(projection / name for name in review['projection']['files'])
    rules.extend(c.Rule(('file-read*',), 'literal', name) for name in sorted(reads))
    directories = {root / 'workspace', projection / q.EMPTY, projection}
    for name in reads:
        directories.update(parent for parent in name.parents if parent == projection or projection in parent.parents)
    rules.extend(c.Rule(('file-read*',), 'literal', name) for name in sorted(directories))
    metadata = {parent for name in reads | directories for parent in name.parents}
    rules.extend(c.Rule(('file-read-metadata',), 'literal', name) for name in sorted(metadata))
    text = c.Policy(tuple(rules)).serialize().replace(
        '; SYNTHETIC C baseline only; no Node/runtime inventory claim.',
        '; Measured Node public-system discovery baseline; NOT minimum SDK/system closure.')
    names = ' '.join(c.quoted(name) for name in n.PAGE_SIZE_SYSCTLS + n.UNAME_SYSCTLS)
    return text + '(allow sysctl-read (sysctl-name ' + names + '))\n'


def command(root, review, mode):
    root = g.compiler_path(root)
    if mode not in MODES:
        raise c.Blocked('fixed SDK compiler attempt required')
    compiler = g.decoded(review['compilerReview'].encode('ascii'))
    projection = g.compiler_path(review['projection']['root'])
    tail = ['--version'] if mode == 'version' else ['--project', str(projection / (mode + '.json'))]
    return [str(c.SANDBOX), '-f', str(root / 'guard.sb'), str(n.NODE),
        '--max-old-space-size=2048', '--openssl-config=' + str(root / 'openssl.cnf'),
        str(g.compiler_path(compiler['compilerRoot']) / 'lib/tsc.js'), *tail]


def observe(mode, code, output, diagnostics, review, cwd=None):
    """Strict consumed-file provenance; potential-read inventory is NOT a program."""
    if diagnostics:
        raise c.Blocked('unexpected compiler stderr')
    if mode == 'version':
        if type(code) is not int or code != 0 or output != b'Version 6.0.3\n':
            raise c.Blocked('compiler version failed')
        return {'version': '6.0.3'}
    if mode not in MODES[1:]:
        raise c.Blocked('unknown compiler result')
    text = output.decode('utf-8', errors='strict')
    if not text.endswith('\n') or '\r' in text or '\0' in text:
        raise c.Blocked('partial compiler output')
    compiler = g.decoded(review['compilerReview'].encode('ascii'))
    projection = Path(review['projection']['root'])
    records = review['projection']['files']
    fixture = '__compiler_roots/sdk_' + mode + ('.tsx' if mode == 'positive' else '.ts')
    permitted = {str(projection / name): ('sdk/' + name, item['sha256'])
                 for name, item in records.items() if item['role'] == 'declaration' or name == fixture}
    permitted.update({str(Path(compiler['compilerRoot']) / name): ('compiler/' + name, item['sha256'])
        for name, item in compiler['files'].items() if item['role'] == 'default_library'})
    # Authentic tsc formats this diagnostic relative to its fixed owned cwd,
    # while listFiles reports absolute paths. Accept only that exact spelling,
    # never arbitrary relative paths, alternate aliases or arbitrary diagnostics.
    if cwd is None:
        raise c.Blocked('fixed compiler cwd required')
    cwd = g.compiler_path(cwd)
    error = os.path.relpath(projection / '__compiler_roots/sdk_negative.ts', cwd) + (
        "(4,9): error TS2345: Argument of type 'string' is not assignable to parameter of type 'number'.")
    consumed, errors = {}, []
    for line in text.splitlines():
        if mode == 'negative' and line == error and not consumed and not errors:
            errors.append(2345)
        elif line in permitted and permitted[line][0] not in consumed:
            relative, digest = permitted[line]
            consumed[relative] = digest
        else:
            raise c.Blocked('unrecognized/duplicate/outside compiler output')
    _, candidate = q.fixed_inputs()
    roots = {'sdk/' + fixture, *('sdk/' + name for name in q.AMBIENT)}
    roots.update('compiler/' + name for name in g.expected_libraries(compiler))
    # All positive imported SDK surfaces must actually participate. The negative
    # intentionally imports only theme; requiring positive scope there is false.
    if mode == 'positive':
        roots.update('sdk/node_modules/' + name + '/' + relative
            for name, files in candidate['fixtureApiBindings'].items() for relative in files)
    else:
        roots.update('sdk/node_modules/@opencode/theme/' + name
                     for name in candidate['fixtureApiBindings']['@opencode/theme'])
    if (type(code) is not int or code != (0 if mode == 'positive' else 2)
            or errors != ([] if mode == 'positive' else [2345]) or not roots.issubset(consumed)):
        raise c.Blocked('compiler semantics/consumed root failed')
    return {'diagnosticCodes': errors, 'programFiles': [
        {'relative': name, 'sha256': digest} for name, digest in consumed.items()],
        'potentialReadsNeedNotAllBeConsumed': True}


def run_guard(review_bytes, approved_digest):
    """FUTURE one-shot measurement, not invoked by preparation, tests or CI.

    External independent review and explicit primary authorization are mandatory.
    SDK discovery PASS is semantic success, NOT full runtime/host compatibility.
    """
    evidence = {'result': 'blocked', 'checks': {mode: 'NOT_RUN' for mode in MODES},
        'experimentKind': RESOURCE_KIND, 'experimentBounds': dict(RESOURCE_BOUNDS),
        'original1024MiBGate': 'FAILED; not superseded by this resource experiment',
        'stage': 'preflight', 'attempts': {}, 'typescript_launched': False, 'host_launched': False,
        'programFileClosure': 'NOT established', 'runtimeDependencyClosure': 'NOT established',
        'limitations': ['listFiles is NOT all metadata/system reads', 'old-space is NOT total RSS',
            'owner raises expose no partial capture', 'same-UID parents trusted; no concurrent runtime updates',
            'discovery does NOT certify SDK host or engine compatibility']}
    deadline = time.monotonic() + 110
    sink = None
    try:
        n.require_platform()
        review = read_review(review_bytes, approved_digest)
        sink = g.PrivateEvidence(approved_digest)
        _run(review, evidence, deadline, sink)
    except (Exception, KeyboardInterrupt) as error:
        evidence['failureCode'] = g.failure_code(error)
        evidence['cleanup'] = ('unverified-retained' if c._QUARANTINED or c.owner._QUARANTINED
            else 'verified-owned-artifacts-removed' if evidence['typescript_launched'] else 'not-launched')
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
        failure = c.Blocked('fixed SDK discovery guard blocked')
        failure.evidence = evidence
        raise failure from None
    provisional = n.encoded(dict(evidence, result='sdk-discovery-checks-passed-unconfirmed',
        stage='awaiting-successful-return', requires='successful-call-receipt'))
    try:
        sink.write('result.json', provisional)
        sink.close()
    except (Exception, KeyboardInterrupt):
        c._QUARANTINED = True
        evidence.update(result='blocked', stage='evidence-finalization', failureCode='evidence-retention',
                        retention='incomplete-retained')
        failure = c.Blocked('fixed SDK discovery guard blocked')
        failure.evidence = evidence
        raise failure from None
    finally:
        try:
            sink.close()
        except (Exception, KeyboardInterrupt):
            pass
    evidence['successReceipt'] = {'reviewSha256': approved_digest, 'recordSha256': t.sha256(provisional)}
    return evidence


def _run(review, evidence, deadline, sink):
    remaining_output = g.OUTPUT_CAP
    with g.artifacts() as root, c.cancellation():
        (root / 'state').mkdir(mode=0o700)
        for name in c.STATE:
            (root / 'state' / name).mkdir(mode=0o700)
        (root / 'workspace').mkdir(mode=0o700)
        protected = {'openssl.cnf': n.OPENSSL_CONFIG, 'guard.sb': policy(root, review).encode('ascii')}
        for name, data in protected.items():
            n.create(root / name, data)
            (root / name).chmod(0o400)
        identities = {name: n.file_record(root / name) for name in protected}
        expected = {'state': True, 'workspace': True, **{name: False for name in protected},
                    **{'state/' + name: True for name in c.STATE}}
        directories = {name: (root / name).lstat() for name, is_dir in expected.items() if is_dir}
        root_info = root.lstat()

        def unchanged():
            try:
                revalidate(review)
                info = root.lstat()
                if (info.st_dev, info.st_ino, info.st_mode) != (root_info.st_dev, root_info.st_ino, root_info.st_mode):
                    raise c.Blocked('SDK execution root identity drift')
                actual = {}
                for parent, dirs, files in os.walk(root, followlinks=False):
                    for name in dirs + files:
                        child = Path(parent) / name
                        relative = child.relative_to(root).as_posix()
                        item = child.lstat()
                        if stat.S_ISLNK(item.st_mode):
                            raise c.Blocked('SDK execution artifact link')
                        actual[relative] = stat.S_ISDIR(item.st_mode)
                if actual != expected or any(n.file_record(root / name) != record for name, record in identities.items()):
                    raise c.Blocked('SDK execution artifacts drift')
                for name, before in directories.items():
                    after = (root / name).lstat()
                    if (after.st_dev, after.st_ino, after.st_mode, after.st_uid) != (
                            before.st_dev, before.st_ino, before.st_mode, before.st_uid):
                        raise c.Blocked('SDK execution directory drift')
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
                attempt['beforeValidationFailureCode'] = g.failure_code(error)
                raise
            sink.write(mode + '-before.json', n.encoded(attempt))
            remaining = deadline - time.monotonic()
            if remaining <= 0 or remaining_output <= 0:
                raise c.Blocked('aggregate compiler budget exhausted')
            evidence['typescript_launched'] = True
            evidence['stage'] = mode + '-owner'
            evidence['checks'][mode] = 'BLOCKED'
            try:
                try:
                    code, output, diagnostics, _ = c.owner.bounded(command(root, review, mode),
                        root / 'workspace', n.clean_env(root), timeout=remaining, limit=remaining_output)
                except BaseException as error:
                    c._QUARANTINED = True
                    attempt.update(ownerFailureCode=g.failure_code(error), capture='unavailable-owner-raised',
                        ownerCleanup='unknown' if isinstance(error, c.owner.CleanupUnverified) else 'verified-by-owner-finally')
                    raise
                attempt.update(exitCode=code if type(code) is int else None, capture='returned', ownerCleanup='verified')
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
                    attempt['afterValidationFailureCode'] = g.failure_code(error)
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
            evidence['checks'][mode] = observe(mode, code, output, diagnostics, review, root / 'workspace')
            sink.write(mode + '-verdict.json', n.encoded(evidence['checks'][mode]))
        evidence['stage'] = 'final-validation'
        unchanged()
        if time.monotonic() > deadline:
            c._QUARANTINED = True
            raise c.Blocked('compiler final validation deadline exceeded')
    evidence.update(result='sdk-resource-discovery-pass', stage='complete',
        programFileClosure='reported program files bound to approved bytes; explicit roots and SDK surfaces present',
        cleanup='verified-owned-artifacts-removed', immutableProjection='retained-not-deleted')
