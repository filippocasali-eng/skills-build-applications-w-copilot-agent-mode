#!/usr/bin/env bash
# MarketPilot AI - build dell'APK di debug (Linux/macOS). Richiede JDK 17+ e Android SDK.
set -euo pipefail
cd "$(dirname "$0")/.."
./gradlew testDebugUnitTest :core:model:test :core:common:test :core:network:test :domain:indicators:test \
  :domain:market:test :domain:scoring:test :domain:risk:test :domain:portfolio:test :domain:papertrading:test \
  :domain:backtesting:test :data:providers:test || echo "ATTENZIONE: alcuni test sono falliti"
./gradlew :app:assembleDebug
echo "APK: $(pwd)/app/build/outputs/apk/debug/app-debug.apk"
