#!/bin/bash

# FOSS Compliance Dependency Audit Automation Script
# Designed for local execution and Automated CI GitHub Workflows

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==============================================="
echo "STARTING FOSS BINARY AUDIT SCANS..."
echo "==============================================="

# Phase 1: Scan local pub.dev cache folders for precompiled binary objects
echo -e "\n[PHASE 1] Scanning .dart_tool/pub.dev cache for compiled native binaries..."
if [ -d ".dart_tool/pub.dev" ]; then
    FOUND_BINARIES=$(find .dart_tool/pub.dev/ \( -name "*.aar" -o -name "*.jar" -o -name "*.so" \) 2>/dev/null || true)
    if [ -n "$FOUND_BINARIES" ]; then
        echo "Attention: Found compiled binary objects in cache:"
        echo "$FOUND_BINARIES"
    else
        echo "No compiled binary blobs detected inside .dart_tool/pub.dev cache."
    fi
else
    echo ".dart_tool/pub.dev cache folder not initialised yet. Skipping local asset scans."
fi

# Phase 2: Inspect releaseRuntimeClasspath dependencies via Gradle configuration
echo -e "\n[PHASE 2] Auditing runtime dependencies from releaseRuntimeClasspath..."
if [ -d "android" ]; then
    cd android
    # Ensure gradlew executable wrapper permissions are configured properly
    chmod +x gradlew

    # Dump runtime dependencies tree list configuration
    ./gradlew app:dependencies --configuration releaseRuntimeClasspath > dependencies_dump.txt

    # Check for proprietary package markers commonly found in non-FOSS dependencies
    # E.g. proprietary authorization kits, vendor billing SDKs, analytics suites
    PROPRIETARY_MATCHES=$(grep -Ei 'com.google.android.gms:play-services-auth|com.android.billingclient|com.google.firebase:firebase-analytics' dependencies_dump.txt || true)

    if [ -n "$PROPRIETARY_MATCHES" ]; then
        echo "FOSS Violation Alert: Potential closed-source package signatures caught in tree:"
        echo "$PROPRIETARY_MATCHES"
        rm dependencies_dump.txt
        exit 1
    else
        echo "Dependency tree lookup verified clean. No flagged proprietary signatures discovered."
    fi
    rm dependencies_dump.txt
else
    echo "Error: Native android module context folder not found."
    exit 1
fi

echo -e "\n==============================================="
echo "FOSS DEPENDENCY AUDIT COMPLETED SUCCESSFULLY!"
echo "==============================================="
exit 0
