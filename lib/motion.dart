import 'dart:async';

import 'package:flutter/material.dart';

/// Motion vocabulary for the app.
///
/// Two rules drive everything here:
///   * feedback starts on pointer-*down*, never on release;
///   * every animation is driven by a controller so it can be grabbed,
///     reversed and re-targeted mid-flight instead of playing to completion.
///
/// Durations stay under 300ms for anything the user triggers directly — a
/// 180ms transition reads as more responsive than a 400ms one even though the
/// work is identical.
class Motion {
  Motion._();

  /// Strong ease-out. Entering elements and anything that should feel like it
  /// answers instantly: the movement is mostly over before the eye settles.
  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Strong ease-in-out, for things repositioning on screen rather than
  /// arriving or leaving.
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// The iOS sheet/drawer curve. Long tail, no overshoot.
  static const drawer = Cubic(0.32, 0.72, 0, 1);

  // ease-in is deliberately absent: it delays the first frames, which are
  // exactly the ones the user is watching.

  static const press = Duration(milliseconds: 120);
  static const micro = Duration(milliseconds: 160);
  static const small = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 260);
  static const page = Duration(milliseconds: 300);

  /// Honour the OS "remove animations" switch. Reduced motion means gentler,
  /// non-vestibular feedback — opacity instead of travel — not dead UI.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Stagger delay for the nth item of a list that animates in as a group.
  /// Capped so a long list never makes the tail feel like it is loading.
  static Duration stagger(int index, {int stepMs = 40, int maxMs = 240}) =>
      Duration(milliseconds: (index * stepMs).clamp(0, maxMs));
}

/// A tap target that acknowledges the press the instant the finger lands.
///
/// The scale is driven by an [AnimationController] rather than an implicit
/// animation so that a quick tap — down and up inside one frame budget —
/// still reverses smoothly from wherever the shrink had got to.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.borderRadius,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Kept subtle. Below ~0.95 a list row reads as collapsing rather than
  /// responding.
  final double scale;
  final BorderRadius? borderRadius;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.press,
    reverseDuration: Motion.micro, // release a touch slower than the press
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) => _c.forward();
  void _up([_]) => _c.reverse();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    if (!enabled) return widget.child;

    final reduced = Motion.reduced(context);

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: reduced ? null : _down,
      onTapUp: reduced ? null : _up,
      onTapCancel: reduced ? null : _up,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: reduced
          ? widget.child
          : AnimatedBuilder(
              animation: _c,
              child: widget.child,
              builder: (context, child) {
                final t = Curves.easeOut.transform(_c.value);
                return Transform.scale(
                  scale: 1 - (1 - widget.scale) * t,
                  filterQuality: FilterQuality.low,
                  child: child,
                );
              },
            ),
    );
  }
}

/// Fades and lifts a child into place once, with an optional stagger delay.
///
/// Entrance only — it never blocks interaction, and under reduced motion the
/// travel is dropped and only the fade remains.
class EnterFade extends StatefulWidget {
  const EnterFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 10,
  });

  final Widget child;
  final Duration delay;

  /// Vertical travel in logical pixels. Small on purpose: a long slide draws
  /// attention to the animation instead of the content.
  final double offset;

  @override
  State<EnterFade> createState() => _EnterFadeState();
}

class _EnterFadeState extends State<EnterFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.medium,
  );

  /// Held so a row scrolled away before its stagger elapses does not leave a
  /// timer running against a disposed State.
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _delay = Timer(widget.delay, _c.forward);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    final curved = CurvedAnimation(parent: _c, curve: Motion.easeOut);
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Drill-down transition: the incoming screen slides in from the trailing edge
/// while the outgoing one is pushed back and dimmed, so the hierarchy reads
/// spatially. Popping runs the same path in reverse.
class ArticleRoute<T> extends PageRoute<T> {
  ArticleRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => Motion.page;

  @override
  Duration get reverseTransitionDuration => Motion.medium;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (Motion.reduced(context)) {
      return FadeTransition(opacity: animation, child: child);
    }

    final enter = CurvedAnimation(
      parent: animation,
      curve: Motion.drawer,
      reverseCurve: Motion.drawer.flipped,
    );
    // The screen being covered recedes instead of sitting still, which is what
    // makes the new screen read as "on top of" rather than "instead of".
    final recede = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Motion.drawer,
      reverseCurve: Motion.drawer.flipped,
    );

    return AnimatedBuilder(
      animation: recede,
      child: child,
      builder: (context, child) {
        final back = recede.value;
        return Transform.translate(
          offset: Offset(-40 * back, 0),
          child: Transform.scale(
            scale: 1 - 0.04 * back,
            child: AnimatedBuilder(
              animation: enter,
              child: child,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  MediaQuery.sizeOf(context).width * (1 - enter.value),
                  0,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Modal-ish transition for a full-screen viewer: scales up from near-size and
/// fades, then leaves along the same path.
class ZoomRoute<T> extends PageRoute<T> {
  ZoomRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => Motion.medium;

  @override
  Duration get reverseTransitionDuration => Motion.small;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (Motion.reduced(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.easeOut,
      reverseCurve: Motion.easeOut.flipped,
    );
    return FadeTransition(
      opacity: curved,
      // Starts at 0.94, never 0 — nothing in the physical world grows out of
      // nothing, and a from-zero scale reads as a pop rather than an arrival.
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}
