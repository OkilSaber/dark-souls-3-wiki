"""Shared MediaWiki API client.

The DS3 wiki runs MediaWiki 1.43 with an open api.php, so there is no reason to
scrape rendered pages: the API gives canonical page lists, real category
membership, and pre-rendered content HTML.
"""
import asyncio
import json
import urllib.parse
from pathlib import Path

import httpx

API = "https://darksouls3.wiki.fextralife.com/api.php"
SITE = "https://darksouls3.wiki.fextralife.com"
UA = ("DarkSouls3OfflineWiki/1.0 (personal offline reader; "
      "contact via github.com/OkilSaber/dark-souls-3-wiki)")

NS_MAIN = 0
NS_SUBCONTENT = 3005

# Namespaces that appear in article links but are not articles themselves.
LINK_PREFIX_SKIP = (
    "File:", "Category:", "Template:", "Help:", "User:", "Talk:",
    "Special:", "MediaWiki:", "Subcontent:", "ValnetWikiComments:",
    "PopWikis:", "PageTemplate:", "Embargo:", "Wikitest:",
)


def slugify(title):
    """MediaWiki canonical URL form: spaces become underscores."""
    return title.replace(" ", "_")


def unslug(slug):
    return slug.replace("_", " ")


def is_article_link(target):
    """True when a link target is a normal content page we might have kept."""
    if not target or target.startswith("#"):
        return False
    return not target.startswith(LINK_PREFIX_SKIP)


class Api:
    """Small async wrapper with retry and a shared concurrency limit."""

    def __init__(self, concurrency=8):
        self._sem = asyncio.Semaphore(concurrency)
        self._client = None

    async def __aenter__(self):
        self._client = httpx.AsyncClient(
            headers={"User-Agent": UA}, timeout=60.0, follow_redirects=True)
        return self

    async def __aexit__(self, *exc):
        await self._client.aclose()

    async def get(self, **params):
        params.setdefault("format", "json")
        params.setdefault("formatversion", "1")
        for attempt in range(5):
            async with self._sem:
                try:
                    r = await self._client.get(API, params=params)
                    if r.status_code == 200:
                        data = r.json()
                        if "error" in data:
                            raise RuntimeError(data["error"])
                        # Be a good citizen even though the API is fast.
                        await asyncio.sleep(0.05)
                        return data
                    if r.status_code in (429, 503):
                        await asyncio.sleep(3 * (attempt + 1))
                        continue
                    r.raise_for_status()
                except (httpx.HTTPError, json.JSONDecodeError):
                    await asyncio.sleep(2 * (attempt + 1))
        raise RuntimeError(f"API failed after retries: {params}")

    async def paged(self, **params):
        """Yield each response page of a list/generator query."""
        cont = {}
        while True:
            data = await self.get(**params, **cont)
            yield data
            if "continue" not in data:
                return
            cont = data["continue"]


def sync_get(**params):
    """Blocking single call, for scripts that only need one or two."""
    params.setdefault("format", "json")
    url = API + "?" + urllib.parse.urlencode(params)
    import urllib.request
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as fh:
        return json.load(fh)


def out_dir():
    d = Path("parsed")
    d.mkdir(exist_ok=True)
    return d
