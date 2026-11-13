import 'package:flutter/material.dart';

/// The Ember design values: colours, text styles and the app theme.
/// They come from `docs/design/source/ember.css` and the prototype.
abstract final class Ember {
  // The dark shell around the panels.
  static const shell = Color(0xFF0F0F10);
  static const raised = Color(0xFF1E1E20);
  static const active = Color(0xFF262628);
  static const shellLine = Color(0xFF2A2A2C);
  static const chart = Color(0xFF141415);

  // Text on the dark shell.
  static const onShell = Color(0xFFF5F5F4);
  static const onShell2 = Color(0xFF9A9A9E);
  static const onShell3 = Color(0xFF6A6A6E);

  // The paper-coloured panels and what sits on them.
  static const paper = Color(0xFFFBFAF7);
  static const tile = Color(0xFFF3F2EE);
  static const line = Color(0xFFE9E7E1);
  static const neutral = Color(0xFFEDEBE5);
  static const ring = Color(0xFFC9C6BE);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);
  static const ink2 = Color(0xFF77746E);
  static const ink3 = Color(0xFFA8A59E);

  /// Orange means "now": the current item, today, something overdue. It is
  /// never used for decoration.
  static const now = Color(0xFFFF5A1F);
  static const nowTint = Color(0xFFFFF1EB);
  static const nowSoft = Color(0xFFFFE9E0);
  static const nowInk = Color(0xFFD5430F);

  static const green = Color(0xFF23A35A);
  static const amber = Color(0xFFE0A400);
  static const amberInk = Color(0xFF9A6A00);

  static const fontFamily = 'Inter';

  /// A text style in Inter. The weight is set twice because Inter is a
  /// variable font: `fontVariations` picks the weight inside the font file.
  static TextStyle text(
    double size,
    double height, {
    int weight = 500,
    Color? color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: height / size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation.weight(weight.toDouble())],
      letterSpacing: letterSpacing * size,
      color: color,
    );
  }

  static final h1 = text(38, 46, weight: 700, letterSpacing: -0.025);
  static final h1Small = text(28, 34, weight: 700, letterSpacing: -0.02);
  static final h2 = text(15, 18, weight: 600);
  static final h3 = text(13, 16, weight: 600);
  static final item = text(13, 16);
  static final body = text(13, 19, weight: 400);
  static final date = text(13, 16, weight: 400, color: ink3);
  static final meta = text(12, 15, weight: 400, color: ink2);
  static final caption = text(11, 13, color: ink3);
  static final stat = text(24, 29, weight: 700, letterSpacing: -0.02);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        brightness: Brightness.light,
        primary: ink,
        onPrimary: white,
        surface: paper,
        onSurface: ink,
        error: nowInk,
      ),
      scaffoldBackgroundColor: shell,
    );
    final radius8 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyLarge: text(13, 16, weight: 400, color: ink),
        bodyMedium: text(13, 19, weight: 400, color: ink),
        bodySmall: meta,
        labelLarge: text(12, 15),
        titleMedium: text(13, 16, weight: 400, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tile,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        hintStyle: text(13, 16, weight: 400, color: ink2),
        labelStyle: text(13, 16, weight: 400, color: ink2),
        floatingLabelStyle: text(13, 16, color: ink2),
        errorStyle: text(12, 15, weight: 400, color: nowInk),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ink, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: white,
          disabledBackgroundColor: neutral,
          disabledForegroundColor: ink3,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: radius8,
          textStyle: text(12, 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: white,
          side: const BorderSide(color: line),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: radius8,
          textStyle: text(12, 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink2,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: radius8,
          textStyle: text(12, 15),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: text(13, 16, color: white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: text(15, 18, weight: 600, color: ink),
        contentTextStyle: text(13, 19, weight: 400, color: ink),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: ink),
    );
  }
}

/// The three shades of one named colour: a strong dot, a soft fill and the
/// text colour that is readable on the soft fill.
class Swatch {
  const Swatch(this.dot, this.soft, this.text);

  final Color dot;
  final Color soft;
  final Color text;
}

/// The colours a life area may have. The name is what is saved.
abstract final class AreaColors {
  static const fallback = 'grey';

