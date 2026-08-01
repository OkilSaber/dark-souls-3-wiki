"""Stage 3b: check how much of each page's text actually survived parsing.

Compares the words visible in the source HTML against the words captured in the
emitted blocks. A page well below full coverage means the walker skipped a
container it should have descended into — the failure mode that otherwise ships
silently as a half-empty article.
"""
import json
import re
import sys

from bs4 import BeautifulSoup

from fetch_parse import cache_path
from parse_pages import SKIP_CLASS
from wikiapi import out_dir

THRESHOLD = 0.80
WORD = re.compile(r"[A-Za-z0-9']+")


def words_in_html(html):
    soup = BeautifulSoup(html, "lxml")
    root = soup.find(class_="mw-parser-output") or soup
    for bad in root.find_all(["script", "style", "noscript", "iframe"]):
        bad.decompose()
    # Drop the same chrome the parser drops, or every page looks lossy.
    for el in root.find_all(attrs={"class": True}):
        if SKIP_CLASS.search(" ".join(el.get("class") or [])):
            el.decompose()
    # Transcluded tab stubs contribute only a placeholder link in the source.
    for el in root.find_all(class_="tabber__transclusion"):
        el.decompose()
    return WORD.findall(root.get_text(" ", strip=True).lower())


def words_in_blocks(blocks):
    out = []
    for b in blocks:
        t = b["t"]
        if t == "h":
            out += WORD.findall(b["x"].lower())
        elif t in ("p", "q"):
            out += WORD.findall("".join(s["x"] for s in b["s"]).lower())
        elif t == "li":
            for it in b["items"]:
                out += WORD.findall("".join(s["x"] for s in it["s"]).lower())
        elif t == "tbl":
            for row in b["rows"]:
                for c in row:
                    out += WORD.findall("".join(s["x"] for s in c["s"]).lower())
        elif t == "img":
            out += WORD.findall((b.get("alt") or "").lower())
    return out


def main():
    d = out_dir()
    pages = json.loads((d / "pages.json").read_text(encoding="utf-8"))

    poor, checked = [], 0
    for slug, page in pages.items():
        cp = cache_path(page["title"])
        if not cp.exists():
            continue
        html = json.loads(cp.read_text(encoding="utf-8"))["html"]
        src = words_in_html(html)
        if len(src) < 40:
            continue
        got = set(words_in_blocks(page["blocks"]))
        covered = sum(1 for w in src if w in got)
        ratio = covered / len(src)
        checked += 1
        if ratio < THRESHOLD:
            poor.append((ratio, slug, len(src)))

    poor.sort()
    print(f"checked {checked} pages, {len(poor)} below {THRESHOLD:.0%} coverage")
    for ratio, slug, n in poor[:25]:
        print(f"  {ratio:5.1%}  {slug}  ({n} words)")
    if poor:
        (d / "audit_low_coverage.json").write_text(
            json.dumps([{"slug": s, "coverage": r, "words": n}
                        for r, s, n in poor], indent=1))
    # Fail loudly if a large share of pages are lossy; a handful is normal
    # (navigation-heavy index pages carry text the reader does not need).
    return 1 if checked and len(poor) / checked > 0.10 else 0


if __name__ == "__main__":
    sys.exit(main())
