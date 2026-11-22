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

  // The paper-coloured panels and what sits on them. They follow the light
  // or dark theme (as in the Sleep log app); the dark shell around them
  // stays dark in both.
  static Palette _palette = Palette.light;

  /// True while the dark theme is on.
  static bool get isDark => identical(_palette, Palette.dark);

  /// Switches every paper colour to the light or dark theme. The app is
  /// then built again from the top.
  static void useDark(bool dark) =>
      _palette = dark ? Palette.dark : Palette.light;

  static Color get paper => _palette.paper;
  static Color get tile => _palette.tile;
  static Color get line => _palette.line;
  static Color get neutral => _palette.neutral;
  static Color get ring => _palette.ring;

  /// A raised surface on paper: a chosen segment, a card, a menu. White in
  /// the light theme.
  static Color get surface => _palette.surface;
  static Color get ink => _palette.ink;
  static Color get ink2 => _palette.ink2;
  static Color get ink3 => _palette.ink3;

  /// Text or an icon on an [ink] fill (a dark button in light, a light one
  /// in dark).
  static Color get onInk => _palette.onInk;

  /// Pure white, in both themes: text on orange, on the shell, on red.
  static const white = Color(0xFFFFFFFF);

  /// Orange means "now": the current item, today, something overdue. It is
  /// never used for decoration.
  static const now = Color(0xFFFF5A1F);
  static Color get nowTint => _palette.nowTint;
  static Color get nowSoft => _palette.nowSoft;
  static Color get nowInk => _palette.nowInk;

  static const green = Color(0xFF23A35A);
  static const amber = Color(0xFFE0A400);
  static Color get amberInk => _palette.amberInk;

  // Soft status fills and their text (dark values from the Sleep log app).
  static Color _pick(int light, int dark) => Color(isDark ? dark : light);
  static Color get goodBg => _pick(0xFFE3F5E9, 0xFF16331F);
  static Color get goodInk => _pick(0xFF23804A, 0xFF6FD394);
  static Color get warnBg => _pick(0xFFFBF0D5, 0xFF3A2E10);
  static Color get badBg => _pick(0xFFFDE8E8, 0xFF3D1A1C);
  static Color get badInk => _pick(0xFFC8242F, 0xFFFF8A8F);
  static Color get blueBg => _pick(0xFFE4EDFD, 0xFF1A2740);
  static Color get blueInk => _pick(0xFF1F4FB8, 0xFF8DB0F5);
  static Color get violetBg => _pick(0xFFEEE7FD, 0xFF2A2140);
  static Color get violetInk => _pick(0xFF6C43D0, 0xFFB9A2F2);

  /// Today's column on the calendar: a faint warm tint.
  static Color get todayTint => _pick(0xFFFBF6F2, 0xFF262220);

  /// Quiet grey marks: a missed day, a past line.
  static Color get mark => _pick(0xFFD5D3CC, 0xFF46464A);

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

  // Getters, so they follow the theme.
  static TextStyle get h1 =>
      text(38, 46, weight: 700, letterSpacing: -0.025, color: ink);
  static TextStyle get h1Small =>
      text(28, 34, weight: 700, letterSpacing: -0.02, color: ink);
  static TextStyle get h2 => text(15, 18, weight: 600, color: ink);
  static TextStyle get h3 => text(13, 16, weight: 600, color: ink);
  static TextStyle get item => text(13, 16);
  static TextStyle get body => text(13, 19, weight: 400);
  static TextStyle get date => text(13, 16, weight: 400, color: ink3);
  static TextStyle get meta => text(12, 15, weight: 400, color: ink2);
  static TextStyle get caption => text(11, 13, color: ink3);
  static TextStyle get stat => text(24, 29, weight: 700, letterSpacing: -0.02);

  static ThemeData theme() {
    final dark = isDark;
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: ink,
        onPrimary: onInk,
        surface: paper,
        onSurface: ink,
        surfaceContainerHighest: tile,
        surfaceContainerHigh: tile,
        surfaceContainer: surface,
        surfaceContainerLow: paper,
        onSurfaceVariant: ink2,
        outline: line,
        outlineVariant: line,
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
          borderSide: BorderSide(color: ink, width: 1.5),
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
          side: BorderSide(color: line),
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
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: ink),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: text(13, 16, weight: 400, color: ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? surface : ink,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: text(12, 15, color: dark ? ink : onInk),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        headerForegroundColor: ink,
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onInk : ink,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : null,
        ),
        todayForegroundColor: WidgetStatePropertyAll(nowInk),
        todayBorder: BorderSide(color: nowInk),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text(13, 16, weight: 400, color: ink),
        menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(surface)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : null,
        ),
        checkColor: WidgetStatePropertyAll(onInk),
        side: BorderSide(color: ring, width: 1.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onInk : ink3,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : tile,
        ),
        trackOutlineColor: WidgetStatePropertyAll(line),
      ),
      iconTheme: IconThemeData(color: ink2),
    );
  }
}

