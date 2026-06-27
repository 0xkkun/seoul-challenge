# Android Build & Device Check

How to build a debug APK and run it on a real Android device for **visual
playtesting**. For automated UI verification, do **not** use this flow — see
[`AGENTS.md` › Android Device UAT Rules](../AGENTS.md) (use a debug bridge,
never coordinate taps).

All paths below are machine-specific (macOS / Homebrew examples) and stay
**untracked** — never commit keystores, editor settings, `build/`, or
`exports/`.

## One-time setup

- **Godot 4.6.3** with the Android export templates installed
  (`Editor → Manage Export Templates → Download`), e.g.
  `~/Library/Application Support/Godot/export_templates/4.6.3.stable/`.
  If `godot` is not on `PATH`, use the binary directly, e.g.
  `/path/to/Godot.app/Contents/MacOS/Godot`.
- **JDK 17** — `brew install openjdk@17` → `/opt/homebrew/opt/openjdk@17`.
- **Android SDK + platform-tools (`adb`)** — e.g. `~/Library/Android/sdk`.
- **Debug keystore** — e.g.
  `~/Library/Application Support/Godot/keystores/debug.keystore` (password
  `android`). Godot can generate one, or use `keytool`.
- **Editor Settings → Export → Android** — set `java_sdk_path`,
  `android_sdk_path`, `debug_keystore`, `debug_keystore_pass`.
- The repo already ships an **`Android`** preset in `export_presets.cfg`
  (arm64-v8a, package `com.oxkkun.afterschool.debug`, debug keystore left empty so
  it falls back to the editor setting above).

## Build

```bash
GODOT=godot   # or the absolute path to the Godot 4.6.3 binary
mkdir -p build/android   # build/ is gitignored
"$GODOT" --headless --path . --export-debug "Android" build/android/afterschool.debug.apk
```

A successful run prints `Signed` and writes the `.apk`.

## Install, launch, capture

```bash
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
"$ADB" install -r build/android/afterschool.debug.apk
"$ADB" shell monkey -p com.oxkkun.afterschool.debug -c android.intent.category.LAUNCHER 1
"$ADB" exec-out screencap -p > shot.png   # eyeball the frame
```

`adb exec-out screencap` is the reliable way to grab a device frame for review.

## Rules (see `AGENTS.md` › Android Device UAT Rules)

- Screenshots are **evidence for visual review only** — not the pass/fail
  control path for button interaction.
- Do **not** assert UI via `adb shell input tap <x y>` / `tap_pct`. Automated
  device UAT must enter Godot through an explicit debug-only bridge (localhost
  TCP/WebSocket with `adb forward`) and assert app state/log transitions.
- Keep `build/`, `exports/`, keystores, and editor settings untracked
  (machine-specific).
