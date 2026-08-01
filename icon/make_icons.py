"""Generate the Android launcher icons from icon.svg.

Produces both shapes Android needs:
  * legacy square PNGs (mipmap-*/ic_launcher.png), the whole illustration;
  * adaptive layers (foreground + background), where the subject is scaled
    into the inner 66% of the 108dp canvas that every launcher mask keeps.

Run from this directory:  python3 make_icons.py
"""
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).parent
RES = HERE.parent / "android" / "app" / "src" / "main" / "res"
SRC = HERE / "icon.svg"

# Legacy icon: 48dp at mdpi, doubling through to xxxhdpi.
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# Adaptive layers are 108dp on the same density ladder.
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

# Centre of the drawn subject inside the 1024 canvas. The flask spans roughly
# y=214 (stopper) to y=838 (base), so its middle sits below the canvas middle.
SUBJECT_CX, SUBJECT_CY = 512, 526
# 0.84 keeps a little air beyond the guaranteed-visible circle, so a round
# mask never clips the pommel or the tip.
SAFE_SCALE = 0.84


def split_source():
    """Return (defs, background rect, subject) from the master drawing."""
    svg = SRC.read_text(encoding="utf-8")
    defs = re.search(r"<defs>.*?</defs>", svg, re.S).group(0)
    bg = re.search(r'<rect width="1024" height="1024" fill="url\(#bg\)"/>', svg).group(0)
    body = svg.split(bg, 1)[1].rsplit("</svg>", 1)[0]
    return defs, bg, body


def wrap(defs, inner):
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">\n'
        f"{defs}\n{inner}\n</svg>\n"
    )


def render(svg_path, out_path, size):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size),
         str(svg_path), "-o", str(out_path)],
        check=True,
    )


def main():
    defs, bg_rect, subject = split_source()

    fg_svg = HERE / "icon_foreground.svg"
    bg_svg = HERE / "icon_background.svg"

    fg_svg.write_text(wrap(
        defs,
        f'  <g transform="translate(512 512) scale({SAFE_SCALE}) '
        f'translate({-SUBJECT_CX} {-SUBJECT_CY})">{subject}</g>',
    ), encoding="utf-8")

    bg_svg.write_text(wrap(defs, f"  {bg_rect}"), encoding="utf-8")

    n = 0
    for density, size in LEGACY.items():
        render(SRC, RES / f"mipmap-{density}" / "ic_launcher.png", size)
        n += 1
    for density, size in ADAPTIVE.items():
        render(fg_svg, RES / f"mipmap-{density}" / "ic_launcher_foreground.png", size)
        render(bg_svg, RES / f"mipmap-{density}" / "ic_launcher_background.png", size)
        n += 2

    # Adaptive descriptor. Android 8+ picks this over the legacy PNG and
    # applies the launcher's own mask to the two layers.
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    # No <monochrome>: the foreground is a full-colour layer with a soft glow,
    # and Android themed icons only keep its alpha — which would tint that
    # glow into a large flat blob. Better to let the launcher fall back.
    descriptor = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )
    (anydpi / "ic_launcher.xml").write_text(descriptor, encoding="utf-8")
    (anydpi / "ic_launcher_round.xml").write_text(descriptor, encoding="utf-8")

    # A Play-Store-sized master, handy to have next to the source.
    render(SRC, HERE / "icon_1024.png", 1024)
    print(f"wrote {n} launcher PNGs + adaptive descriptors under {RES}")


if __name__ == "__main__":
    main()
