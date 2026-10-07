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
import 'package:clearnet/data/models/dns_preset.dart';
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/screens/pin_screen.dart';
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

  final GlobalKey _appLockKey = GlobalKey();
  final GlobalKey _disguiseKey = GlobalKey();
  final GlobalKey _uninstallPinKey = GlobalKey();
  final GlobalKey _dnsKey = GlobalKey();
  final GlobalKey _replayTourKey = GlobalKey();
  Timer? _tourTimer;

  static const List<DnsPreset> _dnsPresets = [
    DnsPreset(id: 'default', label: 'Default (FOSS Cluster)', ip: ''),
    DnsPreset(id: '9.9.9.9', label: 'Quad9 (9.9.9.9)', ip: '9.9.9.9'),
    DnsPreset(
      id: '194.242.2.14',
      label: 'Mullvad DNS (194.242.2.14)',
      ip: '194.242.2.14',
    ),
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

  bool _appLockEnabled = false;
  bool _lockSettingsEnabled = false;
  bool _isAppPinSet = false;
  bool _isUninstallPinSet = false;
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
    AppTourManager.permissionsCheckNotifier.removeListener(_onPermissionsUpdated);
    WidgetsBinding.instance.removeObserver(this);
    _dnsController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndStartAppTour();
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
          _disguiseKey,
          _uninstallPinKey,
          _dnsKey,
          _replayTourKey,
        ],
        tourKey: AppTourManager.settingsTourKey,
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
    _dnsController.text = customDns;
    _updateSelectedDnsPresetId(customDns);
    if (!mounted) return;
    setState(() {
      _appLockEnabled = appLock == 'true';
      _isAppPinSet = appPin != null && appPin.isNotEmpty;
      _isUninstallPinSet = uninstallPin != null && uninstallPin.isNotEmpty;
      _lockSettingsEnabled = lockSettings;
      _currentDisguise = disguise;
    });
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
              'Disguise set to ${disguise.toUpperCase()}. It may take a few moments to update the launcher.',
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
    }
  }

  void _updateSelectedDnsPresetId(String ip) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) {
      _selectedDnsPresetId = 'default';
      return;
    }
    for (final preset in _dnsPresets) {
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
      final isPresetIp = _dnsPresets.any(
        (p) => p.ip.isNotEmpty && p.ip == currentText,
      );
      if (isPresetIp) {
        _dnsController.clear();
        await _saveCustomDns('');
      }
    } else {
      final selectedPreset = _dnsPresets.firstWhere(
        (preset) => preset.id == newValue,
        orElse: () => _dnsPresets.first,
      );
      _dnsController.text = selectedPreset.ip;
      await _saveCustomDns(selectedPreset.ip);
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleLockSettings(bool value) async {
    if (value && !_isAppPinSet) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set an App PIN first')),
      );
      return;
    }

    await _prefs.setBool(Constants.lockSettingsKey, value);
    setState(() {
      _lockSettingsEnabled = value;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      if (!_isAppPinSet) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PinLockScreen(
              confirmMode: true,
              pinKey: Constants.appPinKey,
              title: 'Set App PIN',
              onSuccess: () async {
                await storage.write(
                  key: Constants.appLockEnabledKey,
                  value: 'true',
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App PIN set successfully')),
                );
              },
            ),
          ),
        );
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinLockScreen(
          pinKey: Constants.appPinKey,
          title: 'Verify Current App PIN',
          onSuccess: () async {
            Navigator.pop(context);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PinLockScreen(
                  confirmMode: true,
                  pinKey: Constants.appPinKey,
                  title: 'Set New App PIN',
                  onSuccess: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('App PIN changed successfully'),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
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
          'Once set, it CANNOT be changed or reset for security reasons. '
          'Do you want to proceed?',
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinLockScreen(
          confirmMode: true,
          pinKey: Constants.uninstallPinKey,
          title: 'Set Uninstall PIN',
          onSuccess: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Uninstall PIN set successfully')),
            );
          },
        ),
      ),
    );
    _loadSettings();
  }

  Future<void> _navigateToContentSection(String routeName) async {
    if (_lockSettingsEnabled && !AppSession.isSettingsUnlocked) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinLockScreen(
            pinKey: Constants.appPinKey,
            title: 'Verify App PIN',
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

  Future<void> _showClearContentDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear content'),
        content: const Text(
          'This will remove all items from blocked websites, keywords, whitelist, and unselect all blocked apps. Do you want to proceed?',
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

  Future<void> _showResetContentDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset content'),
        content: const Text(
          'This will reset blocked sites, keywords, and whitelist to default data. Do you want to proceed?',
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

  Future<void> _showThemeDialog() async {
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

  Future<void> _showDisguiseDialog() async {
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
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('None (Default)'),
                value: 'none',
              ),
              RadioListTile<String>(
                title: Text('Calculator'),
                value: 'calculator',
              ),
              RadioListTile<String>(title: Text('Notes'), value: 'notes'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReliabilityDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reliability note'),
        content: const Text(
          'For the VPN, website, and app blocking to work reliably, battery optimisation has to be disabled and the Safe Browsing service has to be enabled while using ClearNet.',
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
                child: SelectableText(
                  privacyPolicy,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.4),
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
                'ClearNet is free open-source software (FOSS). The complete source code, issue tracker, and build instructions are publicly available.',
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
          title: const Text('Support ClearNet'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ClearNet is built and maintained as a free, open-source project with no ads, subscriptions, or tracking.',
              ),
              SizedBox(height: 12),
              Text(
                'If you appreciate ClearNet and wish to support its continued development, you can buy the lead developer a coffee!',
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
      // Extract date: e.g., (2026-09-18)
      final dateMatch = RegExp(
        r'\((\d{4}-\d{2}-\d{2})\)',
      ).firstMatch(trimmedBlock);

      final version = versionMatch?.group(1) ?? 'Update';
      final date = dateMatch?.group(1) ?? '';

      // Extract features (lines starting with '-')
      final lines = trimmedBlock.split('\n');
      final List<String> features = [];
      //String? description;

      for (var line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('-')) {
          features.add(trimmedLine.substring(1).trim());
        } else if (trimmedLine.isNotEmpty &&
            !trimmedLine.startsWith('#') &&
            !trimmedLine.startsWith('!')) {
          // Capture the description text if it's not a header
          // if (description == null) {
          //   description = trimmedLine;
          // } else {
          //   description += ' $trimmedLine';
          // }
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
                // if (description != null && description.isNotEmpty)
                //   Padding(
                //     padding: const EdgeInsets.only(bottom: 16.0),
                //     child: RichText(
                //       text: TextSpan(
                //         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                //               color: Theme.of(context).colorScheme.onSurface,
                //               height: 1.4,
                //             ),
                //         children: _parseBoldText(description),
                //       ),
                //     ),
                //   ),
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, right: 12.0),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                              children: _parseBoldText(feature),
                            ),
                          ),
                        ),
                      ],
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

  List<InlineSpan> _parseBoldText(String text) {
    final List<InlineSpan> spans = [];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else {
        spans.add(TextSpan(text: parts[i]));
      }
    }
    return spans;
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
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
        // Simple version comparison (e.g. v1.1.0 vs 1.0.0)
        final currentVersion = _appVersion.split('+')[0];
        final cleanLatest = latestTag.replaceAll('v', '');

        if (cleanLatest != currentVersion) {
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
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(
              ThemeService.themeModeNotifier.value.name[0].toUpperCase() +
                  ThemeService.themeModeNotifier.value.name.substring(1),
            ),
            onTap: _showThemeDialog,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Reliability',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.verified_user_outlined,
              color: Colors.blue,
            ),
            title: const Text('Reliability & performance note'),
            subtitle: const Text('Important information for app stability'),
            onTap: _showReliabilityDialog,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Security',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          AppTourManager.appTourItem(
            key: _appLockKey,
            title: 'App lock',
            description:
                'Require a secure PIN to open ClearNet or protect Settings section from unauthorised changes.',
            child: SwitchListTile(
              title: const Text('Set app PIN'),
              value: _appLockEnabled,
              onChanged: _toggleAppLock,
            ),
          ),
          if (_isAppPinSet)
            ListTile(
              title: const Text('Change app PIN'),
              leading: const Icon(Icons.password),
              onTap: _changeAppPin,
            ),
          SwitchListTile(
            title: const Text('Lock settings with PIN'),
            subtitle: const Text(
              'Requires app PIN to access this (Settings) screen',
            ),
            value: _lockSettingsEnabled,
            onChanged: _toggleLockSettings,
          ),
          AppTourManager.appTourItem(
            key: _disguiseKey,
            title: 'Disguise mode',
            description:
                'Disguise ClearNet on your home screen as a calculator, calendar or other innocuous application.',
            child: ListTile(
              title: const Text('Disguise mode'),
              subtitle: Text('Current: ${_currentDisguise.toUpperCase()}'),
              leading: const Icon(Icons.theater_comedy_outlined),
              onTap: _showDisguiseDialog,
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Uninstall protection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          AppTourManager.appTourItem(
            key: _uninstallPinKey,
            title: 'Uninstall protection',
            description:
                'Set a permanent PIN to prevent unauthorised app removal.',
            child: ListTile(
              title: const Text('Uninstall PIN'),
              subtitle: Text(
                _isUninstallPinSet
                    ? 'PIN is set and permanent'
                    : 'Set a PIN to prevent unauthorised uninstallation of the application',
              ),
              trailing: _isUninstallPinSet
                  ? const Icon(Icons.lock, color: Colors.green)
                  : null,
              onTap: _isUninstallPinSet ? null : _setupUninstallPin,
              enabled: !_isUninstallPinSet,
            ),
          ),
          if (!_isUninstallPinSet)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Warning: Once set, the Uninstall PIN cannot be changed or reset.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Network & DNS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          AppTourManager.appTourItem(
            key: _dnsKey,
            title: 'Secure DNS Resolver',
            description:
                'Choose a curated encrypted DNS resolver (like Quad9 or Cloudflare) or enter a custom DNS server.',
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
                      labelText: 'Curated DNS Resolver',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    items: _dnsPresets.map((preset) {
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
                          'e.g. 9.9.9.9 (Leave blank for default FOSS cluster)',
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
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Content',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text('Manage blocked websites'),
            onTap: () => _navigateToContentSection(AppRoutes.blockedSites),
          ),
          ListTile(
            title: const Text('Manage blocked apps'),
            onTap: () => _navigateToContentSection(AppRoutes.blockedApps),
          ),
          ListTile(
            title: const Text('Guide'),
            onTap: () => _navigateToContentSection(AppRoutes.guide),
          ),
          AppTourManager.appTourItem(
            key: _replayTourKey,
            title: 'Replay Feature Tour',
            description:
                'Reset and replay the feature walkthrough across all screens at any time.',
            child: ListTile(
              title: const Text('Replay app tour'),
              subtitle: const Text('Walkthrough key features of ClearNet'),
              onTap: () async {
                await AppTourManager.resetAppTourState();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Feature tour reset. Switch to Protection screen to start.',
                    ),
                  ),
                );
              },
            ),
          ),
          ListTile(
            title: const Text('Clear content'),
            onTap: () => _showClearContentDialog(),
          ),
          ListTile(
            title: const Text('Reset content'),
            onTap: () => _showResetContentDialog(),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'About',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            onTap: _showPrivacyPolicyDialog,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licence'),
            onTap: _showLicenseDialog,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App version'),
            subtitle: Text(_appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('Changelog'),
            subtitle: const Text('View recent changes'),
            onTap: _showChangelogDialog,
          ),
          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: const Text('Source code'),
            subtitle: const Text('View on GitHub'),
            onTap: _showSourceCodeDialog,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.coffee_outlined, color: Colors.brown),
            title: const Text('Donate'),
            subtitle: const Text(
              'Support lead app developer by buying a coffee',
            ),
            onTap: _showDonateDialog,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Updates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('App updater'),
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
