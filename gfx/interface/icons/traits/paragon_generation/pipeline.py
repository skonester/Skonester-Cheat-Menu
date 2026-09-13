"""Reuse the established ComfyUI pipeline for the ancestor batch."""
import importlib
from pathlib import Path
import sys
BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE.parent / 'distinct_generation'))
actions = {'generate': 'run_comfy_batch', 'finish': 'finish_comfy_icons', 'collect': 'assemble_results', 'install': 'install_dds_icons'}
if len(sys.argv) < 2 or sys.argv[1] not in actions:
    raise SystemExit('Usage: python pipeline.py generate|finish|collect|install [options]')
action = sys.argv.pop(1)
module = importlib.import_module(actions[action])
module.BASE = BASE
if action == 'install':
    module.TRAITS = BASE.parent
    module.ROOT = BASE.parent.parents[3]
module.main()
