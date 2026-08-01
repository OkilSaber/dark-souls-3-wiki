import 'package:dark_souls_3_wiki/models.dart';
import 'package:dark_souls_3_wiki/wiki_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shard assignment', () {
    test('matches the Python bundle builder for known slugs', () {
      int expected(String slug) {
        var h = 0;
        for (final c in slug.codeUnits) {
          h = (h * 31 + c) & 0xFFFFFFFF;
        }
        return h % 64;
      }

      for (final slug in [
        'Lothric_Knight_Sword',
        'Firelink_Shrine',
        'Vordt_of_the_Boreal_Valley',
        "Havel's_Ring",
      ]) {
        expect(WikiRepository.shardOf(slug), expected(slug));
      }
    });

    test('is stable and within range', () {
      for (final slug in ['a', 'Weapons', 'Soul_of_Cinder']) {
        final s = WikiRepository.shardOf(slug);
        expect(s, inInclusiveRange(0, 63));
        expect(s, WikiRepository.shardOf(slug));
      }
    });
  });

  group('block parsing', () {
    test('reads a paragraph with an internal link', () {
      final b = Block.fromJson({
        't': 'p',
        's': [
          {'x': 'Zweihander is a '},
          {'x': 'Weapon', 'l': 'Weapons', 'b': 1},
          {'x': ' in Dark Souls.'},
        ],
      });
      expect(b.type, 'p');
      expect(b.spans.length, 3);
      expect(b.spans[1].link, 'Weapons');
      expect(b.spans[1].bold, isTrue);
    });

    test('reads an infobox table with colspans and icons', () {
      final b = Block.fromJson({
        't': 'tbl',
        'info': 1,
        'rows': [
          [
            {
              's': [
                {'x': 'Lothric_Knight_Sword'}
              ],
              'img': ['zwei.png'],
              'cs': 20,
              'h': 1
            },
          ],
          [
            {'s': <Map<String, dynamic>>[], 'img': ['phys.jpg'], 'cs': 5},
            {
              's': [
                {'x': '325'}
              ],
              'cs': 5
            },
          ],
        ],
      });
      expect(b.infobox, isTrue);
      expect(b.rows.length, 2);
      expect(b.rows[0][0].colSpan, 20);
      expect(b.rows[0][0].header, isTrue);
      expect(b.rows[0][0].images, ['zwei.png']);
      expect(b.rows[1][1].text, '325');
      expect(b.rows[1][0].isEmpty, isFalse);
    });

    test('reads a gallery card and a heading level', () {
      final card = Block.fromJson({
        't': 'card',
        'src': 'boss.jpg',
        'x': 'Asylum Demon',
        'l': 'Asylum_Demon'
      });
      expect(card.type, 'card');
      expect(card.link, 'Asylum_Demon');

      final h = Block.fromJson({'t': 'h', 'l': 2, 'x': 'General Information'});
      expect(h.level, 2);
      expect(h.text, 'General Information');
    });

    test('unknown block kinds degrade to a paragraph', () {
      final b = Block.fromJson({
        't': 'weird',
        's': [
          {'x': 'hi'}
        ]
      });
      expect(b.type, 'p');
      expect(b.spans.single.text, 'hi');
    });

    test('missing or malformed fields do not throw', () {
      expect(Block.fromJson({'t': 'p'}).spans, isEmpty);
      expect(Block.fromJson({'t': 'tbl'}).rows, isEmpty);
      expect(Block.fromJson({'t': 'li'}).items, isEmpty);
      expect(Span.listFrom('not a list'), isEmpty);
    });
  });

  group('article and index models', () {
    test('article falls back to a slug-derived title', () {
      final a = Article.fromJson('Some_Page', {'blocks': <dynamic>[]});
      expect(a.title, 'Some Page');
      expect(a.blocks, isEmpty);
    });

    test('page ref exposes a lowercased search key', () {
      final p = PageRef.fromJson("Havel's_Ring",
          {'t': "Havel's Ring", 'c': 'Rings', 's': 'Equipment', 'd': 'A ring'});
      expect(p.searchKey, "havel's ring");
      expect(p.category, 'Rings');
    });

    test('section totals its categories', () {
      final s = Section.fromJson({
        'name': 'Equipment',
        'categories': [
          {
            'name': 'Weapons',
            'count': 165,
            'slugs': ['Lothric_Knight_Sword']
          },
          {'name': 'Rings', 'count': 47, 'slugs': <dynamic>[]},
        ],
      });
      expect(s.pageCount, 212);
      expect(s.categories.first.name, 'Weapons');
    });
  });

  group('bundled data', () {
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test('index loads and articles resolve from their shard', () async {
      final repo = WikiRepository();
      await repo.load();

      expect(repo.isReady, isTrue);
      expect(repo.pages.length, greaterThan(1500));
      expect(repo.sections, isNotEmpty);

      final article = await repo.article('Lothric_Knight_Sword');
      expect(article, isNotNull);
      expect(article!.title, contains('Lothric Knight Sword'));
      expect(article.blocks, isNotEmpty);

      expect(await repo.article('No_Such_Page_Here'), isNull);
    });

    test('search ranks an exact title first', () async {
      final repo = WikiRepository();
      await repo.load();

      final hits = repo.search('zweihander');
      expect(hits, isNotEmpty);
      expect(hits.first.title.toLowerCase(), contains('zweihander'));

      expect(repo.search(''), isEmpty);
      expect(repo.search('   '), isEmpty);
    });

    test('every category slug resolves to a known page', () async {
      final repo = WikiRepository();
      await repo.load();

      final dangling = <String>[];
      for (final s in repo.sections) {
        for (final c in s.categories) {
          for (final slug in c.slugs) {
            if (!repo.pages.containsKey(slug)) dangling.add(slug);
          }
        }
      }
      expect(dangling, isEmpty,
          reason: 'browse lists must not contain dead entries');
    });

    test('no category lists the same title twice', () async {
      final repo = WikiRepository();
      await repo.load();

      final dupes = <String>[];
      for (final s in repo.sections) {
        for (final c in s.categories) {
          final seen = <String>{};
          for (final slug in c.slugs) {
            final t = repo.pages[slug]!.title.trim().toLowerCase();
            if (!seen.add(t)) dupes.add('${s.name}/${c.name}: $t');
          }
        }
      }
      expect(dupes, isEmpty, reason: 'alias pages should be collapsed');
    });

    test('category counts match their slug lists', () async {
      final repo = WikiRepository();
      await repo.load();
      for (final s in repo.sections) {
        for (final c in s.categories) {
          expect(c.count, c.slugs.length, reason: '${s.name}/${c.name}');
        }
      }
    });

    test('articles never link to a page that is not bundled', () async {
      final repo = WikiRepository();
      await repo.load();

      final slugs = repo.pages.keys.take(120);
      for (final slug in slugs) {
        final a = await repo.article(slug);
        if (a == null) continue;
        for (final l in a.links) {
          expect(repo.pages.containsKey(l), isTrue,
              reason: '$slug links to missing $l');
        }
      }
    });
  });
}
