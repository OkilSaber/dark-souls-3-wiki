import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's saved pages, persisted across launches.
///
/// The set is held in memory so reads are synchronous — every list row asks
/// whether it is favourited during build, and awaiting storage there would
/// make scrolling stutter. Writes are fire-and-forget: the in-memory set is
/// the source of truth for the session, and storage catches up.
class FavoritesStore extends ChangeNotifier {
  static const _key = 'favorite_slugs';

  final Set<String> _slugs = {};
  SharedPreferences? _prefs;

  /// Insertion order is not preserved by a Set, so ordering is kept
  /// separately: most recently added first, which is what a saved list wants.
  final List<String> _order = [];

  List<String> get slugs => List.unmodifiable(_order);
  int get count => _order.length;
  bool get isEmpty => _order.isEmpty;

  bool contains(String slug) => _slugs.contains(slug);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getStringList(_key) ?? const [];
    _slugs
      ..clear()
      ..addAll(stored);
    _order
      ..clear()
      ..addAll(stored);
    notifyListeners();
  }

  /// Returns the state the page is now in, so callers can phrase feedback
  /// without re-querying.
  bool toggle(String slug) {
    final nowFavorite = !_slugs.contains(slug);
    if (nowFavorite) {
      _slugs.add(slug);
      _order.insert(0, slug);
    } else {
      _slugs.remove(slug);
      _order.remove(slug);
    }
    notifyListeners();
    _persist();
    return nowFavorite;
  }

  /// Drops any saved slug that is no longer in the bundle, so a re-scrape that
  /// renames pages cannot leave unopenable rows behind.
  void pruneMissing(bool Function(String slug) exists) {
    final gone = _order.where((s) => !exists(s)).toList();
    if (gone.isEmpty) return;
    _slugs.removeAll(gone);
    _order.removeWhere(gone.contains);
    notifyListeners();
    _persist();
  }

  void _persist() {
    // Nothing awaits this: the write is small and losing the last toggle to a
    // hard kill is a better trade than blocking the tap.
    _prefs?.setStringList(_key, _order);
  }
}

/// Makes the store reachable from any screen without threading it through
/// every constructor. Widgets that display favourite state use [of] so they
/// rebuild on change; callbacks that only toggle use [read].
class FavoritesScope extends InheritedNotifier<FavoritesStore> {
  const FavoritesScope({
    super.key,
    required FavoritesStore super.notifier,
    required super.child,
  });

  static FavoritesStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FavoritesScope>()!.notifier!;

  static FavoritesStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FavoritesScope>()!.notifier!;
}
