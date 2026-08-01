import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'motion.dart';
import 'theme.dart';
import 'wiki_repository.dart';

/// Owns the tap recognizers for a screen's link spans.
///
/// `TextSpan.recognizer` needs a long-lived object that must be disposed, so
/// recognizers are vended per slug here and torn down with the hosting State.
class LinkTapRegistry {
  LinkTapRegistry(this.onLink);

  final void Function(String slug) onLink;
  final Map<String, TapGestureRecognizer> _bySlug = {};

  TapGestureRecognizer of(String slug) => _bySlug.putIfAbsent(
        slug,
        () => TapGestureRecognizer()..onTap = () => onLink(slug),
      );

  void dispose() {
    for (final r in _bySlug.values) {
      r.dispose();
    }
    _bySlug.clear();
  }
}

/// Renders parsed wiki blocks. `onLink` receives an internal page slug.
class BlockList extends StatelessWidget {
  const BlockList({
    super.key,
    required this.blocks,
    required this.links,
    required this.onImage,
  });

  final List<Block> blocks;
  final LinkTapRegistry links;
  final void Function(String assetPath, String? caption) onImage;

  void Function(String) get onLink => links.onLink;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      // Gallery cards come in runs; lay a whole run out as one grid.
      if (b.type == 'card') {
        final run = <Block>[];
        while (i < blocks.length && blocks[i].type == 'card') {
          run.add(blocks[i]);
          i++;
        }
        i--;
        children.add(_CardGrid(cards: run, links: links));
        continue;
      }
      final w = _build(context, b);
      if (w != null) children.add(w);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget? _build(BuildContext context, Block b) {
    switch (b.type) {
      case 'h':
        return _Heading(block: b, links: links);
      case 'p':
        return _Paragraph(spans: b.spans, links: links);
      case 'q':
        return _Quote(spans: b.spans, links: links);
      case 'li':
        return _BulletList(block: b, links: links);
      case 'tbl':
        return _TableBlock(block: b, links: links);
      case 'img':
        return _Figure(src: b.src!, caption: b.alt, onImage: onImage);
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------- inline text

List<InlineSpan> _inline(
  BuildContext context,
  List<Span> spans,
  LinkTapRegistry links, {
  TextStyle? base,
}) {
  final style = base ?? Theme.of(context).textTheme.bodyMedium!;
  return spans.map<InlineSpan>((s) {
    var st = style;
    if (s.bold) st = st.copyWith(fontWeight: FontWeight.w700);
    if (s.italic) st = st.copyWith(fontStyle: FontStyle.italic);
    if (s.link != null) {
      return TextSpan(
        text: s.text,
        style: st.copyWith(
          color: AppTheme.link,
          // An underline on every wiki link turns dense pages into noise;
          // the warm hue carries it, and the whole run is the tap target.
          decoration: TextDecoration.none,
        ),
        recognizer: links.of(s.link!),
      );
    }
    return TextSpan(text: s.text, style: st);
  }).toList();
}

// ---------------------------------------------------------------- blocks

/// Top-level headings get a hairline rule; deeper ones rely on weight and
/// space alone, so the page has one clear level of division rather than three.
class _Heading extends StatelessWidget {
  const _Heading({required this.block, required this.links});
  final Block block;
  final LinkTapRegistry links;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final major = block.level <= 2;
    final style = switch (block.level) {
      1 || 2 => t.titleLarge!,
      3 => t.titleMedium!,
      _ => t.titleSmall!,
    };

    final label = block.spans.isEmpty
        ? Text(block.text, style: style)
        : Text.rich(
            TextSpan(children: _inline(context, block.spans, links, base: style)),
          );

    return Padding(
      padding: EdgeInsets.only(top: major ? 28 : 20, bottom: major ? 12 : 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          if (major) ...[
            const SizedBox(height: 9),
            Container(height: 1, color: AppTheme.border),
          ],
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.spans, required this.links});
  final List<Span> spans;
  final LinkTapRegistry links;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text.rich(TextSpan(children: _inline(context, spans, links))),
    );
  }
}

/// Flavour text — in this game that is almost always an item description, so
/// it is set like one: serif, italic, warm, held off the left margin.
class _Quote extends StatelessWidget {
  const _Quote({required this.spans, required this.links});
  final List<Span> spans;
  final LinkTapRegistry links;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontFamily: AppTheme.displayFamily,
          fontStyle: FontStyle.italic,
          fontSize: 14.5,
          height: 1.6,
          color: AppTheme.textDim,
        );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(left: BorderSide(color: AppTheme.goldDim, width: 2)),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text.rich(
        TextSpan(children: _inline(context, spans, links, base: base)),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.block, required this.links});
  final Block block;
  final LinkTapRegistry links;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < block.items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: block.ordered
                        ? Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              '${i + 1}.',
                              style: const TextStyle(
                                color: AppTheme.goldDim,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        // A small dot rather than a bullet glyph: it aligns
                        // predictably across font fallbacks.
                        : const Padding(
                            padding: EdgeInsets.only(top: 9, left: 3),
                            child: SizedBox(
                              width: 4,
                              height: 4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppTheme.goldDim,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (block.items[i].spans.isNotEmpty)
                          Text.rich(
                            TextSpan(
                              children:
                                  _inline(context, block.items[i].spans, links),
                            ),
                          ),
                        if (block.items[i].images.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: block.items[i].images
                                  .map((s) => _InlineIcon(src: s))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.src, this.caption, required this.onImage});
  final String src;
  final String? caption;
  final void Function(String, String?) onImage;

  @override
  Widget build(BuildContext context) {
    final hasCaption = caption != null && caption!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Pressable(
            scale: 0.985,
            borderRadius: BorderRadius.circular(10),
            onTap: () => onImage('assets/img/$src', caption),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSoft),
                ),
                child: Image.asset(
                  'assets/img/$src',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          if (hasCaption)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                caption!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// An image inside a table cell or list item.
///
/// The same slot holds both 20px stat icons and full item/boss portraits, so
/// the natural size decides how large to draw it — otherwise portraits get
/// squashed down to icon height.
class _InlineIcon extends StatelessWidget {
  const _InlineIcon({required this.src});
  final String src;

  static const _iconHeight = 22.0;
  static const _portraitMaxHeight = 130.0;
  static const _portraitThreshold = 56;

  @override
  Widget build(BuildContext context) {
    final size = WikiRepository.imageSizes[src];
    final isPortrait = size != null &&
        (size.$1 > _portraitThreshold || size.$2 > _portraitThreshold);

    final image = Image.asset(
      'assets/img/$src',
      height: isPortrait ? null : _iconHeight,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    if (!isPortrait) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _portraitMaxHeight),
        child: image,
      ),
    );
  }
}

// ---------------------------------------------------------------- tables

class _TableBlock extends StatelessWidget {
  const _TableBlock({required this.block, required this.links});
  final Block block;
  final LinkTapRegistry links;

  static const _minColWidth = 92.0;

  @override
  Widget build(BuildContext context) {
    if (block.rows.isEmpty) return const SizedBox.shrink();

    // Infoboxes are laid out with colspan weights and fit the screen width.
    // Data tables get fixed-width columns and scroll sideways.
    if (block.infobox) {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(children: _rows(context, flexible: true)),
        ),
      );
    }

    final maxUnits = block.rows
        .map((r) => r.fold<int>(0, (s, c) => s + c.colSpan))
        .fold<int>(1, (a, b) => a > b ? a : b);
    final width = maxUnits * _minColWidth;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final table = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(children: _rows(context, flexible: false)),
              ),
            );
            // Only hint at sideways scrolling when there is actually more
            // table than screen.
            if (width <= constraints.maxWidth) return table;
            return Stack(
              children: [
                table,
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 26,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [AppTheme.bg, Color(0x000E0D0C)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context, {required bool flexible}) {
    final out = <Widget>[];
    for (var r = 0; r < block.rows.length; r++) {
      final row = block.rows[r];
      if (row.every((c) => c.isEmpty)) continue;
      final isHeader = row.every((c) => c.header) && row.isNotEmpty;
      out.add(DecoratedBox(
        decoration: BoxDecoration(
          color: isHeader
              ? AppTheme.tableHeader
              : (r.isOdd ? AppTheme.surfaceAlt2 : Colors.transparent),
          border: r == block.rows.length - 1
              ? null
              : const Border(bottom: BorderSide(color: AppTheme.borderSoft)),
        ),
        // Not `stretch`: inside a scrolling Column the row height is unbounded,
        // and stretching children against it forces an infinite constraint.
        // The row background comes from the DecoratedBox above regardless.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final cell in row)
              flexible
                  ? Expanded(
                      flex: cell.colSpan,
                      child: _cell(context, cell, isHeader),
                    )
                  : SizedBox(
                      width: cell.colSpan * _minColWidth,
                      child: _cell(context, cell, isHeader),
                    ),
          ],
        ),
      ));
    }
    return out;
  }

  Widget _cell(BuildContext context, Cell cell, bool headerRow) {
    final bold = cell.header || headerRow;
    final base = Theme.of(context).textTheme.bodySmall!.copyWith(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: bold ? AppTheme.gold : AppTheme.text,
          letterSpacing: bold ? 0.2 : 0.1,
          height: 1.35,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (cell.images.isNotEmpty)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: cell.images.map((s) => _InlineIcon(src: s)).toList(),
            ),
          if (cell.spans.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: cell.images.isEmpty ? 0 : 5),
              child: Text.rich(
                TextSpan(
                  children: _inline(context, cell.spans, links, base: base),
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- card grid

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.cards, required this.links});
  final List<Block> cards;
  final LinkTapRegistry links;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth > 520 ? 3 : 2;
          const gap = 10.0;
          final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: cards
                .map((c) => SizedBox(
                      width: w,
                      child: _Card(block: c, links: links),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.block, required this.links});
  final Block block;
  final LinkTapRegistry links;

  @override
  Widget build(BuildContext context) {
    final tappable = block.link != null;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.asset(
                'assets/img/${block.src}',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppTheme.surfaceAlt2,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: AppTheme.textFaint, size: 18),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 9, 8, 10),
              child: Text(
                block.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: tappable ? AppTheme.link : AppTheme.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!tappable) return card;
    return Pressable(
      scale: 0.975,
      borderRadius: BorderRadius.circular(12),
      onTap: () => links.onLink(block.link!),
      child: card,
    );
  }
}
