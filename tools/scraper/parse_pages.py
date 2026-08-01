"""Stage 3: turn cached MediaWiki HTML into the block schema the app renders.

Block kinds (identical to the DS1 reader, so the Dart side is unchanged):
  {"t":"h",  "l":2, "x":"heading text"}
  {"t":"p",  "s":[span,...]}
  {"t":"li", "o":0, "items":[{"s":[span,...], "img":[...]}]}
  {"t":"q",  "s":[span,...]}                     flavour text
  {"t":"tbl","info":1?, "rows":[[cell,...],...]}
  {"t":"img","src":"file.png", "alt":"..."}
span: {"x":text, "l":slug?, "b":1?, "i":1?}
cell: {"s":[span,...], "img":[...], "h":1?, "cs":n?, "rs":n?}

The wrinkle specific to this wiki is tabbed content. A weapon page renders its
"Max" overview tab inline and leaves the per-infusion tabs as `Subcontent:`
transclusion stubs. Each tab becomes a heading followed by its table, with the
stub resolved from that subcontent page's own cached HTML.
"""
import hashlib
import json
import re
import urllib.parse
from collections import Counter
from pathlib import Path

from bs4 import BeautifulSoup, NavigableString, Tag

from fetch_parse import cache_path
from wikiapi import is_article_link, out_dir

IMG_HOST = "static0.fextralifeimages.com"

# Chrome, navigation and editing furniture that is not article content.
SKIP_CLASS = re.compile(
    r"mw-editsection|mw-jump|navbox|catlinks|printfooter|"
    r"valnet|advert|social|comment|siteSub|contentSub|noprint|"
    r"mw-indicators|hatnote|ambox|metadata|mw-empty-elt", re.I)

NOISE_RE = re.compile(
    r"join the page discussion|tired of anon posting|"
    r"^\s*(load more|anonymous|edit|\[edit\])\s*$", re.I)

# Flavour text here is an italic blockquote or a .flavor/.italic wrapper.
FLAVOUR_CLASS = re.compile(r"flavor|flavour|italic|quote", re.I)


def canonical_image(src):
    """Collapse a thumbnail URL onto its original, so sizes dedupe to one file.

    .../file/darksouls3/thumb/9/9b/Name.png/20px-Name.png
      -> .../file/darksouls3/9/9b/Name.png
    """
    if not src:
        return None
    if src.startswith("//"):
        src = "https:" + src
    if not src.startswith("http"):
        return None
    p = urllib.parse.urlparse(src)
    if p.netloc != IMG_HOST:
        return None
    path = urllib.parse.unquote(p.path)
    m = re.match(r"^(/file/[^/]+)/thumb/(\w/\w\w/[^/]+)/\d+px-.*$", path)
    if m:
        path = f"{m.group(1)}/{m.group(2)}"
    return path


def img_name(src):
    """Local asset filename for an image URL, plus the remote path to fetch."""
    path = canonical_image(src)
    if not path:
        return None
    base = path.split("/")[-1]
    ext = Path(base).suffix.lower()
    if ext not in (".png", ".jpg", ".jpeg", ".gif", ".webp"):
        ext = ".png"
    stem = re.sub(r"[^A-Za-z0-9._-]", "_", Path(base).stem)[:60]
    h = hashlib.sha1(path.encode()).hexdigest()[:8]
    return f"{stem}_{h}{ext}", path


def link_slug(href):
    """Internal article slug for an href, or None."""
    if not href:
        return None
    href = href.strip()
    if href.startswith(("#", "mailto:", "javascript:")):
        return None
    if href.startswith("http"):
        p = urllib.parse.urlparse(href)
        if not p.netloc.endswith("darksouls3.wiki.fextralife.com"):
            return None
        href = p.path
    if not href.startswith("/"):
        return None
    target = urllib.parse.unquote(href.split("?")[0].split("#")[0].lstrip("/"))
    if not target or not is_article_link(target):
        return None
    return target


