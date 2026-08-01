library;

class Span {
  final String text;
  final String? link;
  final bool bold;
  final bool italic;

  const Span(this.text, {this.link, this.bold = false, this.italic = false});

  factory Span.fromJson(Map<String, dynamic> j) => Span(
        j['x'] as String? ?? '',
        link: j['l'] as String?,
        bold: j['b'] == 1,
        italic: j['i'] == 1,
      );

  static List<Span> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Span.fromJson)
        .toList(growable: false);
  }
}

class Cell {
  final List<Span> spans;
  final List<String> images;
  final bool header;
  final int colSpan;
  final int rowSpan;

  const Cell({
    required this.spans,
    required this.images,
    required this.header,
    required this.colSpan,
    required this.rowSpan,
  });

  factory Cell.fromJson(Map<String, dynamic> j) => Cell(
        spans: Span.listFrom(j['s']),
        images: (j['img'] as List?)?.whereType<String>().toList() ?? const [],
        header: j['h'] == 1,
        colSpan: (j['cs'] as int?) ?? 1,
        rowSpan: (j['rs'] as int?) ?? 1,
      );

  String get text => spans.map((s) => s.text).join().trim();
  bool get isEmpty => text.isEmpty && images.isEmpty;
}

class ListItem {
  final List<Span> spans;
  final List<String> images;

  const ListItem({required this.spans, required this.images});

  factory ListItem.fromJson(Map<String, dynamic> j) => ListItem(
        spans: Span.listFrom(j['s']),
        images: (j['img'] as List?)?.whereType<String>().toList() ?? const [],
      );
}

class Block {
  final String type;
  final int level;
  final String text;
  final String? alt;
  final String? src;
  final String? link;
  final bool ordered;
  final bool infobox;
  final List<Span> spans;
  final List<ListItem> items;
  final List<List<Cell>> rows;

  const Block({
    required this.type,
    this.level = 0,
    this.text = '',
    this.alt,
    this.src,
    this.link,
    this.ordered = false,
    this.infobox = false,
    this.spans = const [],
    this.items = const [],
    this.rows = const [],
  });

  factory Block.fromJson(Map<String, dynamic> j) {
    final t = j['t'] as String? ?? 'p';
    switch (t) {
      case 'h':
        return Block(
          type: t,
          level: (j['l'] as int?) ?? 3,
          text: j['x'] as String? ?? '',
          spans: Span.listFrom(j['s']),
        );
      case 'p':
      case 'q':
        return Block(type: t, spans: Span.listFrom(j['s']));
      case 'li':
        return Block(
          type: t,
          ordered: j['o'] == 1,
          items: (j['items'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(ListItem.fromJson)
              .toList(),
        );
      case 'tbl':
        return Block(
          type: t,
          infobox: j['info'] == 1,
          rows: (j['rows'] as List? ?? const [])
              .whereType<List>()
              .map((r) => r
                  .whereType<Map<String, dynamic>>()
                  .map(Cell.fromJson)
                  .toList())
              .toList(),
        );
      case 'img':
        return Block(type: t, src: j['src'] as String?, alt: j['alt'] as String?);
      case 'card':
        return Block(
          type: t,
          src: j['src'] as String?,
          text: j['x'] as String? ?? '',
          link: j['l'] as String?,
        );
      default:
        return Block(type: 'p', spans: Span.listFrom(j['s']));
    }
  }
}

class Article {
  final String slug;
  final String title;
  final List<Block> blocks;
  final List<String> links;

  const Article({
    required this.slug,
    required this.title,
    required this.blocks,
    required this.links,
  });

  factory Article.fromJson(String slug, Map<String, dynamic> j) => Article(
        slug: slug,
        title: j['title'] as String? ?? slug.replaceAll('_', ' '),
        blocks: (j['blocks'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Block.fromJson)
            .toList(),
        links: (j['links'] as List?)?.whereType<String>().toList() ?? const [],
      );
}

class PageRef {
  final String slug;
  final String title;
  final String category;
  final String section;
  final String snippet;
  final String? image;
  final String searchKey;

  PageRef({
    required this.slug,
    required this.title,
    required this.category,
    required this.section,
    required this.snippet,
    this.image,
  }) : searchKey = title.toLowerCase();

  factory PageRef.fromJson(String slug, Map<String, dynamic> j) => PageRef(
        slug: slug,
        title: j['t'] as String? ?? slug.replaceAll('_', ' '),
        category: j['c'] as String? ?? 'Misc',
        section: j['s'] as String? ?? 'Lore',
        snippet: j['d'] as String? ?? '',
        image: j['i'] as String?,
      );
}

class WikiCategory {
  final String name;
  final int count;
  final List<String> slugs;

  const WikiCategory({required this.name, required this.count, required this.slugs});

  factory WikiCategory.fromJson(Map<String, dynamic> j) => WikiCategory(
        name: j['name'] as String? ?? '?',
        count: (j['count'] as int?) ?? 0,
        slugs: (j['slugs'] as List?)?.whereType<String>().toList() ?? const [],
      );
}

class Section {
  final String name;
  final List<WikiCategory> categories;

  const Section({required this.name, required this.categories});

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        name: j['name'] as String? ?? '?',
        categories: (j['categories'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WikiCategory.fromJson)
            .toList(),
      );

  int get pageCount =>
      categories.fold(0, (sum, c) => sum + c.count);
}
