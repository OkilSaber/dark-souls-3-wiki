import 'package:dark_souls_3_wiki/favorites.dart';
import 'package:dark_souls_3_wiki/screens/home_screen.dart';
import 'package:dark_souls_3_wiki/theme.dart';
import 'package:dark_souls_3_wiki/wiki_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('favorites store', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('starts empty and reports toggles', () async {
      final store = FavoritesStore();
      await store.load();
      expect(store.isEmpty, isTrue);

      expect(store.toggle('Lothric_Knight_Sword'), isTrue, reason: 'now saved');
      expect(store.contains('Lothric_Knight_Sword'), isTrue);
      expect(store.count, 1);

      expect(store.toggle('Lothric_Knight_Sword'), isFalse, reason: 'now unsaved');
      expect(store.contains('Lothric_Knight_Sword'), isFalse);
      expect(store.isEmpty, isTrue);
    });

    test('survives a restart', () async {
      final first = FavoritesStore();
      await first.load();
      first.toggle('Lothric_Knight_Sword');
      first.toggle('Vordt_of_the_Boreal_Valley');

      final second = FavoritesStore();
      await second.load();
      expect(second.contains('Lothric_Knight_Sword'), isTrue);
      expect(second.contains('Vordt_of_the_Boreal_Valley'), isTrue);
      expect(second.count, 2);
    });

    test('lists most recently saved first', () async {
      final store = FavoritesStore();
      await store.load();
      store.toggle('Estus_Flask');
      store.toggle('Lothric_Knight_Sword');
      expect(store.slugs, ['Lothric_Knight_Sword', 'Estus_Flask']);
    });

    test('drops slugs that are no longer bundled', () async {
      final store = FavoritesStore();
      await store.load();
      store.toggle('Lothric_Knight_Sword');
      store.toggle('Some_Renamed_Page');

      store.pruneMissing((slug) => slug == 'Lothric_Knight_Sword');
      expect(store.slugs, ['Lothric_Knight_Sword']);

      final reloaded = FavoritesStore();
      await reloaded.load();
      expect(reloaded.slugs, ['Lothric_Knight_Sword'],
          reason: 'the prune is persisted, not just in memory');
    });

    test('notifies listeners on change', () async {
      final store = FavoritesStore();
      await store.load();
      var notifications = 0;
      store.addListener(() => notifications++);

      store.toggle('Lothric_Knight_Sword');
      store.toggle('Lothric_Knight_Sword');
      expect(notifications, 2);
    });
  });

  group('favorites scope placement', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('resolves from inside a pushed route', (tester) async {
      final store = FavoritesStore();
      await store.load();
      store.toggle('Lothric_Knight_Sword');

      await tester.pumpWidget(FavoritesScope(
        notifier: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (inner) => Text(
                    FavoritesScope.of(inner).contains('Lothric_Knight_Sword')
                        ? 'saved'
                        : 'not saved',
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('saved'), findsOneWidget);
    });
  });

  group('home screen layout', () {
    late WikiRepository repo;

    setUpAll(() async {
      repo = WikiRepository();
      await repo.load();
    });

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('section cards survive large text and narrow screens',
        (tester) async {
      final store = FavoritesStore();
      await store.load();

      for (final width in [320.0, 411.0, 720.0]) {
        for (final scale in [1.0, 1.3, 1.8, 2.2]) {
          tester.view.physicalSize = Size(width * 3, 2400);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(FavoritesScope(
            notifier: store,
            child: MaterialApp(
              theme: AppTheme.build(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: HomeScreen(repo: repo),
              ),
            ),
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));

          expect(tester.takeException(), isNull,
              reason: 'width $width at text scale $scale overflowed');
        }
      }
    });
  });
}
