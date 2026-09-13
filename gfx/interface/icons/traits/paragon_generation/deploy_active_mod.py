"""Install this batch in the launcher's mod1 copy and repair the Mystic Seer icon."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys

BASE = Path(__file__).resolve().parent
REPO = BASE.parent.parents[3]
ACTIVE = Path(r'C:\Users\admin\Documents\Paradox Interactive\Crusader Kings III\mod\mod1')
sys.path.insert(0, str(BASE.parent/'distinct_generation'))
from install_dds_icons import trait_span


def main():
    assets = Path('gfx/interface/icons/traits')
    payload = {}
    for name in ['super_governor', 'super', 'goodguy_toc']:
        payload[assets/(name+'.dds')] = (BASE/'results/dds_100'/(name+'.dds')).read_bytes()
    # Ensure both distinct, already-reviewed intrigue images exist in the active mod.
    for name in ['savant_intrig', 'trait_ultimate_intrigue_master']:
        payload[assets/(name+'.dds')] = (REPO/assets/(name+'.dds')).read_bytes()
    definition = Path('common/traits/skonester_intrigue_traits.txt')
    original = (ACTIVE/definition).read_bytes()
    text = original.decode('utf-8')
    start, end = trait_span(text, 'trait_ultimate_intrigue_master')
    body = text[start:end]
    matches = list(re.finditer(r'(?m)^([ \t]*icon[ \t]*=[ \t]*")([^"\r\n]+)(")', body))
    if len(matches) != 1 or matches[0][2] not in ('savant_intrig.dds', 'trait_ultimate_intrigue_master.dds'):
        raise RuntimeError('Unexpected Mystic Seer icon mapping in active mod')
    match = matches[0]
    body = body[:match.start(2)]+'trait_ultimate_intrigue_master.dds'+body[match.end(2):]
    payload[definition] = (text[:start]+body+text[end:]).encode('utf-8')
    savant = (ACTIVE/'common/traits/savant_traits.txt').read_bytes().decode('utf-8')
    a, z = trait_span(savant, 'savant_intrig')
    icon = re.search(r'(?m)^\s*icon\s*=\s*"([^"]+)"', savant[a:z])
    if icon and icon[1] != 'savant_intrig.dds':
        raise RuntimeError('Unexpected Savant icon mapping in active mod')

    changed = {}
    for relative, data in payload.items():
        target = ACTIVE/relative
        if not target.resolve().is_relative_to(ACTIVE.resolve()):
            raise ValueError('Target outside active mod')
        old = target.read_bytes() if target.exists() else None
        if old != data:
            changed[relative] = (old, data)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = BASE/'active_mod_backups'/stamp
    backup.mkdir(parents=True)
    records = []
    for relative, (old, new) in changed.items():
        if old is not None:
            path = backup/relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(old)
            assert path.read_bytes() == old
        records.append(dict(path=str(relative), existed=old is not None,
                            before_sha256=hashlib.sha256(old).hexdigest() if old is not None else None,
                            after_sha256=hashlib.sha256(new).hexdigest()))
    written = []
    try:
        for relative, (old, new) in changed.items():
            target = ACTIVE/relative
            if (target.read_bytes() if target.exists() else None) != old:
                raise RuntimeError(f'Active mod file changed during preparation: {relative}')
            written.append(relative)
            target.write_bytes(new)
            assert target.read_bytes() == new
    except Exception:
        for relative in reversed(written):
            old = changed[relative][0]
            if old is None:
                (ACTIVE/relative).unlink(missing_ok=True)
            else:
                (ACTIVE/relative).write_bytes(old)
        raise
    report = dict(status='installed', active_mod=str(ACTIVE), backup=str(backup), files=records,
                  fix='Mystic Seer now references trait_ultimate_intrigue_master.dds; Savant retains savant_intrig.dds.')
    (backup/'installation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    (BASE/'results/active_mod_installation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'Installed {len(changed)} changed files in the launcher mod copy.')
    print(f'Backups: {backup}')


if __name__ == '__main__':
    main()

