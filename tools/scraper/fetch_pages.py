"""Phase 1: fetch every wiki page from the sitemap into a local HTML cache.

Cached to disk so the parser can be iterated on without re-crawling.
Respects the Disallow list in robots.txt for User-agent: *.
"""
import asyncio
import hashlib
import re
import sys
import urllib.parse
from pathlib import Path

import httpx

HOST = "https://darksouls.wiki.fextralife.com"
CACHE = Path("html_cache")
CONCURRENCY = 8
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# robots.txt Disallow for User-agent: *
ROBOTS_DENY = [
    "pixel.png", "forums/search.php", "login", "register", "forums/ucp.php",
    "wiki/authentication", "wiki/filemanager", "Editing+Guide", "wiki/changes",
    "wiki/settings", "ws/",
]


def denied(slug):
    return any(slug == d or slug.startswith(d) for d in ROBOTS_DENY)


def cache_path(slug):
    """Stable, filesystem-safe cache filename for a slug."""
    h = hashlib.sha1(slug.encode()).hexdigest()[:16]
    safe = re.sub(r"[^A-Za-z0-9._+-]", "_", slug)[:80]
    return CACHE / f"{safe}__{h}.html"


def load_slugs():
    xml = Path("sitemap.xml").read_text(encoding="utf-8")
    locs = re.findall(r"<loc>(.*?)</loc>", xml)
    slugs = []
    seen = set()
    for loc in locs:
        if ".com/" not in loc:
            continue
        raw = loc.split(".com/", 1)[1].split("#")[0].split("?")[0]
        slug = urllib.parse.unquote(raw)
        if not slug or denied(slug) or slug in seen:
            continue
        seen.add(slug)
        slugs.append(slug)
    return slugs


async def fetch_one(client, slug, sem, stats):
    dest = cache_path(slug)
    if dest.exists() and dest.stat().st_size > 2000:
        stats["cached"] += 1
        return
    url = f"{HOST}/{urllib.parse.quote(slug, safe='+&()',)}"
    async with sem:
        for attempt in range(4):
            try:
                r = await client.get(url, timeout=45.0, follow_redirects=True)
                if r.status_code == 200:
                    dest.write_text(r.text, encoding="utf-8")
                    stats["ok"] += 1
                    await asyncio.sleep(0.15)
                    return
                if r.status_code == 404:
                    stats["404"] += 1
                    return
                if r.status_code in (429, 503):
                    await asyncio.sleep(3 * (attempt + 1))
                    continue
                stats[f"http{r.status_code}"] = stats.get(f"http{r.status_code}", 0) + 1
                return
            except Exception:
                await asyncio.sleep(2 * (attempt + 1))
        stats["fail"] += 1
        stats.setdefault("failed_slugs", []).append(slug)


async def main():
    CACHE.mkdir(exist_ok=True)
    slugs = load_slugs()
    # always include the wiki home + nav index pages even if absent from sitemap
    import json
    extra = []
    nav = Path("nav_tree.json")
    if nav.exists():
        def walk(ns):
            for n in ns:
                if n.get("slug"):
                    extra.append(n["slug"])
                walk(n.get("children") or [])
        walk(json.loads(nav.read_text()))
    for s in ["Dark+Souls+Wiki"] + extra:
        if s not in slugs and not denied(s):
            slugs.append(s)

    print(f"fetching {len(slugs)} pages, concurrency {CONCURRENCY}")
    stats = {"ok": 0, "cached": 0, "404": 0, "fail": 0}
    sem = asyncio.Semaphore(CONCURRENCY)
    async with httpx.AsyncClient(headers={"User-Agent": UA}) as client:
        tasks = [fetch_one(client, s, sem, stats) for s in slugs]
        done = 0
        for chunk_start in range(0, len(tasks), 100):
            await asyncio.gather(*tasks[chunk_start:chunk_start + 100])
            done = min(chunk_start + 100, len(tasks))
            print(f"  {done}/{len(slugs)}  ok={stats['ok']} cached={stats['cached']} "
                  f"404={stats['404']} fail={stats['fail']}", flush=True)

    print("done:", {k: v for k, v in stats.items() if k != "failed_slugs"})
    if stats.get("failed_slugs"):
        Path("failed_slugs.txt").write_text("\n".join(stats["failed_slugs"]))
        print(f"  {len(stats['failed_slugs'])} failures written to failed_slugs.txt")
    Path("all_slugs.txt").write_text("\n".join(slugs), encoding="utf-8")


if __name__ == "__main__":
    asyncio.run(main())
