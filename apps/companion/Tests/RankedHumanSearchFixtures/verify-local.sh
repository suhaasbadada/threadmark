#!/bin/sh
# Offline, no GUI/host launch. Run from any directory after scripts/check.py builds CLI.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../../../.." && pwd)
cd "$root"
sdk=$(xcrun --sdk macosx --show-sdk-path)
resource=$(xcrun clang -print-resource-dir)
mkdir -p target/retained-fixtures target/export-fixtures target/source-inspection-fixtures
compile() {
  xcrun clang -std=c11 -Wall -Wextra -Werror -nostdinc -isystem "$resource/include" \
    -isystem "$sdk/usr/include" -isysroot "$sdk" "apps/companion/Tests/$1" -o "target/$2"
}
compile RetainedReviewFixtures/retained.c retained-fixtures/retained
for mode in malformed duplicate oversize unknown partial eof pipeclose idle hold deinit; do
  cp target/retained-fixtures/retained "target/retained-fixtures/retained-$mode"
done
compile ProjectExportFixtures/export.c export-fixtures/export
compile SourceInspectionFixtures/inspection.c source-inspection-fixtures/inspection
compile CoverageFixtures/coverage.c coverage-fixture
compile IncrementalBuildFixtures/incremental.c incremental-fixture
compile BatchEditAPIFixtures/batch.c batch-fixture
compile QueryFilterFixtures/query-filter.c query-filter-fixture
compile FileContextFixtures/context.c file-context-fixture
compile RankedHumanSearchFixtures/ranked-human.c ranked-human-fixture
export THREADMARK_CORE_TEST_BINARY="$root/target/debug/threadmark"
export THREADMARK_RETAINED_FIXTURES="$root/target/retained-fixtures"
export THREADMARK_EXPORT_FIXTURE="$root/target/export-fixtures/export"
export THREADMARK_SOURCE_INSPECTION_FIXTURE_BINARY="$root/target/source-inspection-fixtures/inspection"
export THREADMARK_COVERAGE_FIXTURE_BINARY="$root/target/coverage-fixture"
export THREADMARK_INCREMENTAL_FIXTURE_BINARY="$root/target/incremental-fixture"
export THREADMARK_BATCH_FIXTURE_BINARY="$root/target/batch-fixture"
export THREADMARK_QUERY_FILTER_FIXTURE_BINARY="$root/target/query-filter-fixture"
export THREADMARK_FILE_CONTEXT_FIXTURE_BINARY="$root/target/file-context-fixture"
export THREADMARK_RANKED_HUMAN_FIXTURE_BINARY="$root/target/ranked-human-fixture"
for configuration in debug release; do
  sh apps/companion/scripts/swift.sh test -c "$configuration" --no-parallel --disable-xctest --enable-swift-testing \
    -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
done
sh apps/companion/scripts/check-retained-api.sh
for family in SourceInspectionFixtures ComparisonAPIFixtures HumanSearchFilterAPIFixtures CoverageFixtures IncrementalBuildFixtures BatchEditAPIFixtures QueryFilterFixtures FileContextFixtures RankedHumanSearchFixtures; do
  sh "apps/companion/Tests/$family/check-api.sh"
done
sh apps/companion/scripts/bundle.sh
plutil -lint apps/companion/dist/Threadmark.app/Contents/Info.plist
