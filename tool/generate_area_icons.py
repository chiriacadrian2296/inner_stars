"""Generate small, transparent Flutter resolution variants from the area art."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/images/royal_symbols_negative_final"
OUTPUT = ROOT / "assets/images/area_icons"
AREAS = (
    "physical", "psychological", "professional", "financial",
    "personal", "social", "spiritual", "philanthropic",
)


def main() -> None:
    total = 0
    original = 0
    for index, area in enumerate(AREAS, 1):
        source = SOURCE / f"{index:02}-{area}.png"
        original += source.stat().st_size
        image = Image.open(source).convert("RGBA")
        # Remove the hero canvas margin; every emblem fills its icon box.
        bounds = image.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
        if bounds is None:
            raise ValueError(f"Empty artwork: {source}")
        image = image.crop(bounds)
        for scale in (1, 2, 3):
            side = 64 * scale
            emblem = image.copy()
            emblem.thumbnail((side - 4 * scale, side - 4 * scale), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            canvas.alpha_composite(emblem, ((side - emblem.width) // 2, (side - emblem.height) // 2))
            directory = OUTPUT if scale == 1 else OUTPUT / f"{scale}.0x"
            directory.mkdir(parents=True, exist_ok=True)
            destination = directory / f"{area}.png"
            # A compact palette is sufficient at icon size, including alpha.
            canvas.quantize(colors=64, method=Image.Quantize.FASTOCTREE).save(destination, optimize=True)
            total += destination.stat().st_size
    print(f"24 PNG assets: {total:,} bytes; source art: {original:,} bytes")


if __name__ == "__main__":
    main()
