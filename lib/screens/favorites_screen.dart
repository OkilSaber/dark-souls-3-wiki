import 'package:flutter/material.dart';

import '../favorites.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../wiki_repository.dart';
import 'page_tile.dart';

/// Saved pages, most recently saved first.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.repo});

  final WikiRepository repo;

  @override
  Widget build(BuildContext context) {
    final store = FavoritesScope.of(context);
    final items = repo.refsFor(store.slugs);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassBar(
        title: const Text('Saved'),
        actions: [
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _Empty()
          : ListView.builder(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                bottom: 32,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => PageTile(
                repo: repo,
                page: items[i],
                showCategory: true,
              ),
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border,
                size: 34, color: AppTheme.textFaint),
            const SizedBox(height: 14),
            Text(
              'Nothing saved yet.\nTap the bookmark on a page, or hold any row\nin a list, to keep it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
