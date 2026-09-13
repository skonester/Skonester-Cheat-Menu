"""Prepare per-trait regeneration inputs for reused artwork. Requires Pillow.

Run beside the DDS files after convert_dds_to_png.py. No game files are edited.
"""

from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re
import shutil

from PIL import Image


BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
OUT = BASE / 'distinct_generation'
TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|#[^\n]*|[{}=]|[\w.-]+')


def blocks(text):
    tokens = [t for t in TOKEN.finditer(text) if not t.group().startswith('#')]
    depth = 0
    for i, token in enumerate(tokens):
        if token.group() == '{':
            if depth == 0:
                name, start = tokens[i - 2].group(), token.end()
            depth += 1
        elif token.group() == '}':
            depth -= 1
            if depth == 0:
                yield name, text[start:token.start()]


def main():
    loc = {}
    for path in sorted((ROOT / 'localization/english').glob('*.yml')):
        loc.update(re.findall(r'^\s*([\w.-]+):\d*\s*"(.*)"', path.read_text(encoding='utf-8-sig'), re.M))

    def localized(key):
        value = loc.get(key, '')
        for _ in range(8):
            updated = re.sub(r'\$([\w.-]+)\$', lambda m: loc.get(m[1], m[0]), value)
            if updated == value:
                break
            value = updated
        return value

    images, signatures, groups = {}, {}, defaultdict(list)
    for path in sorted((BASE / 'png').glob('*.png')):
        with Image.open(path) as image:
            rgba = image.convert('RGBA')
            signature = str(rgba.size) + ':' + hashlib.sha256(rgba.tobytes()).hexdigest()
        images[path.stem] = path
        signatures[path.stem] = signature
        groups[signature].append(path.stem)

    traits, users = [], defaultdict(list)
    for path in sorted((ROOT / 'common/traits').glob('*.txt')):
        for trait, body in blocks(path.read_text(encoding='utf-8-sig')):
            match = re.search(r'^\s*icon\s*=\s*"([^"]+)"', body, re.M)
            icon = Path(match[1]).stem if match else trait
            if icon not in images:
                continue
            name_match = re.search(r'^\s*name\s*=\s*([\w.-]+)', body, re.M)
            label = localized(name_match[1]) if name_match else ''
            label = label or localized('trait_' + trait) or localized(trait) or trait
            description = localized('trait_' + trait + '_desc') or localized(trait + '_desc')
            record = dict(trait_id=trait, name=label, description=description,
                          source_icon=icon + '.dds', definition_file=path.relative_to(ROOT).as_posix())
            traits.append(record)
            users[signatures[icon]].append(trait)

    # Art direction proposals, based on the actual localized trait meanings.
    subjects = {
        'skonester_trait_marriage_ban': 'Two separated wedding rings divided by a stern iron seal; no chalice or potion.',
        'skonester_trait_yannian_dan': 'A simple jade elixir bottle with one small gold bead.',
        'skonester_trait_yannian_dan_mid': 'An ornate jade elixir bottle with two gold beads; same silhouette as the basic longevity elixir.',
        'skonester_trait_yannian_dan_best': 'An imperial jade elixir bottle with three gold beads and a restrained golden halo; same family as the lesser elixirs.',
        'skonester_trait_immortal_ageless': 'An unbroken golden ring enclosing an evergreen sprig and a still hourglass.',
        'trait_eternal_nether_lord': 'A dark sovereign crown enclosing a cold violet flame, imposing and composed.',
        'trait_nether_conspiracy_lord': 'A black dagger passing behind a veiled crown, with a subtle violet shadow.',
        'trait_ultimate_intrigue_master': 'An open watchful eye inside a silver divination mirror, with a concealed dagger below.',
        'trait_great_builder_god': 'A golden mason compass over a precisely cut stone arch, with restrained divine light.',
        'trait_warlord_eternal': 'A crowned steel helmet before crossed war banners, with a restrained golden halo.',
        'trait_wealth_sovereign_max': 'A royal treasury chest overflowing with a few large gold coins beneath a small crown.',
        'tyranny_gain_remove': 'Balanced justice scales over a sealed legal parchment.',
        'insane_generale': 'A western captain helmet above a sword and a small white-tree heraldic motif.',
        'insane_opinion_fv': 'A faceless black hood beneath nine small iron crown points.',
        'insane_opinion_fa': 'A shadowed iron gauntlet gripping an oath chain.',
        'crazyminded_psycho': 'A cracked dark heart pierced by an iron thorn, with a restrained ember glow.',
        'water_of_life': 'A sacred chalice before an open illuminated scripture, with soft holy light.',
        'toc_gamer0': 'A deceptive half-mask with a concealed dagger.',
        'toc_gamerblood0': 'A dark tower enclosing a crimson blood gem and faint whispering wisps.',
        'toc_immortal': 'A pale undying flame inside a silver ring.',
        'toc_immortalblood': 'A luminous blood droplet enclosing a tiny star, framed by ancestral branches.',
        'immortality': 'A golden infinity knot surrounding a living green leaf.',
        'greatest_lord_np': 'A stewardship key laid across a stone keep.',
        'greatest_lord_t': 'A noble coronet above three small heraldic shields.',
        'pantokratorus_a': 'A single high king crown above a royal sceptre.',
        'pantokratorus_ablood': 'A royal crown above a blood gem with branching ancestral roots.',
        'borntorule_seed': 'A reforged sword beneath a seven-pointed star and a small heir coronet.',
    }
    for index, trait in enumerate(['first_bloodline1', 'second_bloodline2', 'third_bloodline3', 'fourth_bloodline4', 'fifth_bloodline5'], 1):
        subjects[trait] = f'A western heraldic tree with a blood-red gem, tier {index} of five; use {index} clear gold rank studs and progressively richer branches. Keep the family silhouette consistent.'
    for index, trait in enumerate(['toc_patrilinealblood', 'toc_patrilinealblood2', 'toc_patrilinealblood3'], 1):
        subjects[trait] = f'A paternal ancestral tree growing from a signet ring, tier {index} of three, with {index} prominent silver rank studs and progressively richer heraldry.'
    for index in (1, 2):
        subjects[f'bloodline_god_{index}'] = f'A sacred blood droplet inside a radiant ancestral crest, rank {index} of the Barbara bloodline; {index} clear gold rank studs. Preserve family resemblance while making the rank readable.'

    (OUT / 'inputs').mkdir(parents=True, exist_ok=True)
    (OUT / 'prompts').mkdir(exist_ok=True)
    selected = []
    for record in traits:
        trait, icon = record['trait_id'], Path(record['source_icon']).stem
        signature = signatures[icon]
        if len(users[signature]) < 2 and len(groups[signature]) < 2:
            continue
        record['same_artwork_files'] = [name + '.dds' for name in groups[signature]]
        record['same_artwork_traits'] = users[signature]
        record['input_png'] = f'inputs/{trait}.png'
        record['proposed_output_dds'] = trait + '.dds'
        record['requires_icon_reference_change'] = trait != icon
        record['reason'] = 'Multiple traits resolve to identical decoded RGBA artwork.'
        record['prompt'] = (
            f'Create a distinct Crusader Kings III style trait icon for {record["name"]}. '
            f'Trait meaning: {record["description"]} '
            f'Subject: {subjects.get(trait, "Choose a unique medieval emblem expressing this specific trait meaning.")} '
            'Use the supplied image as a reference for icon format, palette and painted finish; '
            'replace its borrowed subject where it conflicts with this trait. '
            'One clear centered emblem, refined hand-painted shading, restrained highlights, '
            'strong silhouette and generous edge padding, readable at small game UI size. '
            'No lettering, no watermark, no scenery, no checkerboard pattern. '
            'Keep related bloodline and elixir tiers visually related but visibly distinguishable.'
        )
        target = OUT / record['input_png']
        if target.exists():
            if target.read_bytes() != images[icon].read_bytes():
                raise RuntimeError(f'Refusing to overwrite changed input: {target}')
        else:
            shutil.copy2(images[icon], target)
        assert target.read_bytes() == images[icon].read_bytes(), target
        (OUT / 'prompts' / (trait + '.txt')).write_text(record['prompt'] + '\n', encoding='utf-8')
        selected.append(record)

    report = dict(
        scope='Exact decoded RGBA duplicates and shared icon references within this mod; not a visual near-duplicate or vanilla-asset audit.',
        source_png_count=len(images), mapped_trait_count=len(traits), selected_trait_count=len(selected),
        duplicate_file_groups=[names for names in groups.values() if len(names) > 1],
        jobs=selected,
    )
    (OUT / 'manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    lines = [
        '# Traits needing distinct artwork', '',
        f'{len(selected)} per-trait inputs selected from {len(images)} original PNGs.', '',
        'Inputs are copies of the current artwork, NOT newly generated images. Originals remain untouched.',
        'Each input is named for its trait ID, including traits currently sharing one DDS filename.', '',
        'Use inputs/ for the image batch. Pair each image with its matching prompts/<trait_id>.txt.',
        'The prompt files are generation briefs; ComfyUI must be configured to load the corresponding prompt for each image.',
        'manifest.json contains the trait meanings, duplicate groups, source mappings and proposed output names.', '',
        'Every member of a reused-artwork group is included so you can decide which version to retain.',
        'Related tiers should receive coordinated variations rather than unrelated symbols.',
        'Selection uses exact decoded pixels and trait icon references; similar but nonidentical images are not assessed.', '',
        'After generation, clean the alpha channel and export DDS. For rows marked yes below,',
        'the trait definition must later point to the proposed unique DDS filename.',
        'No trait definitions have been changed during preparation.', '',
        '| Trait ID | Display name | Current DDS | Change icon reference later |',
        '|---|---|---|---|',
    ]
    for record in selected:
        change = 'yes' if record['requires_icon_reference_change'] else 'no'
        lines.append(f'| {record["trait_id"]} | {record["name"]} | {record["source_icon"]} | {change} |')
    (OUT / 'README.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'Prepared and verified {len(selected)} per-trait PNG inputs and matching prompts.')
    print(f'Duplicate file groups: {len(report["duplicate_file_groups"])}')
    print(f'Later icon reference changes: {sum(r["requires_icon_reference_change"] for r in selected)}')
    print(OUT)


if __name__ == '__main__':
    main()
