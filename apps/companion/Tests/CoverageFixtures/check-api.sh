#!/bin/sh
# Ordinary-import API gate. No @testable access.
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-coverage-api.XXXXXX")
cleanup() { rm -f "$scratch/probe.swift" "$scratch/probe.log"; rmdir "$scratch"; }
trap cleanup EXIT HUP INT TERM
check() {
  "$compiler" -typecheck -sdk "$sdk" -I "$package/.build/debug/Modules" -F "$developer" \
    -Xcc -nostdinc -Xcc -isystem -Xcc "$resource" -Xcc -isystem -Xcc "$sdk/usr/include" \
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" "$scratch/probe.swift"
}
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
@MainActor func action(_ model: CompanionModel, _ project: Project) throws {
    _ = model.canInspectCoverage
    model.inspectCoverage()
    _ = model.coverageReport?.files
    _ = Operation.coverageBound(try CoverageRequest(project: project))
}
SWIFT
check
for member in coverageOwner coverageOperation coverageNeedsMetadata generation configurationGeneration ownedOperations; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { _ = model.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "coverage state unexpectedly public" >&2; exit 1; fi
  grep -q 'inaccessible due to' "$scratch/probe.log"
done
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
func bypass(_ id: String) { _ = Operation.coverageBound(id) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "unbound coverage unexpectedly accepted" >&2; exit 1; fi
grep -q "expected argument type 'CoverageRequest'" "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { model.coverageReport = nil }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "coverage publication unexpectedly public" >&2; exit 1; fi
grep -q 'setter is inaccessible' "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import Foundation
import CompanionKit
func bypass(_ data: Data, _ request: CoverageRequest) throws { _ = try CoverageDocument.decode(data, request: request) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "coverage decoder unexpectedly public" >&2; exit 1; fi
grep -q 'inaccessible due to' "$scratch/probe.log"
echo "coverage model API boundary passed"
