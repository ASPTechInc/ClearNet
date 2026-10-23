// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

class AppSession {
  /// Whether the Settings lock has been passed. Kept in memory only, so it
  /// ends when the app closes or is locked again.
  static bool isSettingsUnlocked = false;
}

/// Whether [latest] (such as "v1.2.0") is a newer version than [current]
/// (such as "1.1.0+3"). Build numbers and pre-release tags are ignored.
bool isNewerVersion(String latest, String current) {
  List<int> numbers(String version) => version
      .trim()
      .replaceFirst(RegExp('^[vV]'), '')
      .split(RegExp('[+-]'))
      .first
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();

  final a = numbers(latest);
  final b = numbers(current);
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
