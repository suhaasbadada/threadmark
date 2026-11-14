#!/bin/sh
# Ordinary import: explicit full-bound read; no lifecycle/publication/frame bypass.
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-file-context-api.XXXXXX")
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
    model.setContextFileFilter(["a.rs"])
    _ = model.canPrepareContext
    _ = model.canInspectRefinement
    model.prepareContext()
    let request = try FileContextRequest(project: project, query: "center", original: "exact original", mode: .literal, selectedPaths: ["a.rs"])
    _ = Operation.prepareContextFilesBound(request)
    _ = FileContextControls(model: model)
}
SWIFT
check
for member in project query original mode selectedPaths; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
func bypass(_ request: inout FileContextRequest) { request.$member = request.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "Context capture unexpectedly mutable" >&2; exit 1; fi
  grep -q 'cannot assign to property' "$scratch/probe.log"
done
for member in fileContextOwner fileContextOperation preparationRevision generation configurationGeneration ownedOperations; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { _ = model.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "Context lifecycle unexpectedly public" >&2; exit 1; fi
  grep -q 'inaccessible due to' "$scratch/probe.log"
done
for member in contextFileFilter contextSelectedPaths preview; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { model.$member = nil }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "Context publication unexpectedly public" >&2; exit 1; fi
  grep -q 'setter is inaccessible' "$scratch/probe.log"
done
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
func bypass(_ id: String) { _ = Operation.prepareContextFilesBound(id) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "unbound file Context accepted" >&2; exit 1; fi
grep -q "expected argument type 'FileContextRequest'" "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import Foundation
import CompanionKit
func bypass(_ data: Data, _ request: FileContextRequest) throws { _ = try FileContextDocument.decode(data, request: request) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "Context decoder unexpectedly public" >&2; exit 1; fi
grep -q 'inaccessible due to' "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import Foundation
import CompanionKit
func bypass(_ preview: ContextPreview, _ data: Data) {
    _ = FileContextDocument(preview: preview, selectedPaths: ["a.rs"], evidence: [], matchingAnchors: 0, scannedAnchors: 0, truncated: false, bytes: data)
}
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "Context frame construction unexpectedly public" >&2; exit 1; fi
grep -q 'inaccessible due to' "$scratch/probe.log"
echo "File-scoped Context API boundary passed"
