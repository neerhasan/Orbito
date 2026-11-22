import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../ui/ember.dart';

/// The light or dark theme, as in the Sleep log app: the paper panels turn
/// dark, the dark shell stays as it is. The choice is kept on this device
/// only (founder's choice), in a small file next to the app's data.
class DarkMode extends Notifier<bool> {
  @override
  bool build() => Ember.isDark;

  void set(bool dark) {
    Ember.useDark(dark);
    state = dark;
    unawaited(saveThemeChoice(dark));
  }

  void toggle() => set(!state);
}

final darkModeProvider = NotifierProvider<DarkMode, bool>(DarkMode.new);

Future<File> _themeFile() async =>
    File('${(await getApplicationSupportDirectory()).path}/theme.txt');

/// True when this device last chose the dark theme.
Future<bool> loadThemeChoice() async {
  try {
    final file = await _themeFile();
    if (!await file.exists()) return false;
    return (await file.readAsString()).trim() == 'dark';
  } on Object {
    return false; // No saved choice: light.
  }
}

/// Remembers the theme on this device. A failure only means the choice is
/// not kept for the next start.
Future<void> saveThemeChoice(bool dark) async {
  try {
    await (await _themeFile()).writeAsString(dark ? 'dark' : 'light');
  } on Object {
    // Not kept; the app still switches.
  }
}
