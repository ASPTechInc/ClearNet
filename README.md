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

[Go to bottom](#bottom)

## Overview

ClearNet is a free and open-source content-control app built with Flutter and Android system services.
It blocks harmful websites and chosen apps, and needs a PIN before it can be switched off or uninstalled.

---

## Features

| Feature                         | Description |
| ------------------------------- | ----------- |
| **Uninstall protection**        | ClearNet registers as a device administrator. With an uninstall PIN set, opening the Settings screens that could remove it (its device admin page, the deactivate dialogue or its accessibility page) shows the uninstall PIN screen instead. The correct PIN allows them for 2 minutes. |
| **App blocking**                | Chosen apps are closed when they're opened. |
| **Website blocking**            | A local VPN checks every DNS lookup on the device. Lookups for blocked domains fail straight away; everything else is forwarded to your DNS server. Comes with a built-in blocklist of adult domains, and you can add your own. |
| **Keyword filtering**           | Blocks domains that contain your keywords, and shows the blocked page when they appear on screen in a supported browser. |
| **SafeSearch**                  | Google, Bing and YouTube searches are sent to their SafeSearch versions. Other Google services, such as Gmail and the Play Store, work normally. |
| **Blocklist import and export** | Back up and restore your domains and keywords as `blocklist.json`. |
| **Custom DNS**                  | Use your own DNS server (e.g. Quad9). By default, allowed lookups go to UncensoredDNS, AdGuard DNS or Quad9. |
| **App disguise**                | Show ClearNet as a Calculator or Notes app on the home screen. |
| **App lock**                    | Optionally ask for a 8 to 16 digit app PIN when ClearNet starts. ClearNet closes itself after you leave it (immediately, after 1 minute or after 5 minutes), so the PIN is needed again. |
| **Settings PIN lock**           | Settings can be locked behind the app PIN. |
| **Disable confirmation**        | Turning blocking off requires completing a confirmation challenge. |
| **Statistics**                  | Daily, weekly and monthly counts of blocked websites and apps. |
| **Themes**                      | Light, dark and system themes. |
| **Privacy**                     | No accounts, analytics or adverts. Settings and lists stay on the device. |
| **Updates and links**           | GitHub update checker (not in F-Droid builds), changelog, source code and donation links in Settings. |

### Possible future features include:

- Translations - move strings to flutter_localizations + ARB files then, host them on Weblate (free for FOSS)

- Extend the default blocklist to use public lists like StevenBlack and OISD to record each list's source and licence. Some can be CC-BY-SA which comes with attribution and share-alike duties.

- Add re-locking when the app comes back from the background when a user switches to another app and back, it stays unlocked until the app is closed. 

---

## Screenshots

### Dark mode

|                         **Protection**                          |                         **Blocked content**                          |                             **Blocked apps**                             |                           **Settings (1)**                            |
| :---------------------------------------------------------------: | :--------------------------------------------------------------: | :---------------------------------------------------------------------: | :-------------------------------------------------------------------: |
| <img src="assets/screenshots/dark-theme/protection-screen-dark.png" /> | <img src="assets/screenshots/dark-theme/blocked-content-screen-dark.png" /> | <img src="assets/screenshots/dark-theme/blocked-apps-screen-dark.png" /> | <img src="assets/screenshots/dark-theme/settings-screen1-dark.png" /> |

|                           **Settings (2)**                            |                           **Settings (3)**                            |                                 **Guide**                                 |                                 **Blocked page**                                 |
| :-------------------------------------------------------------------: | :-------------------------------------------------------------------: | :-----------------------------------------------------------------------------: | :-------------------------------------------------------------------------------: |
| <img src="assets/screenshots/dark-theme/settings-screen2-dark.png" /> | <img src="assets/screenshots/dark-theme/settings-screen3-dark.png" /> | <img src="assets/screenshots/dark-theme/guide-screen-dark.png" /> | <img src="assets/screenshots/dark-theme/blocked-access-screen-dark.png" /> |

|                              **Changelog**                              |                              **Disable confirmation**                              |                                **App disguise**                                |                                **Support**                                |
| :---------------------------------------------------------------------: | :-----------------------------------------------------------------------: | :--------------------------------------------------------------------------: | :-----------------------------------------------------------------------: |
| <img src="assets/screenshots/dark-theme/changelog-dialogue-dark.png" /> | <img src="assets/screenshots/dark-theme/disable-confirmation-dialogue-dark.png" /> | <img src="assets/screenshots/dark-theme/app-disguise-dialogue-dark.png" /> | <img src="assets/screenshots/dark-theme/app-support-dialogue-dark.png" /> |

|                                    **Reset content**                                     |
| :---------------------------------------------------------------------------------------: |
| <img src="assets/screenshots/dark-theme/reset-content-dialogue-dark.png" width="300"  /> |

### Light mode

|                          **Protection**                           |                          **Blocked content**                           |                              **Blocked apps**                              |                            **Settings (1)**                             |
| :-----------------------------------------------------------------: | :----------------------------------------------------------------: | :-----------------------------------------------------------------------: | :---------------------------------------------------------------------: |
| <img src="assets/screenshots/light-theme/protection-screen-light.png" /> | <img src="assets/screenshots/light-theme/blocked-content-screen-light.png" /> | <img src="assets/screenshots/light-theme/blocked-apps-screen-light.png" /> | <img src="assets/screenshots/light-theme/settings-screen1-light.png" /> |

|                            **Settings (2)**                             |                            **Settings (3)**                             |                                  **Guide**                                  |                                  **Blocked page**                                  |
| :---------------------------------------------------------------------: | :---------------------------------------------------------------------: | :-------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------: |
| <img src="assets/screenshots/light-theme/settings-screen2-light.png" /> | <img src="assets/screenshots/light-theme/settings-screen3-light.png" /> | <img src="assets/screenshots/light-theme/guide-screen-light.png" /> | <img src="assets/screenshots/light-theme/blocked-access-screen-light.png" /> |

|                               **Changelog**                               |                               **Disable confirmation**                               |                                 **App disguise**                                 |                                 **Support**                                 |
| :-----------------------------------------------------------------------: | :-------------------------------------------------------------------------: | :----------------------------------------------------------------------------: | :-------------------------------------------------------------------------: |
| <img src="assets/screenshots/light-theme/changelog-dialogue-light.png" /> | <img src="assets/screenshots/light-theme/disable-confirmation-dialogue-light.png" /> | <img src="assets/screenshots/light-theme/app-disguise-dialogue-light.png" /> | <img src="assets/screenshots/light-theme/app-support-dialogue-light.png" /> |

|                                     **Reset content**                                     |
| :----------------------------------------------------------------------------------------: |
| <img src="assets/screenshots/light-theme/reset-content-dialogue-light.png" width="300" /> |

---

## How it works

ClearNet targets parents who want a safe device environment for their kids and organisations that need basic app and site filtering.

1. A parent installs ClearNet.
2. They turn on device administrator access, so ClearNet can't be uninstalled without the PIN.
3. They choose which apps and websites to block.
4. They switch blocking on. ClearNet combines the built-in blocklist with their own entries and starts a local VPN that checks every DNS lookup on the device:
   - Blocked domains and domains containing blocked keywords get a "not found" answer, so they don't load.
   - Google, Bing and YouTube get their SafeSearch addresses.
   - Everything else is forwarded to the chosen DNS server (UncensoredDNS, AdGuard DNS or Quad9 by default).
5. In supported browsers, the accessibility service also checks the address bar and page text, and shows ClearNet's blocked page when something matches.

### Things that affect blocking

- **Private DNS:** if Android's Private DNS is set to a specific provider, websites won't load while blocking is on. ClearNet stops encrypted DNS so it can't be used to get around the filter. Set Private DNS to *Off* or *Automatic*.
- **Secure DNS in browsers:** encrypted DNS to well-known providers (such as Google, Cloudflare, Quad9 and NextDNS) is blocked, so browsers fall back to normal DNS, which ClearNet filters.
- **Other VPNs:** Android allows one VPN at a time, so ClearNet can't run alongside another VPN app.
- **After a restart or update:** open ClearNet once and blocking starts again.

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
dart format lib test
flutter analyze

# Preview proposed changes
dart fix --dry-run

# Apply lint
dart fix --apply
fdroid lint
reuse lint 

# Sort package imports
dart run import_sorter:main
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
The F-Droid build recipe lives in [`metadata/com.asptechinc.clearnet.yml`](metadata/com.asptechinc.clearnet.yml).

F-Droid delivers app updates itself, so F-Droid builds hide the in-app GitHub update checker. This is controlled by a compile-time flag:

```bash
flutter build apk --release --dart-define=FDROID_BUILD=true
```

Builds without the flag (such as GitHub releases) keep the update checker.

---

## Licence

This project is licensed under the [MIT Licence](LICENSE).

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on code style, testing and pull requests.

---

## Developer notes

For a detailed breakdown of technical workflows, local testing guides and setup steps, see the [DEVELOPER_NOTES.md](docs/DEVELOPER_NOTES.md) file.

---

## Other projects

View [other projects by ASPTechnologies Incorporation](docs/FOSS_PROJECTS.md) on GitHub.

## Support

Developed by [**ASPTechnologies Incorporation**](https://github.com/ASPTechInc 'GitHub ASPTechInc').

[Back to top](#top)

<a id="bottom"></a>
