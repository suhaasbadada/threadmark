"""Exact reviewed lock transition; consistency, NOT install/execution approval.

Historical receipts stay immutable. Reverse the complete explicit delta and
verify their original byte hashes; never accept an arbitrary hash mismatch.
"""
import copy
import hashlib
import json

OLD_LOCK = '20571ff490c60ed12a0e6b7eefb54138f9292778d2f4be1a2b874f5db1ed6651'
NEW_LOCK = 'b4566d56a9656b8ff191af83d63cf301cb0398aaf174ae99d4765ab8cbfaae30'
OLD_MANIFEST = 'f1bea8babcc92323e67a6c35efc1fccd4527e79502bee660c086955fe4b8a628'
NEW_MANIFEST = '6deb7b4d256721c2ce7c3ec481cb3966079fe55b5a2951f04fcfb444f6689cb0'
RECEIPT_SHA = 'ccac6466b5229205677fc82ee2469dbad83c828ac3ac1f421195d904c5c50ecf'
PINS = {'@types/node': '24.12.2', 'undici-types': '7.16.0'}
REDIS = {'node_modules/' + name for name in (
    'redis', '@redis/bloom', '@redis/client', '@redis/json', '@redis/search', '@redis/time-series')}
CHANGED = {'', 'node_modules/@types/node', 'node_modules/undici-types',
           'node_modules/@types/emscripten', 'node_modules/typescript'}


def encoded(value):
    return (json.dumps(value, indent=2) + '\n').encode()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def transition(old_manifest, new_manifest, old_lock, new_lock, receipt):
    """Pure exact structural comparison against all reviewed delta records.

    Inputs are data, not authority. current() additionally pins actual byte hashes.
    Nothing here authorizes fetching, installing, distributing or running Redis.
    """
    expected_manifest = copy.deepcopy(old_manifest)
    expected_manifest['devDependencies'].update(PINS)
    require(new_manifest == expected_manifest and all(
        name not in old_manifest['devDependencies'] for name in PINS), 'exact two dev pins')
    require({k: v for k, v in old_lock.items() if k != 'packages'} == {
        k: v for k, v in new_lock.items() if k != 'packages'}, 'lock top-level drift')
    old, new = old_lock['packages'], new_lock['packages']
    require(set(new) - set(old) == REDIS and not set(old) - set(new), 'exact Redis additions/no removals')
    changed = {key for key in old if old[key] != new[key]}
    require(changed == CHANGED, 'unreviewed existing record drift')
    delta = {key: {'old': old.get(key), 'new': new.get(key)} for key in sorted(CHANGED | REDIS)}
    require(delta == receipt['packageDelta'], 'complete delta record mismatch')
    expected_root = copy.deepcopy(old[''])
    expected_root['devDependencies'].update(PINS)
    require(new[''] == expected_root and new['']['devDependencies'] == new_manifest['devDependencies'], 'root pins')
    for name, version in PINS.items():
        entry = new['node_modules/' + name]
        require(entry['version'] == version, 'typings version')
    require(new['node_modules/@types/node']['dependencies'] == {'undici-types': '~7.16.0'}, 'Node dependency range')
    em = copy.deepcopy(old['node_modules/@types/emscripten'])
    require(em.pop('dev') is True, 'old Emscripten dev')
    em['devOptional'] = True
    require(new['node_modules/@types/emscripten'] == em, 'Emscripten flags only')
    ts = copy.deepcopy(old['node_modules/typescript'])
    require(ts.pop('dev') is True and new['node_modules/typescript'] == ts, 'TypeScript dev flag only')
    for key in REDIS:
        require(new[key]['version'] == '6.3.1' and new[key]['peer'] is True, 'Redis peer version')
    require(new['node_modules/redis']['dependencies'] == {
        key.removeprefix('node_modules/'): '6.3.1' for key in REDIS if key != 'node_modules/redis'}, 'Redis exact dependency edges')
    for key in REDIS - {'node_modules/redis', 'node_modules/@redis/client'}:
        require(new[key]['peerDependencies'] == {'@redis/client': '^6.3.1'}, 'Redis client peer edge')


def current(manifest_bytes, lock_bytes, receipt):
    """Return exact historical bytes ONLY for this fixed, reviewed transition."""
    require(sha(encoded(receipt)) == RECEIPT_SHA, 'exact transition receipt')
    require((sha(manifest_bytes), sha(lock_bytes)) == (NEW_MANIFEST, NEW_LOCK), 'current manifest/lock hash')
    require(receipt['kind'] == 'exact-reviewed-typings-lock-transition'
            and receipt['oldManifestSha256'] == OLD_MANIFEST and receipt['oldLockSha256'] == OLD_LOCK
            and receipt['newManifestSha256'] == NEW_MANIFEST and receipt['newLockSha256'] == NEW_LOCK,
            'fixed transition binding')
    new_manifest, new_lock = json.loads(manifest_bytes), json.loads(lock_bytes)
    old_manifest = copy.deepcopy(new_manifest)
    for name in PINS:
        del old_manifest['devDependencies'][name]
    old_lock = copy.deepcopy(new_lock)
    for key, item in receipt['packageDelta'].items():
        if item['old'] is None:
            del old_lock['packages'][key]
        else:
            old_lock['packages'][key] = item['old']
    # npm's stable two-space layout/order lets us recover the ORIGINAL bytes.
    historical_manifest, historical_lock = encoded(old_manifest), encoded(old_lock)
    require((sha(historical_manifest), sha(historical_lock)) == (OLD_MANIFEST, OLD_LOCK), 'historical byte reconstruction')
    transition(old_manifest, new_manifest, old_lock, new_lock, receipt)
    return historical_manifest, historical_lock


def notice_prefix(data, receipt):
    block = receipt['priorNoticeBundle']
    prefix = data[:block['bytes']]
    require(len(prefix) == block['bytes'] and sha(prefix) == block['sha256'], 'historical notice prefix')
    return prefix


def check_notices(data, receipt):
    notice_prefix(data, receipt)
    require(sha(data) == receipt['noticeBundleSha256'], 'new notice bundle hash')
    for item in receipt['archives']:
        block = item['noticeBlock']
        notice = data[block['offset']:block['offset'] + block['bytes']]
        require(len(notice) == block['bytes'] and sha(notice) == block['sha256'], 'actual appended notice bytes')
