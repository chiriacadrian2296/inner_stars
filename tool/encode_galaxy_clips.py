"""Encode the explicit Flutter capture into locally hosted, controllable clips."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent.parent
output = root / 'landing/public/clips'
output.mkdir(exist_ok=True)
for name in ('fly', 'widen', 'energy'):
    files = sorted((root / f'landing/.capture/galaxy-{name}').glob('*.png'))
    expected = 84 if name == 'energy' else 48
    if len(files) != expected:
        raise RuntimeError(f'{name}: expected {expected} frames, found {len(files)}')
    frames = [Image.open(path).convert('RGB') for path in files]
    frames[0].save(output / f'{name}-poster.webp', quality=85)
    frames[0].save(output / f'{name}.webp', save_all=True, append_images=frames[1:],
                   duration=83, loop=0, quality=78, method=4)
    print(name, (output / f'{name}.webp').stat().st_size)
    for frame in frames:
        frame.close()
