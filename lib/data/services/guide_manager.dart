// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/services.dart' show rootBundle;

// Project imports:
import 'package:clearnet/data/models/guide.dart';

class GuideManager {
  static const String jsonAsset = 'assets/data/guide.json';

  static Future<GuideData> loadGuide() async {
    final jsonString = await rootBundle.loadString(jsonAsset);
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return GuideData.fromJson(jsonMap);
  }
}
