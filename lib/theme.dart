import 'package:flutter/material.dart';

/// Visual language: cold ash and firelight.
///
/// Greys carry a warm undertone rather than being neutral, so the gold accent
/// reads as light falling on the surface instead of a sticker placed on top.
/// Type is sized as a set — size, weight, tracking and leading move together,
/// because a single letter-spacing value is always wrong at some size.
class AppTheme {
  AppTheme._();

  // ---- surfaces, darkest first ------------------------------------------
  static const bg = Color(0xFF0E0D0C);
  static const surface = Color(0xFF161513);
  static const surfaceAlt = Color(0xFF1D1B19);
  static const surfaceAlt2 = Color(0xFF252220);
  static const surfaceHigh = Color(0xFF2C2825);

  /// Chrome that content scrolls beneath. Semi-transparent by design — it is
  /// blurred at the point of use so the page shows through as a material.
  static const glass = Color(0xE014120F);

  static const border = Color(0xFF322D28);
  static const borderSoft = Color(0xFF241F1B);

  // ---- ink ---------------------------------------------------------------
  static const text = Color(0xFFEDE7DD);
  static const textDim = Color(0xFF9C938A);
  static const textFaint = Color(0xFF6E665E);

  // ---- accents -----------------------------------------------------------
  static const gold = Color(0xFFD9B45F);
  static const goldDim = Color(0xFF8A7239);
  static const ember = Color(0xFFE07A3C);

  /// Links sit in the same warm family as the gold headings but lighter, so
  /// they read as interactive without introducing a second, colder hue.
  static const link = Color(0xFFE8C579);

  static const tableHeader = Color(0xFF2A2318);

  /// A serif for display text. Android resolves this to Noto Serif, which
  /// suits a wiki about a game whose own UI is book-like — and costs nothing
  /// to ship since it is already on the device.
  static const displayFamily = 'serif';

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        surface: bg,
        primary: gold,
        secondary: ember,
        onPrimary: Colors.black,
        outline: border,
      ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: -0.2,
        ),
      ),
      dividerColor: border,
      dividerTheme: const DividerThemeData(
        color: borderSoft,
        thickness: 1,
        space: 1,
      ),
      cardColor: surfaceAlt,
      listTileTheme: const ListTileThemeData(iconColor: gold, textColor: text),
      textTheme: base.textTheme
          .apply(bodyColor: text, displayColor: text)
          .copyWith(
            // Display: large text needs negative tracking — letters drift
            // apart as they grow — and tight leading.
            displaySmall: const TextStyle(
              fontFamily: displayFamily,
              fontSize: 30,
              height: 1.12,
              letterSpacing: -0.6,
              fontWeight: FontWeight.w600,
              color: text,
            ),
            titleLarge: const TextStyle(
              fontFamily: displayFamily,
              fontSize: 21,
              height: 1.22,
              letterSpacing: -0.3,
              fontWeight: FontWeight.w600,
              color: gold,
            ),
            titleMedium: const TextStyle(
              fontSize: 16.5,
              height: 1.3,
              letterSpacing: -0.1,
              fontWeight: FontWeight.w700,
              color: gold,
            ),
            titleSmall: const TextStyle(
              fontSize: 14.5,
              height: 1.35,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
              color: text,
            ),
            // Body: tracking at zero, leading loose enough to read a wall of
            // wiki prose without losing the line.
            bodyLarge: const TextStyle(fontSize: 16, height: 1.55, color: text),
            bodyMedium:
                const TextStyle(fontSize: 15, height: 1.55, color: text),
            // Small text gets a touch of positive tracking to stay legible.
            bodySmall: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              letterSpacing: 0.15,
              color: textDim,
            ),
            labelSmall: const TextStyle(
              fontSize: 10.5,
              height: 1.2,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: textFaint,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        hintStyle: const TextStyle(color: textFaint, fontSize: 14.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: goldDim),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: text, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Sections are colour-coded so a glance at any screen answers "where am I".
  /// Hues are muted to a common saturation so they read as one family.
  static Color accentForSection(String name) => switch (name) {
        'Weapons' => const Color(0xFFC98F6E),
        'Equipment' => const Color(0xFF7FA6C9),
        'Magic' => const Color(0xFF9E86D4),
        'Items' => const Color(0xFF6FB49A),
        'World' => const Color(0xFFD9954F),
        'Character' => const Color(0xFFD1798A),
        'Builds' => const Color(0xFF5FAFB8),
        'Guides' => const Color(0xFF8DB36B),
        'Lore' => const Color(0xFFB08CA8),
        'General' => const Color(0xFF9A9088),
        'Online' => const Color(0xFF7E93CE),
        'Misc' => const Color(0xFF8E8A94),
        _ => gold,
      };

  static IconData iconForSection(String name) => switch (name) {
        'Weapons' => Icons.gavel_outlined,
        'Equipment' => Icons.shield_outlined,
        'Magic' => Icons.auto_awesome_outlined,
        'Items' => Icons.inventory_2_outlined,
        'World' => Icons.map_outlined,
        'Character' => Icons.person_outline,
        'Builds' => Icons.construction_outlined,
        'Guides' => Icons.menu_book_outlined,
        'Lore' => Icons.history_edu_outlined,
        'General' => Icons.info_outline,
        'Online' => Icons.people_outline,
        'Misc' => Icons.more_horiz,
        _ => Icons.folder_outlined,
      };
}
