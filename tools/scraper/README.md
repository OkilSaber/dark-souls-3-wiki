# Scraper pipeline

Regenerates `assets/data` and `assets/img` from the Fextralife Dark Souls 3
wiki. The app ships the generated output, so this only needs re-running to
refresh content.

Intermediate artefacts (`parse_cache/`, `images_raw/`, `images_opt/`,
`parsed/`) are throwaway — well over a gigabyte — and are not part of the app.

## This wiki is MediaWiki, unlike the DS1 one

The Dark Souls 1 wiki runs Fextralife's own platform and has to be scraped from
rendered HTML. This one runs **MediaWiki 1.43 with an open `api.php`**, which
changes the approach completely:

| | DS1 wiki | DS3 wiki (here) |
| --- | --- | --- |
| Page list | `sitemap.xml` | `list=allpages`, per namespace |
| Content | scrape `#wiki-content-block` | `action=parse` → `.mw-parser-output` |
| Categories | inferred from prose | **real category membership** |
| URL slugs | `Page+Name` | `Page_Name` |
| Images | `/file/Dark-Souls/…` | `static0.fextralifeimages.com`, with thumbs |

The category system is the big win. DS1 needed a text classifier reading *"X is
a Weapon in Dark Souls"* out of each article; here membership is read from the
API and is authoritative.

## Setup

```sh
python3 -m venv venv
./venv/bin/pip install beautifulsoup4 lxml httpx Pillow
```

## Run, in order

```sh
cd tools/scraper
./venv/bin/python list_pages.py        # parsed/pages_meta.json + subcontent list
./venv/bin/python fetch_parse.py       # parse_cache/ (~5100 pages)
./venv/bin/python parse_pages.py       # parsed/pages.json — structured blocks
./venv/bin/python audit.py             # flags pages where extraction lost text
./venv/bin/python categorize.py        # parsed/categories.json
./venv/bin/python fetch_images.py      # images_raw/ (~3330 images, ~1.3 GB)
./venv/bin/python optimize_images.py   # images_opt/ (~93 MB)
./venv/bin/python build_bundle.py      # writes ../../assets/{data,img}
```

`build_bundle.py` resolves the project root from its own location, so it writes
to `assets/` wherever the checkout lives.

## What each stage does

| Script | Purpose |
| --- | --- |
| `wikiapi.py` | Shared async API client: retry, concurrency cap, slug helpers, namespace filtering. |
| `list_pages.py` | Enumerates namespace 0 (articles) and 3005 (`Subcontent:`), then reads real category membership 50 titles per request. |
| `fetch_parse.py` | `action=parse` for every page into a JSON cache. Re-runs skip what is already cached. |
| `parse_pages.py` | Converts MediaWiki HTML into the app's block schema, resolving tabbed content (below). |
| `audit.py` | Compares words in the source HTML against words captured in the blocks and reports anything under 80%. This catches silent extraction bugs — currently 5 of 2048 pages, all tiny navigation stubs. |
| `categorize.py` | Maps ~117 wiki categories onto 10 browsable sections. |
| `fetch_images.py` | Downloads only images reachable from a kept page. |
| `optimize_images.py` | Caps dimensions at 1000px, flattens unused alpha to JPEG, leaves small icons alone. ~1.3 GB → ~93 MB. |
| `build_bundle.py` | Emits `index.json` plus 64 content shards, copies images, rewrites image names, prunes links to pages that were not kept. |

## Tabbed content

The one genuinely awkward part of this wiki. A weapon page shows its upgrade
tables in tabs, and only the first ("Max") is rendered inline. The other 16 are
stubs:

```html
<div class="tabber__transclusion"
     data-mw-tabber-page="Subcontent:Lothric Knight Sword 2 Regular">
```

So `Subcontent:` pages are fetched alongside articles — 2711 of them — and each
stub is resolved from its own cached HTML at parse time. Every tab group
becomes a heading plus its table, inline in reading order. 2526 tabs currently
resolve with none missing.

Most of those tabs are still named `Tab 7` on the wiki. Their opening line
names the gem (*"…+ Sharp Gem"*), so `derive_tab_label` recovers the real
infusion name instead of printing a placeholder.

## Image thumbnails

MediaWiki renders the same image at many sizes:

```
/file/darksouls3/thumb/9/9b/Icon-wp_physicalAttack.png/20px-Icon-wp_physicalAttack.png
```

`canonical_image` collapses any thumbnail onto its original
(`/file/darksouls3/9/9b/Icon-wp_physicalAttack.png`) before hashing, so each
distinct image is downloaded and bundled exactly once however many sizes appear
across the wiki.

## Category mapping

`CATEGORY_MAP` is an ordered list — first match wins. Order matters twice:

1. Specific weapon types (`Katanas`) beat the generic `Weapons` bucket.
2. Both beat DLC groupings, so a Ringed City katana files under **Katanas**
   rather than into a DLC heap.

Category sizes reported by the API look inflated (215 "Straight Swords")
because `Subcontent:` pages inherit their parent's categories. Filtering to
namespace 0 gives the real count (19).

Pages with no usable category fall back to build-field heuristics, then to
Misc — currently ~250 pages, mostly lore fragments and community pages.

## Shard hashing

`build_bundle.shard_of` and `WikiRepository.shardOf` must stay in agreement or
articles resolve to the wrong file. `test/wiki_test.dart` asserts this.
