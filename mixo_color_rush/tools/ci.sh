#!/usr/bin/env bash
# Local CI: format check, static analysis and tests.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test tools
flutter analyze --fatal-infos --fatal-warnings
flutter test test/
