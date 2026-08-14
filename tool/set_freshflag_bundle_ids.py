#!/usr/bin/env python3
"""Replace inherited StayFresh application identifiers with FreshFlag IDs.

This is intentionally a small text migration rather than a hand-maintained Xcode
project rewrite. Run it before the macOS/Xcode Swift Package Manager migration.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBXPROJ = ROOT / "ios" / "Runner.xcodeproj" / "project.pbxproj"

OLD_APP_ID = "com.example.stayfresh"
NEW_APP_ID = "com.rpatel2023.freshflag"


def main() -> None:
    text = PBXPROJ.read_text(encoding="utf-8")
    occurrences = text.count(OLD_APP_ID)
    if occurrences == 0:
        if NEW_APP_ID in text:
            print(f"FreshFlag bundle IDs already present in {PBXPROJ.relative_to(ROOT)}")
            return
        raise SystemExit(
            "Could not find either the inherited or FreshFlag bundle identifier; "
            "inspect the Xcode project before continuing."
        )

    migrated = text.replace(OLD_APP_ID, NEW_APP_ID)
    if OLD_APP_ID in migrated:
        raise SystemExit("Bundle identifier migration was incomplete")
    PBXPROJ.write_text(migrated, encoding="utf-8")
    print(
        f"Replaced {occurrences} inherited bundle-ID occurrence(s) with "
        f"{NEW_APP_ID} in {PBXPROJ.relative_to(ROOT)}"
    )


if __name__ == "__main__":
    main()
