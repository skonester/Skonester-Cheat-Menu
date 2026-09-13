"""Run the prepared trait icons through local ComfyUI image-to-image.

Requires Pillow and a running ComfyUI at http://127.0.0.1:8188.
Example: python run_comfy_batch.py --only skonester_trait_marriage_ban --run-name pilot
Existing completed outputs are skipped. Use a new --run-name for variations.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import time
from urllib import request, parse, error
import uuid

from PIL import Image


BASE = Path(__file__).resolve().parent
SERVER = 'http://127.0.0.1:8188'
CHECKPOINT = 'DreamShaperXL_Turbo_v2_1.safetensors'
NEGATIVE = ('photograph, photorealistic, portrait, person, face, hands, full body, scenery, '
            'landscape, room, floor, text, letters, words, watermark, logo, interface, '
            'multiple panels, grid, checkerboard, cropped, cut off, blurry, flat vector, '
            'plastic, neon, excessive glow, clutter, tiny intricate details')


def api(route, data=None):
    req = request.Request(SERVER + route, data=None if data is None else json.dumps(data).encode(),
                          headers={'Content-Type': 'application/json'})
    try:
        with request.urlopen(req, timeout=30) as response:
            return json.load(response)
    except error.HTTPError as exc:
        raise RuntimeError(exc.read().decode()) from exc


def upload(job, size):
    with Image.open(BASE / job.get('generation_input_png', job['input_png'])) as original:
        icon = original.convert('RGBA')
        bounds = icon.getchannel('A').getbbox()
        if bounds:
            icon = icon.crop(bounds)
        icon.thumbnail((round(size * .76), round(size * .76)), Image.Resampling.LANCZOS)
        # thumbnail does not enlarge the small source icons.
        scale = size * .76 / max(icon.size)
        icon = icon.resize((round(icon.width * scale), round(icon.height * scale)), Image.Resampling.LANCZOS)
        canvas = Image.new('RGB', (size, size), (28, 27, 26))
        canvas.paste(icon, ((size-icon.width)//2, (size-icon.height)//2), icon)
    buffer = io.BytesIO()
    canvas.save(buffer, format='PNG')
    boundary = uuid.uuid4().hex
    name = f'skonester_{job["trait_id"]}_{size}.png'
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\n'
            'Content-Type: image/png\r\n\r\n').encode() + buffer.getvalue()
    body += (f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="overwrite"\r\n\r\ntrue'
             f'\r\n--{boundary}--\r\n').encode()
    req = request.Request(SERVER + '/upload/image', data=body,
                          headers={'Content-Type': f'multipart/form-data; boundary={boundary}'})
    with request.urlopen(req, timeout=30) as response:
        result = json.load(response)
    return '/'.join(filter(None, [result.get('subfolder'), result['name']]))


def graph(job, image, args):
    subject = job['prompt'].split('Subject: ', 1)[1].split(' Use the supplied image', 1)[0]
    overrides_path = BASE / 'generation_overrides.json'
    overrides = json.loads(overrides_path.read_text(encoding='utf-8')) if overrides_path.exists() else {}
    override = overrides.get(job['trait_id'], {})
    subject = override.get('subject', subject)
    if subject.startswith('Choose a unique'):
        subject = job['name'] + '. ' + job['description']
    positive = (
        '(single medieval game trait icon:1.2), ' + subject + ' '
        'medieval grand strategy hand-painted inventory icon, isolated centered emblem, '
        'aged gold and silver, rich muted pigments, painterly brushwork, dimensional sculpted shading, '
        'crisp readable silhouette, restrained highlights, one large clear symbol, '
        'plain uniform dark charcoal background, generous empty border, front view, high quality.'
    )
    seed = (int(hashlib.sha256(job['trait_id'].encode()).hexdigest()[:12], 16) + args.seed_offset) % (2**48)
    return {
        '1': {'class_type': 'CheckpointLoaderSimple', 'inputs': {'ckpt_name': CHECKPOINT}},
        '2': {'class_type': 'LoadImage', 'inputs': {'image': image}},
        '3': {'class_type': 'VAEEncode', 'inputs': {'pixels': ['2', 0], 'vae': ['1', 2]}},
        '4': {'class_type': 'CLIPTextEncode', 'inputs': {'text': positive, 'clip': ['1', 1]}},
        '5': {'class_type': 'CLIPTextEncode', 'inputs': {'text': NEGATIVE + override.get('negative', ''), 'clip': ['1', 1]}},
        '6': {'class_type': 'KSampler', 'inputs': {
            'model': ['1', 0], 'positive': ['4', 0], 'negative': ['5', 0], 'latent_image': ['3', 0],
            'seed': seed, 'steps': args.steps, 'cfg': 2.0, 'sampler_name': 'dpmpp_sde',
            'scheduler': 'karras', 'denoise': override.get('denoise', args.denoise)}},
        '7': {'class_type': 'VAEDecode', 'inputs': {'samples': ['6', 0], 'vae': ['1', 2]}},
        '8': {'class_type': 'SaveImage', 'inputs': {
            'images': ['7', 0], 'filename_prefix': f'Skonester/{args.run_name}/{job["trait_id"]}'}},
    }


def ui_workflow(prompt, info):
    nodes, links = [], []
    positions = {'1': [20, 20], '2': [20, 340], '3': [400, 740], '4': [400, 20],
                 '5': [400, 370], '6': [820, 20], '7': [1170, 20], '8': [1500, 20]}
    for key, item in prompt.items():
        spec = info[item['class_type']]
        node = {'id': int(key), 'type': item['class_type'], 'pos': positions[key],
                'size': [360, 300] if key in ('2', '4', '5', '8') else ([310, 360] if key == '6' else [310, 260]),
                'flags': {}, 'order': int(key)-1, 'mode': 0, 'inputs': [],
                'outputs': [{'name': name, 'type': kind, 'links': []}
                            for name, kind in zip(spec.get('output_name', spec['output']), spec['output'])],
                'properties': {'Node name for S&R': item['class_type']}, 'widgets_values': []}
        for name, value in item['inputs'].items():
            if isinstance(value, list):
                source, slot = value
                kind = info[prompt[source]['class_type']]['output'][slot]
                link = len(links) + 1
                links.append([link, int(source), slot, int(key), len(node['inputs']), kind])
                node['inputs'].append({'name': name, 'type': kind, 'link': link})
        for name in spec['input'].get('required', {}):
            if name in item['inputs'] and not isinstance(item['inputs'][name], list):
                node['widgets_values'].append(item['inputs'][name])
                if name == 'seed':
                    node['widgets_values'].append('fixed')
        if item['class_type'] == 'LoadImage':
            node['widgets_values'].append('image')
        nodes.append(node)
    by_id = {n['id']: n for n in nodes}
    for link, source, slot, *_ in links:
        by_id[source]['outputs'][slot]['links'].append(link)
    return {'last_node_id': 8, 'last_link_id': len(links), 'nodes': nodes, 'links': links,
            'groups': [], 'config': {}, 'extra': {}, 'version': 0.4}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', nargs='+')
    parser.add_argument('--run-name', default='v1')
    parser.add_argument('--denoise', type=float, default=.88)
    parser.add_argument('--steps', type=int, default=8)
    parser.add_argument('--size', type=int, default=1024)
    parser.add_argument('--seed-offset', type=int, default=0)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.run_name):
        parser.error('run-name must contain only letters, numbers, underscores or hyphens')
    jobs = json.loads((BASE / 'manifest.json').read_text(encoding='utf-8'))['jobs']
    if args.only:
        unknown = set(args.only) - {j['trait_id'] for j in jobs}
        if unknown:
            parser.error(f'Unknown traits: {sorted(unknown)}')
        jobs = [j for j in jobs if j['trait_id'] in args.only]
    out = BASE / 'generated' / args.run_name
    out.mkdir(parents=True, exist_ok=True)
    info = api('/object_info')
    models = info['CheckpointLoaderSimple']['input']['required']['ckpt_name'][0]
    if CHECKPOINT not in models:
        raise RuntimeError(f'Model is not ready in ComfyUI: {CHECKPOINT}')
    for index, job in enumerate(jobs, 1):
        trait = job['trait_id']
        output = out / (trait + '.png')
        if output.exists():
            print(f'[{index}/{len(jobs)}] Already generated: {trait}', flush=True)
            continue
        image = upload(job, args.size)
        prompt = graph(job, image, args)
        workflow = ui_workflow(prompt, info)
        (out / (trait + '.api.json')).write_text(json.dumps(prompt, indent=2), encoding='utf-8')
        (out / (trait + '.workflow.json')).write_text(json.dumps(workflow, indent=2), encoding='utf-8')
        queued = api('/prompt', {'prompt': prompt, 'client_id': 'skonester-trait-batch',
                                'extra_data': {'extra_pnginfo': {'workflow': workflow}}})
        prompt_id = queued['prompt_id']
        print(f'[{index}/{len(jobs)}] Generating {trait}: {prompt_id}', flush=True)
        started = time.monotonic()
        last = started
        while True:
            history = api('/history/' + prompt_id)
            if prompt_id in history:
                result = history[prompt_id]
                if result.get('status', {}).get('status_str') == 'error':
                    raise RuntimeError(json.dumps(result['status']))
                saved = result['outputs']['8']['images'][0]
                with request.urlopen(SERVER + '/view?' + parse.urlencode(saved), timeout=30) as response:
                    data = response.read()
                with Image.open(io.BytesIO(data)) as check:
                    check.load()
                    if check.size != (args.size, args.size):
                        raise RuntimeError(f'Unexpected generated image size: {check.size}')
                output.write_bytes(data)
                (out / (trait + '.result.json')).write_text(json.dumps(result, indent=2), encoding='utf-8')
                print(f'  Saved and verified {output.name} ({time.monotonic()-started:.0f}s)', flush=True)
                break
            if time.monotonic() - started > 1800:
                raise TimeoutError(f'ComfyUI job still pending: {prompt_id}; check queue before retrying')
            if time.monotonic() - last > 30:
                print(f'  Waiting for {trait}: {time.monotonic()-started:.0f}s', flush=True)
                last = time.monotonic()
            time.sleep(3)
    print(f'Completed {len(jobs)} requested traits. Output: {out}', flush=True)


if __name__ == '__main__':
    main()
