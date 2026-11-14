"""Fixed FOUR-package evidence consistency, not cryptography or approval.

Does not broaden sdk_notice_receipt's fixed three-package contract. Actual gh
measurement, independent review and primary authorization remain external gates.
"""
import base64
import json
from pathlib import PurePosixPath

import sdk_notice_receipt as r

NAMES = ('@opencode/protocol', '@opencode/schema', '@opencode/ai', '@opencode/util')


def check_source(tree, raw):
    r.require(tree['sha'] == r.COMMIT and tree['truncated'] is False, 'transitive source tree')
    entries = {e['path']: e for e in tree['tree']}
    r.require(len(entries) == len(tree['tree']), 'duplicate source paths')
    roots = ['packages/' + n.split('/')[-1] for n in NAMES]
    notices = []
    for name, e in entries.items():
        p = PurePosixPath(name)
        r.require(not p.is_absolute() and '..' not in p.parts and '\\' not in name,
                  'unsafe source path')
        relevant = name in ('packages', *roots) or any(name.startswith(root + '/') for root in roots)
        if relevant:
            r.require(e['mode'] in ('100644', '100755', '040000'), 'source link/submodule')
        scope = str(p.parent) in ('.', 'packages') or any(name.startswith(root + '/') for root in roots)
        if scope and p.name.upper().split('.')[0] in ('LICENSE', 'LICENCE', 'NOTICE', 'COPYING', 'COPYRIGHT'):
            notices.append(name)
    r.require(sorted(notices) == ['LICENSE'], 'closer/additional transitive source notice')
    r.require(set(raw) == {'LICENSE', '.github/workflows/release.yml'} | {
        root + '/package.json' for root in roots}, 'missing source bytes')
    for name, data in raw.items():
        e = entries[name]
        r.require(e['type'] == 'blob' and e['mode'] == '100644'
                  and e['sha'] == r.blob(data) and e['size'] == len(data), 'source blob identity')
    r.require(r.sha(raw['LICENSE']) == r.NOTICE, 'source notice identity')
    for name, root in zip(NAMES, roots):
        manifest = json.loads(raw[root + '/package.json'])
        r.require(manifest['name'] == name and manifest['license'] == 'MIT', 'source package identity')


def check(receipt, packages, *, tree_bytes, raw, responses, metadata, bundles, verified, notice_bundle):
    """All raw retained evidence required; opaque hashes cannot stand in for it.

    Success means consistency only; NOT that an arbitrary JSON verification
    output is authenticated. Callers must independently inspect actual gh runs.
    """
    r.require(receipt['kind'] == 'transitive-type-selection-notice-evidence'
              and receipt['purpose'] == 'future independently reviewed type-only mapping'
              and receipt['independentReview'] == 'PENDING', 'receipt purpose/review')
    r.require(receipt['sourceCommit'] == r.COMMIT, 'source commit')
    r.require(receipt['sourceTree']['sha256'] == r.sha(tree_bytes), 'tree receipt hash')
    check_source(json.loads(tree_bytes), raw)
    r.require(set(receipt['sourceFiles']) == set(raw), 'raw source record scope')
    for name, data in raw.items():
        r.require(receipt['sourceFiles'][name] == {'bytes': len(data), 'sha256': r.sha(data),
                  'gitBlobSha1': r.blob(data)}, 'raw source receipt')
    r.require(set(bundles) == set(verified) == set(responses) == set(metadata) == set(NAMES), 'verification scope')
    mapped = {p['name']: p for p in receipt['packages']}
    r.require(set(mapped) == set(NAMES) and len(receipt['packages']) == 4, 'fixed four-package scope')
    selected = {p['name']: p for p in packages}
    for name, item in mapped.items():
        p = selected[name]
        r.require(p['version'] == item['version'] == '2.2.5'
                  and item['archiveSha256'] == p['archiveSha256']
                  and item['integrity'] == p['integrity'] and item['resolved'] == p['resolved'], 'archive pin')
        root = 'packages/' + name.split('/')[-1]
        r.require(p['repository']['directory'] == item['sourcePackagePath'] == root, 'archive source directory')
        meta = json.loads(metadata[name])
        r.require(item['registryMetadata'] == {'bytes': len(metadata[name]), 'sha256': r.sha(metadata[name])}
                  and meta['name'] == name and meta['version'] == p['version']
                  and meta['dist']['integrity'] == p['integrity']
                  and meta['dist']['tarball'] == p['resolved'], 'registry metadata binding')
        for label, data in (('bundle', bundles[name]), ('verifiedOutput', verified[name]),
                            ('registryAttestations', responses[name])):
            r.require(item[label] == {'bytes': len(data), 'sha256': r.sha(data)}, 'retained evidence hash')
        bundle = json.loads(bundles[name])
        statement = json.loads(base64.b64decode(bundle['dsseEnvelope']['payload'], validate=True))
        r.require(statement['predicateType'] == 'https://slsa.dev/provenance/v1', 'predicate')
        r.require(statement['subject'] == [{'name': 'pkg:npm/%40opencode/' + name.split('/')[-1] + '@2.2.5',
                  'digest': {'sha512': base64.b64decode(p['integrity'].split('-', 1)[1], validate=True).hex()}}],
                  'subject binding')
        r.require(statement['predicate']['buildDefinition']['resolvedDependencies'][0]['digest']['gitCommit']
                  == r.COMMIT, 'statement source digest')
        response = json.loads(responses[name])
        r.require(any(a['bundle'] == bundle for a in response['attestations']), 'registry bundle identity')
        result = json.loads(verified[name])
        r.require(len(result) == 1 and result[0]['verificationResult']['statement'] == statement, 'verified statement')
        normalized = json.loads(json.dumps(bundle))
        for sig in normalized['dsseEnvelope']['signatures']:
            r.require(sig.pop('keyid', None) == '', 'signature normalization')
        timestamps = normalized['verificationMaterial']['timestampVerificationData']
        r.require(timestamps.pop('rfc3161Timestamps', None) == [], 'timestamp normalization')
        r.require(result[0]['attestation']['bundle'] == normalized, 'verified bundle')
        cert = result[0]['verificationResult']['signature']['certificate']
        fields = {'sourceRepositoryDigest', 'buildSignerDigest', 'sourceRepositoryURI',
                  'sourceRepositoryRef', 'subjectAlternativeName', 'runnerEnvironment', 'issuer'}
        r.require(set(receipt['verifiedCertificatePolicy']) == fields and
                  receipt['verifiedCertificatePolicy'] == {k: cert[k] for k in fields}, 'recorded certificate policy')
        r.require(cert['sourceRepositoryDigest'] == cert['buildSignerDigest'] == r.COMMIT
                  and cert['sourceRepositoryURI'] == r.REPO and cert['sourceRepositoryRef'] == 'refs/heads/dev'
                  and cert['subjectAlternativeName'] == r.WORKFLOW
                  and cert['runnerEnvironment'] == 'github-hosted'
                  and cert['issuer'] == 'https://token.actions.githubusercontent.com', 'verified certificate policy')
        r.require(item['ghExitCode'] == 0 and item['stderrBytes'] == 0, 'actual measurement status')
    block = receipt['noticeBlock']
    r.require(block['bytes'] == 1065 and block['sha256'] == r.NOTICE
              and notice_bundle[block['offset']:block['offset'] + block['bytes']] == raw['LICENSE'], 'actual notice block')
    r.require(r.sha(notice_bundle[:block['prefixBytes']]) == block['prefixSha256']
              and block['offset'] >= block['prefixBytes'], 'preserved notice prefix')
    return None
