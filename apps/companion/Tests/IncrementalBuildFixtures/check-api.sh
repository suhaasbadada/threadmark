#!/bin/sh
# Ordinary imports only; internal publication and lifecycle are not capabilities.
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-incremental-api.XXXXXX")
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
    _ = model.canBuildIncrementally
    model.buildIncrementally()
    _ = model.incrementalBuildReport?.persistentWrites
    _ = Operation.indexIncrementalBound(try IncrementalBuildRequest(project: project))
}
SWIFT
check
for member in incrementalBuildOperation incrementalMutationTicket generation configurationGeneration ownedOperations retainedReview; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { _ = model.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "incremental lifecycle unexpectedly public" >&2; exit 1; fi
  grep -q 'inaccessible due to' "$scratch/probe.log"
done
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
func bypass(_ id: String) { _ = Operation.indexIncrementalBound(id) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "unbound incremental accepted" >&2; exit 1; fi
grep -q "expected argument type 'IncrementalBuildRequest'" "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { model.incrementalBuildReport = nil }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "incremental publication public" >&2; exit 1; fi
grep -q 'setter is inaccessible' "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import Foundation
import CompanionKit
func bypass(_ data: Data, _ request: IncrementalBuildRequest) throws { _ = try IncrementalBuildReport.decode(data, request: request) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "incremental decoder public" >&2; exit 1; fi
grep -q 'inaccessible due to' "$scratch/probe.log"
echo "incremental Build API boundary passed"
