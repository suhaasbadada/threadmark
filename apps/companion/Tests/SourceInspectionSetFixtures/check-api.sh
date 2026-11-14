#!/bin/sh
# Ordinary import: no @testable authority or public unchecked constructors.
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-inspection-set-api.XXXXXX")
cleanup() { rm -f "$scratch/probe.swift" "$scratch/probe.log"; rmdir "$scratch"; }
trap cleanup EXIT HUP INT TERM
check() {
  "$compiler" -typecheck -sdk "$sdk" -I "$package/.build/debug/Modules" -F "$developer" \
    -Xcc -nostdinc -Xcc -isystem -Xcc "$resource" -Xcc -isystem -Xcc "$sdk/usr/include" \
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" "$scratch/probe.swift"
}
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
@MainActor func action(_ m: CompanionModel, _ row: SourceInspectionRow, _ request: SourceInspectionSetRequest) {
    m.stageSourceRow(row, selected: true); m.selectAllSourceRows(); m.clearStagedSourceRows()
    _ = m.canInspectSelectedSources; m.inspectSelectedSources(); _ = m.sourceInspectionSet
    _ = request.project; _ = request.anchors; _ = Operation.inspectSourceSetBound(request)
}
SWIFT
check
for expression in 'm.sourceInspectionSet = nil' 'm.stagedSourceRows = []' 'm.sourceInspectionRows = []' 'm.inspectionQueryCapture' 'm.ownedOperations'; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ m: CompanionModel) { _ = $expression }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "set publication unexpectedly public" >&2; exit 1; fi
  grep -q 'inaccessible' "$scratch/probe.log"
done
for type in SourceInspectionSetRequest SourceInspectionSetDocument SourceInspectionRow; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
func bypass() { _ = $type() }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "unchecked set construction unexpectedly public" >&2; exit 1; fi
  grep -q 'inaccessible\|no accessible initializers' "$scratch/probe.log"
done
echo 'inspection-set model API boundary passed'
