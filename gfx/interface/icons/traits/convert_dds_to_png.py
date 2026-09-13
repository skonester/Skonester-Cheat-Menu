"""Convert this folder's DDS icons to PNG. Requires Pillow: pip install Pillow.

Run: python convert_dds_to_png.py
Existing PNGs are skipped; use --overwrite to replace them.
"""

import argparse
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--overwrite', action='store_true')
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    destination = source / 'png'
    files = sorted(p for p in source.iterdir() if p.suffix.lower() == '.dds')
    if not files:
        parser.exit(1, 'No DDS files found beside the script.\n')
    destination.mkdir(exist_ok=True)
    converted = skipped = failed = 0
    for path in files:
        output = destination / (path.stem + '.png')
        if output.exists() and not args.overwrite:
            skipped += 1
            continue
        try:
            with Image.open(path) as original:
                rgba = original.convert('RGBA')
                rgba.save(output, format='PNG')
            with Image.open(output) as check:
                if check.size != rgba.size or check.convert('RGBA').tobytes() != rgba.tobytes():
                    raise ValueError('PNG pixel verification failed')
            converted += 1
        except Exception as error:
            print(f'FAILED {path.name}: {error}')
            failed += 1
    print(f'Converted and verified: {converted}; skipped: {skipped}; failed: {failed}')
    print(f'PNG folder: {destination}')
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
