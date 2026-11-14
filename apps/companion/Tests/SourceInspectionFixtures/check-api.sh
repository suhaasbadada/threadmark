#!/bin/sh
# Ordinary importing-module probes, not @testable. Run after the SDK wrapper.
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-inspection-api.XXXXXX")
cleanup() { rm -f "$scratch/probe.swift" "$scratch/probe.log"; rmdir "$scratch"; }
trap cleanup EXIT HUP INT TERM
check() {
  "$compiler" -typecheck -sdk "$sdk" -I "$package/.build/debug/Modules" -F "$developer" \
    -Xcc -nostdinc -Xcc -isystem -Xcc "$resource" -Xcc -isystem -Xcc "$sdk/usr/include" \
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" "$scratch/probe.swift"
}
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
@MainActor func action(_ model: CompanionModel, _ anchor: Evidence, _ project: Project) throws {
    model.setInspectionRadius(2)
    model.sourceQueryChanged()
    _ = model.canInspectSource(anchor)
    model.inspectSource(anchor)
    _ = model.sourceInspection
    // Direct normal reads still require the full Z binding, never an ID/row alone.
    _ = Operation.inspectSourceAnchorBound(try SourceInspectionRequest(project: project, anchor: anchor, radius: 2))
}
SWIFT
check
for member in inspectionOwner inspectionQueryScope inspectionQueryGeneration ownedOperations; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { _ = model.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "inspection state unexpectedly public" >&2; exit 1; fi
  grep -q 'inaccessible due to' "$scratch/probe.log"
done
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
func bypass(_ anchor: Evidence) { _ = Operation.inspectSourceAnchorBound(anchor) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "unbound inspection unexpectedly accepted" >&2; exit 1; fi
grep -q "expected argument type 'SourceInspectionRequest'" "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { model.sourceInspection = nil }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "inspection publication unexpectedly public" >&2; exit 1; fi
grep -q "setter is inaccessible" "$scratch/probe.log"
echo "inspection model API boundary passed"
