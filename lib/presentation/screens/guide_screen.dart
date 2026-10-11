// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'package:clearnet/data/models/guide.dart';
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/data/services/guide_manager.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> with WidgetsBindingObserver {
  late Future<GuideData> _guideFuture;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final GlobalKey _guidePageKey = GlobalKey();
  final GlobalKey _guideControlsKey = GlobalKey();
  Timer? _tourTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppTourManager.permissionsCheckNotifier.addListener(_onPermissionsUpdated);
    _guideFuture = GuideManager.loadGuide();

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
    _pageController.dispose();
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
        keys: [_guidePageKey, _guideControlsKey],
        tourKey: AppTourManager.guideTourKey,
      );
    });
  }

  void _nextItem(int totalPages) {
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 450,
        height: 600,
        color: theme.colorScheme.surface,
        child: FutureBuilder<GuideData>(
          future: _guideFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load guide',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }

            final guideData = snapshot.data!;
            final pages = guideData.pages;

            return Column(
              children: [
                // 1. Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          guideData.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // 2. Page View (Content Layout)
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      final content = SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildGuideImage(page, theme),
                            const SizedBox(height: 32),
                            Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page.description,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );

                      if (index == 0) {
                        return AppTourManager.appTourItem(
                          key: _guidePageKey,
                          title: 'Guide Recommendations',
                          description:
                              'Swipe or tap Next to read tips, rules and '
                              'best practices for preventing bypasses.',
                          child: content,
                        );
                      }

                      return content;
                    },
                  ),
                ),

                // 3. Footer (Controls Layout)
                const Divider(height: 1),
                AppTourManager.appTourItem(
                  key: _guideControlsKey,
                  title: 'Guide Controls',
                  description:
                      'Use back and next buttons or page indicators to '
                      'navigate through the guide.',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        // Back Button Layout wrapped in Visibility to 
                        //prevent horizontal space overflow constraints
                        Visibility(
                          visible: _currentPage > 0,
                          maintainState: true,
                          maintainAnimation: true,
                          maintainSize: true,
                          child: IconButton(
                            onPressed: _currentPage > 0
                                ? () => _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  )
                                : null,
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),

                        // Flexible wrapper bounds horizontal footprint of 
                        //progress indicators cleanly
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(pages.length, (index) {
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    height: 8,
                                    width: _currentPage == index ? 24 : 8,
                                    decoration: BoxDecoration(
                                      color: _currentPage == index
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.primary
                                                .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),

                        // Next/Done Selection Action
                        TextButton(
                          onPressed: () => _nextItem(pages.length),
                          child: Text(
                            _currentPage == pages.length - 1
                                ? 'Got it'
                                : 'Next',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGuideImage(GuideItem page, ThemeData theme) {
    IconData iconData;
    Color iconColor;
    Color bgColor;

    switch (page.type) {
      case GuideDataType.intro:
        iconData = Icons.shield_outlined;
        iconColor = theme.colorScheme.primary;
        bgColor = theme.colorScheme.primaryContainer;
        break;
      case GuideDataType.doPage:
        iconData = Icons.check_circle_outline;
        iconColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.15);
        break;
      case GuideDataType.dont:
        iconData = Icons.block;
        iconColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.15);
        break;
      case GuideDataType.tip:
        iconData = Icons.lightbulb_outline;
        iconColor = Colors.amber.shade800;
        bgColor = Colors.amber.withValues(alpha: 0.15);
        break;
    }

    final fallback = CircleAvatar(
      radius: 36,
      backgroundColor: bgColor,
      child: Icon(iconData, size: 40, color: iconColor),
    );

    if (page.image != null && page.image!.isNotEmpty) {
      return SizedBox(
        height: 150,
        width: double.infinity,
        child: Image.asset(
          page.image!,
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    }

    return fallback;
  }
}
