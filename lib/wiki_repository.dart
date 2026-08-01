import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

/// Loads the bundled wiki. Everything is offline: the index is read once at
/// startup, article bodies come from sharded files fetched on demand and kept
/// in a small LRU cache so revisiting pages is instant.
class WikiRepository {
  static const _shardCount = 64;
  static const _maxCachedShards = 8;

  final List<Section> sections = [];
  final Map<String, PageRef> pages = {};

  /// Natural pixel size of each bundled image, by filename.
  static final Map<String, (int, int)> imageSizes = {};

  late final List<PageRef> _sortedPages;

  final Map<int, Map<String, dynamic>> _shardCache = {};
  final _inFlight = <int, Future<Map<String, dynamic>>>{};

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> load() async {
    if (_ready) return;
    final raw = await rootBundle.loadString('assets/data/index.json');
    final json = await compute(_decodeIndex, raw);

    for (final s in json['sections'] as List) {
      sections.add(Section.fromJson(s as Map<String, dynamic>));
    }
    final pageMap = json['pages'] as Map<String, dynamic>;
    pageMap.forEach((slug, v) {
      pages[slug] = PageRef.fromJson(slug, v as Map<String, dynamic>);
    });
    final dims = json['dims'];
    if (dims is Map<String, dynamic>) {
      dims.forEach((name, v) {
        if (v is List && v.length == 2) {
          imageSizes[name] = ((v[0] as num).toInt(), (v[1] as num).toInt());
        }
      });
    }
    _sortedPages = pages.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _ready = true;
  }

  static Map<String, dynamic> _decodeIndex(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;

  /// Must match `shard_of` in the bundle builder.
  static int shardOf(String slug) {
    var h = 0;
    for (final c in slug.codeUnits) {
      h = (h * 31 + c) & 0xFFFFFFFF;
    }
    return h % _shardCount;
  }

  Future<Article?> article(String slug) async {
    if (!pages.containsKey(slug)) return null;
    final shard = await _loadShard(shardOf(slug));
    final data = shard[slug];
    if (data is! Map<String, dynamic>) return null;
    return Article.fromJson(slug, data);
  }

  Future<Map<String, dynamic>> _loadShard(int i) {
    final cached = _shardCache.remove(i);
    if (cached != null) {
      _shardCache[i] = cached; // refresh LRU position
      return Future.value(cached);
    }
    final pending = _inFlight[i];
    if (pending != null) return pending;

    final future = _readShard(i);
    _inFlight[i] = future;
    return future.whenComplete(() => _inFlight.remove(i));
  }

  Future<Map<String, dynamic>> _readShard(int i) async {
    final name = 'assets/data/shard_${i.toString().padLeft(2, '0')}.json';
    final raw = await rootBundle.loadString(name);
    final decoded = await compute(_decodeIndex, raw);
    _shardCache[i] = decoded;
    while (_shardCache.length > _maxCachedShards) {
      _shardCache.remove(_shardCache.keys.first);
    }
    return decoded;
  }

  PageRef? ref(String slug) => pages[slug];

  List<PageRef> refsFor(Iterable<String> slugs) =>
      slugs.map((s) => pages[s]).whereType<PageRef>().toList();

  /// Title-first ranked search: exact, prefix, word-start, then substring.
  /// Falls back to snippet text so a query like "poise" still finds something.
  List<PageRef> search(String query, {int limit = 60}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final scored = <(int, PageRef)>[];

    for (final p in _sortedPages) {
      final t = p.searchKey;
      int? score;
      if (t == q) {
        score = 0;
      } else if (t.startsWith(q)) {
        score = 1;
      } else if (_hasWordStart(t, q)) {
        score = 2;
      } else if (t.contains(q)) {
        score = 3;
      } else if (q.length >= 4 && p.snippet.toLowerCase().contains(q)) {
        score = 4;
      }
      if (score != null) scored.add((score, p));
    }

    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      final l = a.$2.title.length.compareTo(b.$2.title.length);
      if (l != 0) return l;
      return a.$2.title.compareTo(b.$2.title);
    });
    return scored.take(limit).map((e) => e.$2).toList();
  }

  static bool _hasWordStart(String haystack, String needle) {
    var i = haystack.indexOf(needle);
    while (i > 0) {
      final prev = haystack.codeUnitAt(i - 1);
      final isBoundary = prev == 0x20 || prev == 0x2D || prev == 0x27;
      if (isBoundary) return true;
      i = haystack.indexOf(needle, i + 1);
    }
    return false;
  }
}