  static const all = <String, Swatch>{
    'green': Swatch(Color(0xFF23A35A), Color(0xFFE3F5E9), Color(0xFF23804A)),
    'blue': Swatch(Color(0xFF2B62D9), Color(0xFFE4EDFD), Color(0xFF2B62D9)),
    'amber': Swatch(Color(0xFFE0A400), Color(0xFFFBF0D5), Color(0xFF9A6A00)),
    'pink': Swatch(Color(0xFFC65BD6), Color(0xFFF7E6FA), Color(0xFF9B3AAB)),
    'violet': Swatch(Color(0xFF6C43D0), Color(0xFFEEE7FD), Color(0xFF6C43D0)),
    'grey': Swatch(Color(0xFFA8A59E), Color(0xFFEDEBE5), Color(0xFF77746E)),
  };

  static Swatch of(String? name) => all[name] ?? all[fallback]!;
}

/// The colours a project may have. Orange is left out on purpose, because
/// orange means "now". The name is what is saved.
abstract final class ProjectColors {
  static const fallback = 'slate';

  static const all = <String, Swatch>{
    'blue': Swatch(Color(0xFF2B62D9), Color(0xFFE4EDFD), Color(0xFF2B62D9)),
    'green': Swatch(Color(0xFF23A35A), Color(0xFFE3F5E9), Color(0xFF23804A)),
    'violet': Swatch(Color(0xFF6C43D0), Color(0xFFEEE7FD), Color(0xFF6C43D0)),
    'amber': Swatch(Color(0xFFE0A400), Color(0xFFFBF0D5), Color(0xFF9A6A00)),
    'pink': Swatch(Color(0xFFC65BD6), Color(0xFFF7E6FA), Color(0xFF9B3AAB)),
    'teal': Swatch(Color(0xFF1F8A8A), Color(0xFFDFF3F2), Color(0xFF16706F)),
    'brown': Swatch(Color(0xFFA0612F), Color(0xFFF6E9DD), Color(0xFF87501F)),
    'slate': Swatch(Color(0xFF5B6573), Color(0xFFE8EAEE), Color(0xFF4A5361)),
  };

  static Swatch of(String? name) => all[name] ?? all[fallback]!;

  /// The first colour no other project uses yet, so new projects differ.
  static String firstUnused(Iterable<String> used) {
    final taken = used.toSet();
    return all.keys.firstWhere(
      (name) => !taken.contains(name),
      orElse: () => 'blue',
    );
  }
}

/// The colours a goal may have: the project colours, so orange is left out
/// (orange means "now"). The name is what is saved.
abstract final class GoalColors {
  static const fallback = 'blue';

  static const all = ProjectColors.all;

  static Swatch of(String? name) => all[name] ?? all[fallback]!;

  /// The first colour no other goal uses yet, so new goals differ.
  static String firstUnused(Iterable<String?> used) {
    final taken = used.toSet();
    return all.keys.firstWhere(
      (name) => !taken.contains(name),
      orElse: () => fallback,
    );
  }
}

/// The icons a project, goal or life area may have. The name is what is
/// saved.
abstract final class ItemIcons {
  static const fallback = 'folder';

  /// The icon a goal shows when the user picked none.
  static const goalFallback = 'flag';

  static const all = <String, IconData>{
    'folder': Icons.folder_outlined,
    'work': Icons.work_outline,
    'code': Icons.code,
    'book': Icons.menu_book_outlined,
    'school': Icons.school_outlined,
    'idea': Icons.lightbulb_outline,
    'fitness': Icons.fitness_center,
    'heart': Icons.favorite_border,
    'home': Icons.home_outlined,
    'people': Icons.groups_outlined,
    'money': Icons.savings_outlined,
    'shop': Icons.shopping_bag_outlined,
    'travel': Icons.flight_outlined,
    'music': Icons.music_note_outlined,
    'art': Icons.palette_outlined,
    'star': Icons.star_border,
    'flag': Icons.flag_outlined,
  };

  /// The icon with this name; [orElse] when the name is empty or unknown.
  static IconData of(String? name, {String orElse = fallback}) =>
      all[name] ?? all[orElse]!;
}

/// Makes the first letter a capital: `blue` becomes `Blue`.
String capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
