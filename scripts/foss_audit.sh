#!/bin/bash
# SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
# SPDX-License-Identifier: MIT

# Checks that ClearNet's dependencies and build meet F-Droid's FOSS rules.
# Runs locally or in CI. Every check runs, then the script exits non-zero if
# any of them found a problem. Run `flutter pub get` first.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

FAILURES=0
fail() {
    echo "FAIL: $*"
    FAILURES=$((FAILURES + 1))
}

# Proprietary SDKs and services that F-Droid rejects, as Maven group prefixes
PROPRIETARY_PATTERN='com\.google\.android\.gms|com\.google\.firebase|com\.google\.android\.play|com\.google\.mlkit|com\.google\.android\.ads|com\.google\.android\.datatransport|com\.android\.billingclient|com\.crashlytics|io\.fabric|com\.huawei\.hms|com\.huawei\.agconnect|com\.onesignal|com\.facebook\.android|com\.appsflyer|com\.adjust\.sdk|io\.sentry|com\.mapbox\.mapboxsdk|com\.amplitude|com\.mixpanel'

# Equivalent Dart packages that wrap proprietary SDKs
PROPRIETARY_PUB_PATTERN='^(firebase_[a-z_]+|cloud_firestore|google_mobile_ads|google_sign_in|google_maps_flutter|in_app_purchase|in_app_review|sentry_flutter|onesignal_flutter|appsflyer_sdk|facebook_[a-z_]+|mixpanel_flutter|amplitude_flutter|huawei_[a-z_]+|google_mlkit_[a-z_]+)$'

# Licences accepted as FOSS when scanning dependency LICENSE files
FOSS_LICENCE_PATTERN='MIT License|Permission is hereby granted, free of charge|Redistribution and use in source and binary forms|Apache License|Mozilla Public License|GNU (LESSER |AFFERO )?GENERAL PUBLIC LICENSE|GNU Lesser General Public License|ISC License|zlib License|This software is provided .as-is.|Unlicense|Creative Commons Zero|CC0'

echo "==============================================="
echo "FOSS audit"
echo "==============================================="

if [ ! -f ".dart_tool/package_config.json" ]; then
    echo "Error: .dart_tool/package_config.json not found. Run 'flutter pub get' first."
    exit 1
fi

# Resolve the on-disk directory of every third-party Dart package. This app and
# the Flutter SDK's own packages are skipped: F-Droid builds the SDK from source.
PACKAGE_DIRS=$(python3 - <<'EOF'
import json, os, pathlib, urllib.parse
config_path = pathlib.Path(".dart_tool/package_config.json").resolve()
config = json.loads(config_path.read_text())

def to_path(uri):
    if uri.startswith("file://"):
        return urllib.parse.unquote(urllib.parse.urlparse(uri).path)
    return os.path.normpath(os.path.join(config_path.parent, uri))

flutter_root = to_path(config["flutterRoot"]) + os.sep if "flutterRoot" in config else None
for pkg in config["packages"]:
    path = to_path(pkg["rootUri"])
    if pkg["name"] == "clearnet" or (flutter_root and path.startswith(flutter_root)):
        continue
    print(f"{pkg['name']}\t{path}")
EOF
)

# Dart packages that wrap proprietary SDKs
echo -e "\n[PHASE 1] Checking Dart dependencies for proprietary SDK wrappers..."
PUB_MATCHES=$(cut -f1 <<<"$PACKAGE_DIRS" | grep -E "$PROPRIETARY_PUB_PATTERN" || true)
if [ -n "$PUB_MATCHES" ]; then
    fail "Proprietary SDK wrapper packages found:"
    echo "$PUB_MATCHES"
else
    echo "No proprietary SDK wrapper packages found."
fi

