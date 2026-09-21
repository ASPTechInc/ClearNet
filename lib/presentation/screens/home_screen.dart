// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/stats_manager.dart';
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/screens/pin_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _prefs = SharedPreferencesAsync();
  bool _isBlockingEnabled = false;
  int _websitesBlocked = 0;
  int _appsBlocked = 0;
  int _weeklyWebsites = 0;
  int _weeklyApps = 0;
  int _monthlyWebsites = 0;
  int _monthlyApps = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    final webCount = await StatsManager.getBlockedWebsitesCount();
    final appCount = await StatsManager.getBlockedAppsCount();
    final weeklyWeb = await StatsManager.getWeeklyWebsitesCount();
    final weeklyApp = await StatsManager.getWeeklyAppsCount();
    final monthlyWeb = await StatsManager.getMonthlyWebsitesCount();
    final monthlyApp = await StatsManager.getMonthlyAppsCount();
    
    final isEnabled = await _prefs.getBool('is_blocking_enabled') ?? false;

    if (!mounted) return;
    setState(() {
      _isBlockingEnabled = isEnabled;
      _websitesBlocked = webCount;
      _appsBlocked = appCount;
      _weeklyWebsites = weeklyWeb;
      _weeklyApps = weeklyApp;
      _monthlyWebsites = monthlyWeb;
      _monthlyApps = monthlyApp;
    });
  }

  Future<void> _toggleBlocking(bool value) async {
    if (value) {
      final isEnabled = await VpnController.isAccessibilityServiceEnabled();
      if (!isEnabled) {
        if (!mounted) return;
        _showEnableAccessibilityDialog();
        return;
      }
    }

    await _prefs.setBool('is_blocking_enabled', value);
    
    if (value) {
      await VpnController.startVpn();
    } else {
      await VpnController.stopVpn();
    }

    setState(() {
      _isBlockingEnabled = value;
    });
  }

  Future<void> _showEnableAccessibilityDialog() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Safe Browsing'),
        content: const Text(
          'To enable blocking, you must first enable the Safe Browsing service in your device settings.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await VpnController.openAccessibilitySettings();
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    final isLocked = await _prefs.getBool(Constants.lockSettingsKey) ?? false;
    
    if (isLocked) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinLockScreen(
            pinKey: Constants.settingsLockPinKey,
            title: 'Verify Settings PIN',
            onSuccess: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.settingsPath);
            },
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.settingsPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(Constants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: _isBlockingEnabled ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isBlockingEnabled ? 'Blocking active' : 'Blocking paused',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isBlockingEnabled 
                            ? (Theme.of(context).brightness == Brightness.dark ? Colors.green[300] : Colors.green[800])
                            : (Theme.of(context).brightness == Brightness.dark ? Colors.red[300] : Colors.red[800]),
                      ),
                    ),
                    Text(
                      _isBlockingEnabled 
                        ? 'Your device is protected.' 
                        : 'Websites and apps are not being blocked.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                Switch(
                  value: _isBlockingEnabled,
                  onChanged: _toggleBlocking,
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildActivityCard(),
                  const SizedBox(height: 24),
                  Icon(
                    _isBlockingEnabled ? Icons.shield : Icons.shield_outlined,
                    size: 120,
                    color: _isBlockingEnabled ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isBlockingEnabled ? 'ClearNet is Guarding' : 'ClearNet is Idle',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                  ),
                ],
              ),
            ),
          ),
          // Padding(
          //   padding: const EdgeInsets.all(24.0),
          //   child: ElevatedButton.icon(
          //     onPressed: _openSettings,
          //     icon: const Icon(Icons.tune),
          //     label: const Text('Configure Protection'),
          //     style: ElevatedButton.styleFrom(
          //       minimumSize: const Size(double.infinity, 50),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's activity",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.public, _websitesBlocked, 'Websites', _weeklyWebsites, _monthlyWebsites),
                _buildStatItem(Icons.apps, _appsBlocked, 'Apps', _weeklyApps, _monthlyApps),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, int count, String label, int weekly, int monthly) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          'W: $weekly | M: $monthly',
          style: TextStyle(
            color: Colors.grey.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
