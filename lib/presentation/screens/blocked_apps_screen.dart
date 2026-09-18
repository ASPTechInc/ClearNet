// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

class BlockedAppsScreen extends StatefulWidget {
  const BlockedAppsScreen({super.key});

  @override
  State<BlockedAppsScreen> createState() => _BlockedAppsScreenState();
}

class _BlockedAppsScreenState extends State<BlockedAppsScreen> {
  static const platform = MethodChannel(Constants.methodChannelName);
  List<Map<String, String>> _allApps = [];
  List<Map<String, String>> _filteredApps = [];
  Set<String> _blockedPackages = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterApps);
  }

  Future<void> _loadData() async {
    try {
      final List<dynamic> apps = await platform.invokeMethod('getInstalledApps');
      final prefs = await SharedPreferences.getInstance();
      final blocked = prefs.getStringList(Constants.blockedAppsKey) ?? [];

      if (!mounted) return;
      setState(() {
        _allApps = apps.map((e) => Map<String, String>.from(e)).toList();
        _filteredApps = _allApps;
        _blockedPackages = blocked.toSet();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading apps: $e')),
      );
    }
  }

  void _filterApps() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _allApps
          .where((app) =>
              app['name']!.toLowerCase().contains(query) ||
              app['packageName']!.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _toggleApp(String packageName, bool isBlocked) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (isBlocked) {
        _blockedPackages.add(packageName);
      } else {
        _blockedPackages.remove(packageName);
      }
    });
    await prefs.setStringList(Constants.blockedAppsKey, _blockedPackages.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Blocked Apps'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _filteredApps.length,
              itemBuilder: (context, index) {
                final app = _filteredApps[index];
                final pkg = app['packageName']!;
                final isBlocked = _blockedPackages.contains(pkg);

                return SwitchListTile(
                  title: Text(app['name']!),
                  subtitle: Text(pkg, style: const TextStyle(fontSize: 12)),
                  value: isBlocked,
                  onChanged: (val) => _toggleApp(pkg, val),
                  secondary: const Icon(Icons.apps),
                );
              },
            ),
    );
  }
}
