"""Fixed 22-package declaration projection; preparation is NOT external review.

No resolver, acquisition callback, arbitrary selection or approval-from-ledger.
Same-UID ancestors are trusted, as in the separately reviewed standalone guard.
"""
import base64
import json
import os
from pathlib import Path
import stat

import compiler_containment as g
import sdk_compiler_candidate as s
import sdk_notice_receipt as r
import sdk_transitive_notice as u
import sdk_aligned_inputs as aligned
import typings_alignment as alignment

t, p, n, c = g.t, g.p, g.n, g.c
HERE = Path(__file__).parent
PRIVATE_PARENT = g.PRIVATE_PARENT
HISTORICAL_SELECTION_SHA = 'a5b57c65fad62a83e0e2a52d446ffc6eb68f630740aec030bbc53977467d4846'
HISTORICAL_PLAN_SHA = '1dc707d3d6fcac4949914698c5649a19cf48760409cb14fd1cb5d374fe4aa198'
HISTORICAL_ROOT = PRIVATE_PARENT / 'threadmark-sdk-transitive-qb01_wew/review-artifacts-final-v2'
SELECTION_SHA = 'f0dc38a0f023079235ef19b331d93ba0c8e266fa0d0831a302e839e10e13132e'
PLAN_SHA = '70b9500102efccef297db94f5e22af08b9a133ad96259ecc637ddbecf074f203'
INPUT_ROOT = PRIVATE_PARENT / 'threadmark-typings-alignment-dg5nf13e/review-artifacts-v2'
OLD_EVIDENCE = PRIVATE_PARENT / 'threadmark-opencode-attestation-rardyg9p'
NEW_EVIDENCE = PRIVATE_PARENT / 'threadmark-sdk-transitive-qb01_wew'
MARKER = b'incomplete SDK projection; NOT execution approval\n'
AMBIENT = ('node_modules/@types/emscripten/index.d.ts', 'node_modules/@types/node/index.d.ts')
EMPTY = '__state/typeRoots'


def fixed_inputs():
    plan_bytes = p.regular(INPUT_ROOT / 'input-plan.json')
    candidate_bytes = p.regular(INPUT_ROOT / 'candidate.json')
    if t.sha256(plan_bytes) != PLAN_SHA or t.sha256(candidate_bytes) != SELECTION_SHA:
        raise c.Blocked('fixed selection/plan mismatch')
    return g.decoded(plan_bytes), g.decoded(candidate_bytes)


def historical_inputs():
    plan = p.regular(HISTORICAL_ROOT / 'input-plan.json')
    candidate = p.regular(HISTORICAL_ROOT / 'candidate.json')
    if t.sha256(plan) != HISTORICAL_PLAN_SHA or t.sha256(candidate) != HISTORICAL_SELECTION_SHA:
        raise c.Blocked('exact historical selection/plan required')
    return g.decoded(plan), g.decoded(candidate)


def source_bindings():
    names = ('sdk_projection.py', 'sdk_compiler_containment.py', 'sdk_compiler_candidate.py',
             'sdk_notice_receipt.py', 'sdk_transitive_notice.py', 'compiler_containment.py',
             'compiler_plan.py', 'project_types.py', 'node_containment.py',
             'synthetic_containment.py', 'compiler_positive.ts', 'compiler_negative.ts',
             'sdk_positive.tsx', 'sdk_negative.ts',
             'package-lock.json', 'package.json', 'sdk-selection-discovery.json',
             'sdk-transitive-discovery.json', 'sdk-notice-provenance.json',
             'sdk-transitive-notice-provenance.json', 'declaration-prerequisites.json',
             'sdk_aligned_inputs.py', 'typings_alignment.py', 'typings-alignment.json',
             'sdk-aligned-discovery.json',
             'THIRD-PARTY-NOTICES.txt')
    return {str(HERE / name): n.file_record(HERE / name) for name in names}


