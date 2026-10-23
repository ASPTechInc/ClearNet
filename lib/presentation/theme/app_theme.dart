// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';

class AppTheme {
  // Main colour configuration
  static final Color _seedColour = Colors.red[900]!;

  /// Configuration for Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColour,
        brightness: Brightness.light,
      ),
      // You can add more attributes here easily later, for example:
      // appBarTheme: const AppBarTheme(elevation: 0),
      // cardTheme: const CardTheme(margin: EdgeInsets.all(8)),
    );
  }

  /// Configuration for Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColour,
        brightness: Brightness.dark,
      ),
      // scaffoldBackgroundColor: Colors.black,
    );
  }
}
