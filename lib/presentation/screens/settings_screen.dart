// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/presentation/screens/blocked_sites.dart';
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
  final LocalAuthentication auth = LocalAuthentication();

  bool _biometricsEnabled = false;
  bool _lockSettingsEnabled = false;
  bool _isPinSet = false;
  final _dnsController = TextEditingController();
  
  String _appVersion = '1.0.0';
  bool _isUpdateAvailable = false;
  String _latestVersion = '';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchAppVersion();
  }

  Future<void> _fetchAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _loadSettings() async {
    final biometrics = await storage.read(key: 'biometrics_enabled');
    final pin = await storage.read(key: 'uninstall_pin');
    final prefs = await SharedPreferences.getInstance();
    final customDns = prefs.getString('custom_dns') ?? '';
    final lockSettings = prefs.getBool(Constants.lockSettingsKey) ?? false;
    _dnsController.text = customDns;
    if (!mounted) return;
    setState(() {
      _biometricsEnabled = biometrics == 'true';
      _lockSettingsEnabled = lockSettings;
      _isPinSet = pin != null;
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
    if (value && !_isPinSet) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a PIN first to lock settings')),
      );
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.lockSettingsKey, value);
    setState(() {
      _lockSettingsEnabled = value;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    final canUseBiometrics = await auth.canCheckBiometrics;
    if (!canUseBiometrics && value) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrics not available on this device'),
        ),
      );
      return;
    }

    await storage.write(key: 'biometrics_enabled', value: value.toString());
    setState(() {
      _biometricsEnabled = value;
    });
  }

  Future<void> _setupPin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinLockScreen(
          confirmMode: true,
          onSuccess: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN set successfully')),
            );
          },
        ),
      ),
    );
    _loadSettings();
  }

  Future<void> _removePin() async {
    final savedPin = await storage.read(key: 'uninstall_pin');
    if (savedPin == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No PIN set')));
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinLockScreen(
          onSuccess: () async {
            await storage.delete(key: 'uninstall_pin');
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('uninstall_pin');
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('PIN removed')));
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

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('Follow System'),
                value: ThemeMode.system,
                groupValue: ThemeService.themeModeNotifier.value,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    ThemeService().updateThemeMode(value);
                    Navigator.pop(context);
                    setState(() {});
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                value: ThemeMode.light,
                groupValue: ThemeService.themeModeNotifier.value,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    ThemeService().updateThemeMode(value);
                    Navigator.pop(context);
                    setState(() {});
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                value: ThemeMode.dark,
                groupValue: ThemeService.themeModeNotifier.value,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    ThemeService().updateThemeMode(value);
                    Navigator.pop(context);
                    setState(() {});
                  }
                },
              ),
            ],
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
                child: SelectableText(changelog),
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
        final data = json.decode(response.body);
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
            title: const Text('Enable Biometrics for App Lock'),
            value: _biometricsEnabled,
            onChanged: _toggleBiometrics,
          ),
          SwitchListTile(
            title: const Text('Lock Settings with PIN'),
            subtitle: const Text('Requires PIN to access this screen'),
            value: _lockSettingsEnabled,
            onChanged: _toggleLockSettings,
          ),
          ListTile(
            title: const Text('Set Uninstall PIN'),
            onTap: _setupPin,
          ),
          if (_isPinSet)
            ListTile(
              title: const Text('Remove Uninstall PIN'),
              onTap: _removePin,
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
                labelText: 'Custom Upstream DNS Server',
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
            title: const Text('Manage Blocked Websites'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedSitesScreen()),
              );
            },
          ),
          ListTile(
            title: const Text('Manage Blocked Apps'),
            onTap: () {
              Navigator.pushNamed(context, '/blocked_apps');
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
            title: const Text('Privacy Policy'),
            onTap: () => _launchUrl(Constants.privacyPolicyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licence'),
            onTap: () => _launchUrl(Constants.licenseUrl),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
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
            title: const Text('Source Code'),
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
            title: const Text('App Updater'),
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
                        child: const Text('Update Now'),
                      )
                    : TextButton(
                        onPressed: _checkUpdates,
                        child: const Text('Check Updates'),
                      ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
