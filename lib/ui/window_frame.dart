import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart' show calcWindowPosition;
import 'package:window_manager/window_manager.dart';

import 'ember.dart';

/// True on Windows, where Orbito hides the system title bar and draws its
/// own: the dark top bar moves the window and holds the window buttons
/// (like Notion Calendar). Off in tests, which have no real window.
final bool customWindowFrame =
    !kIsWeb &&
    Platform.isWindows &&
    !Platform.environment.containsKey('FLUTTER_TEST');

/// The app's window, or null where Orbito keeps the system frame.
Window? get _window =>
    customWindowFrame ? WindowManager.instance.getCurrent() : null;

/// The smallest the full app window can be.
const _appMinimumSize = Size(960, 600);

/// Hides the system title bar. Called once at start-up.
void setUpWindow() {
  final window = _window;
  if (window == null) return;
  window.titleBarStyle = TitleBarStyle.hidden;
  window.minimumSize = _appMinimumSize.toNative();
  window.title = 'Orbito';
}

/// Puts the window in full screen or takes it out. Does nothing in tests
/// or where Orbito keeps the system frame.
void setWindowFullScreen(bool on) {
  final window = _window;
  if (window == null) return;
  if (window.isFullScreen != on) window.isFullScreen = on;
}

/// The size of the mini focus window.
const miniWindowSize = Size(320, 76);

/// The gap between the mini window and the screen's corner.
const _miniWindowMargin = 16.0;

/// Where the window was, and whether it was maximised, before it became the
/// mini window, so it can go back.
Rect? _boundsBeforeMini;
var _maximizedBeforeMini = false;

/// Shrinks the app window into the small mini focus window: it sits in the
/// bottom-right corner of the screen, above every other app. Does nothing
/// in tests or where Orbito keeps the system frame.
Future<void> enterMiniWindow() async {
  final window = _window;
  if (window == null) return;
  final fullScreen = window.isFullScreen;
  if (fullScreen) window.isFullScreen = false;
  _maximizedBeforeMini = window.isMaximized;
  if (_maximizedBeforeMini) window.unmaximize();
  // Leaving full screen or maximised takes Windows a moment; wait, so the
  // saved place is the normal window and not the whole screen.
  if (fullScreen || _maximizedBeforeMini) {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  _boundsBeforeMini = window.bounds.toRect();
  final corner = await calcWindowPosition(
    miniWindowSize,
    Alignment.bottomRight,
  );
  window.minimumSize = miniWindowSize.toNative();
  window.isResizable = false;
  window.isMaximizable = false;
  window.bounds =
      (corner - const Offset(_miniWindowMargin, _miniWindowMargin) &
              miniWindowSize)
          .toNative();
  window.isAlwaysOnTop = true;
}

/// Turns the mini window back into the full app window, where it was
/// before. Does nothing in tests or where Orbito keeps the system frame.
void leaveMiniWindow() {
  final window = _window;
  if (window == null) return;
  window.isAlwaysOnTop = false;
  window.isResizable = true;
  window.isMaximizable = true;
  window.minimumSize = _appMinimumSize.toNative();
  if (_boundsBeforeMini case final bounds?) window.bounds = bounds.toNative();
  if (_maximizedBeforeMini) window.maximize();
  _boundsBeforeMini = null;
  _maximizedBeforeMini = false;
}

/// Makes [child] move the mini window when dragged. Unlike
/// [WindowDragArea], a double click does nothing, so the mini window never
/// fills the screen by accident.
class MiniWindowDragArea extends StatelessWidget {
  const MiniWindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!customWindowFrame) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _window?.startDragging(),
      child: child,
    );
  }
}

/// Makes [child] move the window when dragged, and maximise or restore it
/// on a double click. Buttons inside still work as before.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      customWindowFrame ? DragToMoveArea(child: child) : child;
}

/// Minimise, maximise (or restore) and close, for the dark top bar.
class WindowButtons extends StatefulWidget {
  const WindowButtons({super.key});

  @override
  State<WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<WindowButtons> {
  var _maximized = false;
  ListenerId? _listener;

  @override
  void initState() {
    super.initState();
    final window = _window;
    if (window == null) return;
    _maximized = window.isMaximized;
    _listener = window.addListener((event) {
      if (!mounted) return;
      switch (event) {
        case WindowMaximizedEvent():
          setState(() => _maximized = true);
        case WindowRestoredEvent() || WindowResizedEvent():
          setState(() => _maximized = window.isMaximized);
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    if (_listener case final id?) _window?.removeListener(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final window = _window;
    if (window == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          tooltip: 'Minimise',
          icon: Icons.remove,
          onPressed: window.minimize,
        ),
        _WindowButton(
          tooltip: _maximized ? 'Restore' : 'Maximise',
          icon: _maximized ? Icons.filter_none : Icons.crop_square,
          iconSize: _maximized ? 13 : 15,
          onPressed: () {
            _maximized ? window.unmaximize() : window.maximize();
            setState(() => _maximized = !_maximized);
          },
        ),
        _WindowButton(
          tooltip: 'Close',
          icon: Icons.close,
          close: true,
          onPressed: window.close,
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconSize = 16,
    this.close = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;
  final bool close;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final background = !_hover
        ? Colors.transparent
        : widget.close
        ? const Color(0xFFE81123)
        : Ember.raised;
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 44,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _hover && widget.close ? Ember.white : Ember.onShell2,
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin dark strip with the window buttons, for screens without the app's
/// top bar (sign-in, set-up). It moves the window when dragged.
class WindowStrip extends StatelessWidget {
  const WindowStrip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!customWindowFrame) return child;
    return ColoredBox(
      color: Ember.shell,
      child: Column(
        children: [
          WindowDragArea(
            child: Container(
              height: 40,
              padding: const EdgeInsets.only(right: 6, top: 3),
              alignment: Alignment.centerRight,
              child: const WindowButtons(),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
