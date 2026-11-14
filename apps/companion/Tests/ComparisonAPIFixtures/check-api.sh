#!/bin/sh
# Ordinary-import public controls and private capture/registry fences.
set -eu
fixtures=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
package=$(CDPATH= cd -- "$fixtures/../.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-comparison-api.XXXXXX")
cleanup() { rm -f "$scratch/private.log"; rmdir "$scratch"; }
trap cleanup EXIT HUP INT TERM
check() {
  "$compiler" -typecheck -strict-concurrency=complete -warnings-as-errors \
    -sdk "$sdk" -I "$package/.build/debug/Modules" -F "$developer" \
    -Xcc -nostdinc -Xcc -isystem -Xcc "$resource" \
    -Xcc -isystem -Xcc "$sdk/usr/include" \
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" "$1"
}
check "$fixtures/ComparisonPublic.swift"
if check "$fixtures/ComparisonPrivate.swift" > "$scratch/private.log" 2>&1; then
  echo "comparison capture and registry must not be public" >&2
  exit 1
fi
grep -q "'comparisonActive' is inaccessible due to 'private' protection level" "$scratch/private.log"
grep -q "'ownedOperations' is inaccessible due to 'private' protection level" "$scratch/private.log"
grep -q "inaccessible due to 'internal' protection level" "$scratch/private.log"
echo "comparison model API boundary passed"