def notice_evidence(candidate):
    """Recheck retained actual evidence consistency; cryptographic review is external.

    All raw verification receipts are additionally bound in the new external review
    digest. No gh execution, regenerated certificate or self-authentication here.
    """
    observed = {}

    def read(path):
        path = p.absolute(str(g.compiler_path(path)))
        data = p.regular(path)
        observed[str(path)] = {'bytes': len(data), 'sha256': t.sha256(data)}
        return data

    tree = read(OLD_EVIDENCE / 'source-tree.json')
    common = {name: read(OLD_EVIDENCE / ('source-' + name.replace('/', '_')))
              for name in ('LICENSE', '.github/workflows/release.yml')}
    direct = dict(common, **{'packages/' + name + '/package.json': read(
        OLD_EVIDENCE / ('source-packages_' + name + '_package.json'))
        for name in ('client', 'plugin', 'theme')})
    transitive = dict(common, **{'packages/' + name + '/package.json': read(
        NEW_EVIDENCE / ('source-packages_' + name + '_package.json'))
        for name in ('protocol', 'schema', 'ai', 'util')})
    notices = p.regular(HERE / 'THIRD-PARTY-NOTICES.txt')
    receipt = g.decoded(p.regular(HERE / 'sdk-notice-provenance.json'))
    r.check_tree(g.decoded(tree), direct)
    r.check_receipt(receipt, g.decoded(p.regular(HERE / 'sdk-selection-discovery.json')), notices)
    for item in receipt['packages']:
        short = item['name'].split('/')[-1]
        bundle = g.decoded(read(OLD_EVIDENCE / (short + '-bundle.json')))
        verified = g.decoded(read(OLD_EVIDENCE / (short + '-verify-stdout')))
        read(OLD_EVIDENCE / (short + '.json'))
        if read(OLD_EVIDENCE / (short + '-verify-stderr')) != b'':
            raise c.Blocked('notice verification stderr')
        statement = g.decoded(base64.b64decode(bundle['dsseEnvelope']['payload'], validate=True))
        if (len(verified) != 1 or verified[0]['verificationResult']['statement'] != statement
                or statement['subject'] != [item['subject']]
                or verified[0]['verificationResult']['signature']['certificate'] != item['certificate']):
            raise c.Blocked('notice verified identity mismatch')
    evidence = {label: {} for label in ('responses', 'metadata', 'bundles', 'verified')}
    for name in u.NAMES:
        short = name.split('/')[-1]
        for label, suffix in (('responses', '-attestations.json'), ('metadata', '-metadata.json'),
                              ('bundles', '-bundle.json'), ('verified', '-verify-stdout.json')):
            evidence[label][name] = read(NEW_EVIDENCE / (short + suffix))
        if (g.decoded(read(NEW_EVIDENCE / (short + '-verify-status.json'))) != {'exitCode': 0}
                or read(NEW_EVIDENCE / (short + '-verify-stderr')) != b''):
            raise c.Blocked('notice verification failed')
    u.check(g.decoded(p.regular(HERE / 'sdk-transitive-notice-provenance.json')),
            candidate['packages'], tree_bytes=tree, raw=transitive,
            notice_bundle=notices, **evidence)
    notice = common['LICENSE']
    if (t.sha256(notice) != r.NOTICE or base64.b64decode(
            candidate['sourceNoticeEvidence']['noticeBase64'], validate=True) != notice):
        raise c.Blocked('authentic source notice mismatch')
    mappings = {name: '__notices/' + name.removeprefix('@').replace('/', '-') + '/LICENSE'
                for name in candidate['sourceNoticeEvidence']['scope']}
    if set(mappings) != {'@opencode/' + name for name in (
            'client', 'plugin', 'theme', 'protocol', 'schema', 'ai', 'util')}:
        raise c.Blocked('fixed notice scope mismatch')
    return {name: notice for name in mappings.values()}, mappings, observed


def selected(archives):
    """Reconstruct exact bound inputs; new alignment requires independent review."""
    plan, candidate = fixed_inputs()
    lock_bytes = p.regular(HERE / 'package-lock.json')
    receipt = g.decoded(p.regular(HERE / 'typings-alignment.json'))
    alignment.check_notices(p.regular(HERE / 'THIRD-PARTY-NOTICES.txt'), receipt)
    fixtures = {name: p.regular(HERE / name) for name in s.FIXTURE_HASHES}
    historical_plan, historical = historical_inputs()
    reconstructed = aligned.prepare(p.regular(HERE / 'package.json'), lock_bytes, plan, archives,
                                    fixtures, historical_plan, historical, receipt)
    for key, value in reconstructed.items():
        if candidate[key] != value:
            raise c.Blocked('reviewed selection reconstruction mismatch')
    if candidate['counts'] != {'packages': 22, 'potentialReadFiles': 1492,
                               'declarations': 1444, 'typingSources': 0}:
        raise c.Blocked('fixed selection counts mismatch')
    for name, digest in {**plan['sourceBindings'], **plan['evidenceBindings']}.items():
        s.path(name)
        if t.sha256(p.regular(HERE / name)) != digest:
            raise c.Blocked('reviewed source/evidence drift')
    output, roles = {}, {}
    lock = g.decoded(lock_bytes)
    for selection in plan['packages']:
        files, _ = aligned.inspect_package(lock, selection, archives[selection['integrity']], receipt)
        output.update(files)
        roles.update({selection['path'] + '/' + name: item['role']
                      for name, item in selection['files'].items()})
    for name, data in fixtures.items():
        output['__compiler_roots/' + name] = data
        roles['__compiler_roots/' + name] = 'owned_fixture'
    if {name: t.sha256(data) for name, data in output.items()} != candidate['potentialReadFileHashes']:
        raise c.Blocked('potential read inventory drift')
    notices, mappings, observed = notice_evidence(candidate)
    output.update(notices)
    roles.update({name: 'external_authentic_source_notice' for name in notices})
    return output, roles, mappings, observed


def config(root, mode):
    root = g.compiler_path(root)
    if mode not in ('positive', 'negative'):
        raise c.Blocked('fixed SDK config required')
    return n.encoded({'compilerOptions': {**s.OPTIONS, 'listFiles': True, 'pretty': False,
        'typeRoots': [str(root / EMPTY)]}, 'files': [str(root / '__compiler_roots' / (
        'sdk_positive.tsx' if mode == 'positive' else 'sdk_negative.ts')),
        *(str(root / name) for name in AMBIENT)], 'include': [], 'exclude': []})


