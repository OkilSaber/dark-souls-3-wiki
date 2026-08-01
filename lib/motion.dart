import 'dart:async';

import 'package:flutter/material.dart';

class Motion {
  Motion._();

  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  static const drawer = Cubic(0.32, 0.72, 0, 1);

  static const press = Duration(milliseconds: 120);
  static const micro = Duration(milliseconds: 160);
  static const small = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 260);
  static const page = Duration(milliseconds: 300);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration stagger(int index, {int stepMs = 40, int maxMs = 240}) =>
      Duration(milliseconds: (index * stepMs).clamp(0, maxMs));
}

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
    reverseDuration: Motion.micro,
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

class EnterFade extends StatefulWidget {
  const EnterFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 10,
  });

  final Widget child;
  final Duration delay;

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
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}
