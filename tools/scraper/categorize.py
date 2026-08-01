"""Stage 4: group pages into sections using real MediaWiki categories.

The DS1 wiki had no category system, so that scraper had to infer membership
from each article's opening sentence. Here membership is authoritative — the
only work is mapping ~117 wiki categories onto a browsable hierarchy and
picking one when a page belongs to several.

Order matters: entries earlier in CATEGORY_MAP win. Specific weapon types beat
the generic "Weapons" bucket, and both beat DLC groupings, so a Ringed City
katana files under Katanas rather than under a DLC heap.
"""
import json
import re
from collections import Counter, defaultdict

from wikiapi import out_dir

# wiki category -> (display name, section). First match in this order wins.
CATEGORY_MAP = [
    # --- Equipment: weapons, most specific first
    ("Straight Swords", "Straight Swords", "Weapons"),
    ("Greatswords", "Greatswords", "Weapons"),
    ("Ultra Greatswords", "Ultra Greatswords", "Weapons"),
    ("Curved Swords", "Curved Swords", "Weapons"),
    ("Curved Greatswords", "Curved Greatswords", "Weapons"),
    ("Katanas", "Katanas", "Weapons"),
    ("Thrusting Swords", "Thrusting Swords", "Weapons"),
    ("Daggers", "Daggers", "Weapons"),
    ("Axes", "Axes", "Weapons"),
    ("Greataxes", "Greataxes", "Weapons"),
    ("Hammers", "Hammers", "Weapons"),
    ("Great Hammers", "Great Hammers", "Weapons"),
    ("Spears and Pikes", "Spears & Pikes", "Weapons"),
    ("Halberds", "Halberds", "Weapons"),
    ("Reapers", "Reapers", "Weapons"),
    ("Whips", "Whips", "Weapons"),
    ("Fist and Claws", "Fists & Claws", "Weapons"),
    ("Bows", "Bows", "Weapons"),
    ("Greatbows", "Greatbows", "Weapons"),
    ("Crossbows", "Crossbows", "Weapons"),
    ("Boss Soul Weapons", "Boss Soul Weapons", "Weapons"),
    ("Weapons", "Other Weapons", "Weapons"),
    ("Ashes of Ariandel Weapons", "DLC Weapons", "Weapons"),
    ("The Ringed City Weapons", "DLC Weapons", "Weapons"),

    # --- Equipment: shields, armour, catalysts
    ("Small Shields", "Small Shields", "Equipment"),
    ("Standard Shields", "Standard Shields", "Equipment"),
    ("Greatshields", "Greatshields", "Equipment"),
    ("Shields", "Other Shields", "Equipment"),
    ("Helms", "Helms", "Equipment"),
    ("Chest Armor", "Chest Armor", "Equipment"),
    ("Gauntlets", "Gauntlets", "Equipment"),
    ("Leggings", "Leggings", "Equipment"),
    ("The Ringed City Helms", "Helms", "Equipment"),
    ("The Ringed City Chest Armor", "Chest Armor", "Equipment"),
    ("The Ringed City Gauntlets", "Gauntlets", "Equipment"),
    ("The Ringed City Leggings", "Leggings", "Equipment"),
    ("Ashes of Ariandel Helms", "Helms", "Equipment"),
    ("Ashes of Ariandel Chest Armor", "Chest Armor", "Equipment"),
    ("Ashes of Ariandel Gauntlets", "Gauntlets", "Equipment"),
    ("Ashes of Ariandel Leggings", "Leggings", "Equipment"),
    ("Ashes of Ariandel Armor", "Armor Sets", "Equipment"),
    ("Armor", "Armor Sets", "Equipment"),
    ("The Ringed City Armor", "Armor Sets", "Equipment"),
    ("Staves", "Staves", "Equipment"),
    ("Chimes", "Chimes", "Equipment"),
    ("Sacred Chimes", "Chimes", "Equipment"),
    ("Talismans", "Talismans", "Equipment"),
    ("Flames", "Pyromancy Flames", "Equipment"),
    ("Rings", "Rings", "Equipment"),
    ("Ammunition", "Ammunition", "Equipment"),

    # --- Magic
    ("Sorceries", "Sorceries", "Magic"),
    ("Miracles", "Miracles", "Magic"),
    ("Pyromancies", "Pyromancies", "Magic"),
    ("Ashes of Ariandel Spells", "DLC Spells", "Magic"),
    ("Skills", "Weapon Skills", "Magic"),
    ("Magic", "Magic Overview", "Magic"),

    # --- Items
    ("Key Items", "Key Items", "Items"),
    ("Consumables", "Consumables", "Items"),
    ("Upgrade Materials", "Upgrade Materials", "Items"),
    ("Multiplayer Items", "Multiplayer Items", "Items"),
    ("Boss Souls", "Boss Souls", "Items"),
    ("Souls", "Souls", "Items"),
    ("Ashes", "Ashes", "Items"),
    ("Projectiles", "Projectiles", "Items"),
    ("Tools", "Tools", "Items"),
    ("Upgrades", "Upgrade Materials", "Items"),
    ("Items", "Other Items", "Items"),

    # --- World
    ("Bosses", "Bosses", "World"),
    ("Enemies", "Enemies", "World"),
    ("NPCs", "NPCs", "World"),
    ("Invading NPC Phantoms", "Invaders", "World"),
    ("Locations", "Locations", "World"),
    ("Summonable NPC Phantoms", "Summons", "World"),
    ("Sumonable NPC Phantoms", "Summons", "World"),   # the wiki's own typo
    ("Hollow Arena", "Hollow Arena", "World"),
    ("Ashes of Ariandel", "DLC: Ashes of Ariandel", "World"),
    ("The Ringed City", "DLC: The Ringed City", "World"),
    ("DLC", "DLC", "World"),

    # --- Character
    ("Classes", "Classes", "Character"),
    ("Stats", "Stats", "Character"),
    ("Covenants", "Covenants", "Character"),
    ("Character Information", "Character Info", "Character"),

    # --- Builds & guides
    ("PvE Builds", "PvE Builds", "Builds"),
    ("PvP Builds", "PvP Builds", "Builds"),
    ("Builds", "Builds", "Builds"),
    ("Fashion Souls", "Fashion Souls", "Builds"),
    ("Guides and Walkthroughs", "Guides", "Guides"),
    ("Japanese Version Help", "Japanese Version", "Guides"),

    # --- General
    ("Combat", "Combat", "General"),
    ("Damage Types", "Damage Types", "General"),
    ("Status Effects", "Status Effects", "General"),
    ("Secrets", "Secrets", "General"),
    ("Tools and Calculators", "Tools & Calculators", "General"),
    ("Online Information", "Online", "General"),
    ("Player IDs", "Community", "General"),
    ("Media and Art", "Community", "General"),
    ("Equipment and Magic", "Equipment Overview", "General"),
    ("World Information", "World Info", "General"),
    ("General Information", "General Info", "General"),
    ("FAQs", "FAQs", "General"),
    ("Dark Souls 3", "About", "General"),
    ("Media and Community", "Community", "General"),
]