def ledger(records, mappings):
    return n.encoded({'state': 'inert_prepared_NOT_compiled', 'selectionSha256': SELECTION_SHA,
        'inputPlanSha256': PLAN_SHA, 'files': records, 'externalSourceNoticeMappings': mappings,
        'typeGraphClosure': 'NOT established', 'executionApproved': False})


def validate(root, records, mappings, *, preparing=False):
    root = p.absolute(str(g.compiler_path(root)), directory=True)
    if root.parent != PRIVATE_PARENT:
        raise c.Blocked('fresh direct private SDK root required')
    p.inventory({name: item['sha256'] for name, item in records.items()})
    expected = {name: item['sha256'] for name, item in records.items()}
    expected['ledger.json'] = t.sha256(ledger(records, mappings))
    if preparing:
        expected['INCOMPLETE'] = t.sha256(MARKER)
    actual = {}
    for parent, directories, files in os.walk(root, followlinks=False):
        for name in directories + files:
            child = Path(parent) / name
            relative = child.relative_to(root).as_posix()
            info = child.lstat()
            if info.st_uid != os.getuid():
                raise c.Blocked('SDK owner mismatch')
            if stat.S_ISDIR(info.st_mode) and stat.S_IMODE(info.st_mode) == 0o700:
                actual[relative] = True
            elif (stat.S_ISREG(info.st_mode) and stat.S_IMODE(info.st_mode) == 0o400
                  and info.st_nlink == 1 and relative in expected
                  and t.sha256(p.regular(child)) == expected[relative]
                  and (relative not in records or info.st_size == records[relative]['bytes'])):
                actual[relative] = False
            else:
                raise c.Blocked('SDK file/mode/link/hash mismatch')
    wanted = t.with_directories({name: False for name in expected})
    wanted[EMPTY] = True
    wanted.update({name: True for name in s.ancestors(EMPTY)})
    t.check_paths(actual)
    info = root.lstat()
    if (actual != wanted or stat.S_IMODE(info.st_mode) != 0o700 or info.st_uid != os.getuid()):
        raise c.Blocked('SDK exact tree mismatch')
    for mode in ('positive', 'negative'):
        if p.regular(root / (mode + '.json')) != config(root, mode):
            raise c.Blocked('SDK config drift')


def materialize(destination, archives):
    """Fresh immutable audit projection. Failures retain marker; NEVER delete inputs."""
    destination = p.absolute(str(g.compiler_path(destination)))
    if destination.parent != PRIVATE_PARENT:
        raise c.Blocked('fresh direct private SDK root required')
    output, roles, mappings, observed = selected(archives)
    for mode in ('positive', 'negative'):
        output[mode + '.json'] = config(destination, mode)
        roles[mode + '.json'] = 'fixed_config'
    t.check_paths(t.with_directories({name: False for name in output}))
    if sum(map(len, output.values())) > t.DESTINATION_LIMIT:
        raise c.Blocked('SDK projection bound')
    records = {name: s.record(data, roles[name]) for name, data in sorted(output.items())}
    parent = os.open(destination.parent, t.DIR_FLAGS)
    try:
        os.mkdir(destination.name, 0o700, dir_fd=parent)
        root = os.open(destination.name, t.DIR_FLAGS, dir_fd=parent)
    finally:
        os.close(parent)
    identity = os.fstat(root)

    def incomplete(fd):
        try:
            t.write_file(fd, 'INCOMPLETE', MARKER)
        except FileExistsError:
            pass

    try:
        t.write_file(root, 'INCOMPLETE', MARKER)
        for name, data in output.items():
            t.write_file(root, name, data)
        empty = t.directory(root, EMPTY.split('/'))
        os.close(empty)
        t.write_file(root, 'ledger.json', ledger(records, mappings))
        validate(destination, records, mappings, preparing=True)
        os.fsync(root)
        os.unlink('INCOMPLETE', dir_fd=root)
        os.fsync(root)
    except BaseException:
        # In particular an fsync failure AFTER unlink must not leave an apparently
        # committed ledger. Never erase/replace files while marking failure.
        incomplete(root)
        raise
    finally:
        try:
            os.close(root)
        except BaseException:
            # close may already have closed the descriptor: NEVER retry it. Open
            # independently and check the original root identity before marking.
            reopened = os.open(destination, t.DIR_FLAGS)
            try:
                current = os.fstat(reopened)
                if (current.st_dev, current.st_ino) != (identity.st_dev, identity.st_ino):
                    raise c.Blocked('failed SDK root identity drift') from None
                incomplete(reopened)
            finally:
                os.close(reopened)
            raise
    return {'root': str(destination), 'files': records, 'sourceNoticeMappings': mappings,
            'privateEvidence': observed, 'selectionSha256': SELECTION_SHA, 'inputPlanSha256': PLAN_SHA}
