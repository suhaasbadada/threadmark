#!/bin/sh
# Command-scoped SDK isolation: this host has incompatible /usr/local/include
# system headers. Never alter global headers, SDK selection, or preferences.
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
sdk=$(xcrun --sdk macosx --show-sdk-path)
resource=$(xcrun --find swiftc)
resource="$(dirname "$resource")/../lib/swift/clang/include"
developer="$(dirname "$(xcrun --find swiftc)")/../../Library/Developer/Frameworks"
exec swift "$@" --package-path "$package" --build-system native --sdk "$sdk" \
  -Xswiftc -F -Xswiftc "$developer" -Xlinker -rpath -Xlinker "$developer" \
  -Xcc -nostdinc -Xcc -isystem -Xcc "$resource" \
  -Xcc -isystem -Xcc "$sdk/usr/include" \
  -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks"
