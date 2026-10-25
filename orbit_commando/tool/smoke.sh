#!/usr/bin/env bash
# Installs the release and debug APKs on the running emulator, launches each
# several times (cold start) and records whether the process is still alive
# after 40 s. On a death, prints the app's error lines and why it died.
PKG=com.orbitcommando.orbit_commando
result=OK
: > smoke-result.txt
for apk in orbit-commando-94.apk orbit-commando-94-debug.apk; do
  adb uninstall "$PKG" >/dev/null 2>&1
  adb install -r "dist/$apk" || { echo "INSTALL FAILED $apk" >> smoke-result.txt; result=FAIL; continue; }
  runs=3
  [ "$apk" = orbit-commando-94-debug.apk ] && runs=1
  for run in $(seq 1 $runs); do
    adb shell am force-stop "$PKG"
    adb logcat -c
    adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 40
    log="smoke-logcat-$apk-$run.txt"
    adb logcat -d > "$log"
    adb exec-out screencap -p > "smoke-$apk-$run.png" 2>/dev/null
    pids=$(grep -oE "Start proc [0-9]+:$PKG" "$log" | grep -oE "[0-9]+" | tr '\n' '|')
    if adb shell pidof "$PKG" >/dev/null; then
      echo "alive $apk run $run" >> smoke-result.txt
    else
      echo "DIED $apk run $run" >> smoke-result.txt
      result=FAIL
      {
        echo "== $apk run $run"
        # Errors/warnings from the app process, and system lines about it.
        grep -E "^\S+ \S+\s+(${pids%|}${pids:+|}NOPID)\s+[0-9]+ [EFW] " "$log" | grep -v "Access denied"
        grep -E "has died|Killing ${pids%|}|Fatal signal|DEBUG|tombstone|ANR in|lowmemorykiller|$PKG.*(crash|died|exit)" "$log"
      } | head -120 >> smoke-crash.txt
    fi
  done
done
sed -i "1i $result" smoke-result.txt
