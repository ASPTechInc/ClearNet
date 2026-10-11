// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/shared/utilities/constants.dart';

class BlockedAppsScreen extends StatefulWidget {
  const BlockedAppsScreen({super.key});

  @override
  State<BlockedAppsScreen> createState() => _BlockedAppsScreenState();
}

class _BlockedAppsScreenState extends State<BlockedAppsScreen>
    with WidgetsBindingObserver {
  static const platform = MethodChannel(Constants.methodChannelName);
  final _prefs = SharedPreferencesAsync();

  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _appToggleKey = GlobalKey();
  Timer? _tourTimer;

  List<Map<String, String>> _allApps = [];
  List<Map<String, String>> _filteredApps = [];
  Set<String> _blockedPackages = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppTourManager.permissionsCheckNotifier.addListener(_onPermissionsUpdated);
    unawaited(_loadData());
    _searchController.addListener(_filterApps);

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
    _searchController.dispose();
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
        keys: [_searchKey, _appToggleKey],
        tourKey: AppTourManager.blockedAppsTourKey,
      );
    });
  }

  Future<void> _loadData() async {
    try {
      final List<dynamic> apps = await platform.invokeMethod(
        'getInstalledApps',
      );
      final blocked =
          await _prefs.getStringList(Constants.blockedAppsKey) ?? [];

      if (!mounted) return;
      setState(() {
        _allApps = apps.map((e) => Map<String, String>.from(e)).toList();
        _filteredApps = _allApps;
        _blockedPackages = blocked.toSet();
        _isLoading = false;
      });
      _checkAndStartAppTour();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading apps: $e')));
    }
  }

  void _filterApps() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _allApps
          .where(
            (app) =>
                app['name']!.toLowerCase().contains(query) ||
                app['packageName']!.toLowerCase().contains(query),
          )
          .toList();
    });
  }

  Future<void> _toggleApp(String packageName, bool isBlocked) async {
    setState(() {
      if (isBlocked) {
        _blockedPackages.add(packageName);
      } else {
        _blockedPackages.remove(packageName);
      }
    });
    await _prefs.setStringList(
      Constants.blockedAppsKey,
      _blockedPackages.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked apps'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: AppTourManager.appTourItem(
              key: _searchKey,
              title: 'Search Applications',
              description:
                  'Find any installed application by typing its name or '
                  'package name.',
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _filteredApps.length,
              itemBuilder: (context, index) {
                final app = _filteredApps[index];
                final pkg = app['packageName']!;
                final isBlocked = _blockedPackages.contains(pkg);

                final tile = SwitchListTile(
                  title: Text(app['name']!),
                  subtitle: Text(pkg, style: const TextStyle(fontSize: 12)),
                  value: isBlocked,
                  onChanged: (val) => _toggleApp(pkg, val),
                  secondary: const Icon(Icons.apps),
                );

                if (index == 0) {
                  return AppTourManager.appTourItem(
                    key: _appToggleKey,
                    title: 'Block Application',
                    description:
                        'Toggle the switch to block or allow access to '
                        'specific installed apps.',
                    child: tile,
                  );
                }

                return tile;
              },
            ),
    );
  }
}
