<a id="top"></a>

# ClearNet

<img alt="Logo" src="assets/images/app-logo.png" width="120" height="120" />

[![Open Source](https://img.shields.io/badge/Open%20Source-MIT%20License-green.svg)](LICENSE)

![Continuous Integration](https://github.com/ASPTechInc/ClearNet/actions/workflows/ci.yml/badge.svg)

## Table of contents

- [Overview](#overview)
- [Features](#features)
- [Screenshots](#screenshots)
- [App concept](#how-it-works)
- [Requirements](#requirements)
- [Development setup](#development-setup)
- [Running the application](#how-to-run)
- [Testing the application](#how-to-test)
- [Formatting project code](#how-to-format-code)
- [Releasing the application](#how-to-release)
- [F-Droid metadata](#f-droid-metadata)
- [Licence](#licence)
- [Contributing](#contributing)
- [Developer notes](#developer-notes)
- [Other projects](#other-projects)
- [Support](#support)

---

[⬇️ Go to bottom](#bottom)

## Overview

ClearNet is a parental control app built with Flutter and Android system services.
It is designed to protect individuals by blocking harmful content, restricting apps, and preventing unauthorised removal.

---

## Features

|     | Feature               | Description                                                                                                                                                                                        |
| --- | :-------------------- |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ✅  | **Uninstall Protection with PIN**    | The app registers as a Device Admin that cannot be removed without entering the parent-set PIN.                                                                                                   |
| ✅  | **App Restriction**     | Blocks selected apps from being launched on the device.                                                                                                                                            |
| ✅  | **Website Blocking**  | - Built-in local VPN service filters network traffic. - Preloaded blocklist of harmful adult domains stored completely offline. - Parents can add custom domains to the blocklist. |
| ✅  | **SafeSearch Enforcement** | Automatically redirects Google, Bing, and YouTube queries to their respective SafeSearch IPs for family-safe browsing. |
| ✅  | **Offline & Secure**        | - Ships with a default blocklist stored in local assets. - Works without internet access. - No external servers, no data collection.                                                               |
| ✅  | **In-App Transparency** | Direct access to the Changelog, GitHub source code, and donation options within the app settings. |

---

## Screenshots

### Dark mode

| **Start screen** | **Game screen** | **Leaderboard** | **Settings (1)** |
| :---: | :---: | :---: | :---: |
| <img src="assets/screenshots/dark-theme/start-screen-dark.png" /> | <img src="assets/screenshots/dark-theme/game-screen-dark.png" /> | <img src="assets/screenshots/dark-theme/leaderboard-screen-dark.png" /> | <img src="assets/screenshots/dark-theme/settings-screen1-dark.png" /> |

| **Settings (2)** | **Settings (3)** | **How to play** | **How to answer** |
| :---: | :---: | :---: | :---: |
| <img src="assets/screenshots/dark-theme/settings-screen2-dark.png" /> | <img src="assets/screenshots/dark-theme/settings-screen3-dark.png" /> | <img src="assets/screenshots/dark-theme/how-to-play-guide-dialogue-dark.png" /> | <img src="assets/screenshots/dark-theme/how-to-answer-guide-dialogue-dark.png" /> |

| **Changelog** | **App updater** | **Build info** | **Support** |
| :---: | :---: | :---: | :---: |
| <img src="assets/screenshots/dark-theme/changelog-dialogue-dark.png" /> | <img src="assets/screenshots/dark-theme/app-updater-dialogue-dark.png" /> | <img src="assets/screenshots/dark-theme/app-build-info-dialogue-dark.png" /> | <img src="assets/screenshots/dark-theme/app-support-dialogue-dark.png" /> |

| **Reset progress** |
| :---: |
| <img src="assets/screenshots/dark-theme/reset-progress-dialogue-dark.png" width="300"  /> |

### Light mode

| **Start screen** | **Game screen** | **Leaderboard** | **Settings (1)** |
| :---: | :---: | :---: | :---: |
| <img src="assets/screenshots/light-theme/start-screen-light.png" /> | <img src="assets/screenshots/light-theme/game-screen-light.png" /> | <img src="assets/screenshots/light-theme/leaderboard-screen-light.png" /> | <img src="assets/screenshots/light-theme/settings-screen1-light.png" /> |

| **Settings (2)** | **Settings (3)** | **How to play** | **How to answer** |
| :---: | :---: | :---: | :---: |
| <img src="assets/screenshots/light-theme/settings-screen2-light.png" /> | <img src="assets/screenshots/light-theme/settings-screen3-light.png" /> | <img src="assets/screenshots/light-theme/how-to-play-guide-dialogue-light.png" /> | <img src="assets/screenshots/light-theme/how-to-answer-guide-dialogue-light.png" /> |

| **Changelog** | **App updater** | **Build info** | **Support** |
| :---: | :---: | :---: | :---: |
| <img src="assets/screenshots/light-theme/changelog-dialogue-light.png" /> | <img src="assets/screenshots/light-theme/app-updater-dialogue-light.png" /> | <img src="assets/screenshots/light-theme/app-build-info-dialogue-light.png" /> | <img src="assets/screenshots/light-theme/app-support-dialogue-light.png" /> |

| **Reset progress** |
| :---: |
| <img src="assets/screenshots/light-theme/reset-progress-dialogue-light.png" width="300" /> |

---

## How it works

ClearNet targets parents who want a safe device environment for their kids and organisations that need basic app and site filtering.

1. Parent installs ClearNet.
2. Enables Device Admin configuration -> protects against unauthorized uninstall.
3. Configures blocked apps or websites via the secure UI.
4. The application merges local asset blocklists with custom configurations, routing device queries through a local VPNService to filter traffic entirely offline.

---

## Requirements

- **Flutter SDK**: Stable channel (`^3.8.1` or higher).
- **Dart SDK**: `^3.8.1`.
- **Android Studio / Android SDK**: For compilation and testing.

---

## Development setup

```bash
# Fetch all dependencies
flutter pub get

# Check environment health
flutter doctor

flutter clean
flutter pub get
flutter run
```

---

## How to run

```bash
flutter run
```

### To run web server

starts a local server instance and provides you with a clickable UR
f you don't have Google Chrome installed locally or prefer to preview/debug your web application inside your choice of an alternate browser (like Firefox or Brave),
flutter run -d web-server
OR
Identify the path to ghromee
$(which google-chrome || which chromium-browser || which chromium)

Replace '/usr/bin/google-chrome' the with the result
echo 'export CHROME_EXECUTABLE="/usr/bin/google-chrome"' >> ~/.bashrc
source ~/.bashrc

# Navigate to the Android SDK tools directory
cd ~/Android/Sdk/cmdline-tools/latest/bin/

# Accept licenses using the updated tool structure
./sdkmanager --licenses

---

## How to test

```bash
flutter test
```

---

## How to format code

```bash
dart format .
flutter analyze
```

---

## How to release

This project uses GitHub Actions for automated releases. Pushing a tag matching `v*` to the `main` branch will trigger a build and create a release with a signed APK and app bundle.

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## F-Droid metadata

This project includes Fastlane compatible metadata under `fastlane/metadata/android/en-GB/` to ensure F-Droid repository listing compliance.

---

## Licence

This project is licensed under the [MIT Licence](LICENSE).

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on code style, testing, and pull requests.

---

## Developer notes

For a detailed breakdown of technical workflows, local testing guides, and setup steps, see the [DEVELOPER_NOTES.md](docs/DEVELOPER_NOTES.md) file.

---

## Other projects

View [other projects by ASPTechnologies Incorporation](docs/FOSS_PROJECTS.md) on GitHub.

## Support

Developed by [**ASPTechnologies Incorporation**](https://github.com/ASPTechInc 'GitHub ASPTechInc').

[🔝 Back to top](#top)

<a id="bottom"></a>
