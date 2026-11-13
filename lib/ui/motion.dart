import 'package:flutter/material.dart';

/// The app's motion: soft and fluid, never bouncy or fast enough to pull
/// attention. Every animation uses these values, so the feel is the same
/// everywhere and easy to tune in one place.
///
/// When the system asks for less motion (Windows: Settings, Accessibility,
/// Visual effects, "Animation effects" off), every duration becomes zero.
abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 340);
  static const slow = Duration(milliseconds: 620);

  /// Starts quickly and settles slowly, like a liquid coming to rest.
  static const soft = Cubic(0.22, 1, 0.36, 1);

  /// Like [soft] with a very small overshoot, for things that fill or grow
  /// (a ring being ticked, a check mark).
  static const settle = Cubic(0.34, 1.3, 0.64, 1);

  /// True when the system asks for less motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when the system asks for less motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Fades its child in and lets it rise a few pixels into place the first
/// time it is shown. New items in a list arrive this way.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.rise = 10});

  final Widget child;

  /// How far, in pixels, the child rises while it fades in.
  final double rise;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Motion.soft,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    final duration = Motion.of(context, Motion.base);
    if (duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.duration = duration;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.rise),
            child: child,
          ),
        );
      },
    );
  }
}

/// Cross-fades from one child to the next when the child's key changes;
/// the new child rises softly into place. Used for page and panel changes.
class SoftSwitcher extends StatelessWidget {
  const SoftSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.base),
      reverseDuration: Motion.of(context, Motion.fast),
      switchInCurve: Motion.soft,
      switchOutCurve: Curves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Makes its child react softly to the pointer: it shrinks a little while
/// pressed and springs back when released.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.enabled && down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.985 : 1,
        duration: Motion.of(context, _down ? Motion.fast : Motion.base),
        curve: _down ? Curves.easeOut : Motion.settle,
        child: widget.child,
      ),
    );
  }
}
