"""Inert exact two-archive replacement of the historical 22-package selection.

The historical preparer remains byte-identical. Node24's authentic tar root
contains a space: validate that exact archive-only root without rewriting it or
relaxing representable projection paths. No resolver, scripts or acquisition.
"""
import base64
import copy
import json

import sdk_compiler_candidate as s
import typings_alignment as a

DIRECTIVE_REQUIREMENT = ('Review all retained aligned reference directives and six suppression mentions '
    'in effect documentation comments; historical Node26 directive counts are not current. '
    'No static scanner is an official compiler semantic oracle.')


def requirements(historical):
    result = copy.deepcopy(historical)
    for item in result:
        if item['id'] == 'UPSTREAM-DIRECTIVES':
            item['requirement'] = DIRECTIVE_REQUIREMENT
    return result


def inspect_package(lock, selection, data, receipt):
    if selection['name'] not in a.PINS:
        return s.inspect_package(lock, selection, data)
    record = next(item for item in receipt['archives'] if item['name'] == selection['name'])
    package = s.path(selection['path'])
    a.require(package == 'node_modules/' + record['name'], 'exact aligned package location')
    entry = lock['packages'][package]
    for key in ('name', 'version', 'integrity', 'resolved', 'archiveSha256', 'archiveRoot', 'metadataSha256'):
        a.require(selection[key] == record[key], 'aligned selection identity')
    for key in ('version', 'integrity', 'resolved'):
        a.require(entry[key] == record[key], 'aligned lock identity')
    a.require(s.t.sha256(data) == record['archiveSha256'], 'aligned archive hash')
    files, expanded, declared = s.t.inspect(data, record['integrity'])
    root = s.t.safe_path(record['archiveRoot'])
    a.require(all(n.startswith(root + '/') for n in files), 'authentic archive root')
    relative = {s.path(n[len(root) + 1:]): b for n, b in files.items()}
    a.require({n: {'bytes': len(b), 'sha256': s.t.sha256(b)} for n, b in relative.items()}
              == record['files'], 'complete authentic archive inventory')
    manifest = json.loads(relative['package.json'])
    a.require(manifest == record['manifest'], 'whole authentic package metadata')
    required = {n: s.record(b, 'complete_metadata' if n == 'package.json' or n.endswith('/package.json')
        else 'authentic_notice' if s.NOTICE.fullmatch(n.rsplit('/', 1)[-1]) else 'declaration')
        for n, b in relative.items() if n == 'package.json' or n.endswith('/package.json')
        or n.endswith(s.TYPE_SUFFIXES) or s.NOTICE.fullmatch(n.rsplit('/', 1)[-1])}
    a.require(selection['files'] == required, 'all declarations/metadata/notices exactly selected')
    output = {package + '/' + n: relative[n] for n in required}
    s.t.check_paths(s.t.with_directories({n: False for n in output}))
    return output, {'path': package, 'name': record['name'], 'version': entry['version'],
        'integrity': entry['integrity'], 'resolved': entry['resolved'],
        'archiveSha256': s.t.sha256(data), 'archiveRoot': root,
        'compressedBytes': len(data), 'expandedBytes': expanded, 'declaredBytes': declared,
        'files': required, 'repository': manifest.get('repository'),
        'metadataBytesBase64': {n: base64.b64encode(b).decode() for n, b in relative.items()
                              if n == 'package.json' or n.endswith('/package.json')},
        'noticeBytesBase64': {n: base64.b64encode(b).decode() for n, b in relative.items()
                            if s.NOTICE.fullmatch(n.rsplit('/', 1)[-1])},
        'typeReferenceFacts': {n: s.facts(relative[n]) for n, r in required.items() if r['role'] == 'declaration'},
        'excludedTypeSources': {}, 'unselectedExportTypeSourceTargets': [],
        'noticeStatus': 'EVIDENCE_PRESENT_REVIEW_PENDING', 'typeGraphClosure': 'NOT established'}


