import 'package:dark_souls_3_wiki/favorites.dart';
import 'package:dark_souls_3_wiki/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lives in its own file on purpose.
///
/// This is the only test that pumps the real app, which kicks off the index
/// load on a background isolate via `compute`. Fake-async cannot drive that
/// isolate, so it stays pending for the rest of the file and starves any later
/// test that awaits a real `WikiRepository.load()`. One file, one such test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('favorites scope wraps MaterialApp, above the Navigator',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DarkSoulsWikiApp());
    await tester.pump();

    // Regression: the scope used to sit inside `MaterialApp.home`. Pushed
    // routes mount under the Navigator, which is above `home`, so search,
    // category and article screens all threw on lookup.
    final navigator = find.byType(Navigator);
    expect(navigator, findsWidgets);
    expect(
      find.ancestor(of: navigator.first, matching: find.byType(FavoritesScope)),
      findsOneWidget,
      reason: 'pushed routes lose the scope unless it wraps MaterialApp',
    );

    // Let the real index load finish rather than leaving an isolate running
    // past the end of the test.
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
