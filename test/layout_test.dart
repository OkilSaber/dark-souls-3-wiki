import 'package:dark_souls_3_wiki/block_renderer.dart';
import 'package:dark_souls_3_wiki/models.dart';
import 'package:dark_souls_3_wiki/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<Block> blocks) async {
    final links = LinkTapRegistry((_) {});
    addTearDown(links.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlockList(blocks: blocks, links: links, onImage: (_, _) {}),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('paragraph renders visible text', (tester) async {
    await pump(tester, [
      Block(type: 'p', spans: const [Span('Zweihander is a weapon.')]),
    ]);
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(BlockList));
    expect(size.height, greaterThan(0));
  });

  testWidgets('infobox table has non-zero height', (tester) async {
    await pump(tester, [
      const Block(
        type: 'tbl',
        infobox: true,
        rows: [
          [
            Cell(
                spans: [Span('Zweihander +15')],
                images: [],
                header: true,
                colSpan: 20,
                rowSpan: 1),
          ],
          [
            Cell(
                spans: [Span('325')], images: [], header: false, colSpan: 5, rowSpan: 1),
            Cell(
                spans: [Span('100')], images: [], header: false, colSpan: 5, rowSpan: 1),
          ],
        ],
      ),
    ]);
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(BlockList));
    expect(size.height, greaterThan(10), reason: 'infobox collapsed to nothing');
  });

  testWidgets('wide data table has non-zero height', (tester) async {
    await pump(tester, [
      const Block(
        type: 'tbl',
        rows: [
          [
            Cell(spans: [Span('Name')], images: [], header: true, colSpan: 1, rowSpan: 1),
            Cell(spans: [Span('Atk')], images: [], header: true, colSpan: 1, rowSpan: 1),
          ],
          [
            Cell(spans: [Span('Regular')], images: [], header: false, colSpan: 1, rowSpan: 1),
            Cell(spans: [Span('130')], images: [], header: false, colSpan: 1, rowSpan: 1),
          ],
        ],
      ),
    ]);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BlockList)).height, greaterThan(10));
  });

  testWidgets('list, quote and heading all render', (tester) async {
    await pump(tester, [
      const Block(type: 'h', level: 2, text: 'General Information'),
      const Block(type: 'q', spans: [Span('One of the gigantic swords.')]),
      const Block(
        type: 'li',
        items: [
          ListItem(spans: [Span('Found in the Graveyard.')], images: []),
          ListItem(spans: [Span('Requires 24 strength.')], images: []),
        ],
      ),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.text('General Information'), findsOneWidget);
    expect(tester.getSize(find.byType(BlockList)).height, greaterThan(30));
  });
}
