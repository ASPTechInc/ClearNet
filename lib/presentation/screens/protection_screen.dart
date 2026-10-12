// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/app_nav_service.dart';
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/data/services/stats_manager.dart';
import 'package:clearnet/presentation/widgets/permission_requirement_dialogue.dart';
import 'package:clearnet/shared/utilities/constants.dart';

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});

  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen>
    with WidgetsBindingObserver {
  // Declare keys for app tour
  final GlobalKey _protectionSwitchKey = GlobalKey();
  final GlobalKey _activityCardKey = GlobalKey();
  Timer? _tourTimer;

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
    WidgetsBinding.instance.addObserver(this);
    AppTourManager.permissionsCheckNotifier.addListener(_onPermissionsUpdated);
    unawaited(_loadData());

    // Attempt starting the app tour once the initial frame is drawn
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
        keys: [_protectionSwitchKey, _activityCardKey],
        tourKey: AppTourManager.protectionTourKey,
        onFinish: _goToContentTab,
      );
    });
  }

  void _goToContentTab() {
    // Protection tab: 0, Content tab: 1, Settings tab: 2
    if (!mounted) return;
    AppNavigationService.jumpToTab(1); // Content tab
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
      final isAccessibilityEnabled =
          await VpnController.isAccessibilityServiceEnabled();
      if (!isAccessibilityEnabled) {
        if (!mounted) return;
        final granted = await _showEnableAccessibilityDialog();
        if (!granted) return;
      }

      final isBatteryOptimised =
          await VpnController.isIgnoringBatteryOptimisations();
      if (!isBatteryOptimised) {
        if (!mounted) return;
        final granted = await _showBatteryOptimisationDialog();
        if (!granted) return;
      }
    } else {
      // User is trying to disable blocking, show the complex confirmation task
      final confirmed = await VpnController.showDisableConfirmation();
      if (!confirmed) {
        // User failed or cancelled the task, do not toggle the switch
        setState(() {
          _isBlockingEnabled = true;
        });
        return;
      }
    }

    await _prefs.setBool('is_blocking_enabled', value);

    if (value) {
      await VpnController.startVpn();
    } else {
      await VpnController.stopVpn();
    }

    if (!mounted) return;
    setState(() {
      _isBlockingEnabled = value;
    });

    _checkAndStartAppTour();
  }

  Future<bool> _showEnableAccessibilityDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionRequirementDialogue(
        title: 'Enable Safe Browsing',
        description:
            'To enable blocking, you must first enable the Safe browsing '
            'service in your device settings.',
        initialButtonText: 'Go to Settings',
        clickedButtonText: 'Confirm enabling',
        exitButtonText: 'Cancel',
        onActionPressed: () async {
          await VpnController.openAccessibilitySettings();
        },
        onCheckPermission: () async {
          return VpnController.isAccessibilityServiceEnabled();
        },
        onExitPressed: () => Navigator.pop(context, false),
        notEnabledMessage:
            'Safe Browsing Service is not enabled yet. Please enable it in '
            'Accessibility settings.',
      ),
    );
    return result ?? false;
  }

  Future<bool> _showBatteryOptimisationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionRequirementDialogue(
        title: 'Battery performance',
        description:
            'Battery optimisation has to be disabled for '
            '${Constants.appName} in order for the VPN and website '
            'blocking to work reliably.',
        initialButtonText: 'Disable optimisation',
        clickedButtonText: 'Confirm disabling',
        exitButtonText: 'Cancel',
        onActionPressed: () async {
          await VpnController.requestIgnoreBatteryOptimisations();
        },
        onCheckPermission: () async {
          return VpnController.isIgnoringBatteryOptimisations();
        },
        onExitPressed: () => Navigator.pop(context, false),
        notEnabledMessage:
            'Battery optimisation is still active for ${Constants.appName}. '
            'Please allow ignoring battery optimisation.',
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Constants.appName), actions: []),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: _isBlockingEnabled
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isBlockingEnabled
                          ? 'Blocking active'
                          : 'Blocking paused',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isBlockingEnabled
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.green[300]
                                  : Colors.green[800])
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.red[300]
                                  : Colors.red[800]),
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
                AppTourManager.appTourItem(
                  key: _protectionSwitchKey,
                  title: 'Activate blocking',
                  description: 'Toggle this switch to turn blocking on or off.',
                  child: Switch(
                    value: _isBlockingEnabled,
                    onChanged: _toggleBlocking,
                    activeThumbColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  AppTourManager.appTourItem(
                    key: _activityCardKey,
                    title: 'Daily blocking statistics',
                    description:
                        'View real-time daily statistics of blocked '
                        'websites and apps. The weekly and monthly '
                        'statistics are also available.',
                    child: _buildActivityCard(),
                  ),
                  const SizedBox(height: 24),
                  Icon(
                    _isBlockingEnabled ? Icons.shield : Icons.shield_outlined,
                    size: 120,
                    color: _isBlockingEnabled ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isBlockingEnabled
                        ? '${Constants.appName} is guarding'
                        : '${Constants.appName} is idle',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
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
              "Today's activity",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.public,
                  _websitesBlocked,
                  'Websites',
                  _weeklyWebsites,
                  _monthlyWebsites,
                ),
                _buildStatItem(
                  Icons.apps,
                  _appsBlocked,
                  'Apps',
                  _weeklyApps,
                  _monthlyApps,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    int count,
    String label,
    int weekly,
    int monthly,
  ) {
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
