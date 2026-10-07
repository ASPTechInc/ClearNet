# [v1.0.0](https://github.com/ASPTechInc/ClearNet/tree/v1.0.0) (2026-09-18)

Full stable release of ClearNet, a free and open-source (FOSS) parental control application built with Flutter.

### Features

- **Uninstall Protection**: Registers securely as a Device Admin to block unauthorised 
  uninstallation of the application
  without a valid parent PIN.
- **App Restriction**: Seamless restriction of selected applications from being launched.
- **Local Network Filtering**: Built-in high-performance local VPNService to intercept and filter 
  malicious adult domains.
- **Privacy-First Architecture**: No cloud requirements, no telemetry analytics trackers, and 
  zero data gathering.
- **Offline blocklist**: Embedded JSON-based adult domain blocklist preloaded straight within 
  app assets.
- **Custom Filters**: Empower parents to append customised domains or exceptions directly to the 
  local blocklist.
- **Automated Workflow Layouts**: Refactored complete GitHub Action runners for rapid Lint, Test 
  and Releases.
- **FOSS Ready**: Open-source transparency under the highly permissive MIT licence.
- **SafeSearch Integration**: Automatic routing for Google, Bing, and YouTube to SafeSearch VIPs 
  to enforce family-safe content at the network level.
- **Enhanced Settings**: Added in-app Changelog viewer, Source Code link, and Support/Donation 
  section.
- **Improved DNS Logic**: Refactored internal VPN packet handling for better accuracy and 
  performance.
- **Keyword Filtering**: Custom keyword-based content filtering to block specific words or domains.
- **Blocklist Import & Export**: Import and export user custom blocklists as JSON files for backup and sync.
- **App Disguise Mode**: Disguise app launcher appearance as a Calculator or Notes app.
- **Settings Security**: Dedicated Settings PIN protection to secure app settings from tampering.
- **Disable Confirmation Challenge**: Interactive confirmation prompt required when attempting to disable blocking.
- **Activity Tracker**: Real-time daily, weekly, and monthly activity statistics for blocked websites and restricted apps.
- **Custom Upstream DNS**: Support for configuring custom upstream DNS servers (e.g. Quad9).
- **Theme Modes**: Support for Dark, Light, and System theme modes.
- **App Updater**: Integrated GitHub release updater to check for app updates directly within settings.
