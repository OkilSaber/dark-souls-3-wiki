import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore extends ChangeNotifier {
  static const _key = 'favorite_slugs';

  final Set<String> _slugs = {};
  SharedPreferences? _prefs;

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

  void pruneMissing(bool Function(String slug) exists) {
    final gone = _order.where((s) => !exists(s)).toList();
    if (gone.isEmpty) return;
    _slugs.removeAll(gone);
    _order.removeWhere(gone.contains);
    notifyListeners();
    _persist();
  }

  void _persist() {
    _prefs?.setStringList(_key, _order);
  }
}

class FavoritesScope extends InheritedNotifier<FavoritesStore> {
  const FavoritesScope({
    super.key,
    required FavoritesStore super.notifier,
    required super.child,
  });

  static final FavoritesStore _detached = FavoritesStore();

  static FavoritesStore _resolve(FavoritesScope? scope) {
    assert(
      scope != null,
      'No FavoritesScope above this widget. It must wrap MaterialApp, not sit '
      'inside home, or pushed routes cannot see it.',
    );
    return scope?.notifier ?? _detached;
  }

  static FavoritesStore of(BuildContext context) =>
      _resolve(context.dependOnInheritedWidgetOfExactType<FavoritesScope>());

  static FavoritesStore read(BuildContext context) =>
      _resolve(context.getInheritedWidgetOfExactType<FavoritesScope>());
}