def prepare(manifest_bytes, lock_bytes, plan, archives, fixtures, historical_plan, historical, receipt):
    """Reconstruct fixed data; the outer guard alone has separate resource intent.

    Historical candidate/plan hashes are pinned by sdk_projection before entry.
    Every unchanged package/fixture/API/compiler binding remains identical.
    """
    _, old_lock_bytes = a.current(manifest_bytes, lock_bytes, receipt)
    old_lock, lock = json.loads(old_lock_bytes), json.loads(lock_bytes)
    a.require(historical['lockSha256'] == historical_plan['lockSha256'] == a.OLD_LOCK,
              'historical lock binding')
    expected_plan = copy.deepcopy(historical_plan)
    for key in ('lockSha256', 'packages', 'sourceBindings', 'evidenceBindings'):
        expected_plan[key] = plan[key]
    expected_plan['knownMissing'] = requirements(historical_plan['knownMissing'])
    a.require(plan == expected_plan and plan['lockSha256'] == a.NEW_LOCK, 'closed aligned plan')
    a.require(len(plan['packages']) == len(historical_plan['packages']) == 22, 'fixed 22 packages')
    packages, output = [], {}
    for old, selection in zip(historical_plan['packages'], plan['packages']):
        a.require(old['path'] == selection['path'] and old['name'] == selection['name'], 'no added/moved package')
        if selection['name'] not in a.PINS:
            a.require(old == selection, 'other twenty selections unchanged')
            # Check old and new locks identically; accepted Redis is NOT selected.
            a.require(all(old_lock['packages'][old['path']][key] == lock['packages'][old['path']][key]
                          for key in ('version', 'integrity', 'resolved')), 'unchanged selected archive identity')
        selected, evidence = inspect_package(lock, selection, archives[selection['integrity']], receipt)
        a.require(not set(output) & set(selected), 'duplicate aligned file')
        output.update(selected)
        if selection['name'] not in a.PINS:
            a.require(evidence == next(p for p in historical['packages'] if p['path'] == selection['path']),
                      'other twenty actual package bytes unchanged')
        packages.append(evidence)
    for name, bound in (('compressedBytes', s.t.COMPRESSED_LIMIT), ('expandedBytes', s.t.EXPANDED_LIMIT),
                        ('declaredBytes', s.t.EXPANDED_LIMIT)):
        a.require(sum(p[name] for p in packages) <= bound, 'aggregate aligned archive bound')
    a.require(set(fixtures) == set(s.FIXTURE_HASHES) and plan['fixtureHashes'] == s.FIXTURE_HASHES,
              'fixed full fixture scope')
    for name, data in fixtures.items():
        a.require(s.t.sha256(data) == s.FIXTURE_HASHES[name], 'unchanged fixture bytes')
        output['__compiler_roots/' + name] = data
    s.t.check_paths(s.t.with_directories({n: False for n in output}))
    a.require(sum(map(len, output.values())) <= s.t.DESTINATION_LIMIT, 'aligned destination bound')
    candidate = copy.deepcopy(historical)
    candidate.update(lockSha256=a.NEW_LOCK, inputPlanSha256=s.t.sha256(s.encoded(plan)),
        knownMissing=requirements(historical['knownMissing']),
        packages=packages, sourceBindings=plan['sourceBindings'], evidenceBindings=plan['evidenceBindings'],
        potentialReadFileHashes={n: s.t.sha256(b) for n, b in sorted(output.items())},
        counts={'packages': len(packages), 'potentialReadFiles': len(output),
                'declarations': sum(r['role'] == 'declaration' for p in packages for r in p['files'].values()),
                'typingSources': 0})
    # Only the two replacements change facts. They have no omitted export source,
    # missing notice or unknown recognized operand, so historical requirements
    # remain as explicit blocking history, NOT evidence of new semantic success.
    for package in packages:
        if package['name'] in a.PINS:
            a.require(not any(f['unknownReferences'] for f in package['typeReferenceFacts'].values()),
                      'new unknown reference requires separate review')
    a.require(candidate['executionApproved'] is False and candidate['selectionApproved'] is False
              and candidate['materialized'] is False and candidate['compilerDescriptor'] is None,
              'inert candidate only')
    return candidate
