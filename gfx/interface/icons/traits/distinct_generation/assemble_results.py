"""Collect reviewed ComfyUI runs into one named set and a local comparison gallery."""
from pathlib import Path
import hashlib
import html
import json
import shutil

from PIL import Image, ImageDraw, ImageFont
from PIL.PngImagePlugin import PngInfo

from run_comfy_batch import api, ui_workflow

BASE = Path(__file__).resolve().parent


def main():
    jobs = json.loads((BASE / 'manifest.json').read_text(encoding='utf-8'))['jobs']
    destination = BASE / 'results'
    for directory in ['masters', 'png', 'renders', 'workflows']:
        (destination / directory).mkdir(parents=True, exist_ok=True)
    overrides_file = BASE / 'selected_runs.json'
    overrides = json.loads(overrides_file.read_text()) if overrides_file.exists() else {}
    info = api('/object_info')
    selections = []
    fingerprints = set()
    cards = []
    font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 16)
    sheets = []

    for index, job in enumerate(jobs):
        trait = job['trait_id']
        run = overrides.get(trait, 'refined' if (BASE/'generated/refined'/f'{trait}.png').exists() else 'v1')
        folder = BASE/'generated'/run
        prompt = json.loads((folder/f'{trait}.api.json').read_text())
        workflow = ui_workflow(prompt, info)
        metadata = PngInfo()
        metadata.add_text('prompt', json.dumps(prompt))
        metadata.add_text('workflow', json.dumps(workflow))
        for input_folder, output_folder, size in [('transparent', 'masters', 1024), ('icons_120', 'png', 120)]:
            with Image.open(folder/input_folder/f'{trait}.png') as image:
                image.load()
                assert image.size == (size, size) and image.mode == 'RGBA', trait
                assert image.getchannel('A').getextrema() == (0, 255), trait
                image.save(destination/output_folder/f'{trait}.png', pnginfo=metadata)
                if size == 120:
                    fingerprint = hashlib.sha256(image.tobytes()).hexdigest()
                    assert fingerprint not in fingerprints, f'Duplicate result: {trait}'
                    fingerprints.add(fingerprint)
        shutil.copy2(folder/f'{trait}.png', destination/'renders'/f'{trait}.png')
        (destination/'workflows'/f'{trait}.json').write_text(json.dumps(workflow, indent=2), encoding='utf-8')
        selections.append(dict(trait_id=trait, name=job['name'], selected_run=run,
                               original_dds=job['source_icon'], proposed_dds=job['proposed_output_dds'],
                               requires_icon_reference_change=job['requires_icon_reference_change'],
                               seed=prompt['6']['inputs']['seed'],
                               denoise=prompt['6']['inputs']['denoise'],
                               positive_prompt=prompt['4']['inputs']['text']))
        safe_name = html.escape(job['name'])
        safe_description = html.escape(job['description'])
        cards.append(f'''<article data-search="{html.escape((job['name']+' '+trait).lower(), quote=True)}">
<h2>{safe_name}</h2><p class="id">{trait}</p>
<div class="pair"><figure><div class="image"><img src="../{job['input_png']}" alt="Original {safe_name}"></div><figcaption>Original</figcaption></figure>
<figure><div class="image"><a href="masters/{trait}.png"><img src="png/{trait}.png" alt="Redrawn {safe_name}"></a></div><figcaption>Redrawn · 120 px</figcaption></figure></div>
<p class="description">{safe_description}</p><nav><a href="masters/{trait}.png">1024 px PNG</a><a href="png/{trait}.png">120 px PNG</a><a href="workflows/{trait}.json">Workflow</a></nav></article>''')
        page, cell = divmod(index, 12)
        if cell == 0:
            sheets.append(Image.new('RGB', (1200, 900), (37, 35, 34)))
        sheet = sheets[page]
        draw = ImageDraw.Draw(sheet)
        x, y = cell % 3 * 400, cell // 3 * 225
        with Image.open(BASE/job['input_png']) as original:
            old = original.convert('RGBA')
            old.thumbnail((120, 120), Image.Resampling.LANCZOS)
            sheet.paste(old, (x+20+(120-old.width)//2, y+25+(120-old.height)//2), old)
        with Image.open(destination/'png'/f'{trait}.png') as new:
            sheet.paste(new, (x+190, y+25), new)
        draw.text((x+23, y+152), 'Original', fill='#aaa69f', font=font)
        draw.text((x+195, y+152), 'Redrawn', fill='#d6bd8d', font=font)
        label = job['name']
        while draw.textlength(label, font=font) > 365:
            label = label[:-2]
        draw.text((x+18, y+183), label, fill='white', font=font)

    for page, sheet in enumerate(sheets, 1):
        count = min(12, len(jobs) - (page-1)*12)
        sheet = sheet.crop((0, 0, 1200, ((count+2)//3)*225))
        sheet.save(destination/f'comparison_{page:02}.jpg', quality=94)

    document = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Skonester · Trait icon review</title>
<style>
:root{color-scheme:dark;font-family:Segoe UI,Arial,sans-serif;background:#181716;color:#e8e3da}
*{box-sizing:border-box}body{margin:0 auto;max-width:1500px;padding:38px 28px}
h1{font-family:Georgia,serif;font-size:36px;font-weight:400;margin:0 0 12px;color:#e4cda4}
.intro{max-width:850px;color:#bcb5a8;line-height:1.6}header{margin-bottom:30px}
.controls{display:flex;gap:14px;align-items:center;flex-wrap:wrap;margin:24px 0}
input{background:#252320;color:#fff;border:1px solid #5f5340;padding:12px 16px;border-radius:5px;font:inherit;min-width:320px}
button{background:#3b3329;color:#f3dec0;border:1px solid #776347;border-radius:5px;padding:12px 16px;cursor:pointer}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:20px}
article{background:#252320;border:1px solid #403a30;border-radius:8px;padding:22px}
h2{font-size:18px;font-weight:500;margin:0 0 6px;color:#e5cfaa}
.id{font-family:monospace;font-size:11px;color:#9d968a;overflow-wrap:anywhere;margin:0 0 20px}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:10px}figure{margin:0}
.image{height:150px;display:flex;align-items:center;justify-content:center;background:#211f1d;border-radius:4px}
.image img{max-width:120px;max-height:120px;object-fit:contain}figcaption{font-size:12px;text-align:center;margin:9px 0;color:#b5aa98}
.description{font-size:13px;line-height:1.5;min-height:42px;color:#b7b0a4}
nav{display:flex;gap:15px;font-size:12px;flex-wrap:wrap}a{color:#d7b980;text-decoration:none}a:hover{text-decoration:underline}
.light .image{background:#e8e4db}footer{margin:30px 0;color:#938b7d;font-size:13px}
</style><header><h1>Skonester · Trait icon review</h1>
<p class="intro">__TRAIT_COUNT__ distinct redraws, generated locally from the existing icons. Compare each original with its replacement at 120 pixels. Click a new icon to inspect the transparent 1024-pixel master.</p>
<p class="intro">Each redraw has a trait-specific subject and a transparent background. The original PNGs are preserved for comparison. DDS installation is a separate step, recorded in installation.json when completed.</p>
<div class="controls"><input id="search" type="search" placeholder="Find a trait…" aria-label="Find a trait"><button id="background">Toggle light background</button><span id="count">__TRAIT_COUNT__ traits</span></div></header>
<main class="grid">''' + '\n'.join(cards) + '''</main>
<footer>DreamShaper XL · image-to-image · transparent PNGs · per-trait ComfyUI workflows</footer>
<script>
document.getElementById('search').addEventListener('input',e=>{
const term=e.target.value.toLowerCase();let n=0;
document.querySelectorAll('article').forEach(card=>{const show=card.dataset.search.includes(term);card.hidden=!show;if(show)n++;});
document.getElementById('count').textContent=n+' traits';
});
document.getElementById('background').addEventListener('click',()=>document.body.classList.toggle('light'));
</script></html>'''
    document = document.replace('__TRAIT_COUNT__', str(len(jobs)))
    (destination/'review.html').write_text(document, encoding='utf-8')
    (destination/'selection.json').write_text(json.dumps(selections, ensure_ascii=False, indent=2), encoding='utf-8')
    assert len(list((destination/'png').glob('*.png'))) == len(jobs)
    print(f'Collected and verified {len(jobs)} unique transparent icons, masters, workflows and review gallery.')
    print(destination)


if __name__ == '__main__':
    main()

