"""Export selected icons as 100x100 RGBA DDS; use --install to replace game assets.

Requires Pillow. Backs up every changed file before installation. Existing
unrelated textures and trait settings are preserved. Run without --install
to prepare and verify exports and trait-file patches only.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

from PIL import Image


BASE = Path(__file__).resolve().parent
TRAITS = BASE.parent
ROOT = TRAITS.parents[3]
TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|#[^\n]*|[{}=]|[\w.-]+')


def trait_span(text, name):
    tokens = [t for t in TOKEN.finditer(text) if not t.group().startswith('#')]
    depth = 0
    found = []
    for i, token in enumerate(tokens):
        if token.group() == '{':
            if depth == 0:
                current, start = tokens[i - 2].group(), token.end()
            depth += 1
        elif token.group() == '}':
            depth -= 1
            if depth == 0 and current == name:
                found.append((start, token.start()))
    if len(found) != 1:
        raise ValueError(f'Expected exactly one trait definition for {name}, found {len(found)}')
    return found[0]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    selected = json.loads((BASE/'results/selection.json').read_text(encoding='utf-8'))
    jobs = {j['trait_id']: j for j in json.loads((BASE/'manifest.json').read_text(encoding='utf-8'))['jobs']}
    dds_dir, png_dir = BASE/'results/dds_100', BASE/'results/png_100'
    dds_dir.mkdir(exist_ok=True)
    png_dir.mkdir(exist_ok=True)
    edits, originals, reference_updates = {}, {}, []
    targets = set()
    for selection in selected:
        trait = selection['trait_id']
        job = jobs[trait]
        filename = job['proposed_output_dds']
        if Path(filename).name != filename or not filename.endswith('.dds') or filename in targets:
            raise ValueError(f'Invalid or repeated output name: {filename}')
        targets.add(filename)
        with Image.open(BASE/'results/masters'/f'{trait}.png') as master:
            rgba = master.convert('RGBA').resize((100, 100), Image.Resampling.LANCZOS)
        if rgba.getchannel('A').getextrema() != (0, 255):
            raise ValueError(f'Missing full transparency or opaque foreground: {trait}')
        rgba.save(png_dir/f'{trait}.png')
        export = dds_dir/filename
        # Legacy DDS with uncompressed 32-bit BGRA, straight alpha, one surface.
        # This preserves every resized pixel and avoids BC compression artifacts.
        rgba.save(export, format='DDS')
        with Image.open(export) as check:
            check.load()
            if check.size != (100, 100) or check.convert('RGBA').tobytes() != rgba.tobytes():
                raise ValueError(f'DDS round-trip mismatch: {trait}')
        target = TRAITS/filename
        originals[target] = target.read_bytes() if target.exists() else None
        edits[target] = export.read_bytes()

        definition = ROOT/job['definition_file']
        if not definition.resolve().is_relative_to(ROOT/'common/traits'):
            raise ValueError(f'Trait definition outside common/traits: {definition}')
        if job['requires_icon_reference_change']:
            if definition not in originals:
                originals[definition] = definition.read_bytes()
            text = edits.get(definition, originals[definition]).decode('utf-8')
            start, end = trait_span(text, trait)
            body = text[start:end]
            pattern = re.compile(r'(?m)^([ \t]*icon[ \t]*=[ \t]*")([^"\r\n]+)(")')
            matches = list(pattern.finditer(body))
            if len(matches) != 1:
                raise ValueError(f'Expected one explicit icon reference for {trait}')
            match = matches[0]
            if match[2] not in (job['source_icon'], filename):
                raise ValueError(f'Unexpected current icon for {trait}: {match[2]}')
            updated = body[:match.start(2)] + filename + body[match.end(2):]
            edits[definition] = (text[:start] + updated + text[end:]).encode('utf-8')
            reference_updates.append(dict(trait_id=trait, file=job['definition_file'],
                                          previous=match[2], new=filename))
        else:
            text = definition.read_bytes().decode('utf-8')
            start, end = trait_span(text, trait)
            match = re.search(r'(?m)^\s*icon\s*=\s*"([^"]+)"', text[start:end])
            actual_icon = match[1] if match else trait + '.dds'
            if actual_icon != filename:
                raise ValueError(f'Trait {trait} resolves to {actual_icon}, not {filename}')

    stage = BASE/'results/trait_patches'
    for path, data in edits.items():
        if path.parent != TRAITS:
            staged = stage/path.relative_to(ROOT)
            staged.parent.mkdir(parents=True, exist_ok=True)
            staged.write_bytes(data)
    changed = {p: b for p, b in edits.items() if originals[p] != b}
    print(f'Exported and pixel-verified {len(selected)} transparent 100x100 DDS files.')
    print(f'Prepared {len(reference_updates)} icon references in {len({r["file"] for r in reference_updates})} trait files.')
    print(f'Pending file changes: {len(changed)}')
    if not args.install:
        print('Prepared only. Run with --install to back up and install.')
        return
    if not changed:
        print('Already installed; no files changed.')
        return

    # Detect edits made while preparing, before any game files are replaced.
    for path in changed:
        actual = path.read_bytes() if path.exists() else None
        if actual != originals[path]:
            raise RuntimeError(f'File changed during preparation: {path}')
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = BASE/'backups'/stamp
    backup.mkdir(parents=True)
    records = []
    for path, data in changed.items():
        relative = path.relative_to(ROOT)
        old = originals[path]
        if old is not None:
            saved = backup/relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            saved.write_bytes(old)
            if saved.read_bytes() != old:
                raise RuntimeError(f'Backup verification failed: {path}')
        records.append(dict(path=relative.as_posix(), existed=old is not None,
                            before_sha256=digest(old) if old is not None else None,
                            after_sha256=digest(data)))
    record = dict(status='backed_up', export_size=[100, 100], format='32-bit BGRA DDS, straight alpha, no mipmaps',
                  files=records, icon_reference_updates=reference_updates)
    report_path = backup/'installation.json'
    report_path.write_text(json.dumps(record, indent=2), encoding='utf-8')
    written = []
    try:
        for path, data in changed.items():
            written.append(path)
            path.write_bytes(data)
            if path.read_bytes() != data:
                raise RuntimeError(f'Installed file verification failed: {path}')
    except Exception:
        for path in reversed(written):
            if originals[path] is None:
                path.unlink(missing_ok=True)
            else:
                path.write_bytes(originals[path])
        record['status'] = 'rolled_back'
        report_path.write_text(json.dumps(record, indent=2), encoding='utf-8')
        raise
    record['status'] = 'installed'
    report_path.write_text(json.dumps(record, indent=2), encoding='utf-8')
    (BASE/'results/installation.json').write_text(json.dumps(dict(record, backup=str(backup)), indent=2), encoding='utf-8')
    print(f'Installed {len(selected)} DDS icons and updated their trait references.')
    print(f'Backup: {backup}')


if __name__ == '__main__':
    main()
