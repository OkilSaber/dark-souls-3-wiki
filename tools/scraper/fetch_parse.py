"""Stage 2: fetch rendered content HTML for every page, into a local cache.

Subcontent pages are fetched alongside articles because the weapon upgrade
tables live there: a weapon page renders one "Max" overview tab inline and
leaves the per-infusion tabs as `Subcontent:` transclusion stubs. Resolving
them offline means having their HTML too.
"""
import asyncio
import hashlib
import json
import re
import sys
from pathlib import Path

from wikiapi import Api, out_dir

CACHE = Path("parse_cache")


def cache_path(title):
    h = hashlib.sha1(title.encode()).hexdigest()[:16]
    safe = re.sub(r"[^A-Za-z0-9._-]", "_", title)[:70]
    return CACHE / f"{safe}__{h}.json"


async def fetch_one(api, title, stats):
    dest = cache_path(title)
    if dest.exists() and dest.stat().st_size > 200:
        stats["cached"] += 1
        return
    try:
        data = await api.get(action="parse", page=title,
                             prop="text|categories|displaytitle",
                             disablelimitreport=1, disableeditsection=1)
    except Exception as e:
        # A page can vanish between listing and fetching; that is not fatal.
        stats["failed"] += 1
        stats.setdefault("errors", []).append(f"{title}: {e}")
        return
    p = data.get("parse")
    if not p:
        stats["empty"] += 1
        return
    dest.write_text(json.dumps({
        "title": p.get("title", title),
        "displaytitle": p.get("displaytitle", ""),
        "categories": [c["*"] for c in p.get("categories", [])],
        "html": p.get("text", {}).get("*", ""),
    }, ensure_ascii=False), encoding="utf-8")
    stats["ok"] += 1


async def main():
    CACHE.mkdir(exist_ok=True)
    d = out_dir()
    meta = json.loads((d / "pages_meta.json").read_text(encoding="utf-8"))
    subs = json.loads((d / "subcontent_titles.json").read_text(encoding="utf-8"))

    titles = [v["title"] for v in meta.values()] + subs
    print(f"fetching {len(titles)} pages "
          f"({len(meta)} articles + {len(subs)} subcontent)")

    stats = {"ok": 0, "cached": 0, "empty": 0, "failed": 0}
    async with Api(concurrency=8) as api:
        for i in range(0, len(titles), 200):
            chunk = titles[i:i + 200]
            await asyncio.gather(*(fetch_one(api, t, stats) for t in chunk))
            done = min(i + 200, len(titles))
            print(f"  {done}/{len(titles)}  ok={stats['ok']} "
                  f"cached={stats['cached']} empty={stats['empty']} "
                  f"failed={stats['failed']}", flush=True)

    print("done:", {k: v for k, v in stats.items() if k != "errors"})
    if stats.get("errors"):
        Path("fetch_errors.txt").write_text("\n".join(stats["errors"]))
        print(f"  {len(stats['errors'])} errors -> fetch_errors.txt")
        for line in stats["errors"][:5]:
            print("   ", line[:140])


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
