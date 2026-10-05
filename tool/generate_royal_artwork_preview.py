"""Build temporary transparent gold previews from Craftwork public covers."""

from pathlib import Path
import sys

from PIL import Image


SOURCES = {
    "physical": "49649-1782652273467.webp",
    "psychological": "49655-1782652270900.webp",
    "professional": "49576-1782652308561.webp",
    "financial": "49632-1782652281492.webp",
    "personal": "49412-1782652394033.webp",
    "social": "49521-1782652337950.webp",
    "spiritual": "49657-1782652270856.webp",
    "philanthropic": "49652-1782652272367.webp",
}

# AppColors.dark.gold — keep raster previews identical to the app theme.
GOLD = (242, 184, 75)
CANVAS_SIZE = 1024
ART_SIZE = 900


def isolate_emblem(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGB")
    alpha = Image.new("L", image.size)
    alpha.putdata([
        max(0, min(255, (160 - round(0.213 * r + 0.715 * g + 0.072 * b)) * 4))
        for r, g, b in image.get_flattened_data()
    ])
    bounds = alpha.getbbox()
    if bounds is None:
        raise RuntimeError(f"No emblem detected in {source}")

    alpha = alpha.crop(bounds)
    scale = min(ART_SIZE / alpha.width, ART_SIZE / alpha.height)
    alpha = alpha.resize(
        (round(alpha.width * scale), round(alpha.height * scale)),
        Image.Resampling.LANCZOS,
    )
    emblem = Image.new("RGBA", alpha.size, (*GOLD, 0))
    emblem.putalpha(alpha)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(
        emblem,
        ((CANVAS_SIZE - emblem.width) // 2, (CANVAS_SIZE - emblem.height) // 2),
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, optimize=True)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate_royal_artwork_preview.py SOURCE_DIR OUTPUT_DIR")
    source_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    for area, filename in SOURCES.items():
        isolate_emblem(source_dir / filename, output_dir / f"{area}.png")


if __name__ == "__main__":
    main()
