import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../favorites.dart';
import '../motion.dart';
import '../theme.dart';

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.slug});

  final String slug;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: Motion.medium,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 38),
    TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0), weight: 62),
  ]).animate(CurvedAnimation(parent: _pop, curve: Motion.easeOut));

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _toggle() {
    final store = FavoritesScope.read(context);
    final nowFavorite = store.toggle(widget.slug);
    if (nowFavorite) {
      HapticFeedback.lightImpact();
      if (!Motion.reduced(context)) _pop.forward(from: 0);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = FavoritesScope.of(context).contains(widget.slug);
    return IconButton(
      onPressed: _toggle,
      tooltip: saved ? 'Remove from saved' : 'Save this page',
      icon: ScaleTransition(
        scale: _scale,
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_border,
          color: saved ? AppTheme.gold : AppTheme.textDim,
          size: 22,
        ),
      ),
    );
  }
}
