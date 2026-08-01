import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

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
