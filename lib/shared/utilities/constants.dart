// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Project imports:
import 'package:clearnet/data/models/dns_preset.dart';

class Constants {
  static const String appName = 'ClearNet';
  static const String appCalculatorDisguiseName = 'Calculator';
  static const String appNotesDisguiseName = 'Notes';
  // The Android side reads the next three keys and blockedAppsKey by name
  // (DataStoreReader.kt), so renaming them breaks the VPN and app blocking
  static const String blocklistKey = 'blocked_sites';
  static const String keywordsKey = 'blocked_keywords';
  static const String whitelistKey = 'whitelisted_sites';
  static const String vpnStatusKey = 'vpn_status';
  static const String methodChannelName = 'app_control/channel';
  static const String blocklistAsset = 'assets/data/blocklist.json';
  static const String blocklistFileName = 'blocklist.json';
  static const String backupFileExtension = 'backup';
  static const String themeModeKey = 'theme_mode';
  static const String blockedAppsKey = 'blocked_apps';
  static const String blockedWebsitesCountKey = 'blocked_websites_count';
  static const String blockedAppsCountKey = 'blocked_apps_count';

  static const String weeklyWebsitesCountKey = 'weekly_websites_count';
  static const String weeklyAppsCountKey = 'weekly_apps_count';
  static const String monthlyWebsitesCountKey = 'monthly_websites_count';
  static const String monthlyAppsCountKey = 'monthly_apps_count';

  static const String lastStatsDateKey = 'last_stats_date';
  static const String lastWeeklyResetKey = 'last_weekly_reset';
  static const String lastMonthlyResetKey = 'last_monthly_reset';
  static const String lockSettingsKey = 'lock_settings';
  static const String appLockEnabledKey = 'app_lock_enabled';
  static const String appPinKey = 'app_pin';
  static const String appLockTimeoutKey = 'app_lock_timeout_seconds';
  static const String uninstallPinKey = 'uninstall_pin';
  static const String appPinResetRequestedKey = 'app_pin_reset_requested_at';
  static const String appDisguiseKey = 'app_disguise';

  static const String githubRepoUrl = 'https://github.com/asptechinc/clearnet';
  static const String privacyPolicyUrl =
      'https://github.com/asptechinc/clearnet/blob/main/PRIVACY_POLICY.md';
  static const String licenseUrl =
      'https://github.com/asptechinc/clearnet/blob/main/LICENSE';
  static const String releasesUrl =
      'https://github.com/asptechinc/clearnet/releases/latest';
  static const String releasesApiUrl =
      'https://api.github.com/repos/asptechinc/clearnet/releases/latest';

  static const String buyMeACoffeeUrl = 'https://buymeacoffee.com/asptechinc';

  /// Set with `--dart-define=FDROID_BUILD=true`. F-Droid delivers updates
  /// itself, so the in-app GitHub update checker is hidden in those builds.
  static const bool isFdroidBuild = bool.fromEnvironment('FDROID_BUILD');

  static const List<DnsPreset> dnsPresets = [
    DnsPreset(
      id: 'default',
      label: 'Default (UncensoredDNS, AdGuard, Quad9)',
      ip: '',
    ),
    DnsPreset(id: '9.9.9.9', label: 'Quad9 (9.9.9.9)', ip: '9.9.9.9'),
    DnsPreset(
      id: '94.140.14.14',
      label: 'AdGuard DNS (94.140.14.14)',
      ip: '94.140.14.14',
    ),
    DnsPreset(
      id: '91.239.100.100',
      label: 'UncensoredDNS (91.239.100.100)',
      ip: '91.239.100.100',
    ),
    DnsPreset(id: '1.1.1.1', label: 'Cloudflare (1.1.1.1)', ip: '1.1.1.1'),
    DnsPreset(id: '8.8.8.8', label: 'Google DNS (8.8.8.8)', ip: '8.8.8.8'),
    DnsPreset(id: 'custom', label: 'Custom IP Address', ip: ''),
  ];

  static const List<String> wordPool = [
    'persistence',
    'extraordinary',
    'conundrum',
    'labyrinth',
    'ephemeral',
    'melancholy',
    'serendipity',
    'quintessential',
    'eloquence',
    'nefarious',
    'obfuscate',
    'pragmatic',
    'resilient',
    'ubiquitous',
    'vivacious',
    'whimsical',
    'zealous',
    'aberration',
    'benevolent',
    'capricious',
    'deference',
    'enervate',
    'garrulous',
    'haughty',
    'impetuous',
    'idiosyncratic',
    'juxtaposition',
    'kaleidoscope',
    'loquacious',
    'magnanimous',
    'nonchalant',
    'obsequious',
    'perspicacious',
    'querulous',
    'recalcitrant',
    'sycophant',
    'tenacious',
    'unequivocal',
    'vicissitude',
    'acquiesce',
    'belligerent',
    'cacophony',
    'dichotomy',
    'egregious',
    'fastidious',
    'gregarious',
    'hierarchy',
    'incongruous',
    'jubilant',
    'mnemonic',
  ];
}
