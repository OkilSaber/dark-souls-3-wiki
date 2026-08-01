<div align="center">

<img src="icon/icon_1024.png" width="120" alt="Dark Souls 3 Wiki app icon">

# Dark Souls III Wiki — Offline

An Android app holding a complete offline copy of the
[Fextralife Dark Souls 3 wiki](https://darksouls3.wiki.fextralife.com).
No network access at any point, including images.

**2,133 pages · 3,329 images · ~129 MB bundled**

</div>

---

## Why

Dark Souls is a game you play with a wiki open, and that wiki is exactly the
kind of site that struggles on a phone: ad-heavy, slow, and useless without
signal. This bundles the whole thing into the APK — every article, table,
infobox and image — and renders it natively.

Sibling to [dark-souls-wiki](https://github.com/OkilSaber/dark-souls-wiki),
the same reader for Dark Souls 1. Same design system, different source: that
wiki is Fextralife's own platform and has to be scraped from HTML, while this
one is MediaWiki with a proper API.

## Features

- **Fully offline.** No requests, no spinners, no degraded mode.
- **Organised by real wiki categories** — 10 sections, ~70 categories, read
  from the MediaWiki category system rather than guessed.
- **Instant ranked search** over every page title, falling back to summaries.
- **Save pages** — tap the bookmark in an article, or long-press any list row.
  Persisted across launches.
- **Complete weapon upgrade tables.** The wiki hides each infusion path behind
  a lazily-transcluded tab; all 2,526 of them are resolved and inlined.
- **Faithful articles** — infoboxes, multi-column stat tables with colspans,
  item-description flavour text, tappable cross-links.
- **Pinch-zoom image viewer** with drag-to-dismiss.
- Adapts to the system font-size setting and honours *remove animations*.

## Quick start

The scraped content is **not committed** (see [Content](#content)), so generate
it once, then build:

```sh
# 1. Generate assets/data and assets/img  (~30 min, ~1.5 GB of scratch space)
cd tools/scraper
python3 -m venv venv
./venv/bin/pip install beautifulsoup4 lxml httpx Pillow
#    then follow tools/scraper/README.md for the eight stages

# 2. Build and run
cd ../..
flutter pub get
flutter run
```

Release builds should split per ABI — a fat APK carries three copies of the
Flutter engine:

```sh
flutter build apk --release --split-per-abi
```

## How it works

### The pipeline

This wiki runs **MediaWiki 1.43 with an open `api.php`**, so nothing is scraped
from rendered pages. Full detail in
[`tools/scraper/README.md`](tools/scraper/README.md).

```
list_pages → fetch_parse → parse_pages → categorize
                                ↓             ↓
                          fetch_images → optimize_images → build_bundle
                                                                ↓
                                                       assets/{data,img}
```

Two things are specific to this wiki:

**Tabbed upgrade tables.** A weapon page renders only its "Max" overview tab
inline; the other sixteen are `Subcontent:` transclusion stubs. So 2,711
subcontent pages are fetched alongside the 2,362 articles and each stub is
resolved at parse time. Most of those tabs are still called `Tab 7` on the
wiki, so the real infusion name is recovered from the panel's opening line
(*"…+ Sharp Gem"*).

**Real categories.** The DS1 scraper had to infer membership from each
article's opening sentence. Here it is read from the API. The only judgement
left is ordering: specific weapon types beat the generic `Weapons` bucket, and
both beat DLC groupings, so a Ringed City katana files under Katanas.

`audit.py` compares words in the source HTML against words captured in the
parsed blocks — currently 5 of 2,048 pages fall below 80%, all tiny navigation
stubs.

### The app

| Path | Role |
| --- | --- |
| `lib/wiki_repository.dart` | Loads a ~0.7 MB index at startup; article bodies come from 64 shards on demand, behind an LRU cache. |
| `lib/block_renderer.dart` | Turns parsed blocks into widgets — the bulk of the rendering. |
| `lib/motion.dart` | Curves, durations, `Pressable`, staggered entrances, page transitions. |
| `lib/theme.dart` | Palette and type scale. |
| `lib/favorites.dart` | Saved pages, persisted via `SharedPreferences`. |
| `lib/screens/` | Home, section, category, article, search, saved, image viewer. |

Sharding keeps startup cheap: the index parses in one frame, and a ~545 KB
shard is only touched when you open a page inside it. Both are decoded on a
background isolate via `compute`. A page's shard is `hash(slug) % 64`, and the
Dart and Python implementations must agree — `test/wiki_test.dart` pins that.

### Design notes

A few decisions that aren't obvious from the code:

- **Feedback starts on pointer-down, never on release.** Every tap target is a
  `Pressable` driven by an `AnimationController`, so a fast tap still reverses
  smoothly from wherever the shrink had reached.
- **No `ease-in` anywhere.** It delays the first frames — exactly the ones being
  watched. Entrances use a strong ease-out.
- **Type is sized as a set.** Tracking is negative on display text, zero on
  body, slightly positive on small labels. One letter-spacing value is always
  wrong at some size.
- **Layout scales with text, not just fonts.** The section grid states its
  height and grows with `MediaQuery.textScalerOf`; a fixed aspect ratio clips
  labels the moment the system font scales up.
- **The image viewer decides on projected momentum,** not raw distance — a short
  flick dismisses where a slow drag of the same length springs back.

## Icon

`icon/icon.svg` is the source — an Estus Flask, deliberately a different
silhouette from the DS1 app's coiled sword so the two are never confused on a
home screen. `icon/make_icons.py` regenerates every density plus the adaptive
layers.

```sh
cd icon && python3 make_icons.py     # requires rsvg-convert
```

## Tests

```sh
flutter test
flutter analyze
```

Beyond unit coverage, the suite renders a wide sample of *real bundled
articles* and fails on any layout error, and sweeps the home screen across
three widths × four text scales.

`app_structure_test.dart` is deliberately its own file: it is the only test
that pumps the real app, which starts the index load on a background isolate
that fake-async cannot drive, and that would starve any later test in the same
file awaiting a real load.

The suite reads `assets/`, so run the scraper first.

## Known gaps

- Embedded YouTube walkthroughs can't work offline, so those headings appear
  with no body.
- The ~250 pages under Misc are genuinely uncategorised on the wiki (lore
  fragments, community pages, calculators) rather than misfiled.
- Comment and forum namespaces are not fetched at all.

## Content

The wiki text and images belong to
[Fextralife](https://darksouls3.wiki.fextralife.com) and its contributors; Dark
Souls III is © FromSoftware / Bandai Namco. **None of that content is committed
here** — only the code that fetches and renders it. Run the scraper to build
your own local copy.

The scraper uses the wiki's public API with a descriptive user agent, a
concurrency cap and a request delay. Built for personal offline use, not
redistribution.

The [MIT licence](LICENSE) applies to the code in this repository only — it does
not and cannot grant any rights over the wiki content it fetches.