class Parser:
    def __init__(self, subcontent):
        self.images = {}
        self.links = set()
        self.subcontent = subcontent   # Subcontent title -> cached html
        self.resolved_tabs = 0
        self.missing_tabs = 0

    # ---------------- inline ----------------
    def spans(self, node, bold=False, italic=False, link=None):
        out = []
        for child in node.children:
            if isinstance(child, NavigableString):
                txt = str(child)
                if txt.strip():
                    s = {"x": re.sub(r"\s+", " ", txt)}
                    if bold:
                        s["b"] = 1
                    if italic:
                        s["i"] = 1
                    if link:
                        s["l"] = link
                    out.append(s)
                elif txt and out and not out[-1]["x"].endswith(" "):
                    out.append({"x": " "})
                continue
            if not isinstance(child, Tag):
                continue
            name = child.name
            cls = " ".join(child.get("class") or [])
            if name in ("script", "style", "sup", "sub") or SKIP_CLASS.search(cls):
                continue
            if name == "br":
                out.append({"x": "\n"})
            elif name in ("strong", "b"):
                out += self.spans(child, True, italic, link)
            elif name in ("em", "i"):
                out += self.spans(child, bold, True, link)
            elif name == "a":
                sl = link_slug(child.get("href"))
                if sl:
                    self.links.add(sl)
                out += self.spans(child, bold, italic, sl or link)
            elif name == "img":
                pass  # images are handled at block level
            else:
                out += self.spans(child, bold, italic, link)
        return self.merge(out)

    @staticmethod
    def merge(spans):
        out = []
        for s in spans:
            if out and out[-1].get("l") == s.get("l") \
                    and out[-1].get("b") == s.get("b") \
                    and out[-1].get("i") == s.get("i"):
                out[-1]["x"] += s["x"]
            else:
                out.append(dict(s))
        for s in out:
            s["x"] = re.sub(r" {2,}", " ", s["x"])
        return [s for s in out if s["x"].strip() or "\n" in s["x"]]

    def collect_imgs(self, node):
        names = []
        for im in node.find_all("img"):
            r = img_name(im.get("src"))
            if r:
                name, path = r
                self.images[name] = path
                names.append(name)
        return names

    # ---------------- blocks ----------------
    def table(self, tb, info=False):
        rows = []
        for tr in tb.find_all("tr"):
            cells = []
            for td in tr.find_all(["td", "th"], recursive=False):
                c = {"s": self.spans(td)}
                imgs = self.collect_imgs(td)
                if imgs:
                    c["img"] = imgs
                if td.name == "th":
                    c["h"] = 1
                try:
                    cs = int(td.get("colspan") or 1)
                    rs = int(td.get("rowspan") or 1)
                except ValueError:
                    cs = rs = 1
                if cs > 1:
                    c["cs"] = cs
                if rs > 1:
                    c["rs"] = rs
                cells.append(c)
            if cells and any(c["s"] or "img" in c for c in cells):
                rows.append(cells)
        if not rows:
            return None
        b = {"t": "tbl", "rows": rows}
        if info:
            b["info"] = 1
        return b

    def list_block(self, ul):
        items = []
        for li in ul.find_all("li", recursive=False):
            inner = self.spans(li)
            imgs = self.collect_imgs(li)
            if inner or imgs:
                it = {"s": inner}
                if imgs:
                    it["img"] = imgs
                items.append(it)
        if not items:
            return None
        return {"t": "li", "o": 1 if ul.name == "ol" else 0, "items": items}

    # ---------------- tabs ----------------
    def tabber(self, node, out, depth):
        """Flatten a tab group into headings plus their panel content."""
        labels = [a.get_text(" ", strip=True)
                  for a in node.select(".tabber__tabs .tabber__tab")]
        panels = node.select(".tabber__panel")

        for i, panel in enumerate(panels):
            label = labels[i] if i < len(labels) else f"Tab {i + 1}"
            stub = panel.find(class_="tabber__transclusion")

            body = panel
            if stub is not None:
                page = stub.get("data-mw-tabber-page")
                html = self.subcontent.get(page)
                if not html:
                    self.missing_tabs += 1
                    continue
                sub = BeautifulSoup(html, "lxml")
                body = sub.find(class_="mw-parser-output") or sub
                self.resolved_tabs += 1

            inner = []
            self.walk(body, inner, depth + 1)
            if not inner:
                continue
            # Most infusion tabs are still called "Tab 7" on the wiki. Their
            # lead paragraph names the gem, so recover the real label from it
            # rather than printing a placeholder or nothing.
            if re.fullmatch(r"tab \d+", label.strip(), re.I):
                label = self.derive_tab_label(inner)
            if label:
                out.append({"t": "h", "l": 4, "x": label})
            out.extend(inner)

    @staticmethod
    def derive_tab_label(blocks):
        """Infer an infusion name from a panel's opening paragraph."""
        for b in blocks[:2]:
            if b["t"] != "p":
                continue
            text = "".join(s["x"] for s in b["s"])
            m = re.search(r"\+\s*([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)?)\s+Gem",
                          text)
            if m:
                return m.group(1).strip()
        return None

    # ---------------- walk ----------------
    def walk(self, node, out, depth=0):
        for child in node.children:
            if isinstance(child, NavigableString):
                if child.strip():
                    sp = self.merge([{"x": re.sub(r"\s+", " ", str(child))}])
                    if sp:
                        out.append({"t": "p", "s": sp})
                continue
            if not isinstance(child, Tag):
                continue
            n = child.name
            if n in ("script", "style", "noscript", "iframe", "form",
                     "button", "nav", "audio", "video"):
                continue
            classes = child.get("class") or []
            cls = " ".join(classes)
            if SKIP_CLASS.search(cls) or SKIP_CLASS.search(child.get("id") or ""):
                continue

            if "tabber" in classes:
                self.tabber(child, out, depth)
            elif n in ("h1", "h2", "h3", "h4", "h5", "h6"):
                txt = " ".join(child.get_text(" ", strip=True).split())
                txt = re.sub(r"\s*\[\s*edit\s*\]\s*$", "", txt, flags=re.I)
                if txt and not NOISE_RE.search(txt):
                    out.append({"t": "h", "l": int(n[1]), "x": txt})
            elif n == "p":
                imgs = self.collect_imgs(child)
                sp = self.spans(child)
                txt = "".join(s["x"] for s in sp).strip()
                if sp and not NOISE_RE.search(txt):
                    out.append({"t": "p", "s": sp})
                for i in imgs:
                    out.append({"t": "img", "src": i})
            elif n in ("ul", "ol"):
                b = self.list_block(child)
                if b:
                    out.append(b)
            elif n == "table":
                b = self.table(child, info=bool(re.search(r"infobox", cls, re.I)))
                if b:
                    out.append(b)
            elif n == "blockquote":
                sp = self.spans(child)
                if sp:
                    out.append({"t": "q", "s": sp})
            elif n == "img":
                r = img_name(child.get("src"))
                if r:
                    name, path = r
                    self.images[name] = path
                    alt = (child.get("alt") or "").strip()
                    out.append({"t": "img", "src": name,
                                **({"alt": alt} if alt else {})})
            elif n == "figure":
                imgs = self.collect_imgs(child)
                cap = child.find("figcaption")
                caption = cap.get_text(" ", strip=True) if cap else ""
                for i in imgs:
                    out.append({"t": "img", "src": i,
                                **({"alt": caption} if caption else {})})
            elif n == "hr":
                continue
            elif n == "dl":
                # Indented definition lists are used for flavour text.
                for dd in child.find_all("dd", recursive=False):
                    sp = self.spans(dd)
                    if sp:
                        out.append({"t": "q", "s": sp})
            else:
                if re.search(r"infobox", cls, re.I):
                    for tb in child.find_all("table"):
                        b = self.table(tb, info=True)
                        if b:
                            out.append(b)
                    continue
                if FLAVOUR_CLASS.search(cls) and child.find("table") is None:
                    sp = self.spans(child)
                    if sp:
                        out.append({"t": "q", "s": sp})
                        continue
                if depth < 16:
                    self.walk(child, out, depth + 1)


