import 'package:flutter/material.dart';

import '../favorites.dart';
import '../models.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../wiki_repository.dart';
import 'article_screen.dart';
import 'category_screen.dart';
import 'favorites_screen.dart';
import 'search_screen.dart';
import 'section_screen.dart';

/// Browse entry point.
///
/// Two routes into the wiki sit above the fold: search, and a row of shortcuts
/// to the handful of categories people actually come here for. The section
/// grid underneath is the exhaustive path, not the primary one.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.repo});

  final WikiRepository repo;

  /// Shortcut targets, in the order a player is likely to want them. Names are
  /// matched against the real category list so a rename in the scraper drops
  /// the chip rather than producing a dead one.
  static const _quickPicks = [
    'Bosses',
    'Straight Swords',
    'Greatswords',
    'Armor Sets',
    'Rings',
    'Weapon Skills',
    'Sorceries',
    'Miracles',
    'Pyromancies',
    'Enemies',
    'NPCs',
    'Locations',
    'Consumables',
  ];

  List<(Section, WikiCategory)> get _quick {
    final byName = <String, (Section, WikiCategory)>{};
    for (final s in repo.sections) {
      for (final c in s.categories) {
        byName.putIfAbsent(c.name, () => (s, c));
      }
    }
    return [
      for (final name in _quickPicks) ?byName[name],
    ];
  }

  /// Card height: icon, two lines of label, padding — then whatever extra the
  /// user's font scale asks for.
  static double _cardHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return 112 + (scale - 1).clamp(0, 1.4) * 52;
  }

  @override
  Widget build(BuildContext context) {
    final quick = _quick;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Masthead(total: repo.pages.length)),
          SliverToBoxAdapter(child: _SearchField(repo: repo)),
          if (quick.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionLabel('Jump to')),
            SliverToBoxAdapter(child: _QuickRow(repo: repo, picks: quick)),
          ],
          const SliverToBoxAdapter(child: SectionLabel('Browse')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid(
              // Height is stated outright and grows with the user's text size
              // setting. A fixed aspect ratio would clip the labels as soon as
              // the system font scales up.
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: _cardHeight(context),
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: repo.sections.length,
                (context, i) => EnterFade(
                  delay: Motion.stagger(i, stepMs: 35),
                  child: _SectionCard(
                    repo: repo,
                    section: repo.sections[i],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top + 28, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: AppTheme.ember, size: 20),
              const SizedBox(width: 8),
              // Tracked-out capitals get wide fast under a large text scale;
              // let the label give way rather than push past the margin.
              Flexible(
                child: Text('BONFIRE LIT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppTheme.goldDim)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Dark Souls III',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 2),
          Text(
            '$total pages, fully offline',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.repo});
  final WikiRepository repo;

  @override
  Widget build(BuildContext context) {
    final savedCount = FavoritesScope.of(context).count;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context)
                  .push(ArticleRoute(builder: (_) => SearchScreen(repo: repo))),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 20, color: AppTheme.textDim),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text('Search weapons, bosses, items…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppTheme.textFaint, fontSize: 14.5)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SavedButton(repo: repo, count: savedCount),
        ],
      ),
    );
  }
}

/// Entry to the saved list. Shows its count so the shortcut advertises that it
/// has something in it, rather than looking like an empty bookmark icon.
class _SavedButton extends StatelessWidget {
  const _SavedButton({required this.repo, required this.count});

  final WikiRepository repo;
  final int count;

  @override
  Widget build(BuildContext context) {
    final has = count > 0;
    return Pressable(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context)
          .push(ArticleRoute(builder: (_) => FavoritesScreen(repo: repo))),
      child: Container(
        height: 52,
        constraints: const BoxConstraints(minWidth: 52),
        padding: EdgeInsets.symmetric(horizontal: has ? 13 : 15),
        decoration: BoxDecoration(
          color: has
              ? AppTheme.gold.withValues(alpha: 0.12)
              : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: has
                ? AppTheme.gold.withValues(alpha: 0.32)
                : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              has ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
              color: has ? AppTheme.gold : AppTheme.textDim,
            ),
            if (has) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal shortcut rail. Scrolls rather than wrapping so it stays one
/// predictable line however many picks survive the name match.
class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.repo, required this.picks});

  final WikiRepository repo;
  final List<(Section, WikiCategory)> picks;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: 40 + (scale - 1).clamp(0, 1.4) * 22,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: picks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (section, cat) = picks[i];
          final accent = AppTheme.accentForSection(section.name);
          return EnterFade(
            delay: Motion.stagger(i, stepMs: 25, maxMs: 180),
            offset: 0,
            child: Pressable(
              borderRadius: BorderRadius.circular(20),
              onTap: () => CategoryScreen.open(context, repo, cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Row(
                  children: [
                    Text(
                      cat.name,
                      style: TextStyle(
                        color: accent,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${cat.count}',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.repo, required this.section});

  final WikiRepository repo;
  final Section section;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentForSection(section.name);
    return Pressable(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        ArticleRoute(builder: (_) => SectionScreen(repo: repo, section: section)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(AppTheme.iconForSection(section.name),
                  size: 18, color: accent),
            ),
            const Spacer(),
            Text(
              section.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${section.pageCount} pages · ${section.categories.length} lists',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 11.5, color: AppTheme.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared "open this article" helper so every entry point behaves the same.
void openArticle(BuildContext context, WikiRepository repo, String slug) =>
    ArticleScreen.open(context, repo, slug);
