"""Remove generated backgrounds and export transparent masters and 120px previews.

Uses the U2Net model distributed by https://github.com/danielgatis/rembg.
Dependencies: Pillow, numpy, onnxruntime. Originals and generated RGB masters are retained.
"""

import argparse
import json
import re
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageDraw, ImageFont
from PIL.PngImagePlugin import PngInfo


BASE = Path(__file__).resolve().parent
DEFAULT_MODEL = Path(r'C:\Users\admin\Downloads\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable\ComfyUI\models\background_removal\u2net.onnx')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-name', default='v1')
    parser.add_argument('--model', type=Path, default=DEFAULT_MODEL)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.run_name):
        parser.error('Invalid run name')
    source = BASE / 'generated' / args.run_name
    files = sorted(source.glob('*.png'))
    if not files:
        parser.error('No generated PNGs in the selected run')
    destination = source / 'transparent'
    small_dir = source / 'icons_120'
    destination.mkdir(exist_ok=True)
    small_dir.mkdir(exist_ok=True)
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    session = ort.InferenceSession(str(args.model), sess_options=options, providers=['CPUExecutionProvider'])
    mean = np.array([.485, .456, .406], dtype=np.float32)
    std = np.array([.229, .224, .225], dtype=np.float32)
    report = []
    for i, path in enumerate(files, 1):
        with Image.open(path) as original:
            metadata = PngInfo()
            for key in ('prompt', 'workflow'):
                if key in original.info:
                    metadata.add_text(key, original.info[key])
            rgb = original.convert('RGB')
        pixels = np.asarray(rgb.resize((320, 320), Image.Resampling.LANCZOS), dtype=np.float32)
        pixels /= max(float(pixels.max()), 1e-6)
        tensor = ((pixels - mean) / std).transpose(2, 0, 1)[None]
        prediction = session.run(None, {session.get_inputs()[0].name: tensor})[0][0, 0]
        mask_values = (prediction - prediction.min()) / max(float(prediction.max()-prediction.min()), 1e-6)
        mask = Image.fromarray(np.uint8(np.clip(mask_values, 0, 1)*255)).resize(rgb.size, Image.Resampling.LANCZOS)
        # Remove extremely faint background residue while retaining antialiasing.
        mask = mask.point(lambda value: 0 if value < 8 else (255 if value > 247 else value))
        rgba = rgb.convert('RGBA')
        rgba.putalpha(mask)
        bbox = mask.getbbox()
        if not bbox:
            raise RuntimeError(f'Empty foreground mask: {path.name}')
        rank = None
        for family in [
            ['skonester_trait_yannian_dan', 'skonester_trait_yannian_dan_mid', 'skonester_trait_yannian_dan_best'],
            ['first_bloodline1', 'second_bloodline2', 'third_bloodline3', 'fourth_bloodline4', 'fifth_bloodline5'],
            ['toc_patrilinealblood', 'toc_patrilinealblood2', 'toc_patrilinealblood3'],
            ['bloodline_god_1', 'bloodline_god_2'],
        ]:
            if path.stem in family:
                rank = family.index(path.stem) + 1
        cropped = rgba.crop(bbox)
        scale = min(880 / cropped.width, (810 if rank else 880) / cropped.height)
        cropped = cropped.resize((round(cropped.width*scale), round(cropped.height*scale)), Image.Resampling.LANCZOS)
        master = Image.new('RGBA', (1024, 1024))
        master.alpha_composite(cropped, ((1024-cropped.width)//2, (940-cropped.height)//2 if rank else (1024-cropped.height)//2))
        marks = ImageDraw.Draw(master)
        if rank:
            # Explicit UI rank markers stay countable after downscaling.
            for n in range(rank):
                x = 512 + (n-(rank-1)/2)*64
                marks.ellipse((x-20, 925-20, x+20, 925+20), fill='#d8b46b', outline='#47341e', width=5)
                marks.ellipse((x-9, 912, x+1, 922), fill='#fff0bf')
        if path.stem == 'skonester_trait_marriage_ban':
            # The generated rings need an unambiguous prohibition mark.
            marks.line((230, 810, 794, 214), fill='#472c20', width=66)
            marks.line((230, 810, 794, 214), fill='#c6a16a', width=54)
            marks.line((230, 810, 794, 214), fill='#9f322c', width=38)
            marks.line((225, 803, 789, 207), fill='#e1735a', width=8)
        if path.stem == 'skonester_trait_stats_100_locked':
            # Typeset the exact attribute value on the generated lock faceplate.
            marks.ellipse((270, 445, 754, 770), fill='#30271c', outline='#b99653', width=10)
            marks.ellipse((286, 461, 738, 754), outline='#665034', width=4)
            numeral_font = ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf', 200)
            marks.text((512, 604), '100', font=numeral_font, anchor='mm', fill='#ead49a', stroke_width=3, stroke_fill='#17120e')
        master.save(destination / path.name, pnginfo=metadata)
        small = master.resize((120, 120), Image.Resampling.LANCZOS)
        small.save(small_dir / path.name, pnginfo=metadata)
        with Image.open(small_dir / path.name) as check:
            check.load()
            assert check.mode == 'RGBA' and check.size == (120, 120)
            assert check.getchannel('A').getextrema() == (0, 255)
        coverage = float((np.asarray(mask) > 127).mean())
        report.append({'trait_id': path.stem, 'foreground_coverage': round(coverage, 4),
                       'foreground_bbox': bbox, 'review_mask': coverage < .03 or coverage > .8})
        print(f'[{i}/{len(files)}] Transparent: {path.stem}', flush=True)

    font_path = Path('C:/Windows/Fonts/segoeui.ttf')
    font = ImageFont.truetype(str(font_path), 16) if font_path.exists() else ImageFont.load_default()
    jobs = {j['trait_id']: j for j in json.loads((BASE/'manifest.json').read_text(encoding='utf-8'))['jobs']}
    # Keep individual review sheets manageable, with originals beside the new icons.
    for page, start in enumerate(range(0, len(files), 12), 1):
        subset = files[start:start+12]
        sheet = Image.new('RGB', (1200, ((len(subset)+2)//3)*225), (37, 35, 34))
        draw = ImageDraw.Draw(sheet)
        for i, path in enumerate(subset):
            x, y = i%3*400, i//3*225
            job = jobs[path.stem]
            with Image.open(BASE/job['input_png']) as old:
                icon = old.convert('RGBA')
                icon.thumbnail((120,120), Image.Resampling.LANCZOS)
                sheet.paste(icon, (x+20+(120-icon.width)//2,y+25+(120-icon.height)//2), icon)
            with Image.open(small_dir/path.name) as new:
                sheet.paste(new, (x+190,y+25), new)
            draw.text((x+23,y+152), 'Original', fill='#aaa69f', font=font)
            draw.text((x+195,y+152), 'Redrawn', fill='#d6bd8d', font=font)
            draw.text((x+18,y+183), job['name'][:42], fill='white', font=font)
        sheet.save(source/f'comparison_{page:02}.jpg', quality=92)
    (source/'alpha_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'Finished {len(files)} icons. Review sheets: {source}', flush=True)


if __name__ == '__main__':
    main()
