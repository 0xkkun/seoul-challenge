#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPORT_PRESETS = ROOT / "export_presets.cfg"
HAPTIC_MANAGER = ROOT / "scripts" / "autoload" / "haptic_manager.gd"
REQUIRED_PERMISSION = "android.permission.VIBRATE"


def main() -> int:
    if not HAPTIC_MANAGER.exists():
        print("[verify_android_permissions] OK: no haptic manager present")
        return 0

    haptic_source = HAPTIC_MANAGER.read_text(encoding="utf-8")
    if "Input.vibrate_handheld" not in haptic_source:
        print("[verify_android_permissions] OK: haptic manager does not use handheld vibration")
        return 0

    preset_source = EXPORT_PRESETS.read_text(encoding="utf-8")
    if REQUIRED_PERMISSION not in preset_source:
        print(
            "[verify_android_permissions] FAIL: Android export preset must include "
            f"{REQUIRED_PERMISSION} when Input.vibrate_handheld is used"
        )
        return 1

    print(f"[verify_android_permissions] OK: Android preset includes {REQUIRED_PERMISSION}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
