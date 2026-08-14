#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo '===== PHASE 8 SOURCE PREP ====='
python3 tool/set_freshflag_bundle_ids.py
python3 tool/generate_freshflag_icons.py

echo
echo '===== DEPENDENCIES ====='
flutter pub get
# Flutter 3.47 may rewrite this unrelated file during tool invocations.
git restore analysis_options.yaml

echo
echo '===== TESTS ====='
flutter test --no-pub

echo
echo '===== ANALYZE ====='
dart analyze

echo
echo '===== LINUX RELEASE BUILD ====='
flutter build linux --release --no-pub

echo
echo '===== IDENTITY CHECK ====='
if grep -R --line-number --fixed-strings 'stayfresh-36edf' lib android ios 2>/dev/null; then
  echo 'ERROR: inherited StayFresh Firebase project reference remains.' >&2
  exit 1
else
  echo 'No inherited stayfresh-36edf Firebase project reference found.'
fi

if grep -R --line-number --fixed-strings 'com.example.stayfresh' android ios 2>/dev/null; then
  echo 'ERROR: inherited StayFresh application identifier remains.' >&2
  exit 1
else
  echo 'No inherited com.example.stayfresh application identifier found.'
fi

grep -n 'PRODUCT_BUNDLE_IDENTIFIER = com.rpatel2023.freshflag' \
  ios/Runner.xcodeproj/project.pbxproj

echo
echo '===== GENERATED FRESHFLAG ICONS ====='
file assets/images/logos/freshflag.png \
  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png

echo
echo '===== WORKING TREE ====='
git status --short

echo
echo '===== DIFF STAT ====='
git diff --stat

echo
echo 'Phase 8 local source checkpoint completed successfully.'
