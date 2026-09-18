## Table of Contents

- [Overview](#overview)
- [Useful commands for developers](#useful-commands-for-developers)
- [Updating app version notes](#updating-app-version-notes)
- [Releasing the application notes](#releasing-the-application-notes)
- [App Icon Generation](#app-icon-generation)
- [Test GitHub workflows locally](#test-github-workflows-locally)
- [Stop tracking files in Git](#stop-tracking-files-in-git)
- [Enable GitHub pages](#enable-github-pages)

---

## Overview

This document provides an overview of the Flutter/Dart concepts, commands, and project-specific workflows used in ClearNet to help new developers get up to speed quickly.

It complements what is documented in the [README](/README.md).

---

## Useful commands for developers

### Code Quality & Maintenance
- **Format everything**: `dart format .`
- **Check for static analysis issues**: `flutter analyze`
- **Run all unit/widget tests**: `flutter test`
- **Clean the build artifacts**: `flutter clean`
- **Fetch dependencies**: `flutter pub get`
- **Check environment health**: `flutter doctor`

### Build Commands
- **Build Debug APK**: `flutter build apk --debug`
- **Build Release APK**: `flutter build apk --release`
- **Build Release App Bundle (AAB)**: `flutter build appbundle --release`

### Execution & Telemetry
- **List available Emulators**: `flutter emulators`
- **Disable Dart/Flutter telemetry**: `dart --disable-analytics`
- **Force kill hanging Dart processes**: `pkill -9 dart`

### Framework upgrades
- **Upgrade Dart**: `sudo apt-get update && sudo apt-get install dart`
- **Upgrade Dart version**: `dart --version`

- **Upgrade Flutter**: `flutter upgrade`
- **Check Flutter version**: `flutter --version`

---

## Updating app version notes

To update the app to a higher version:

1. Insert a new entry in the [CHANGELOG.md](/CHANGELOG.md) describing the changes.
2. Open the [pubspec.yaml](/pubspec.yaml) file and locate the `version:` line (e.g., `version: 1.0.0+1`).
   - Increment the version name before the `+` (e.g., `1.0.1`) which corresponds to Android's `versionName`.
   - Increment the build number after the `+` (e.g., `2`) which corresponds to Android's `versionCode`.
3. Add any relevant text changelogs required for metadata updates if Fastlane or Google Play deployment pipelines are configured.

---

## Releasing the application notes

A keystore stores the cryptographic signing key required for Android production app releases.

### Create a keystore file

> Replace `keystore.jks` and `key-alias` with your desired secure values.

```bash
keytool -genkeypair \
  -v \
  -keystore keystore.jks \
  -alias key-alias \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

### Encode the keystore file

The decoding of this file occurs dynamically inside the GitHub repository release workflow.

```bash
base64 -i keystore.jks | tr -d '\n' > keystore.base64
```

### Update the local keystore configuration

Copy the example keystore property template from [keystore.properties.example](/android/app/src/keystore.properties.example) into a new file located at `android/app/keystore.properties`. 

Update the configuration variables inside `android/app/keystore.properties`:
```properties
storeFile=keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```
*(Ensure `keystore.jks` is placed in `android/app/` if building locally).*

### Create environment secrets in GitHub repository

To support automated production builds via GitHub Actions, add the following Repository Secrets in GitHub Settings under **Secrets and Variables > Actions**:

```txt
KEY_ALIAS
KEY_PASSWORD
KEYSTORE_CONTENT
KEYSTORE_FILE_NAME
KEYSTORE_PASSWORD
```

### Create app release via Tags

Push a tag matching the pattern `v*` to the `main` branch. The [release.yml](/.github/workflows/release.yml) workflow will automatically build the release APK and bundle, sign them securely, and create a new GitHub Release.

```bash
git checkout main
git tag v1.0.0
git push origin v1.0.0
```

#### Rebuild an existing tag (Force Push)

```bash
git tag -f v1.0.0 && git push origin v1.0.0 --force
```

---

## App Icon Generation

ClearNet uses the `icons_launcher` package to automatically format and generate adaptive launcher icons for both Android and iOS. This avoids having to manually resize assets in GIMP or third-party image manipulation programs.

### Automated Launcher Icon Configuration
1. Place your high-resolution app icon source file at `assets/images/app-logo.png`.
2. Ensure the configuration section exists in your [pubspec.yaml](/pubspec.yaml):
   ```yaml
   icons_launcher:
     image_path: 'assets/images/app-logo.png'
     platforms:
       android:
         enable: true
       ios:
         enable: true
   ```
3. Run the automated generation command in your terminal:
   ```bash
   dart run icons_launcher:create
   ```

---

## Test GitHub workflows locally

[**`act`**](https://github.com/nektos/act) is used to test workflows locally without pushing to GitHub or exhausting Actions runner runner minutes. It executes workflow runners inside local Docker containers.

### Installation
- **macOS (Homebrew)**: `brew install act`
- **Linux**: `curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash`
- **Windows**: `choco install act` or `scoop install act`

### Local Workspace Variables

Create these environment configurations at the root directory of the project to enable Android SDK bindings within `act`:

`.env` / `.vars`
```bash
ANDROID_HOME=/<path-to-your-local-sdk>/Android/Sdk
```

### Running Workflow Tasks
1. **List all available actions/jobs:**
   ```bash
   act -l
   ```
2. **Test Continuous Integration pipeline (`ci.yml`):**
   ```bash
   act -j build -W .github/workflows/ci.yml
   act -j test -W .github/workflows/ci.yml
   act -j lint -W .github/workflows/ci.yml
   ```
3. **Test Release Production pipeline (`release.yml`):**
   ```bash
   act -j build -W .github/workflows/release.yml
   ```

---

## Stop tracking files in Git

To wipe untracked build caches or files from Git tracking without deleting them locally from your disk, execute the following from the workspace root:

```bash
# Untrack build directory cache
git rm -r --cached build/

# Commit tracking updates
git commit -m "Stop tracking build/ directory"
```

---

## Enable GitHub Pages

The [pages.yml](/.github/workflows/pages.yml) workflow builds and deploys web artifacts directly to the `gh-pages` branch.

1. Go to the GitHub Repository Settings.
2. Select **Pages** from the left navigation panel.
3. Under **Build and deployment > Source**, select **Deploy from a branch**.
4. Choose `gh-pages` and select `/(root)` as the folder destination.
5. Click **Save**.


omplete the installation and run it for the first time, run the following commands in your terminal:
1.
Fetch the new dependency:
Shell Script
flutter pub get
2.
Install the pre-commit git hooks: If you haven't installed pre-commit on your system yet, install it first (e.g., via pip install pre-commit or brew install pre-commit), then install the hook into your local git repository:
Shell Script
python3 -m venv .venv
source .venv/bin/activate
Upgrade pip:

python -m pip install --upgrade pip
pip install pre-commit
pre-commit install

pre-commit installed at .git/hooks/pre-commit
3.
Run the initial sort across all files:
Shell Script
pre-commit run --all-files

(Note: Ensure you are within your active Python virtual environment .venv where pre-commit is installed if you haven't installed it globally).



/home/sherida101/flutter/bin/cache/dart-sdk

/home/sherida101/flutter