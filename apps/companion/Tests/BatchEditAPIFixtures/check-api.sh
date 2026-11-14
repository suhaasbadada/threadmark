#!/bin/sh
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-batch-api.XXXXXX")
cleanup() { rm -f "$scratch/probe.swift" "$scratch/probe.log"; rmdir "$scratch"; }
trap cleanup EXIT HUP INT TERM
check() {
  "$compiler" -typecheck -strict-concurrency=complete -warnings-as-errors -sdk "$sdk" -I "$package/.build/debug/Modules" -F "$developer" \
    -Xcc -nostdinc -Xcc -isystem -Xcc "$resource" -Xcc -isystem -Xcc "$sdk/usr/include" \
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" "$scratch/probe.swift"
}
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
@MainActor func flow(_ m: CompanionModel, _ id: String) {
    m.openContext(id)
    m.stageBatchUpdate(id: id, kind: "note", text: "Synthetic draft", expected: m.humanContextRevisionBinding(id))
    m.stageBatchRetire(); m.removeBatchEntry(id); m.clearBatchPlan()
    m.reviewBatch(); m.cancelBatchReview(); m.reviewBatch()
    if let review = m.pendingBatchReview { m.applyBatch(review) }
    _ = m.stagedBatch.count; _ = m.batchReceipt?.count
}
SWIFT
check
for member in batchExecution batchBinding batchActive batchDispatched batchPlanGeneration generation configurationGeneration ownedOperations retainedReview; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ m: CompanionModel) { _ = m.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "batch lifecycle unexpectedly public" >&2; exit 1; fi
  grep -q 'inaccessible due to' "$scratch/probe.log"
done
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
func bypass(_ review: BatchReview) { _ = Operation.editContextBatchBound(review) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "pending batch disclosure executable" >&2; exit 1; fi
grep -q "expected argument type 'BatchExecution'" "$scratch/probe.log"
cat > "$scratch/probe.swift" <<'SWIFT'
import CompanionKit
func bypass(_ review: BatchReview) { _ = BatchExecution(review) }
SWIFT
if check > "$scratch/probe.log" 2>&1; then echo "batch execution construction public" >&2; exit 1; fi
grep -q 'inaccessible due to' "$scratch/probe.log"
for member in stagedBatch pendingBatchReview batchReceipt; do
  cat > "$scratch/probe.swift" <<SWIFT
import CompanionKit
@MainActor func bypass(_ m: CompanionModel) { m.$member = m.$member }
SWIFT
  if check > "$scratch/probe.log" 2>&1; then echo "batch publisher public" >&2; exit 1; fi
  grep -q 'setter is inaccessible' "$scratch/probe.log"
done
echo "batch API boundary passed"
