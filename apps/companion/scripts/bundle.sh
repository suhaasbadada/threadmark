#!/bin/sh
# Build/package only. Does not launch, install, sign, download, or change preferences.
set -eu
cd "$(dirname "$0")/.."
sh scripts/swift.sh build --configuration release --product ThreadmarkCompanion
bin_dir=$(sh scripts/swift.sh build --configuration release --show-bin-path)
mkdir -p dist/Threadmark.app/Contents/MacOS
cp "$bin_dir/ThreadmarkCompanion" dist/Threadmark.app/Contents/MacOS/ThreadmarkCompanion
cp Resources/Info.plist dist/Threadmark.app/Contents/Info.plist
