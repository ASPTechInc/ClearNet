// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/stats_manager.dart';
import 'package:clearnet/presentation/screens/pin_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isBlockingEnabled = false;
  int _websitesBlocked = 0;
  int _appsBlocked = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final webCount = await StatsManager.getBlockedWebsitesCount();
    final appCount = await StatsManager.getBlockedAppsCount();

    if (!mounted) return;
    setState(() {
      _isBlockingEnabled = prefs.getBool('is_blocking_enabled') ?? false;
      _websitesBlocked = webCount;
      _appsBlocked = appCount;
    });
  }

  Future<void> _toggleBlocking(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_blocking_enabled', value);
    
    if (value) {
      await VpnController.startVpn();
    } else {
      await VpnController.stopVpn();
    }

    setState(() {
      _isBlockingEnabled = value;
    });
  }

  Future<void> _openSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool(Constants.lockSettingsKey) ?? false;
    
    if (isLocked) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinLockScreen(
            onSuccess: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.pushNamed(context, '/settings');
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
                      _isBlockingEnabled ? 'Blocking Active' : 'Blocking Paused',
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
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.tune),
              label: const Text('Configure Protection'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
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
              "Today's Activity",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.public, _websitesBlocked, 'Websites'),
                _buildStatItem(Icons.apps, _appsBlocked, 'Apps'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, int count, String label) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
