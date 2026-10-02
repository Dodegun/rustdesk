#!/usr/bin/env bash
set -euo pipefail
mkdir -p crash-evidence
app_id=com.dodegun.rustdesk.ime
apk=apk/RustDesk-IME-1.5.0-arm64.apk
finish() {
  local exit_code=$?
  adb logcat -d -v threadtime > crash-evidence/logcat.txt 2>&1 || true
  adb logcat -b crash -d -v threadtime > crash-evidence/crash-buffer.txt 2>&1 || true
  adb shell dumpsys activity exit-info "$app_id" > crash-evidence/exit-info.txt 2>&1 || true
  adb exec-out screencap -p > crash-evidence/screen.png 2>/dev/null || true
  if [[ ! -f crash-evidence/result.txt && "$exit_code" != 0 ]]; then
    echo "FAIL: execution stopped with exit code $exit_code; inspect crash logs." > crash-evidence/result.txt
  fi
}
trap finish EXIT
sha256sum "$apk" > crash-evidence/tested-apk-sha256.txt
sdk=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
adb shell getprop ro.build.fingerprint > crash-evidence/device-build.txt
adb shell getprop ro.product.cpu.abilist > crash-evidence/device-abis.txt
adb shell getprop ro.dalvik.vm.native.bridge > crash-evidence/native-bridge.txt
if ! grep -q arm64-v8a crash-evidence/device-abis.txt; then
  echo 'BLOCKED: emulator does not expose arm64-v8a; exact APK not executed.' | tee crash-evidence/result.txt
  exit 2
fi
adb install --abi arm64-v8a "$apk" | tee crash-evidence/install.txt
adb logcat -c
adb logcat -b crash -c
for iteration in 1 2 3 4 5; do
  adb shell am force-stop "$app_id"
  adb shell am start -W -n "$app_id/com.carriez.flutter_hbb.MainActivity" | tee -a crash-evidence/launches.txt
  sleep 5
  adb shell pidof "$app_id" | tee -a crash-evidence/pids.txt
done
adb shell monkey -p "$app_id" -s 20261002 --throttle 100 --pct-syskeys 0 300 > crash-evidence/monkey.txt 2>&1
adb shell input keyevent KEYCODE_HOME
sleep 2
adb shell am start -W -n "$app_id/com.carriez.flutter_hbb.MainActivity" >> crash-evidence/launches.txt
sleep 5
adb shell pidof "$app_id" >> crash-evidence/pids.txt
finish
if grep -Eiq 'FATAL EXCEPTION|Fatal signal|ANR in com.dodegun.rustdesk.ime|Unhandled Exception|E/flutter.*\[ERROR' crash-evidence/logcat.txt crash-evidence/crash-buffer.txt; then
  echo 'FAIL: crash/ANR/Flutter error signature found; inspect logs.' | tee crash-evidence/result.txt
  exit 1
fi
if grep -Eiq 'CRASH:|NOT RESPONDING|Monkey aborted|Error:' crash-evidence/monkey.txt crash-evidence/launches.txt; then
  echo 'FAIL: launch or stress test failed; inspect logs.' | tee crash-evidence/result.txt
  exit 1
fi
echo "PASS: exact ARM64 APK installed; 5 cold starts, 300 seeded events, background/foreground. Android API $sdk with ARM translation only; no Windows session/physical device validation." | tee crash-evidence/result.txt
