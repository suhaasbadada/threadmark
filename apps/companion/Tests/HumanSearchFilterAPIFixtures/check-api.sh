#!/bin/sh
# Ordinary-import checks; no GUI/host launch.
set -eu
fixtures=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
package=$(CDPATH= cd -- "$fixtures/../.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find swiftc)
resource="$(dirname "$compiler")/../lib/swift/clang/include"
developer="$(dirname "$compiler")/../../Library/Developer/Frameworks"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/threadmark-filter-api.XXXXXX")
cleanup() { rm -f "$scratch/private.log"; rmdir "$scratch"; }
trap cleanup EXIT HUP INT TERM
check() {
  "$compiler" -typecheck -strict-concurrency=complete -warnings-as-errors \
    -sdk "$sdk" -I "$package/.build/debug/Modules" -F "$developer" \
    -Xcc -nostdinc -Xcc -isystem -Xcc "$resource" \
    -Xcc -isystem -Xcc "$sdk/usr/include" \
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" "$1"
}
check "$fixtures/FilterPublic.swift"
if check "$fixtures/FilterPrivate.swift" > "$scratch/private.log" 2>&1; then
  echo "filtered search capture and publication must not be public" >&2; exit 1
fi
grep -q "setter is inaccessible" "$scratch/private.log"
grep -q "'humanSearchGeneration' is inaccessible due to 'private' protection level" "$scratch/private.log"
grep -q "'ownedOperations' is inaccessible due to 'private' protection level" "$scratch/private.log"
grep -q "inaccessible due to 'internal' protection level" "$scratch/private.log"
echo "human kind-filter API boundary passed"
