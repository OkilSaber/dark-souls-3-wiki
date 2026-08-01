"""Phase 6: emit the Flutter asset bundle.

  assets/data/index.json        categories, page titles, search terms  (startup)
  assets/data/shard_NN.json     page content, 64 shards               (on demand)
  assets/img/<file>             optimised images

Image references inside blocks are rewritten to their final filenames, and
internal links are dropped when they point at a page we did not keep, so the
app never renders a dead link.
"""
import json
import re
import shutil
from collections import Counter
from pathlib import Path

# tools/scraper/build_bundle.py -> the Flutter project root
APP = Path(__file__).resolve().parents[2]
DATA = APP / "assets" / "data"
IMG = APP / "assets" / "img"
SHARDS = 64


def shard_of(slug):
    """Stable shard index; must match the Dart implementation exactly."""
    h = 0
    for ch in slug:
        h = (h * 31 + ord(ch)) & 0xFFFFFFFF
    return h % SHARDS


def main():
    pages = json.loads(Path("parsed/pages.json").read_text(encoding="utf-8"))
    cats = json.loads(Path("parsed/categories.json").read_text(encoding="utf-8"))
    kept = set(json.loads(Path("parsed/kept_slugs.json").read_text(encoding="utf-8")))
    imap = json.loads(Path("parsed/image_map.json").read_text())

    pages = {k: v for k, v in pages.items() if k in kept}
    DATA.mkdir(parents=True, exist_ok=True)
    IMG.mkdir(parents=True, exist_ok=True)

    # ---- collapse alias pages
    # The wiki keeps several URLs for the same subject (Quelaag / Chaos Witch
    # Quelaag), which would show as duplicate rows in a category list. Keep the
    # richest version and point links at it.
    where_pre = {}
    for sec in cats:
        for c in sec["categories"]:
            for s in c["slugs"]:
                where_pre[s] = (sec["name"], c["name"])

    groups = {}
    for slug, page in pages.items():
        key = (where_pre.get(slug, ("", "")), page["title"].strip().lower())
        groups.setdefault(key, []).append(slug)

    alias = {}
    for key, slugs in groups.items():
        if len(slugs) < 2:
            continue
        # richest first; prefer the shorter slug to break ties (the canonical one)
        slugs.sort(key=lambda s: (-len(pages[s]["blocks"]), len(s), s))
        winner = slugs[0]
        for loser in slugs[1:]:
            alias[loser] = winner
    for loser in alias:
        del pages[loser]
    print(f"collapsed {len(alias)} duplicate alias pages -> {len(pages)} pages")

    def resolve(slug):
        """Follow an alias to the page we actually ship, if any."""
        seen = set()
        while slug in alias and slug not in seen:
            seen.add(slug)
            slug = alias[slug]
        return slug if slug in pages else None

    # ---- copy images
    for old in IMG.glob("*"):
        old.unlink()
    n_img = 0
    for src in Path("images_opt").iterdir():
        if src.is_file():
            shutil.copy2(src, IMG / src.name)
            n_img += 1

    def fix_img(name):
        return imap.get(name)

    # ---- rewrite blocks: image names + prune dead links
    dropped_links = 0
    missing_imgs = 0

    def clean_spans(spans):
        nonlocal dropped_links
        for s in spans:
            if "l" not in s:
                continue
            target = resolve(s["l"])
            if target is None:
                del s["l"]
                dropped_links += 1
            else:
                s["l"] = target
        return spans

    for slug, page in pages.items():
        out = []
        for b in page["blocks"]:
            t = b["t"]
            if t in ("p", "q"):
                clean_spans(b["s"])
            elif t == "li":
                for it in b["items"]:
                    clean_spans(it["s"])
                    if "img" in it:
                        it["img"] = [x for x in (fix_img(i) for i in it["img"]) if x]
            elif t == "h":
                if "s" in b:
                    clean_spans(b["s"])
            elif t == "tbl":
                for row in b["rows"]:
                    for c in row:
                        clean_spans(c["s"])
                        if "img" in c:
                            c["img"] = [x for x in (fix_img(i) for i in c["img"]) if x]
                            if not c["img"]:
                                del c["img"]
            elif t == "img":
                nn = fix_img(b["src"])
                if not nn:
                    missing_imgs += 1
                    continue
                b["src"] = nn
            elif t == "card":
                nn = fix_img(b["src"])
                if not nn:
                    missing_imgs += 1
                    continue
                b["src"] = nn
                if "l" in b:
                    target = resolve(b["l"])
                    if target is None:
                        del b["l"]
                        dropped_links += 1
                    else:
                        b["l"] = target
            out.append(b)
        page["blocks"] = out

    # ---- category index + reverse lookup, minus the collapsed aliases
    for sec in cats:
        for c in sec["categories"]:
            c["slugs"] = [s for s in c["slugs"] if s in pages]
            c["count"] = len(c["slugs"])
        sec["categories"] = [c for c in sec["categories"] if c["count"]]
    cats = [sec for sec in cats if sec["categories"]]

    where = {}
    for sec in cats:
        for c in sec["categories"]:
            for s in c["slugs"]:
                where[s] = (sec["name"], c["name"])

    # lead image per page for list thumbnails
    def lead_image(page):
        for b in page["blocks"]:
            if b["t"] == "card":
                return b["src"]
            if b["t"] == "tbl" and b.get("info"):
                for row in b["rows"]:
                    for c in row:
                        if c.get("img"):
                            return c["img"][0]
            if b["t"] == "img":
                return b["src"]
        return None

    index_pages = {}
    for slug, page in pages.items():
        sec, cat = where.get(slug, ("Lore", "Misc"))
        entry = {
            "t": page["title"],
            "c": cat,
            "s": sec,
            "d": page["text"][:150],
        }
        li = lead_image(page)
        if li:
            entry["i"] = li
        index_pages[slug] = entry

    # Natural sizes let the renderer tell a 20px stat icon apart from a boss
    # portrait, which otherwise both get drawn at icon size inside a table.
    all_dims = json.loads(Path("parsed/image_dims.json").read_text())
    used = set()
    for page in pages.values():
        for b in page["blocks"]:
            if b["t"] in ("img", "card") and b.get("src"):
                used.add(b["src"])
            elif b["t"] == "tbl":
                for row in b["rows"]:
                    for c in row:
                        used.update(c.get("img") or ())
            elif b["t"] == "li":
                for it in b["items"]:
                    used.update(it.get("img") or ())
    dims = {n: all_dims[n] for n in sorted(used) if n in all_dims}

    index = {
        "dims": dims,
        "sections": [
            {"name": sec["name"],
             "categories": [{"name": c["name"], "count": c["count"],
                             "slugs": c["slugs"]} for c in sec["categories"]]}
            for sec in cats
        ],
        "pages": index_pages,
        "shards": SHARDS,
    }
    (DATA / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8")

    # ---- shards
    for old in DATA.glob("shard_*.json"):
        old.unlink()
    buckets = [{} for _ in range(SHARDS)]
    for slug, page in pages.items():
        buckets[shard_of(slug)][slug] = {
            "title": page["title"],
            "blocks": page["blocks"],
            "links": sorted({t for t in (resolve(l) for l in page["links"]) if t}),
        }
    sizes = []
    for i, b in enumerate(buckets):
        p = DATA / f"shard_{i:02d}.json"
        p.write_text(json.dumps(b, ensure_ascii=False, separators=(",", ":")),
                     encoding="utf-8")
        sizes.append(p.stat().st_size)

    idx_size = (DATA / "index.json").stat().st_size
    img_bytes = sum(p.stat().st_size for p in IMG.iterdir())
    print(f"pages         {len(pages)}")
    print(f"images        {n_img}  ({img_bytes/1e6:.1f} MB)")
    print(f"index.json    {idx_size/1e6:.2f} MB")
    print(f"shards        {SHARDS}  total {sum(sizes)/1e6:.1f} MB, "
          f"max {max(sizes)/1e3:.0f} KB, mean {sum(sizes)/len(sizes)/1e3:.0f} KB")
    print(f"pruned dead links {dropped_links}, missing images {missing_imgs}")
    print(f"total assets  {(img_bytes + idx_size + sum(sizes))/1e6:.1f} MB")
    bt = Counter(b["t"] for p in pages.values() for b in p["blocks"])
    print("blocks:", dict(bt))


if __name__ == "__main__":
    main()
