import asyncio
import json

from wikiapi import NS_MAIN, NS_SUBCONTENT, Api, out_dir, slugify

async def all_titles(api, namespace):
    titles = []
    async for page in api.paged(action="query", list="allpages",
                                apnamespace=namespace, aplimit=500):
        titles += [p["title"] for p in page["query"]["allpages"]]
    return titles

async def categories_for(api, titles):
    out = {}
    batches = [titles[i:i + 50] for i in range(0, len(titles), 50)]

    async def one(batch):
        cont = {}
        while True:
            data = await api.get(action="query", titles="|".join(batch),
                                 prop="categories", cllimit="max",
                                 clshow="!hidden", **cont)
            for page in data.get("query", {}).get("pages", {}).values():
                if "missing" in page:
                    continue
                names = [c["title"].removeprefix("Category:")
                         for c in page.get("categories", [])]
                out.setdefault(page["title"], []).extend(names)
            if "continue" not in data:
                return
            cont = data["continue"]

    await asyncio.gather(*(one(b) for b in batches))
    return out

async def main():
    async with Api() as api:
        articles, subcontent = await asyncio.gather(
            all_titles(api, NS_MAIN),
            all_titles(api, NS_SUBCONTENT),
        )
        print(f"articles      {len(articles)}")
        print(f"subcontent    {len(subcontent)}")

        cats = await categories_for(api, articles)

    meta = {
        slugify(t): {"title": t, "categories": sorted(set(cats.get(t, [])))}
        for t in articles
    }
    d = out_dir()
    (d / "pages_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    (d / "subcontent_titles.json").write_text(
        json.dumps(sorted(subcontent), ensure_ascii=False), encoding="utf-8")

    uncategorised = sum(1 for v in meta.values() if not v["categories"])
    print(f"with categories {len(meta) - uncategorised}/{len(meta)} "
          f"({uncategorised} bare)")

if __name__ == "__main__":
    asyncio.run(main())
