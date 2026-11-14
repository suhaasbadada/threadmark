#!/bin/sh
# Ordinary-import positive bound read; private publication/registry remains private.
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-query-filter-api.XXXXXX")
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
    model.setQueryFileFilter(["a.rs"])
    _ = model.canQuery("center")
    model.query("center")
    let request = try FileQueryRequest(project: project, query: "center", mode: .literal, selectedPaths: ["a.rs"])
    _ = Operation.queryFilesBound(request)
    _ = QueryFilterControls(model: model)
}
SWIFT
check
for member in fileQueryOwner generation configurationGeneration ownedOperations inspectionQueryScope; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { _ = model.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "query lifecycle unexpectedly public" >&2; exit 1; fi
  grep -q 'inaccessible due to' "$scratch/probe.log"
done
for member in queryFileFilter querySelectedPaths evidence; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { model.$member = nil }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "query publication unexpectedly public" >&2; exit 1; fi
  grep -q 'setter is inaccessible' "$scratch/probe.log"
done
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
func bypass(_ id: String) { _ = Operation.queryFilesBound(id) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "unbound file query accepted" >&2; exit 1; fi
grep -q "expected argument type 'FileQueryRequest'" "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import Foundation
import CompanionKit
func bypass(_ data: Data, _ request: FileQueryRequest) throws { _ = try FilteredQuery.decode(data, request: request) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "query decoder unexpectedly public" >&2; exit 1; fi
grep -q 'inaccessible due to' "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import Foundation
import CompanionKit
func bypass(_ report: QueryReport, _ data: Data) { _ = FilteredQuery(report: report, selectedPaths: ["a.rs"], bytes: data) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "query frame construction unexpectedly public" >&2; exit 1; fi
grep -q 'inaccessible due to' "$scratch/probe.log"
echo "Query file filter API boundary passed"