/// The paper-side colours of one theme. The light values come from the
/// Ember design, the dark ones from the Sleep log app's dark theme.
class Palette {
  const Palette({
    required this.paper,
    required this.tile,
    required this.line,
    required this.neutral,
    required this.ring,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.onInk,
    required this.nowTint,
    required this.nowSoft,
    required this.nowInk,
    required this.amberInk,
  });

  final Color paper;
  final Color tile;
  final Color line;
  final Color neutral;
  final Color ring;
  final Color surface;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color onInk;
  final Color nowTint;
  final Color nowSoft;
  final Color nowInk;
  final Color amberInk;

  static const light = Palette(
    paper: Color(0xFFFBFAF7),
    tile: Color(0xFFF3F2EE),
    line: Color(0xFFE9E7E1),
    neutral: Color(0xFFEDEBE5),
    ring: Color(0xFFC9C6BE),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF111111),
    ink2: Color(0xFF77746E),
    ink3: Color(0xFFA8A59E),
    onInk: Color(0xFFFFFFFF),
    nowTint: Color(0xFFFFF1EB),
    nowSoft: Color(0xFFFFE9E0),
    nowInk: Color(0xFFD5430F),
    amberInk: Color(0xFF9A6A00),
  );

  static const dark = Palette(
    paper: Color(0xFF1E1E20),
    tile: Color(0xFF262628),
    line: Color(0xFF333336),
    neutral: Color(0xFF2E2E31),
    ring: Color(0xFF4A4A4E),
    surface: Color(0xFF3A3A3D),
    ink: Color(0xFFF5F5F4),
    ink2: Color(0xFF9A9A9E),
    ink3: Color(0xFF6A6A6E),
    onInk: Color(0xFF111111),
    nowTint: Color(0xFF3A2116),
    nowSoft: Color(0xFF4A2618),
    nowInk: Color(0xFFFF8A5C),
    amberInk: Color(0xFFF2C230),
  );
}

/// The three shades of one named colour: a strong dot, a soft fill and the
/// text colour that is readable on the soft fill.
class Swatch {
  const Swatch(this.dot, this.soft, this.text);

  final Color dot;
  final Color soft;
  final Color text;

  /// This colour in the current theme: in the dark theme the soft fill is
  /// a dark tint of the colour and the text a lighter shade of it.
  Swatch get themed {
    if (!Ember.isDark) return this;
    return Swatch(
      dot,
      Color.alphaBlend(dot.withValues(alpha: 0.22), Palette.dark.paper),
      Color.lerp(dot, Ember.white, 0.4)!,
    );
  }
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

  static Swatch of(String? name) => (all[name] ?? all[fallback]!).themed;
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

  static Swatch of(String? name) => (all[name] ?? all[fallback]!).themed;

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

  static Swatch of(String? name) => (all[name] ?? all[fallback]!).themed;

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
