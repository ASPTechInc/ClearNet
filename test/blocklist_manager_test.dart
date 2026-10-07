// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Project imports:
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();

  group('BlocklistManager Unit Tests', () {
    late Map<String, List<String>> fakeAssetJson;

    setUp(() async {
      await SharedPreferencesAsync().clear();
      fakeAssetJson = {
        'domains': ['adultcontent.com', 'gamblingsite.net'],
        'keywords': ['casino', 'betting', 'xxx'],
        'whitelist': ['safe-casino.com'],
      };

      // Mock rootBundle for Constants.blocklistAsset
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            if (message == null) return null;
            final String key = utf8.decode(message.buffer.asUint8List());
            if (key.contains('blocklist.json')) {
              final encoded = json.encode(fakeAssetJson);
              return ByteData.view(
                Uint8List.fromList(utf8.encode(encoded)).buffer,
              );
            }
            return null;
          });

      SharedPreferences.setMockInitialValues({});

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              return '.';
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('loadUserDomains returns an empty list initially', () async {
      final userSites = await BlocklistManager.loadUserDomains();
      expect(userSites, isEmpty);
    });

    test(
      'addUserDomain clean and adds site successfully in lowercase',
      () async {
        await BlocklistManager.addUserDomain('  MyBlockedSite.Com ');
        final userSites = await BlocklistManager.loadUserDomains();

        expect(userSites, hasLength(1));
        expect(userSites.first, 'myblockedsite.com');
      },
    );

    test('addUserDomain rejects duplicate additions', () async {
      await BlocklistManager.addUserDomain('gamblingsite.net');
      await BlocklistManager.addUserDomain('gamblingsite.net');
      final userSites = await BlocklistManager.loadUserDomains();

      expect(userSites, hasLength(1));
    });

    test('addUserWhitelist cleans and adds site successfully', () async {
      await BlocklistManager.addUserWhitelist('  MyAllowedSite.Com ');
      final userWhitelist = await BlocklistManager.loadUserWhitelist();

      expect(userWhitelist, hasLength(1));
      expect(userWhitelist.first, 'myallowedsite.com');
    });

    test(
      'buildFinalBlocklist correctly merges baseline assets and user-configured sites',
      () async {
        await BlocklistManager.addUserDomain('customblocked.org');
        await BlocklistManager.addUserWhitelist('myallowedsite.com');
        await BlocklistManager.buildFinalBlocklist();

        final prefs = SharedPreferencesAsync();
        final syncedDomains =
            await prefs.getStringList(Constants.blocklistKey) ?? [];
        final syncedKeywords =
            await prefs.getStringList(Constants.keywordsKey) ?? [];
        final syncedWhitelist =
            await prefs.getStringList(Constants.whitelistKey) ?? [];

        expect(syncedDomains, hasLength(3));
        expect(
          syncedDomains,
          containsAll([
            'adultcontent.com',
            'gamblingsite.net',
            'customblocked.org',
          ]),
        );
        expect(syncedKeywords, containsAll(['casino', 'betting', 'xxx']));
        expect(
          syncedWhitelist,
          containsAll(['safe-casino.com', 'myallowedsite.com']),
        );
      },
    );

    test(
      'shouldBlock flags domains matching the blocklist exactly or partially',
      () async {
        await BlocklistManager.buildFinalBlocklist();
        expect(
          await BlocklistManager.shouldBlock('subdomain.adultcontent.com'),
          isTrue,
        );
        expect(
          await BlocklistManager.shouldBlock('safeportfolio.com'),
          isFalse,
        );
      },
    );

    test('shouldBlock flags domains containing blocked keywords', () async {
      await BlocklistManager.buildFinalBlocklist();
      expect(
        await BlocklistManager.shouldBlock('onlinecasinoplay.org'),
        isTrue,
      );
      expect(
        await BlocklistManager.shouldBlock('sportsbettingapp.net'),
        isTrue,
      );
      expect(
        await BlocklistManager.shouldBlock('educational-text.com'),
        isFalse,
      );
    });

    test(
      'shouldBlock respects whitelist override over blocked keywords and domains',
      () async {
        await BlocklistManager.addUserWhitelist('custom-casino-news.com');
        await BlocklistManager.buildFinalBlocklist();

        // "casino" is a blocked keyword, but "safe-casino.com" (from asset) & "custom-casino-news.com" are whitelisted
        expect(await BlocklistManager.shouldBlock('safe-casino.com'), isFalse);
        expect(
          await BlocklistManager.shouldBlock('custom-casino-news.com'),
          isFalse,
        );
      },
    );
  });
}
