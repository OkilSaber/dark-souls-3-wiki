import 'package:dark_souls_3_wiki/block_renderer.dart';
import 'package:dark_souls_3_wiki/models.dart';
import 'package:dark_souls_3_wiki/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const available = 400.0;

  Future<void> pumpTable(WidgetTester tester, Block table) async {
    final links = LinkTapRegistry((_) {});
    addTearDown(links.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
        body: SizedBox(
          width: available,
          child: SingleChildScrollView(
            child: BlockList(
              blocks: [table],
              links: links,
              onImage: (_, _) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  List<double> cellWidths(WidgetTester tester) => tester
      .widgetList<SizedBox>(find.descendant(
          of: find.byType(BlockList), matching: find.byType(SizedBox)))
      .map((b) => b.width)
      .whereType<double>()
      .toList();

  Cell cell(String text, {int cs = 1, bool header = false}) => Cell(
        spans: [Span(text)],
        images: const [],
        header: header,
        colSpan: cs,
        rowSpan: 1,
      );

  testWidgets('a single-column table spans the available width', (tester) async {
    final table = Block(type: 'tbl', rows: [
      [cell('Area Bosses')],
      [cell('Asylum Demon - Bell Gargoyle - Capra Demon - Centipede Demon')],
    ]);

    await pumpTable(tester, table);

    expect(cellWidths(tester).first, greaterThan(available - 40),
        reason: 'a one-column table used to be pinned to a 92px cell, '
            'leaving the content in a narrow strip with dead space beside it');
  });

  testWidgets('a row shorter than the widest one still fills the width',
      (tester) async {
    final table = Block(type: 'tbl', rows: [
      [cell('Header', cs: 6, header: true)],
      [cell('a'), cell('b'), cell('c'), cell('d'), cell('e'), cell('f')],
      [cell('spans one, should stretch')],
    ]);

    await pumpTable(tester, table);

    final totals = [
      for (final row in find.byType(Row).evaluate())
        tester
            .widgetList<SizedBox>(find.descendant(
                of: find.byWidget(row.widget), matching: find.byType(SizedBox)))
            .map((b) => b.width)
            .whereType<double>()
            .fold<double>(0, (a, b) => a + b),
    ].where((t) => t > 0).toList();

    expect(totals, hasLength(3));
    for (final t in totals.skip(1)) {
      expect(t, closeTo(totals.first, 1),
          reason: 'a row whose colspans fall short must stretch to match, '
              'not leave a gap at the end');
    }
  });
}
