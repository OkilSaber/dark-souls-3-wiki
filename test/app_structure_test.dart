import 'package:dark_souls_3_wiki/favorites.dart';
import 'package:dark_souls_3_wiki/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('favorites scope wraps MaterialApp, above the Navigator',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DarkSoulsWikiApp());
    await tester.pump();

    final navigator = find.byType(Navigator);
    expect(navigator, findsWidgets);
    expect(
      find.ancestor(of: navigator.first, matching: find.byType(FavoritesScope)),
      findsOneWidget,
      reason: 'pushed routes lose the scope unless it wraps MaterialApp',
    );

    await tester.runAsync(() async {
      for (var i = 0; i < 60; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (tester.binding.rootElement != null) tester.binding.scheduleFrame();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
            find.byType(Navigator).evaluate().isNotEmpty) {
          break;
        }
      }
    });
    await tester.pump();
  });
}
