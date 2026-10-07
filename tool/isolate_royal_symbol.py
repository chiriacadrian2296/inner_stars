"""Turn a public Royal Symbols cover into a transparent app artwork."""

from pathlib import Path
import sys

from PIL import Image


CANVAS_SIZE = 1254
ART_SIZE = 1000
GOLD = (234, 186, 79)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: isolate_royal_symbol.py SOURCE OUTPUT")

    source = Image.open(Path(sys.argv[1])).convert("RGB")
    alpha = Image.new("L", source.size)
    alpha.putdata([
        max(0, min(255, (165 - round(0.213 * r + 0.715 * g + 0.072 * b)) * 4))
        for r, g, b in source.get_flattened_data()
    ])
    bounds = alpha.getbbox()
    if bounds is None:
        raise RuntimeError("No dark emblem found in source image")

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
    destination = Path(sys.argv[2])
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, optimize=True)


if __name__ == "__main__":
    main()
