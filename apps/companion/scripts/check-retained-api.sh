#!/bin/sh
# Run after the documented Swift test wrapper builds CompanionKit. Verify both
# successful public model access and rejection of direct controller access from
# an ordinary importing module (not @testable).
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-retained-api.XXXXXX")
cleanup() {
  rm -f "$scratch/public.swift" "$scratch/controller.swift" "$scratch/controller.log"
  rmdir "$scratch"
}
trap cleanup EXIT HUP INT TERM
cat > "$scratch/public.swift" <<'SWIFT'
import CompanionKit
@MainActor func inspect(_ model: CompanionModel) {
    _ = model.retainedActionsAvailable
    model.cancelRefinement()
}
SWIFT
cat > "$scratch/controller.swift" <<'SWIFT'
import CompanionKit
@MainActor func bypass(_ model: CompanionModel) {
    _ = model.retainedReview
}
SWIFT
check() {
  "$compiler" -typecheck -sdk "$sdk" -I "$package/.build/debug/Modules" -F "$developer" \
    -Xcc -nostdinc -Xcc -isystem -Xcc "$resource" \
    -Xcc -isystem -Xcc "$sdk/usr/include" \
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" "$1"
}
check "$scratch/public.swift"
if check "$scratch/controller.swift" > "$scratch/controller.log" 2>&1; then
  echo "retained controller must not be public" >&2
  exit 1
fi
grep -q "'retainedReview' is inaccessible due to 'internal' protection level" "$scratch/controller.log"
echo "retained model API boundary passed"
