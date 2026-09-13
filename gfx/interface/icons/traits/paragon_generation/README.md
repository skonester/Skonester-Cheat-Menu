# Steward, Paragon, and Grace icon update

The Steward of Wonders and Paragon redraws use the installed Warlord Anointed master as their direct image-to-image style reference. Grace of the Valar receives a white dove and olive-branch emblem instead of the reused winged saint artwork.

The launcher points to a separate mod copy at `C:/Users/admin/Documents/Paradox Interactive/Crusader Kings III/mod/mod1`. Its Mystic Seer definition still pointed to `savant_intrig.dds`, although the two distinct textures were already present. Deployment patches that one icon reference while preserving the rest of the file.

`results/` contains the comparison gallery, transparent masters, 100px DDS exports, and installation records. Repository backups are under `backups/`; launcher-copy backups are under `active_mod_backups/`.

Generation uses the shared local ComfyUI pipeline in `../distinct_generation`. The per-trait reference path, prompts, seeds, and workflows are saved with this batch. Original icons are retained in `inputs/` for comparison.
