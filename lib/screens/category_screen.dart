import 'package:flutter/material.dart';

import '../models.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../wiki_repository.dart';
import 'article_screen.dart';
import 'page_tile.dart';

/// Alphabetical page list for one category, with an inline filter.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.repo,
    required this.title,
    required this.slugs,
  });

  final WikiRepository repo;
  final String title;
  final List<String> slugs;

  /// Opens a category, short-circuiting to the article when the category holds
  /// exactly one page — a one-row list is a dead end, not a choice.
  static void open(
      BuildContext context, WikiRepository repo, WikiCategory category) {
    if (category.slugs.length == 1) {
      ArticleScreen.open(context, repo, category.slugs.first);
      return;
    }
    Navigator.of(context).push(ArticleRoute(
      builder: (_) => CategoryScreen(
        repo: repo,
        title: category.name,
        slugs: category.slugs,
      ),
    ));
  }

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late final List<PageRef> _all = widget.repo.refsFor(widget.slugs)
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  final _controller = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<PageRef> get _visible {
    if (_filter.isEmpty) return _all;
    final q = _filter.toLowerCase();
    return _all.where((p) => p.searchKey.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _filter = v),
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Filter ${_all.length} pages…',
                prefixIcon:
                    const Icon(Icons.search, size: 19, color: AppTheme.textFaint),
                suffixIcon: _filter.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 17),
                        color: AppTheme.textDim,
                        onPressed: () {
                          _controller.clear();
                          setState(() => _filter = '');
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      body: items.isEmpty
          ? _Empty(query: _filter)
          : ListView.builder(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + kToolbarHeight + 68,
                bottom: 32,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => PageTile(
                repo: widget.repo,
                page: items[i],
              ),
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 34, color: AppTheme.textFaint),
            const SizedBox(height: 12),
            Text(
              'Nothing matches “$query”',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
