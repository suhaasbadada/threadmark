#!/bin/sh
# Ordinary-import bound read is public; response construction/publication/lifetime is not.
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-ranked-human-api.XXXXXX")
cleanup() { rm -f "$scratch/probe.swift" "$scratch/probe.log"; rmdir "$scratch"; }
trap cleanup EXIT HUP INT TERM
check() {
  "$compiler" -typecheck -sdk "$sdk" -I "$package/.build/debug/Modules" -F "$developer" \
    -Xcc -nostdinc -Xcc -isystem -Xcc "$resource" -Xcc -isystem -Xcc "$sdk/usr/include" \
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" "$scratch/probe.swift"
}
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
@MainActor func action(_ model: CompanionModel, _ project: Project, _ service: any CoreService) async throws {
    model.setHumanSearchMode(.rankedAnyTerms)
    model.setHumanSearchKindFilter(["note"])
    _ = model.canSearchHumanNotes("synthetic terms")
    model.searchHumanContext("synthetic terms")
    let request = try RankedHumanSearchRequest(binding: HumanContextReadBinding(project: project), query: "synthetic terms", kinds: ["note"])
    _ = try await service.perform(.searchHumanContextTermsBound(request))
    _ = HumanContextSearchView(model: model)
}
SWIFT
check
for member in rankedHumanSearchOwner humanSearchGeneration humanSearchTicket humanSearchScope generation configurationGeneration ownedOperations; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { _ = model.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "ranked human lifecycle unexpectedly public" >&2; exit 1; fi
  grep -q 'inaccessible due to' "$scratch/probe.log"
done
for member in rankedHumanSearch humanSearchMode; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) { model.$member = model.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "ranked human publication unexpectedly public" >&2; exit 1; fi
  grep -q 'setter is inaccessible' "$scratch/probe.log"
done
cat > "$scratch/probe.swift" <<'SWIFT'
import Foundation
import CompanionKit
func bypass(_ bytes: Data, _ request: RankedHumanSearchRequest) throws { _ = try RankedHumanSearch.decode(bytes, request: request) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "ranked human decoder unexpectedly public" >&2; exit 1; fi
grep -q 'inaccessible due to' "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import Foundation
import CompanionKit
func bypass(_ document: RankedHumanSearch.Document, _ bytes: Data) { _ = RankedHumanSearch(document: document, bytes: bytes) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "ranked human constructor unexpectedly public" >&2; exit 1; fi
grep -q 'inaccessible due to' "$scratch/probe.log"
for member in bytes readID; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
func bypass(_ result: RankedHumanSearch) { _ = result.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "ranked human adoption identity unexpectedly public" >&2; exit 1; fi
  grep -q 'inaccessible due to' "$scratch/probe.log"
done
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
func bypass() { _ = Operation.searchHumanContextTermsBound("alpha") }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "ranked human unbound ID accepted" >&2; exit 1; fi
grep -q "expected argument type 'RankedHumanSearchRequest'" "$scratch/probe.log"
echo "Ranked human search API boundary passed"