# Prebuilt binaries shipped inside Dart packages (F-Droid builds from source)
echo -e "\n[PHASE 2] Scanning Dart packages for prebuilt binaries..."
FOUND_BINARIES=""
while IFS=$'\t' read -r name dir; do
    [ -d "$dir" ] || continue
    # Skip build/ folders: Gradle writes local build output into plugin folders
    MATCHES=$(find "$dir" -type d -name build -prune -o -type f \( -name "*.aar" -o -name "*.jar" -o -name "*.so" \
        -o -name "*.a" -o -name "*.dex" -o -name "*.apk" -o -name "*.dylib" -o -name "*.dll" \) \
        ! -name "gradle-wrapper.jar" -print 2>/dev/null || true)
    [ -n "$MATCHES" ] && FOUND_BINARIES+="$name:"$'\n'"$MATCHES"$'\n'
done <<<"$PACKAGE_DIRS"
if [ -n "$FOUND_BINARIES" ]; then
    fail "Prebuilt binaries found in Dart packages:"
    echo "$FOUND_BINARIES"
else
    echo "No prebuilt binaries found in Dart packages."
fi

# Every Dart dependency must carry a recognised FOSS licence
echo -e "\n[PHASE 3] Checking Dart dependency licences..."
UNLICENSED=""
while IFS=$'\t' read -r name dir; do
    [ -d "$dir" ] || continue
    LICENCE_FILE=$(find "$dir" -maxdepth 1 -type f -iname "LICEN[CS]E*" | head -n 1)
    if [ -z "$LICENCE_FILE" ]; then
        UNLICENSED+="$name (no licence file)"$'\n'
    elif ! grep -qiE "$FOSS_LICENCE_PATTERN" "$LICENCE_FILE"; then
        UNLICENSED+="$name (unrecognised licence: $LICENCE_FILE)"$'\n'
    fi
done <<<"$PACKAGE_DIRS"
if [ -n "$UNLICENSED" ]; then
    fail "Dependencies without a recognised FOSS licence (review manually):"
    echo "$UNLICENSED"
else
    echo "All Dart dependencies carry a recognised FOSS licence."
fi

# Gradle release runtime classpath must be free of proprietary artifacts
echo -e "\n[PHASE 4] Auditing Android releaseRuntimeClasspath..."
if [ -d "android" ]; then
    DEPENDENCIES_DUMP="$(mktemp)"
    trap 'rm -f "$DEPENDENCIES_DUMP"' EXIT
    (cd android && chmod +x gradlew && ./gradlew -q app:dependencies --configuration releaseRuntimeClasspath) >"$DEPENDENCIES_DUMP"

    PROPRIETARY_MATCHES=$(grep -E "$PROPRIETARY_PATTERN" "$DEPENDENCIES_DUMP" | sed 's/^[ |+\\-]*//' | sort -u || true)
    if [ -n "$PROPRIETARY_MATCHES" ]; then
        fail "Proprietary artifacts found in the release dependency tree:"
        echo "$PROPRIETARY_MATCHES"
    else
        echo "No proprietary artifacts found in the release dependency tree."
    fi
else
    fail "Native android module folder not found."
fi

# Project sources must not reference proprietary SDKs
echo -e "\n[PHASE 5] Scanning project sources for proprietary SDK references..."
SOURCE_MATCHES=$(grep -rnE "$PROPRIETARY_PATTERN" lib android/app/src android/*.kts android/app/*.kts 2>/dev/null || true)
if [ -n "$SOURCE_MATCHES" ]; then
    fail "Proprietary SDK references found in project sources:"
    echo "$SOURCE_MATCHES"
else
    echo "No proprietary SDK references found in project sources."
fi

# The APK must not embed Google's encrypted dependency metadata blob
echo -e "\n[PHASE 6] Checking that the dependency-info block is disabled..."
if grep -q "includeInApk = false" android/app/build.gradle.kts &&
    grep -q "includeInBundle = false" android/app/build.gradle.kts; then
    echo "dependenciesInfo is disabled for APKs and bundles."
else
    fail "android/app/build.gradle.kts must set dependenciesInfo { includeInApk = false; includeInBundle = false }."
fi

echo -e "\n==============================================="
if [ "$FAILURES" -gt 0 ]; then
    echo "FOSS AUDIT FAILED: $FAILURES phase(s) reported problems."
    echo "==============================================="
    exit 1
fi
echo "FOSS AUDIT COMPLETED SUCCESSFULLY!"
echo "==============================================="
