// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import 'package:clearnet/data/controllers/uninstall_protection_controller.dart';
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/app_lock_service.dart';
import 'package:clearnet/data/services/app_nav_service.dart';
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/screens/pin_pad_screen.dart';
import 'package:clearnet/presentation/widgets/markdown_text.dart';
import 'package:clearnet/presentation/widgets/set_pin_dialogue.dart';
import 'package:clearnet/shared/utilities/constants.dart';
import 'package:clearnet/shared/utilities/helpers.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  static const platform = MethodChannel(Constants.methodChannelName);
  final storage = const FlutterSecureStorage();
  final _prefs = SharedPreferencesAsync();
  final ScrollController _scrollController = ScrollController();
  final ExpansibleController _aboutSecController = ExpansibleController();

  final GlobalKey _appLockKey = GlobalKey();
  final GlobalKey _disguiseKey = GlobalKey();
  final GlobalKey _uninstallPinKey = GlobalKey();
  final GlobalKey _dnsKey = GlobalKey();
  final GlobalKey _replayTourKey = GlobalKey();
  Timer? _tourTimer;

  bool _appLockEnabled = false;
  int _appLockTimeoutSeconds = AppLockService.defaultTimeoutSeconds;
  bool _lockSettingsEnabled = false;
  bool _isAppPinSet = false;
  bool _isUninstallPinSet = false;
  bool _isDeviceAdminActive = false;
  String _currentDisguise = 'none';
  final _dnsController = TextEditingController();
  String _selectedDnsPresetId = 'default';

  String _appVersion = '1.0.0';
  bool _isUpdateAvailable = false;
  String _latestVersion = '';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppTourManager.permissionsCheckNotifier.addListener(_onPermissionsUpdated);
    unawaited(_loadSettings());
    unawaited(_fetchAppVersion());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartAppTour();
    });
  }

  @override
  void dispose() {
    _tourTimer?.cancel();
    AppTourManager.permissionsCheckNotifier.removeListener(
      _onPermissionsUpdated,
    );
    WidgetsBinding.instance.removeObserver(this);
    _dnsController.dispose();
    _scrollController.dispose();
    _aboutSecController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndStartAppTour();
      // Device admin may have been turned on or off in Android's settings
      unawaited(_loadSettings());
    }
  }

  void _onPermissionsUpdated() {
    _checkAndStartAppTour();
  }

  void _checkAndStartAppTour() {
    _tourTimer?.cancel();
    _tourTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      await AppTourManager.startAppTourIfReady(
        context: context,
        keys: [
          _appLockKey,

          _uninstallPinKey,
          _disguiseKey,
          _dnsKey,
          _replayTourKey,
        ],
        tourKey: AppTourManager.settingsTourKey,
        tabIndex: 2,
        // The list builds lazily, so the first targets only exist once the
        // list is back at the top (e.g. after tapping 'Replay app tour').
        beforeStart: () {
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
        },
      );
    });
  }

  Future<void> _fetchAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _loadSettings() async {
    final appLock = await storage.read(key: Constants.appLockEnabledKey);
    final appPin = await storage.read(key: Constants.appPinKey);
    final uninstallPin = await storage.read(key: Constants.uninstallPinKey);
    final customDns = await _prefs.getString('custom_dns') ?? '';
    final lockSettings =
        await _prefs.getBool(Constants.lockSettingsKey) ?? false;
    final disguise = await _prefs.getString(Constants.appDisguiseKey) ?? 'none';
    final lockTimeout = await AppLockService.getTimeoutSeconds();
    final isAdminActive =
        await UninstallProtectionController.isDeviceAdminActive();
    _dnsController.text = customDns;
    _updateSelectedDnsPresetId(customDns);
    if (!mounted) return;
    setState(() {
      _appLockEnabled = appLock == 'true';
      _isAppPinSet = appPin != null && appPin.isNotEmpty;
      _isUninstallPinSet = uninstallPin != null && uninstallPin.isNotEmpty;
      _isDeviceAdminActive = isAdminActive;
      _lockSettingsEnabled = lockSettings;
      _currentDisguise = disguise;
      _appLockTimeoutSeconds = lockTimeout;
    });
  }

  Future<void> _changeAppLockTimeout(int? seconds) async {
    if (seconds == null) return;
    await AppLockService.setTimeoutSeconds(seconds);
    if (!mounted) return;
    setState(() => _appLockTimeoutSeconds = seconds);
  }

  Future<void> _changeDisguise(String disguise) async {
    try {
      await platform.invokeMethod('setAppDisguise', {'disguise': disguise});
      await _prefs.setString(Constants.appDisguiseKey, disguise);
      setState(() => _currentDisguise = disguise);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Disguise set to ${disguise.toUpperCase()}. It may take a '
              'few moments to update the launcher.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to set disguise: $e');
    }
  }

  bool _isValidIpOrEmpty(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    return InternetAddress.tryParse(trimmed) != null;
  }

  String? get _dnsErrorText {
    final text = _dnsController.text.trim();
    if (text.isNotEmpty && !_isValidIpOrEmpty(text)) {
      return 'Enter a valid IPv4 or IPv6 address (e.g. 9.9.9.9)';
    }
    return null;
  }

  Future<void> _saveCustomDns(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _prefs.remove('custom_dns');
    } else if (_isValidIpOrEmpty(trimmed)) {
      await _prefs.setString('custom_dns', trimmed);
    } else {
      return;
    }
    // A running VPN reloads its DNS server when started again
    if (await _prefs.getBool('is_blocking_enabled') ?? false) {
      await VpnController.startVpn();
    }
  }

  void _updateSelectedDnsPresetId(String ip) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) {
      _selectedDnsPresetId = 'default';
      return;
    }
    for (final preset in Constants.dnsPresets) {
      if (preset.id != 'default' &&
          preset.id != 'custom' &&
          preset.ip == trimmed) {
        _selectedDnsPresetId = preset.id;
        return;
      }
    }
    _selectedDnsPresetId = 'custom';
  }

  String _getDnsDropdownSelectedId() {
    return _selectedDnsPresetId;
  }

  Future<void> _onDnsDropdownChanged(String? newValue) async {
    if (newValue == null) return;
    setState(() {
      _selectedDnsPresetId = newValue;
    });

    if (newValue == 'default') {
      _dnsController.clear();
      await _saveCustomDns('');
    } else if (newValue == 'custom') {
      final currentText = _dnsController.text.trim();
      final isPresetIp = Constants.dnsPresets.any(
        (p) => p.ip.isNotEmpty && p.ip == currentText,
      );
      if (isPresetIp) {
        _dnsController.clear();
        await _saveCustomDns('');
      }
    } else {
      final selectedPreset = Constants.dnsPresets.firstWhere(
        (preset) => preset.id == newValue,
        orElse: () => Constants.dnsPresets.first,
      );
      _dnsController.text = selectedPreset.ip;
      await _saveCustomDns(selectedPreset.ip);
    }
    if (mounted) setState(() {});
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleLockSettings(bool value) async {
    // Settings are unlocked with the app PIN, so app lock has to be on first
    if (value && !_appLockEnabled) {
      _showSnackBar('Turn on "Set app PIN" first');
      return;
    }

    await _prefs.setBool(Constants.lockSettingsKey, value);
    setState(() {
      _lockSettingsEnabled = value;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    // The Settings lock relies on the app PIN, so it has to be turned off first
    if (!value && _lockSettingsEnabled) {
      _showSnackBar('Turn off "Lock settings with PIN" first');
      return;
    }

    if (value) {
      if (!_isAppPinSet) {
        if (!mounted) return;
        final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const SetPinDialogue(
            pinKey: Constants.appPinKey,
            title: 'Set App PIN',
            distinctFromPinKey: Constants.uninstallPinKey,
            distinctFromPinName: 'uninstall PIN',
          ),
        );
        if (saved == true) {
          await storage.write(key: Constants.appLockEnabledKey, value: 'true');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('App PIN set successfully')),
            );
          }
        }
        _loadSettings();
        return;
      }

      await storage.write(key: Constants.appLockEnabledKey, value: 'true');
      setState(() {
        _appLockEnabled = true;
      });
    } else {
      await storage.write(key: Constants.appLockEnabledKey, value: 'false');
      setState(() {
        _appLockEnabled = false;
      });
    }
  }

  Future<void> _changeAppPin() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SetPinDialogue(
        pinKey: Constants.appPinKey,
        title: 'Change App PIN',
        requireCurrentPin: true,
        distinctFromPinKey: Constants.uninstallPinKey,
        distinctFromPinName: 'uninstall PIN',
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App PIN changed successfully')),
      );
    }
    _loadSettings();
  }

  Future<void> _setupUninstallPin() async {
    if (_isUninstallPinSet) return; // Cannot change once set

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set permanent PIN'),
        content: const Text(
          'This Uninstall PIN will be used for uninstallation protection. '
          'Once set, it CANNOT be changed or reset for security reasons.'
          '\n\nDo you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SetPinDialogue(
        pinKey: Constants.uninstallPinKey,
        title: 'Set Uninstall PIN',
        distinctFromPinKey: Constants.appPinKey,
        distinctFromPinName: 'app PIN',
      ),
    );
    if (saved == true) {
      unawaited(UninstallProtectionController.sync());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uninstall PIN set successfully')),
        );
      }
      // The PIN only protects anything once ClearNet is a device admin
      await UninstallProtectionController.requestDeviceAdmin();
    }
    _loadSettings();
  }

  Future<void> _navigateToContentSection(String routeName) async {
    if (_lockSettingsEnabled && !AppSession.isSettingsUnlocked) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinPadScreen(
            pinKey: Constants.appPinKey,
            title: 'Verify App PIN',
            showBackButton: true,
            onSuccess: () {
              AppSession.isSettingsUnlocked = true;
              Navigator.pop(context);
              Navigator.pushNamed(context, routeName);
            },
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.pushNamed(context, routeName);
    }
  }

  Future<void> _showClearContentDialogue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear content'),
        content: const Text(
          'This will remove all items from blocked websites, keywords, '
          'whitelist and unselect all blocked apps.'
          '\n\nDo you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BlocklistManager.clearAll();
      await _prefs.setStringList(Constants.blockedAppsKey, []);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content cleared successfully')),
      );
    }
  }

  Future<void> _showResetContentDialogue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset content'),
        content: const Text(
          'This will reset blocked sites, keywords and whitelist to '
          'default data.'
          '\n\nDo you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BlocklistManager.resetToDefault();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Content reset to default')));
    }
  }

  Future<void> _showThemeDialogue() async {
    await showDialog(
      context: context,
      builder: (context) {
        final currentMode = ThemeService.themeModeNotifier.value;
        return AlertDialog(
          title: const Text('Choose theme'),
          content: RadioGroup<ThemeMode>(
            groupValue: currentMode,
            onChanged: (ThemeMode? value) async {
              if (value != null) {
                await ThemeService().updateThemeMode(value);
                if (!context.mounted) return;
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('Follow system'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Light'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Dark'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDisguiseDialogue() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose app disguise'),
        content: RadioGroup(
          groupValue: _currentDisguise,
          onChanged: (value) async {
            if (value != null) {
              Navigator.pop(context);
              _changeDisguise(value);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RadioListTile<String>(
                title: Text('None (Default)'),
                value: 'none',
              ),
              RadioListTile<String>(
                title: const Text(Constants.appCalculatorDisguiseName),
                value: Constants.appCalculatorDisguiseName.toLowerCase(),
              ),
              RadioListTile<String>(
                title: const Text(Constants.appNotesDisguiseName),
                value: Constants.appNotesDisguiseName.toLowerCase(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReliabilityDialogue() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reliability note'),
        content: const Text(
          'Battery optimisation has to be disabled and the Safe '
          'browsing service has to be enabled in order for the '
          'blocking of websites and apps too work reliably while '
          'using ${Constants.appName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacyPolicyDialog() async {
    try {
      final privacyPolicy = await rootBundle.loadString('PRIVACY_POLICY.md');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Privacy policy'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                // The dialogue already shows the title, so skip the file's own
                child: MarkdownText(privacyPolicy, skipTitle: true),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load privacy policy')),
        );
      }
    }
  }

  Future<void> _showLicenseDialog() async {
    try {
      final licenseText = await rootBundle.loadString('LICENSE');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Licence'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MIT Licence',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      licenseText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load licence')));
      }
    }
  }

  Future<void> _showSourceCodeDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Source code'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Constants.appName} is free open-source software (FOSS). '
                'The complete source code, issue tracker and build '
                'instructions are publicly available.',
              ),
              SizedBox(height: 12),
              SelectableText(
                'Repository: ${Constants.githubRepoUrl}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Licence: MIT Licence'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                unawaited(_launchUrl(Constants.githubRepoUrl));
              },
              child: const Text('Open in browser'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDonateDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Support ${Constants.appName}'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Constants.appName} is built and maintained as a free, '
                'open-source project with no ads, subscriptions or tracking.',
              ),
              SizedBox(height: 12),
              Text(
                'If you appreciate ${Constants.appName} and wish to support '
                'its continued development, you can buy the lead developer '
                'a coffee!',
              ),
              SizedBox(height: 12),
              SelectableText(
                'Support page: ${Constants.buyMeACoffeeUrl}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                unawaited(_launchUrl(Constants.buyMeACoffeeUrl));
              },
              child: const Text('Donate via browser'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showChangelogDialog() async {
    try {
      final changelog = await rootBundle.loadString('CHANGELOG.md');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Changelog'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: _parseChangelog(changelog),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load changelog')),
        );
      }
    }
  }

  List<Widget> _parseChangelog(String text) {
    // Split by "# [v" to get each version block
    final blocks = text.split(RegExp(r'(?=# \[v)'));
    final List<Widget> widgets = [];

    for (var block in blocks) {
      final trimmedBlock = block.trim();
      if (trimmedBlock.isEmpty) continue;

      // Extract version: e.g., [v1.0.0]
      final versionMatch = RegExp(r'\[(v.*?)\]').firstMatch(trimmedBlock);
      // Extract date: e.g., (2026-10-13)
      final dateMatch = RegExp(
        r'\((\d{4}-\d{2}-\d{2})\)',
      ).firstMatch(trimmedBlock);

      final version = versionMatch?.group(1) ?? 'Update';
      final date = dateMatch?.group(1) ?? '';

      // Extract features (lines starting with '-')
      final lines = trimmedBlock.split('\n');
      final List<String> features = [];

      for (var line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('-')) {
          features.add(trimmedLine.substring(1).trim());
        } else if (line.startsWith(' ') &&
            trimmedLine.isNotEmpty &&
            features.isNotEmpty) {
          // An indented line continues the bullet above it
          features.last = '${features.last} $trimmedLine';
        }
      }

      widgets.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 0,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                if (date.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      date,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ...features.map(
                  (feature) => MarkdownBullet(
                    child: Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.4,
                        ),
                        children: MarkdownText.inlineSpans(feature),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      return [SelectableText(text)];
    }

    return widgets;
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    AppLockService.expectExternalActivity();
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  Future<void> _checkUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
      _isUpdateAvailable = false;
    });

    try {
      final response = await http.get(Uri.parse(Constants.releasesApiUrl));
      if (response.statusCode == 200) {
        // Cast the decoded JSON to Map<String, dynamic>
        final data = json.decode(response.body) as Map<String, dynamic>;
        final latestTag = data['tag_name'] as String;

        if (isNewerVersion(latestTag, _appVersion)) {
          setState(() {
            _isUpdateAvailable = true;
            _latestVersion = latestTag;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('App is up to date')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to check for updates')),
        );
      }
    } finally {
      setState(() => _isCheckingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        controller: _scrollController,
        children: [
          // Section: General
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'General',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // Theme
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(
              ThemeService.themeModeNotifier.value.name[0].toUpperCase() +
                  ThemeService.themeModeNotifier.value.name.substring(1),
            ),
            onTap: _showThemeDialogue,
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Reliability & performance note'),
            subtitle: const Text(
              'Important information about the stability '
              'of the application',
            ),
            onTap: _showReliabilityDialogue,
          ),
          const Divider(),
          // Section: Privacy & Security
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Privacy & Security',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // App lock
          AppTourManager.appTourItem(
            key: _appLockKey,
            enableAutoScroll: true,
            title: 'App lock',
            description:
                'Require a secure PIN to open ${Constants.appName} or '
                'protect Settings section from unauthorised changes.',
            child: SwitchListTile(
              title: const Text('Set app PIN'),
              value: _appLockEnabled,
              onChanged: _toggleAppLock,
            ),
          ),
          if (_appLockEnabled)
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Lock after leaving'),
              subtitle: const Text(
                'Closes ${Constants.appName} after you leave it, so the app '
                'PIN is needed again',
              ),
              trailing: DropdownButton<int>(
                value: _appLockTimeoutSeconds,
                onChanged: _changeAppLockTimeout,
                items: [
                  for (final option in AppLockService.timeoutOptions.entries)
                    DropdownMenuItem(
                      value: option.key,
                      child: Text(option.value),
                    ),
                ],
              ),
            ),
          if (_isAppPinSet)
            ListTile(
              title: const Text('Change app PIN'),
              leading: const Icon(Icons.password),
              onTap: _changeAppPin,
            ),
          // Lock settings with PIN
          SwitchListTile(
            title: const Text('Lock settings with PIN'),
            subtitle: const Text(
              'Requires app PIN to access this (Settings) screen and the '
              'Content screen',
            ),
            value: _lockSettingsEnabled,
            onChanged: _toggleLockSettings,
          ),
          // Uninstall protection
          AppTourManager.appTourItem(
            key: _uninstallPinKey,
            enableAutoScroll: true,
            title: 'Uninstall protection',
            description:
                'Set a permanent PIN to prevent unauthorised app removal.',
            child: !_isUninstallPinSet
                ? ListTile(
                    title: const Text('Uninstall PIN'),
                    subtitle: const Text(
                      'Set a PIN to prevent unauthorised uninstallation '
                      'of the application',
                    ),
                    onTap: _setupUninstallPin,
                  )
                : _isDeviceAdminActive
                ? const ListTile(
                    title: Text('Uninstall PIN'),
                    subtitle: Text('PIN is set and permanent'),
                    trailing: Icon(Icons.lock, color: Colors.green),
                    enabled: false,
                  )
                // A PIN without device admin does not stop uninstalling
                : const ListTile(
                    title: Text('Uninstall PIN'),
                    subtitle: Text(
                      'Not active: device admin is off, so the app can be '
                      'uninstalled. Tap to turn it on.',
                    ),
                    trailing: Icon(Icons.warning_amber, color: Colors.orange),
                    onTap: UninstallProtectionController.requestDeviceAdmin,
                  ),
          ),
          if (!_isUninstallPinSet)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Warning: Once set, it CANNOT be changed or reset.',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          // Disguise mode
          AppTourManager.appTourItem(
            key: _disguiseKey,
            enableAutoScroll: true,
            title: 'Disguise mode',
            description:
                'Disguise ${Constants.appName} on your home screen as an '
                'innocuous application like a calculator or notes.',
            child: ListTile(
              title: const Text('Disguise mode'),
              subtitle: Text('Current: ${_currentDisguise.toUpperCase()}'),
              leading: const Icon(Icons.theater_comedy_outlined),
              onTap: _showDisguiseDialogue,
            ),
          ),
          const Divider(),
          // Section: Network & DNS
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Network & DNS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          AppTourManager.appTourItem(
            key: _dnsKey,
            enableAutoScroll: true,
            title: 'Secure DNS Resolver',
            description:
                'Choose a curated encrypted DNS resolver (like Quad9 or '
                'Cloudflare) or enter a custom DNS server.',
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(_getDnsDropdownSelectedId()),
                    initialValue: _getDnsDropdownSelectedId(),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'DNS server',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    items: Constants.dnsPresets.map((preset) {
                      return DropdownMenuItem<String>(
                        value: preset.id,
                        child: Text(
                          preset.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _onDnsDropdownChanged,
                  ),
                  const SizedBox(height: 12.0),
                  TextField(
                    controller: _dnsController,
                    decoration: InputDecoration(
                      labelText: 'Enter a custom upstream DNS server',
                      hintText:
                          'e.g. 9.9.9.9 (leave blank for the default servers)',
                      errorText: _dnsErrorText,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.edit_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (value) async {
                      await _saveCustomDns(value);
                      if (mounted) {
                        setState(() {
                          _updateSelectedDnsPresetId(value);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          // Section: Content
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Content',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // Guide
          ListTile(
            title: const Text('Help & tips'),
            subtitle: const Text('Learn how to use the app effectively'),
            onTap: () => _navigateToContentSection(AppRoutes.guide),
          ),
          // Replay app tour
          AppTourManager.appTourItem(
            key: _replayTourKey,
            enableAutoScroll: true,
            isLastStep: true,
            title: 'Replay feature tour',
            description: 'Watch the key features of the application again.',
            child: ListTile(
              title: const Text('Replay app tour'),
              subtitle: const Text(
                'Walkthrough key features '
                'of ${Constants.appName}',
              ),
              onTap: () async {
                await AppTourManager.resetAppTourState();
                if (!context.mounted) return;
                AppNavigationService.jumpToTab(0);
                AppTourManager.notifyPermissionsUpdated();
              },
            ),
          ),
          // Clear content
          ListTile(
            title: const Text('Clear content'),
            subtitle: const Text('Remove all blocklist rules'),
            onTap: () => _showClearContentDialogue(),
          ),
          // Reset content
          ListTile(
            title: const Text('Reset content'),
            subtitle: const Text('Revert to the default state of the app'),
            onTap: () => _showResetContentDialogue(),
          ),
          const Divider(),
          // Section: About
          ExpansionTile(
            title: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'About',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            subtitle: ListenableBuilder(
              listenable: _aboutSecController,
              builder: (context, _) => _aboutSecController.isExpanded
                  ? const SizedBox.shrink()
                  : const Text('Tap to expand'),
            ),
            controller: _aboutSecController,
            children: [
              // Privacy policy
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                onTap: _showPrivacyPolicyDialog,
              ),
              // Licence information
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Licence'),
                onTap: _showLicenseDialog,
              ),
              // Open-source licences
              ListTile(
                leading: const Icon(Icons.library_books_outlined),
                title: const Text('Open-source licences'),
                subtitle: const Text('Licences of third-party packages'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: Constants.appName,
                  applicationVersion: _appVersion,
                ),
              ),
              // App version information
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App version'),
                subtitle: Text(_appVersion),
              ),
              if (!Constants.isFdroidBuild) ...[
                // App updater
                ListTile(
                  leading: const Icon(Icons.system_update_outlined),
                  title: const Text('Updater'),
                  subtitle: _isUpdateAvailable
                      ? Text('New version available: $_latestVersion')
                      : const Text('Check for latest releases'),
                  trailing: _isCheckingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _isUpdateAvailable
                      ? ElevatedButton(
                          onPressed: () => _launchUrl(Constants.releasesUrl),
                          child: const Text('Update now'),
                        )
                      : TextButton(
                          onPressed: _checkUpdates,
                          child: const Text('Check updates'),
                        ),
                ),
              ],
              // Changelog
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Changelog'),
                subtitle: const Text('View recent changes'),
                onTap: _showChangelogDialog,
              ),
              // Source code
              ListTile(
                leading: const Icon(Icons.code_outlined),
                title: const Text('Source code'),
                subtitle: const Text('View on GitHub'),
                onTap: _showSourceCodeDialog,
              ),
              // Donate
              ListTile(
                leading: const Icon(Icons.coffee_outlined, color: Colors.brown),
                title: const Text('Donate'),
                subtitle: const Text(
                  'Support lead app developer by buying a coffee',
                ),
                onTap: _showDonateDialog,
              ),
              // App updater
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
