import json
from pathlib import Path

from PIL import Image

Image.MAX_IMAGE_PIXELS = None

RAW = Path("images_raw")
OUT = Path("images_opt")
MAX_DIM = 1000
ICON_DIM = 160
JPEG_Q = 78

def alpha_used(im):
    if im.mode not in ("RGBA", "LA", "P"):
        return False
    if im.mode == "P":
        if "transparency" not in im.info:
            return False
        im = im.convert("RGBA")
    a = im.getchannel("A")
    return a.getextrema()[0] < 250

def main():
    OUT.mkdir(exist_ok=True)
    mapping = {}
    dims = {}
    before = after = 0
    skipped = resized = flattened = failed = 0

    for src in sorted(RAW.iterdir()):
        if not src.is_file():
            continue
        raw_size = src.stat().st_size
        before += raw_size
        try:
            with Image.open(src) as im:
                im.load()
                w, h = im.size
                keeps_alpha = alpha_used(im)

                if max(w, h) <= ICON_DIM and raw_size < 60_000:
                    dest = OUT / src.name
                    dest.write_bytes(src.read_bytes())
                    mapping[src.name] = src.name
                    dims[src.name] = [w, h]
                    after += dest.stat().st_size
                    skipped += 1
                    continue

                if max(w, h) > MAX_DIM:
                    scale = MAX_DIM / max(w, h)
                    im = im.resize((max(1, int(w * scale)), max(1, int(h * scale))),
                                   Image.LANCZOS)
                    resized += 1

                if keeps_alpha:
                    if im.mode != "RGBA":
                        im = im.convert("RGBA")
                    dest = OUT / (src.stem + ".png")
                    if im.width * im.height > 60_000:
                        q = im.convert("RGBA").quantize(
                            colors=160, method=Image.FASTOCTREE)
                        q.save(dest, "PNG", optimize=True)
                    else:
                        im.save(dest, "PNG", optimize=True)
                else:
                    if im.mode != "RGB":
                        bg = Image.new("RGB", im.size, (255, 255, 255))
                        if im.mode in ("RGBA", "LA", "P"):
                            tmp = im.convert("RGBA")
                            bg.paste(tmp, mask=tmp.getchannel("A"))
                        else:
                            bg.paste(im.convert("RGB"))
                        im = bg
                        flattened += 1
                    dest = OUT / (src.stem + ".jpg")
                    im.save(dest, "JPEG", quality=JPEG_Q, optimize=True,
                            progressive=True)

                if dest.stat().st_size >= raw_size and dest.suffix == src.suffix:
                    dest.write_bytes(src.read_bytes())
                mapping[src.name] = dest.name
                dims[dest.name] = list(im.size)
                after += dest.stat().st_size
        except Exception as e:
            failed += 1
            print(f"  FAILED {src.name}: {e}")

    Path("parsed/image_map.json").write_text(json.dumps(mapping, indent=1))
    Path("parsed/image_dims.json").write_text(json.dumps(dims, separators=(",", ":")))
    print(f"images: {len(mapping)}  (icons kept {skipped}, resized {resized}, "
          f"flattened {flattened}, failed {failed})")
    print(f"size: {before/1e6:.1f}MB -> {after/1e6:.1f}MB "
          f"({100*after/before:.0f}%)")

if __name__ == "__main__":
    main()
