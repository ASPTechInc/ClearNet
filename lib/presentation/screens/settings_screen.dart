// Dart imports:
import 'dart:async';
import 'dart:convert';

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
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/screens/pin_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const platform = MethodChannel(Constants.methodChannelName);
  final storage = const FlutterSecureStorage();

  bool _appLockEnabled = false;
  bool _lockSettingsEnabled = false;
  bool _isPinSet = false;
  bool _isSettingsPinSet = false;
  final _dnsController = TextEditingController();
  
  String _appVersion = '1.0.0';
  bool _isUpdateAvailable = false;
  String _latestVersion = '';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
    unawaited(_fetchAppVersion());
  }

  Future<void> _fetchAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _loadSettings() async {
    final appLock = await storage.read(key: Constants.appLockEnabledKey);
    final pin = await storage.read(key: Constants.uninstallPinKey);
    final settingsPin = await storage.read(key: Constants.settingsLockPinKey);
    final prefs = await SharedPreferences.getInstance();
    final customDns = prefs.getString('custom_dns') ?? '';
    final lockSettings = prefs.getBool(Constants.lockSettingsKey) ?? false;
    _dnsController.text = customDns;
    if (!mounted) return;
    setState(() {
      _appLockEnabled = appLock == 'true';
      _lockSettingsEnabled = lockSettings;
      _isPinSet = pin != null;
      _isSettingsPinSet = settingsPin != null;
    });
  }

  Future<void> _saveCustomDns(String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.trim().isEmpty) {
      await prefs.remove('custom_dns');
    } else {
      await prefs.setString('custom_dns', value.trim());
    }
  }

  Future<void> _toggleLockSettings(bool value) async {
    if (value && !_isSettingsPinSet) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a Settings PIN first')),
      );
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.lockSettingsKey, value);
    setState(() {
      _lockSettingsEnabled = value;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value && !_isPinSet) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set an Uninstall PIN first'),
        ),
      );
      return;
    }

    await storage.write(key: Constants.appLockEnabledKey, value: value.toString());
    setState(() {
      _appLockEnabled = value;
    });
  }

  Future<void> _setupPin() async {
    if (_isPinSet) return; // Cannot change once set

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Permanent PIN'),
        content: const Text(
          'This Uninstall PIN will be used for biometric fallback and uninstallation protection. '
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

  Future<void> _setupSettingsPin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinLockScreen(
          confirmMode: true,
          pinKey: Constants.settingsLockPinKey,
          title: 'Set Settings PIN',
          onSuccess: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings PIN set successfully')),
            );
          },
        ),
      ),
    );
    _loadSettings();
  }

  Future<void> _removeSettingsPin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinLockScreen(
          pinKey: Constants.settingsLockPinKey,
          title: 'Verify Settings PIN',
          onSuccess: () async {
            await storage.delete(key: Constants.settingsLockPinKey);
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(Constants.settingsLockPinKey);
            await prefs.setBool(Constants.lockSettingsKey, false);
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Settings PIN removed')));
          },
        ),
      ),
    );
    _loadSettings();
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint("Failed to open accessibility settings: '${e.message}'.");
    }
  }

  Future<void> _showThemeDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        final currentMode = ThemeService.themeModeNotifier.value;
        return AlertDialog(
          title: const Text('Choose Theme'),
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
                  title: Text('Follow System'),
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
      final dateMatch = RegExp(r'\((\d{4}-\d{2}-\d{2})\)').firstMatch(trimmedBlock);
      
      final version = versionMatch?.group(1) ?? 'Update';
      final date = dateMatch?.group(1) ?? '';

      // Extract features (lines starting with '-')
      final lines = trimmedBlock.split('\n');
      final List<String> features = [];
      String? description;

      for (var line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('-')) {
          features.add(trimmedLine.substring(1).trim());
        } else if (trimmedLine.isNotEmpty && 
                   !trimmedLine.startsWith('#') && 
                   !trimmedLine.startsWith('!')) {
          // Capture the description text if it's not a header
          if (description == null) {
            description = trimmedLine;
          } else {
            description += ' $trimmedLine';
          }
        }
      }

      widgets.add(Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                version,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
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
              if (description != null && description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.4,
                          ),
                      children: _parseBoldText(description),
                    ),
                  ),
                ),
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, right: 12.0),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.pink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.4,
                              ),
                          children: _parseBoldText(feature),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ));
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
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('App is up to date')),
            );
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
            subtitle: Text(ThemeService.themeModeNotifier.value.name[0].toUpperCase() + 
                           ThemeService.themeModeNotifier.value.name.substring(1)),
            onTap: _showThemeDialog,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Permissions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.accessibility_new, color: Colors.blue),
            title: const Text('Enable Safe Browsing Service'),
            subtitle: const Text(
              'Required for blocking sites while using a VPN',
            ),
            onTap: _openAccessibilitySettings,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Security',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('Enable PIN for App'),
            value: _appLockEnabled,
            onChanged: _toggleAppLock,
          ),
          SwitchListTile(
            title: const Text('Lock settings with PIN'),
            subtitle: const Text('Requires Settings PIN to access this screen'),
            value: _lockSettingsEnabled,
            onChanged: _toggleLockSettings,
          ),
          ListTile(
            title: Text(_isSettingsPinSet ? 'Change settings PIN' : 'Set settings PIN'),
            leading: const Icon(Icons.password),
            onTap: _setupSettingsPin,
          ),
          if (_isSettingsPinSet)
            ListTile(
              title: const Text('Remove Settings PIN'),
              leading: const Icon(Icons.delete_outline),
              onTap: _removeSettingsPin,
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Uninstall Protection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text('Uninstall PIN'),
            subtitle: Text(_isPinSet 
              ? 'PIN is set and permanent' 
              : 'Set a PIN to prevent unauthorized uninstallation'),
            trailing: _isPinSet ? const Icon(Icons.lock, color: Colors.green) : null,
            onTap: _isPinSet ? null : _setupPin,
            enabled: !_isPinSet,
          ),
          if (!_isPinSet)
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _dnsController,
              decoration: const InputDecoration(
                labelText: 'Custom upstream DNS server',
                hintText: 'e.g., 9.9.9.9 (Leave blank for default FOSS cluster)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: _saveCustomDns,
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
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.blockedSites);
            },
          ),
          ListTile(
            title: const Text('Manage blocked apps'),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.blockedApps);
            },
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
            onTap: () => _launchUrl(Constants.privacyPolicyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licence'),
            onTap: () => _launchUrl(Constants.licenseUrl),
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
            onTap: () => _launchUrl(Constants.githubRepoUrl),
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
            subtitle: const Text('Buy me a coffee'),
            onTap: () => _launchUrl(Constants.buyMeACoffeeUrl),
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
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : _isUpdateAvailable 
                    ? ElevatedButton(
                        onPressed: () => _launchUrl(Constants.releasesUrl),
                        child: const Text('Update now'),
                      )
                    : TextButton(
                        onPressed: _checkUpdates,
                        child: const Text('Check for updates'),
                      ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