def clean_blocks(blocks):
    out = []
    for b in blocks:
        if b["t"] == "p":
            txt = "".join(s["x"] for s in b["s"]).strip()
            if len(txt) < 2 or NOISE_RE.search(txt):
                continue
        out.append(b)
    ded = []
    for b in out:
        if ded and json.dumps(ded[-1], sort_keys=True) == json.dumps(b, sort_keys=True):
            continue
        ded.append(b)
    while ded and ded[-1]["t"] == "h":
        ded.pop()
    return ded


def load_subcontent(titles):
    """Cached HTML for every Subcontent page, keyed by full title."""
    out = {}
    for t in titles:
        p = cache_path(t)
        if not p.exists():
            continue
        try:
            out[t] = json.loads(p.read_text(encoding="utf-8"))["html"]
        except Exception:
            pass
    return out


def main():
    d = out_dir()
    meta = json.loads((d / "pages_meta.json").read_text(encoding="utf-8"))
    subs = json.loads((d / "subcontent_titles.json").read_text(encoding="utf-8"))

    subcontent = load_subcontent(subs)
    print(f"subcontent html loaded: {len(subcontent)}/{len(subs)}")

    pages, all_images = {}, {}
    stats = Counter()
    resolved = missing = 0

    for i, (slug, info) in enumerate(meta.items()):
        cp = cache_path(info["title"])
        if not cp.exists():
            stats["missing"] += 1
            continue
        try:
            cached = json.loads(cp.read_text(encoding="utf-8"))
        except Exception:
            stats["unreadable"] += 1
            continue

        soup = BeautifulSoup(cached["html"], "lxml")
        root = soup.find(class_="mw-parser-output") or soup
        for bad in root.find_all(["script", "style", "noscript", "iframe"]):
            bad.decompose()

        p = Parser(subcontent)
        blocks = []
        p.walk(root, blocks)
        blocks = clean_blocks(blocks)
        resolved += p.resolved_tabs
        missing += p.missing_tabs

        if not blocks:
            stats["empty"] += 1
            continue

        text = " ".join(s["x"] for b in blocks if b["t"] in ("p", "q")
                        for s in b["s"])
        all_images.update(p.images)
        pages[slug] = {
            "slug": slug,
            "title": info["title"],
            "categories": info["categories"],
            "blocks": blocks,
            "images": sorted(p.images),
            "links": sorted(p.links),
            "text": re.sub(r"\s+", " ", text).strip()[:1200],
        }
        stats["ok"] += 1
        if (i + 1) % 400 == 0:
            print(f"  parsed {i+1}/{len(meta)}  ok={stats['ok']}", flush=True)

    (d / "pages.json").write_text(json.dumps(pages, ensure_ascii=False),
                                  encoding="utf-8")
    (d / "images.json").write_text(json.dumps(all_images, indent=1),
                                   encoding="utf-8")
    print("stats:", dict(stats))
    print(f"pages {len(pages)}  images {len(all_images)}")
    print(f"tabs resolved {resolved}, unresolved {missing}")
    print("blocks:", dict(Counter(b["t"] for p in pages.values()
                                  for b in p["blocks"])))


if __name__ == "__main__":
    main()
