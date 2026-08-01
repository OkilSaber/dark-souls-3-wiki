import 'package:flutter/material.dart';

import '../block_renderer.dart';
import '../models.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/favorite_button.dart';
import '../widgets/glass.dart';
import '../wiki_repository.dart';
import 'category_screen.dart';
import 'image_screen.dart';

class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, required this.repo, required this.slug});

  final WikiRepository repo;
  final String slug;

  /// Pushes an article, or tells the user when the target was not scraped.
  static void open(BuildContext context, WikiRepository repo, String slug) {
    if (repo.ref(slug) == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            '“${slug.replaceAll('_', ' ')}” is not in this offline copy',
          ),
          duration: const Duration(seconds: 2),
        ));
      return;
    }
    Navigator.of(context).push(
      ArticleRoute(builder: (_) => ArticleScreen(repo: repo, slug: slug)),
    );
  }

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late final Future<Article?> _future = widget.repo.article(widget.slug);
  late final LinkTapRegistry _links = LinkTapRegistry(_openLink);
  final _scroll = ScrollController();

  /// The bar only names the page once its own title has scrolled away, so the
  /// title is never on screen twice.
  final _showBarTitle = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final show = _scroll.hasClients && _scroll.offset > 76;
    if (show != _showBarTitle.value) _showBarTitle.value = show;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _links.dispose();
    _scroll.dispose();
    _showBarTitle.dispose();
    super.dispose();
  }

  void _openLink(String slug) {
    if (slug == widget.slug) return;
    ArticleScreen.open(context, widget.repo, slug);
  }

  void _openImage(String assetPath, String? caption) {
    Navigator.of(context).push(ZoomRoute(
      builder: (_) => ImageScreen(assetPath: assetPath, caption: caption),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.repo.ref(widget.slug);
    final title = ref?.title ?? widget.slug.replaceAll('_', ' ');
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassBar(
        title: ValueListenableBuilder<bool>(
          valueListenable: _showBarTitle,
          builder: (context, show, _) => AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: Motion.micro,
            curve: Motion.easeOut,
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        actions: [
          FavoriteButton(slug: widget.slug),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<Article?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _Loading();
          }
          final article = snap.data;
          if (article == null) {
            return const Center(
              child: Text('This page has no offline content.',
                  style: TextStyle(color: AppTheme.textDim)),
            );
          }
          return Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                  18, topInset + kToolbarHeight + 18, 18, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ref != null) _Breadcrumb(repo: widget.repo, ref: ref),
                  const SizedBox(height: 10),
                  Text(article.title,
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 16),
                  BlockList(
                    blocks: article.blocks,
                    links: _links,
                    onImage: _openImage,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldDim),
      ),
    );
  }
}

/// Section › category, tinted with the section accent and tappable — it says
/// where you are and doubles as the way back out to siblings.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.repo, required this.ref});

  final WikiRepository repo;
  final PageRef ref;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentForSection(ref.section);
    return Align(
      alignment: Alignment.centerLeft,
      child: Pressable(
        borderRadius: BorderRadius.circular(7),
        onTap: () {
          final section = repo.sections
              .where((s) => s.name == ref.section)
              .firstOrNull;
          final cat = section?.categories
              .where((c) => c.name == ref.category)
              .firstOrNull;
          if (cat != null) CategoryScreen.open(context, repo, cat);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '${ref.section}  ›  ${ref.category}',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
