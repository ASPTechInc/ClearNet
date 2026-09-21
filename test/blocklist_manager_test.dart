// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlocklistManager Unit Tests', () {
    late Map<String, List<String>> fakeAssetJson;

    setUp(() {
      fakeAssetJson = {
        'domains': ['adultcontent.com', 'gamblingsite.net'],
        'keywords': ['casino', 'betting', 'xxx'],
      };

      // Mock rootBundle for Constants.blocklistAsset
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            if (message == null) return null;
            final String key = utf8.decode(message.buffer.asUint8List());
            // The key might have a leading slash or be relative
            if (key.contains('blocklist.json')) {
              final encoded = json.encode(fakeAssetJson);
              return ByteData.view(
                Uint8List.fromList(utf8.encode(encoded)).buffer,
              );
            }
            return null;
          });

      // Initialise SharedPreferences with mock initial values
      SharedPreferences.setMockInitialValues({});

      // Mock Path Provider
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
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

    test('addUserDomain clean and adds site successfully in lowercase', () async {
      await BlocklistManager.addUserDomain('  MyBlockedSite.Com ');
      final userSites = await BlocklistManager.loadUserDomains();

      expect(userSites, hasLength(1));
      expect(userSites.first, 'myblockedsite.com');
    });

    test('addUserDomain rejects duplicate additions', () async {
      await BlocklistManager.addUserDomain('gamblingsite.net');
      await BlocklistManager.addUserDomain('gamblingsite.net');
      final userSites = await BlocklistManager.loadUserDomains();

      expect(userSites, hasLength(1));
    });

    test(
      'buildFinalBlocklist correctly merges baseline assets and user-configured sites',
      () async {
        await BlocklistManager.addUserDomain('customblocked.org');
        await BlocklistManager.buildFinalBlocklist();

        // Check SharedPreferences synchronization
        final prefs = await SharedPreferences.getInstance();
        final syncedDomains = prefs.getStringList(Constants.blocklistKey) ?? [];
        final syncedKeywords = prefs.getStringList(Constants.keywordsKey) ?? [];

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
  });
}
