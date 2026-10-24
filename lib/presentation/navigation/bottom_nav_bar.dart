// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/screens/pin_pad_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';
import 'package:clearnet/shared/utilities/helpers.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key, required this.controller});

  final PersistentTabController controller;

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  void jumpToTab(int index) {
    widget.controller.jumpToTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tabs = [
      PersistentTabConfig(
        screen: AppRoutes.getScreen(AppRoutes.home),
        item: ItemConfig(
          icon: const Icon(Icons.shield),
          inactiveIcon: const Icon(Icons.shield_outlined),
          title: 'Protection',
          activeForegroundColor: colorScheme.primary,
          inactiveForegroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
      PersistentTabConfig(
        screen: PinGuardedTab(
          child: AppRoutes.getScreen(AppRoutes.blockedSites),
        ),
        item: ItemConfig(
          icon: const Icon(Icons.block),
          inactiveIcon: const Icon(Icons.block_outlined),
          title: 'Content',
          activeForegroundColor: colorScheme.primary,
          inactiveForegroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
      PersistentTabConfig(
        screen: PinGuardedTab(
          child: AppRoutes.getScreen(AppRoutes.settingsPath),
        ),
        item: ItemConfig(
          icon: const Icon(Icons.settings),
          inactiveIcon: const Icon(Icons.settings_outlined),
          title: 'Settings',
          activeForegroundColor: colorScheme.primary,
          inactiveForegroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
    ];

    return PersistentTabView(
      controller: widget.controller,
      tabs: tabs,
      navBarBuilder: (navBarConfig) {
        return NavigationBar(
          selectedIndex: navBarConfig.selectedIndex,
          onDestinationSelected: navBarConfig.onItemSelected,
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primaryContainer,
          destinations: navBarConfig.items.map((item) {
            return NavigationDestination(
              icon: item.inactiveIcon,
              selectedIcon: item.icon,
              label: item.title ?? '',
            );
          }).toList(),
        );
      },
    );
  }
}

/// A wrapper widget that enforces PIN lock verification before displaying
/// its [child].
/// If lock settings is enabled and [AppSession.isSettingsUnlocked] is false,
/// [PinPadScreen] is displayed until the user enters the correct PIN.
class PinGuardedTab extends StatefulWidget {
  const PinGuardedTab({super.key, required this.child});

  final Widget child;

  @override
  State<PinGuardedTab> createState() => _PinGuardedTabState();
}

class _PinGuardedTabState extends State<PinGuardedTab> {
  late Future<bool> _isLockedFuture;

  @override
  void initState() {
    super.initState();
    _isLockedFuture = _checkIsLocked();
  }

  Future<bool> _checkIsLocked() async {
    final prefs = SharedPreferencesAsync();
    return await prefs.getBool(Constants.lockSettingsKey) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (AppSession.isSettingsUnlocked) {
      return widget.child;
    }

    return FutureBuilder<bool>(
      future: _isLockedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isLocked = snapshot.data ?? false;

        if (isLocked && !AppSession.isSettingsUnlocked) {
          // Settings use the app PIN; there's no separate Settings PIN
          return PinPadScreen(
            pinKey: Constants.appPinKey,
            title: 'Verify App PIN',
            onSuccess: () {
              setState(() {
                AppSession.isSettingsUnlocked = true;
              });
            },
          );
        }

        return widget.child;
      },
    );
  }
}
