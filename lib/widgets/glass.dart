import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Translucent chrome that content scrolls underneath.
///
/// The blur is what makes the bar read as a material sitting above the page
/// rather than an opaque strip cut out of it. Where the OS asks for reduced
/// transparency we fall back to a solid fill, since legibility wins.
class GlassBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassBar({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.titleSpacing,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final double? titleSpacing;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final opaque = MediaQuery.maybeHighContrastOf(context) ?? false;
    return ClipRect(
      child: BackdropFilter(
        filter: opaque
            ? ImageFilter.blur()
            : ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: opaque ? AppTheme.surface : AppTheme.glass,
            border: const Border(
              bottom: BorderSide(color: AppTheme.borderSoft),
            ),
          ),
          child: AppBar(
            title: title,
            leading: leading,
            actions: actions,
            bottom: bottom,
            titleSpacing: titleSpacing,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

/// A short gradient at the top of a scroll view, so content dissolves into the
/// chrome instead of sliding under a hard line.
class ScrollEdgeFade extends StatelessWidget {
  const ScrollEdgeFade({super.key, this.height = 20});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.bg, Color(0x000E0D0C)],
          ),
        ),
      ),
    );
  }
}

/// Small uppercase label used to head a group of rows.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
