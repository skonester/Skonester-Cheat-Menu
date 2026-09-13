# Ancestor and additional trait icons

This batch covers the 10 active blood_ancester traits (1, 2, 4 through 11), Peace of Mind, Maxed Attributes (Locked), Poison Immunity, Plague Immunity, Blood of the Dunedain, and Blood of Numenor.

Source images are preserved in inputs/. Prompts and original trait mappings are recorded in manifest.json and generation_overrides.json.

ComfyUI model and tools are reused from ../distinct_generation. Run from this folder:

```powershell
python pipeline.py generate --run-name v2 --seed-offset 1
python pipeline.py finish --run-name v2
```

The selected collection is saved in results/: transparent 1024px masters, comparison gallery, 120px previews, and 100px DDS/PNG exports. DDS installation is recorded in results/installation.json, with backups under backups/.

The inactive blood_ancester_10_back texture is not an active trait and is left alone. There is no active blood_ancester_3 definition in this mod.

The locked-attributes icon uses a generated medieval padlock with an exact typeset 100 faceplate, added during PNG finishing.

Installation complete: all 16 DDS textures replaced at 100x100 with straight alpha. No trait-definition changes were needed. The prior 42 installed icons are unchanged. In-game appearance has not been tested.
