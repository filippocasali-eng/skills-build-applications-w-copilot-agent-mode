#!/usr/bin/env bash
# Installs the release and debug APKs on the running emulator, launches each
# and records whether the process is still alive after 25 s, plus logcat.
PKG=com.orbitcommando.orbit_commando
result=OK
for apk in orbit-commando-94.apk orbit-commando-94-debug.apk; do
  adb uninstall "$PKG" >/dev/null 2>&1
  adb install -r "dist/$apk" || { echo "INSTALL FAILED $apk" >> smoke-result.txt; result=FAIL; continue; }
  adb logcat -c
  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
  sleep 25
  adb exec-out screencap -p > "smoke-$apk.png" 2>/dev/null
  adb logcat -d > "smoke-logcat-$apk.txt"
  if adb shell pidof "$PKG" >/dev/null; then
    echo "alive $apk" >> smoke-result.txt
  else
    echo "DIED $apk" >> smoke-result.txt
    result=FAIL
  fi
  grep -E "FATAL EXCEPTION|AndroidRuntime|E/flutter|F libc|Fatal signal|E DEBUG|Abort message" "smoke-logcat-$apk.txt" | head -60 >> "smoke-crash-$apk.txt"
done
sed -i "1i $result" smoke-result.txt
