import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../favorites.dart';
import '../models.dart';
import '../motion.dart';
import '../theme.dart';
import '../wiki_repository.dart';
import 'article_screen.dart';

class PageTile extends StatelessWidget {
  const PageTile({
    super.key,
    required this.repo,
    required this.page,
    this.showCategory = false,
  });

  final WikiRepository repo;
  final PageRef page;

  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentForSection(page.section);
    final subtitle = showCategory
        ? '${page.section} · ${page.category}'
        : page.snippet;
    final saved = FavoritesScope.of(context).contains(page.slug);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Pressable(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ArticleScreen.open(context, repo, page.slug),
        onLongPress: () {
          FavoritesScope.read(context).toggle(page.slug);
          HapticFeedback.mediumImpact();
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Thumb(image: page.image, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      page.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: showCategory
                              ? accent.withValues(alpha: 0.85)
                              : AppTheme.textFaint,
                          fontWeight:
                              showCategory ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (saved)
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Icon(Icons.bookmark, size: 15, color: AppTheme.gold),
                )
              else
                const Icon(Icons.chevron_right,
                    size: 17, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.accent});

  final String? image;
  final Color accent;

  static const _size = 46.0;

  static const _decodeWidth = 138;

  @override
  Widget build(BuildContext context) {
    if (image == null) return _placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/img/$image',
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        cacheWidth: _decodeWidth,
        errorBuilder: (_, _, _) => _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.article_outlined,
            size: 17, color: accent.withValues(alpha: 0.55)),
      );
}