SECTION_ORDER = ["Weapons", "Equipment", "Magic", "Items", "World",
                 "Character", "Builds", "Guides", "General", "Misc"]

# Maintenance categories carry no meaning for a reader.
IGNORE_CATEGORY = re.compile(
    r"^(Pages using|Pages with|Articles |Candidates |Stubs?$|"
    r"Chatroom$|Dark Souls 3 Wiki$|Dark Souls 3 Build$|Porcine Shield$)", re.I)

BUILD_FIELD_RE = re.compile(
    r"(starting class|soul level|created by|starting gift)\s*:", re.I)
BUILD_RE = re.compile(r"\b(build|pvp|pve)\b", re.I)

# Titles that are wiki scaffolding rather than content.
JUNK_TITLE = re.compile(r"^(Subcontent:|Template:|Sandbox|Test page)", re.I)


def main():
    d = out_dir()
    pages = json.loads((d / "pages.json").read_text(encoding="utf-8"))
    print(f"pages: {len(pages)}")

    stubs = [s for s, p in pages.items()
             if JUNK_TITLE.match(p["title"])
             or (len(p["text"]) < 40 and len(p["blocks"]) <= 3)]
    for s in stubs:
        del pages[s]
    print(f"dropped {len(stubs)} stubs -> {len(pages)} pages")

    lookup = {}
    for wiki_cat, display, section in CATEGORY_MAP:
        lookup.setdefault(wiki_cat, (display, section))
    priority = {c: i for i, (c, _, _) in enumerate(CATEGORY_MAP)}

    assigned, members, origin = {}, defaultdict(list), Counter()
    unmapped = Counter()

    for slug, page in pages.items():
        cats = [c.replace("_", " ") for c in page.get("categories", [])
                if not IGNORE_CATEGORY.match(c.replace("_", " "))]
        known = [c for c in cats if c in lookup]
        if known:
            best = min(known, key=lambda c: priority[c])
            display, section = lookup[best]
            assigned[slug] = (display, section)
            members[(section, display)].append(slug)
            origin["category"] += 1
            continue
        for c in cats:
            unmapped[c] += 1
        # No usable category: builds are recognisable by their stat fields.
        if BUILD_FIELD_RE.search(page["text"]) or BUILD_RE.search(page["title"]):
            assigned[slug] = ("Builds", "Builds")
            members[("Builds", "Builds")].append(slug)
            origin["build-fields"] += 1
        else:
            assigned[slug] = ("Misc", "Misc")
            members[("Misc", "Misc")].append(slug)
            origin["misc"] += 1

    sections = []
    for section in SECTION_ORDER:
        cats = []
        for (sec, display), slugs in members.items():
            if sec != section:
                continue
            slugs = sorted(set(slugs), key=lambda s: pages[s]["title"].lower())
            if slugs:
                cats.append({"name": display, "count": len(slugs),
                             "slugs": slugs})
        if cats:
            cats.sort(key=lambda c: -c["count"])
            sections.append({"name": section, "categories": cats})

    (d / "categories.json").write_text(
        json.dumps(sections, ensure_ascii=False, indent=1), encoding="utf-8")
    (d / "kept_slugs.json").write_text(
        json.dumps(sorted(pages), ensure_ascii=False), encoding="utf-8")

    print(f"\nassignment source: {dict(origin)}")
    total = sum(c["count"] for s in sections for c in s["categories"])
    print(f"sections {len(sections)}  categorized {total}")
    for s in sections:
        n = sum(c["count"] for c in s["categories"])
        print(f"  {s['name']:<10} {n:>5}  " +
              ", ".join(f"{c['name']}({c['count']})"
                        for c in s["categories"][:7]))
    if unmapped:
        print("\nunmapped categories seen on uncategorised pages:")
        for c, n in unmapped.most_common(12):
            print(f"  {n:>4}  {c}")


if __name__ == "__main__":
    main()
