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
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/app_lock_service.dart';
import 'package:clearnet/data/services/app_nav_service.dart';
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/shared/utilities/constants.dart';

class BlockedContentScreen extends StatefulWidget {
  const BlockedContentScreen({super.key});

  @override
  State<BlockedContentScreen> createState() => _BlockedContentScreenState();
}

class _BlockedContentScreenState extends State<BlockedContentScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const platform = MethodChannel(Constants.methodChannelName);
  final _prefs = SharedPreferencesAsync();

  late final TabController _tabController;

  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _whitelistController = TextEditingController();
  final TextEditingController _appController = TextEditingController();

  final GlobalKey _importExportKey = GlobalKey();
  final GlobalKey _tabBarKey = GlobalKey();
  final GlobalKey _addInputKey = GlobalKey();
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _appToggleKey = GlobalKey();
  Timer? _tourTimer;
  bool _areAppsLoading = true;
  bool _isBlockingEnabled = false;

  List<String> userDomains = [];
  List<String> userKeywords = [];
  List<String> userWhitelist = [];
  List<Map<String, String>> _allApps = [];
  List<Map<String, String>> _filteredApps = [];
  Set<String> _blockedPackages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    AppTourManager.permissionsCheckNotifier.addListener(_onPermissionsUpdated);
    // Blocking can be turned on from the Protection tab while this screen is
    // kept alive, so re-check it whenever the tab changes
    AppNavigationService.controller.addListener(_onTabChanged);
    unawaited(_loadData());
    _appController.addListener(_filterApps);

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
    AppNavigationService.controller.removeListener(_onTabChanged);
    WidgetsBinding.instance.removeObserver(this);
    _domainController.dispose();
    _keywordController.dispose();
    _whitelistController.dispose();
    _appController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndStartAppTour();
      unawaited(_refreshBlockingState());
    }
  }

  void _onTabChanged() {
    // Settings can clear or reset content while this screen is kept alive,
    // so reload the saved lists whenever the Content tab is opened
    if (AppNavigationService.controller.index == 1) {
      unawaited(_reloadSavedContent());
    } else {
      unawaited(_refreshBlockingState());
    }
  }

  /// Reloads the saved lists and blocked apps without re-fetching the
  /// installed apps, so the app search stays as it is.
  Future<void> _reloadSavedContent() async {
    final domains = await BlocklistManager.loadUserDomains();
    final keywords = await BlocklistManager.loadUserKeywords();
    final whitelist = await BlocklistManager.loadUserWhitelist();
    final blocked = await _prefs.getStringList(Constants.blockedAppsKey) ?? [];
    final isBlockingEnabled =
        await _prefs.getBool('is_blocking_enabled') ?? false;

    if (!mounted) return;
    setState(() {
      userDomains = domains;
      userKeywords = keywords;
      userWhitelist = whitelist;
      _blockedPackages = blocked.toSet();
      _isBlockingEnabled = isBlockingEnabled;
    });
  }

  Future<void> _refreshBlockingState() async {
    final isEnabled = await _prefs.getBool('is_blocking_enabled') ?? false;
    if (!mounted || isEnabled == _isBlockingEnabled) return;
    setState(() {
      _isBlockingEnabled = isEnabled;
    });
  }

  /// While blocking is on, only changes that make blocking stricter are
  /// allowed. Returns true, and tells the user why, if [action] has to wait
  /// until blocking is turned off.
  Future<bool> _isLockedFor(String action) async {
    await _refreshBlockingState();
    if (!_isBlockingEnabled) return false;
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Turn off blocking to $action.'),
            action: SnackBarAction(
              label: 'Protection',
              onPressed: () => AppNavigationService.jumpToTab(0),
            ),
          ),
        );
    }
    return true;
  }

  void _onPermissionsUpdated() {
    _checkAndStartAppTour();
  }

  void _checkAndStartAppTour() {
    _tourTimer?.cancel();
    _tourTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      // The app tour on the 'Content' screen starts and uses
      // only the 'Domain' tab
      await AppTourManager.startAppTourIfReady(
        context: context,
        keys: [_importExportKey, _tabBarKey, _addInputKey, _addButtonKey],
        tourKey: AppTourManager.contentTourKey,
        tabIndex: 1,
        beforeStart: () => _tabController.index = 0,
        onFinish: _goToSettingsTab,
      );
    });
  }

  void _goToSettingsTab() {
    // Protection tab: 0, Content tab: 1, Settings tab: 2
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      AppNavigationService.jumpToTab(2); // Settings tab
    });
  }

  Future<void> _loadData() async {
    final domains = await BlocklistManager.loadUserDomains();
    final keywords = await BlocklistManager.loadUserKeywords();
    final whitelist = await BlocklistManager.loadUserWhitelist();
    final isBlockingEnabled =
        await _prefs.getBool('is_blocking_enabled') ?? false;

    if (!mounted) return;
    setState(() {
      userDomains = domains;
      userKeywords = keywords;
      userWhitelist = whitelist;
      _isBlockingEnabled = isBlockingEnabled;
    });

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
        _areAppsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _areAppsLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading apps: $e')));
    }
  }

  Future<void> _addDomain() async {
    final domain = _domainController.text.trim().toLowerCase();
    if (domain.isEmpty) return;

    if (await BlocklistManager.isItemInWhitelist(domain)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This domain is already in the whitelist. Please remove it '
            'from the whitelist first.',
          ),
        ),
      );
      return;
    }

    await BlocklistManager.addUserDomain(domain);
    _domainController.clear();
    await _loadData();
    await VpnController.addSite(domain);
  }

  Future<void> _addKeyword() async {
    final keyword = _keywordController.text.trim().toLowerCase();
    if (keyword.isEmpty) return;

    if (await BlocklistManager.isItemInWhitelist(keyword)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This keyword is already in the whitelist. Please remove it from '
            'the whitelist first.',
          ),
        ),
      );
      return;
    }

    await BlocklistManager.addUserKeyword(keyword);
    _keywordController.clear();
    await _loadData();
    await VpnController.addKeyword(keyword);
  }

  Future<void> _addWhitelist(String site) async {
    if (await _isLockedFor('add whitelisted sites')) return;
    final cleaned = site.trim().toLowerCase();
    if (cleaned.isEmpty) return;

    final inDomains = await BlocklistManager.isItemInDomains(cleaned);
    final inKeywords = await BlocklistManager.isItemInKeywords(cleaned);

    if (inDomains || inKeywords) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This site is already in blocked domains or keywords. Please '
            'remove it from there first.',
          ),
        ),
      );
      return;
    }

    await BlocklistManager.addUserWhitelist(cleaned);
    _whitelistController.clear();
    await _loadData();
    await VpnController.addWhitelist(cleaned);
  }

  Future<void> _removeDomain(String domain) async {
    if (await _isLockedFor('remove domains')) return;
    await BlocklistManager.removeUserDomain(domain);
    await _loadData();
    await VpnController.removeSite(domain);
  }

  Future<void> _removeKeyword(String keyword) async {
    if (await _isLockedFor('remove keywords')) return;
    await BlocklistManager.removeUserKeyword(keyword);
    await _loadData();
    await VpnController.removeKeyword(keyword);
  }

  Future<void> _removeWhitelist(String site) async {
    await BlocklistManager.removeUserWhitelist(site);
    await _loadData();
    await VpnController.removeWhitelist(site);
  }

  Future<void> _updateDomain(String oldDomain, String newDomain) async {
    if (newDomain.trim().isEmpty) return;
    await BlocklistManager.updateUserDomain(oldDomain, newDomain);
    await _loadData();
    await VpnController.removeSite(oldDomain);
    await VpnController.addSite(newDomain);
  }

  Future<void> _updateKeyword(String oldKeyword, String newKeyword) async {
    if (newKeyword.trim().isEmpty) return;
    await BlocklistManager.updateUserKeyword(oldKeyword, newKeyword);
    await _loadData();
    await VpnController.removeKeyword(oldKeyword);
    await VpnController.addKeyword(newKeyword);
  }

  Future<void> _updateWhitelist(String oldSite, String newSite) async {
    if (newSite.trim().isEmpty) return;
    await BlocklistManager.updateUserWhitelist(oldSite, newSite);
    await _loadData();
    await VpnController.removeWhitelist(oldSite);
    await VpnController.addWhitelist(newSite);
  }

  void _filterApps() {
    final query = _appController.text.toLowerCase();
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
    if (!isBlocked && await _isLockedFor('unblock apps')) return;
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

  Future<void> _showEditDialog(String value, String type) async {
    // An edit removes the old entry, so it is locked like a removal
    if (await _isLockedFor('edit rules') || !mounted) return;
    final TextEditingController editController = TextEditingController(
      text: value,
    );
    String title;
    String hintText;

    if (type == 'domain') {
      title = 'Edit Domain';
      hintText = 'example.com';
    } else if (type == 'keyword') {
      title = 'Edit Keyword';
      hintText = 'keyword';
    } else {
      title = 'Edit Whitelisted Site';
      hintText = 'safe.com';
    }

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: editController,
            decoration: InputDecoration(hintText: hintText),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newValue = editController.text.trim().toLowerCase();
                if (newValue.isNotEmpty && newValue != value.toLowerCase()) {
                  if (type == 'domain') {
                    if (await BlocklistManager.isItemInWhitelist(newValue)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This domain is already in the whitelist. '
                              'Please remove it from there first.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    await _updateDomain(value, newValue);
                  } else if (type == 'keyword') {
                    if (await BlocklistManager.isItemInWhitelist(newValue)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This keyword is already in the whitelist. '
                              'Please remove it from there first.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    await _updateKeyword(value, newValue);
                  } else if (type == 'whitelist') {
                    final inDomains = await BlocklistManager.isItemInDomains(
                      newValue,
                    );
                    final inKeywords = await BlocklistManager.isItemInKeywords(
                      newValue,
                    );
                    if (inDomains || inKeywords) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This site is already in blocked domains or '
                              'keywords. Please remove it from there first.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    await _updateWhitelist(value, newValue);
                  }
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importFromFile() async {
    // Importing replaces every list, so it could remove rules
    if (await _isLockedFor('import a blocklist')) return;
    try {
      AppLockService.expectExternalActivity();
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.path != null) {
        final file = File(result.path!);
        final jsonString = await file.readAsString();
        await BlocklistManager.importFromJson(jsonString);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Blocklist imported successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _exportToFile() async {
    try {
      final jsonString = await BlocklistManager.exportToJson();
      AppLockService.expectExternalActivity();
      final result = await FilePicker.saveFile(
        dialogTitle: 'Export Blocklist',
        fileName: Constants.blocklistFileName,
        bytes: utf8.encode(jsonString),
      );

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Blocklist exported to $result')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked content'),
        actions: [
          AppTourManager.appTourItem(
            key: _importExportKey,
            title: 'Import & Export',
            description:
                'Import a custom blocklist file or export your current '
                'configuration to JSON.',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('import_button'),
                  icon: const Icon(Icons.file_upload),
                  onPressed: _importFromFile,
                  tooltip: 'Import ${Constants.blocklistFileName}',
                ),
                IconButton(
                  key: const Key('export_button'),
                  icon: const Icon(Icons.file_download),
                  onPressed: _exportToFile,
                  tooltip: 'Export ${Constants.blocklistFileName}',
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: AppTourManager.appTourItem(
            key: _tabBarKey,
            title: 'Filter categories',
            description:
                'Switch between blocked domains (or websites), keywords, '
                'whitelisted websites and applications.',
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Domains', icon: Icon(Icons.language)),
                Tab(text: 'Keywords', icon: Icon(Icons.text_format)),
                Tab(text: 'Whitelist', icon: Icon(Icons.check_circle_outline)),
                Tab(text: 'Apps', icon: Icon(Icons.apps)),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isBlockingEnabled) _buildLockedBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDomainList(),
                _buildKeywordList(),
                _buildWhitelistList(),
                _buildAppList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('blocking_locked_banner'),
      width: double.infinity,
      color: colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Blocking is on. You can add rules, but removing or editing '
              'them needs blocking turned off first.',
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// Trailing button for a list entry that can only be removed while blocking
  /// is off
  Widget _buildRemoveButton(VoidCallback onRemove) {
    if (_isBlockingEnabled) {
      return IconButton(
        icon: const Icon(Icons.lock_outline, color: Colors.grey),
        tooltip: 'Locked while blocking is on',
        onPressed: onRemove,
      );
    }
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: onRemove,
    );
  }

  Widget _buildDomainList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: AppTourManager.appTourItem(
                  key: _addInputKey,
                  title: 'Add custom rule',
                  description:
                      'Enter a domain to block websites.\n\n'
                      'You can also add keywords, '
                      'whitelisted websites and applications under their '
                      'respective tabs to customise your rules.',
                  child: TextField(
                    key: const Key('domain_input'),
                    controller: _domainController,
                    decoration: const InputDecoration(
                      labelText: 'Add domain (e.g. example.com)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppTourManager.appTourItem(
                key: _addButtonKey,
                title: 'Save rule',
                description:
                    'Tap to add the entered item to your blocklist or '
                    'whitelist.',
                child: IconButton(
                  key: const Key('add_domain_button'),
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.green,
                    size: 40,
                  ),
                  onPressed: _addDomain,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'User-added domains are merged with the built-in blocklist.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: userDomains.isEmpty
              ? _buildNoDataView('No blocked domains yet')
              : ListView.builder(
                  itemCount: userDomains.length,
                  itemBuilder: (context, index) {
                    final domain = userDomains[index];
                    return ListTile(
                      title: Text(domain),
                      onTap: () => _showEditDialog(domain, 'domain'),
                      trailing: _buildRemoveButton(() => _removeDomain(domain)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildKeywordList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('keyword_input'),
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: 'Add keyword (e.g. gambling)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('add_keyword_button'),
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.green,
                  size: 40,
                ),
                onPressed: _addKeyword,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Keywords are used to block content in apps and websites.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: userKeywords.isEmpty
              ? _buildNoDataView('No blocked keywords yet')
              : ListView.builder(
                  itemCount: userKeywords.length,
                  itemBuilder: (context, index) {
                    final keyword = userKeywords[index];
                    return ListTile(
                      title: Text(keyword),
                      onTap: () => _showEditDialog(keyword, 'keyword'),
                      trailing: _buildRemoveButton(
                        () => _removeKeyword(keyword),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWhitelistList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('whitelist_input'),
                  controller: _whitelistController,
                  // Whitelisting loosens blocking, so it waits until
                  // blocking is off
                  enabled: !_isBlockingEnabled,
                  decoration: InputDecoration(
                    labelText: _isBlockingEnabled
                        ? 'Turn off blocking to add sites'
                        : 'Add whitelisted site (e.g. safe.com)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('add_whitelist_button'),
                icon: Icon(
                  _isBlockingEnabled ? Icons.lock_outline : Icons.add_circle,
                  color: _isBlockingEnabled ? Colors.grey : Colors.green,
                  size: 40,
                ),
                onPressed: () => _addWhitelist(_whitelistController.text),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Whitelisted sites bypass domain and keyword blocking rules.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: userWhitelist.isEmpty
              ? _buildNoDataView('No whitelisted sites yet')
              : ListView.builder(
                  itemCount: userWhitelist.length,
                  itemBuilder: (context, index) {
                    final site = userWhitelist[index];
                    return ListTile(
                      title: Text(site),
                      onTap: () => _showEditDialog(site, 'whitelist'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeWhitelist(site),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAppList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _appController,
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
            ],
          ),
        ),
        Expanded(
          child: _areAppsLoading
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
        ),
      ],
    );
  }

  Widget _buildNoDataView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/no-data.png',
            width: 150,
            height: 150,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
