import 'package:dark_souls_3_wiki/block_renderer.dart';
import 'package:dark_souls_3_wiki/favorites.dart';
import 'package:dark_souls_3_wiki/screens/article_screen.dart';
import 'package:dark_souls_3_wiki/theme.dart';
import 'package:dark_souls_3_wiki/wiki_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WikiRepository repo;
  late FavoritesStore favorites;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    repo = WikiRepository();
    await repo.load();
    favorites = FavoritesStore();
  });

  Future<void> pumpArticle(WidgetTester tester, String slug) async {
    await tester.runAsync(() => repo.article(slug));
    await tester.pumpWidget(FavoritesScope(
      notifier: favorites,
      child: MaterialApp(
        theme: AppTheme.build(),
        home: ArticleScreen(repo: repo, slug: slug),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  void sizeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders a weapon page with an infobox and data tables',
      (tester) async {
    sizeScreen(tester);
    await pumpArticle(tester, 'Lothric_Knight_Sword');

    expect(tester.takeException(), isNull);
    expect(find.byType(BlockList), findsOneWidget);
    expect(tester.getSize(find.byType(BlockList)).height, greaterThan(200));
  });

  testWidgets('renders a boss, a location and gallery index pages',
      (tester) async {
    sizeScreen(tester);
    for (final slug in [
      'Vordt_of_the_Boreal_Valley',
      'Firelink_Shrine',
      'Bosses',
      'Rings',
      'Weapons',
    ]) {
      await pumpArticle(tester, slug);
      expect(tester.takeException(), isNull, reason: 'while rendering $slug');
      expect(tester.getSize(find.byType(BlockList)).height, greaterThan(100),
          reason: '$slug rendered empty');
    }
  });

  testWidgets('a wide sample of pages renders without layout errors',
      (tester) async {
    sizeScreen(tester);
    final failures = <String>[];
    for (final slug in repo.pages.keys.take(60)) {
      await pumpArticle(tester, slug);
      final err = tester.takeException();
      if (err != null) failures.add('$slug -> $err');
    }
    expect(failures, isEmpty);
  });
}
