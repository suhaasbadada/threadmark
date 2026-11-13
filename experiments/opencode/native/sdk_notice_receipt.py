"""Pure evidence consistency only. NOT a Sigstore/cryptographic verifier.

Actual signature verification is a separate gh measurement retained by the parent.
Neither hashes nor this checker can authenticate an untrusted receipt or approve
selection. No fetching, execution, projection, or approval API exists here.
"""
import base64
import hashlib
import json
from pathlib import PurePosixPath

COMMIT = '958f965d35ed44d32b018fd55b02a5357a7748fd'
REPO = 'https://github.com/anomalyco/opencode'
WORKFLOW = REPO + '/.github/workflows/release.yml@refs/heads/dev'
NOTICE = '625f0f619133f89bbbb2abe37369613dfa1885eba1e50d02170deb62bb42cb6b'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def check_tree(tree, raw):
    """Check complete retained tree DATA and raw blobs, never upstream code."""
    require(tree['sha'] == COMMIT and tree['truncated'] is False, 'source tree')
    entries = {x['path']: x for x in tree['tree']}
    require(len(entries) == len(tree['tree']), 'duplicate tree path')
    roots = ['packages/' + x for x in ('client', 'plugin', 'theme')]
    notices = []
    for path, entry in entries.items():
        p = PurePosixPath(path)
        require(not p.is_absolute() and '..' not in p.parts, 'unsafe tree path')
        relevant = (path in ('packages', *roots) or
                    any(path.startswith(r + '/') for r in roots))
        if relevant:
            require(entry['mode'] in ('100644', '100755', '040000'), 'source symlink/submodule')
        scope = (str(p.parent) in ('.', 'packages') or
                 any(path.startswith(r + '/') for r in roots))
        stem = p.name.upper().split('.')[0]
        if scope and stem in ('LICENSE', 'LICENCE', 'NOTICE', 'COPYING', 'COPYRIGHT'):
            notices.append(path)
    require(sorted(notices) == ['LICENSE'], 'nearer or additional source notice')
    expected = {'LICENSE', '.github/workflows/release.yml'} | {
        r + '/package.json' for r in roots}
    require(set(raw) == expected, 'missing source raw bytes')
    for path, data in raw.items():
        e = entries[path]
        require(e['type'] == 'blob' and e['mode'] == '100644' and
                e['sha'] == blob(data) and e['size'] == len(data), 'source blob binding')
    require(sha(raw['LICENSE']) == NOTICE, 'raw notice hash')
    for root in roots:
        manifest = json.loads(raw[root + '/package.json'])
        require(manifest['name'] == '@opencode/' + root.split('/')[-1] and
                manifest['license'] == 'MIT', 'source package mapping')
    return sorted(notices)


def check_receipt(receipt, selection, notices):
    """Public consistency checks, deliberately unable to grant any approval."""
    require(receipt['kind'] == 'measured-gh-provenance-notice-mapping', 'receipt kind')
    require(receipt['sourceCommit'] == COMMIT, 'source commit')
    require(receipt['independentReview'] == 'PENDING', 'review gate')
    require(receipt['sourceFiles']['LICENSE']['sha256'] == NOTICE and
            receipt['sourceFiles']['LICENSE']['bytes'] == 1065,
            'raw notice record')
    require(receipt['sourceTree']['sha256'] ==
            '56dfc80e39ac8f080a5e771bf5e5fa829c4eac3e98fac615bd49881561c8fb52' and
            receipt['sourceTree']['bytes'] == 2609724 and
            receipt['sourceTree']['truncated'] is False and
            receipt['sourceTree']['noticePaths'] == ['LICENSE'], 'retained tree record')
    require(selection['compilerDescriptor'] is None and
            selection['selectionApproved'] is False and
            selection['executionApproved'] is False and
            selection['materialized'] is False, 'closed selection gates')
    n = receipt['noticeBlock']
    data = notices[n['offset']:n['offset'] + n['bytes']]
    require(n['bytes'] == 1065 and sha(data) == NOTICE == n['sha256'], 'notice block')
    require(sha(notices[:n['prefixBytes']]) == n['prefixSha256'] and
            n['offset'] >= n['prefixBytes'], 'original notice prefix')
    packages = {p['name']: p for p in selection['packages']}
    require({p['name'] for p in receipt['packages']} == {
        '@opencode/client', '@opencode/plugin', '@opencode/theme'} and
        len(receipt['packages']) == 3, 'exact mapping scope')
    for r in receipt['packages']:
        p = packages[r['name']]
        require(r['archiveSha256'] == p['archiveSha256'] and
                r['archiveSha512'] == base64.b64decode(p['integrity'].split('-', 1)[1]).hex(),
                'archive identity')
        require(r['sourcePackagePath'] == 'packages/' + r['name'].split('/')[-1] ==
                p['repository']['directory'], 'package path')
        require(r['subject'] == {'name': 'pkg:npm/%40opencode/' + r['name'].split('/')[-1] + '@' + p['version'],
                                'digest': {'sha512': r['archiveSha512']}}, 'subject identity')
        c = r['certificate']
        require(c['sourceRepositoryDigest'] == c['buildSignerDigest'] == COMMIT and
                c['sourceRepositoryURI'] == REPO and
                c['subjectAlternativeName'] == WORKFLOW and
                c['sourceRepositoryRef'] == 'refs/heads/dev' and
                c['issuer'] == 'https://token.actions.githubusercontent.com' and
                c['runnerEnvironment'] == 'github-hosted', 'certificate identity')
        require(r['ghExitCode'] == 0 and r['stderrBytes'] == 0, 'verification measurement')
    return None  # Never returns an executable descriptor or an approval token.
