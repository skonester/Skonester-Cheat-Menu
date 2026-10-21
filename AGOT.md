# AGOT.md — why A Game of Thrones crashes on CK3 1.20.1

Notes on A Game of Thrones (AGOT) compatibility with CK3 1.20 "Crozier" (By God Alone), so we know what has to
change before Skonester Cheat Menu Gold can support AGOT again. Based on one test run on 2026-10-21 with **AGOT
alone**: no Skonester, no other mods.

## Summary

AGOT 0.5.2.1 is still built for CK3 1.19. It loads to the main menu on 1.20.1.1, but **the game crashes as soon
as a game is started from a bookmark**. Several of CK3 1.20's database formats changed, and AGOT's files are still
in the 1.19 format, so the game rejects them. The crash is almost certainly caused by religion: none of AGOT's
faiths load, so characters fall back to a vanilla faith whose religion AGOT has deleted.

This is AGOT's to fix, not ours. Nothing in Skonester needs to change until AGOT ships a 1.20 build.

## Test setup

| | |
|---|---|
| Game | CK3 1.20.1.1 (Crozier), Steam, branch `release/1.20.1` |
| DLC | All 23 owned DLC enabled, including By God Alone |
| Mods | A Game of Thrones 0.5.2.1 (Workshop `2962333032`) only |
| Crash folder | `Documents/Paradox Interactive/Crusader Kings III/crashes/ck3_20261021_020031/` |
| Result | `EXCEPTION_ACCESS_VIOLATION` in `ck3.exe` (the stack trace has no function names) |
| error.log | 94,623 lines |

## Crash timeline

From `debug.log` / `error.log` in the crash folder:

| Time | What happened |
|---|---|
| 02:00:02 | Database loading. AGOT's religion, law and government files are rejected (see below). |
| 02:00:27 | `Setup completion (history loaded)`: the game reaches the main menu. |
| 02:00:30 | A bookmark is started: `Start running through history`. |
| 02:00:31 | Hundreds of `fots_seven is not a valid faith for province history` (and every other AGOT faith). |
| 02:00:31 | `Unknown faith 'valyrian_pan_freehold' for character history of 'animation_test_female', defaulting to first scripted faith`. This is the last line written. |
| 02:00:31 | Crash. |

So AGOT does **not** crash at startup on 1.20.1.1. It crashes when you start a game. (Our `agent.md` recorded a
startup crash for AGOT 0.5.2.1 on CK3 1.20.0.2.)

## Root cause: religions (most likely crash trigger)

CK3 1.20 split religions into separate databases. Faiths moved out of the religion file into
`common/religion/faith_types/`, and rites and tenets got their own folders (`rite_types/`, `tenet_types/`).
AGOT still writes every religion in the 1.19 layout, with `family`, `graphical_faith` and a nested `faiths = { }`
block. 1.20 rejects all three keys in all 22 AGOT religion files:

```
Unexpected token: family           (22 files)
Unexpected token: graphical_faith  (22 files)
Unexpected token: faiths           (22 files)
```

Result:

1. **No AGOT faith exists.** Every province and character history that names an AGOT faith (`fots_seven`,
   `old_gods_*`, `rhllor_fc`, `fc_pan_*`, `valyrian_pan_freehold`, …) is rejected.
2. **The vanilla faiths that survive are broken.** AGOT uses `replace_path` on `religion_types`, which deletes
   vanilla's religions. It doesn't replace `faith_types` (that folder didn't exist in 1.19), so vanilla's 103
   faiths still load, but each points at a religion that no longer exists. The log shows
   `'christianity_religion' … could not be found in the database` and the same for every other vanilla religion,
   plus 9,451 `faith 'X': missing custom localization` lines.
3. **The crash.** A character with an invalid faith is given "the first scripted faith". That's vanilla's `aluk`,
   whose religion `aluk_religion` AGOT deleted. The game crashes on that first character. The minidump has no
   symbols, so this is inferred from the timing (it's the last thing logged), not proven.

What AGOT needs: move each faith into `common/religion/faith_types/` (with `faith_details = { religion = … }` and
a `main_rite`), use the new `religion_details = { family = … }` block in `religion_types`, and add its rites and
tenets in `rite_types/` and `tenet_types/`. `common/religion/*/_*.info` in the 1.20 game folder documents the formats.

## Other 1.20 incompatibilities (not the crash, but would break play)

### Laws: 1.19 nested law groups
1.20 moved law groups into their own folder, `common/law_groups/`, and each law is now a top-level entry with
`law_group_type = <group>`. AGOT ships 1.19-format copies of vanilla's `00_realm_laws.txt`,
`00_succession_laws.txt`, `01_title_succession_laws.txt` and `02_admininistrative_laws.txt`, which **replace
vanilla's 1.20 files**, plus its own `01_agot_realm_laws.txt` and `02_agot_free_cities_laws.txt`. 1.20 rejects their
group-level keys (`Unexpected token: default` / `cumulative` / `is_treasury_budget_group`), so whole law groups are lost.
- Missing laws include vanilla ones: `male_only_law`, `male_preference_law`, `equal_law`, `female_preference_law`,
  `female_only_law`, `noble_family_succession_law`, `confederate_partition_succession_law`,
  `landless_adventurer_succession_law`, `camp_purpose_*`, `nomadic_authority_*`; and AGOT's own
  `norvos_regency_succession_law`.
- About 3,300 `has_realm_law … Cannot find … in law database` errors follow from this, plus missing law flags
  (`vassal_refusal_is_treason`, `title_revocation_allowed`, `male_rulers`, …).

### Governments: removed government rules
AGOT's `00_agot_government_types.txt` and its copies of vanilla's `00_government_types.txt` and
`01_japan_government_types.txt` use the government rules `religious = yes/no` and `administrative = yes`. 1.20 removed
both (`mechanic_type = theocracy` / `administrative` covers them now). This causes `Unexpected enum found`
errors and about 680 `government_allows … Not a valid government rule` errors in scripts.

### Shaders: 1.19 copies of vanilla shaders
AGOT overrides five vanilla shader files: `gfx/FX/pdxmesh.shader`, `pdxmesh_decal.shader`, `tree.shader`,
`pdxterrain.shader` and `pdxwater.shader`. The 1.20 renderer can't compile them (`Texture Samplers have same binding
index 'ShadowTexture'`, about 5,300 `Failed creating shader state`), so 3D meshes, decals and trees use broken
materials. These may become a second crash source once the religion crash is fixed.

### Portraits and GUI (cosmetic)
- About 12,000 `Invalid … node` lines from AGOT's portrait environments and cameras (`environment_ep`,
  `environment_fp`, `camera_head`, …) referencing nodes that aren't on 1.20's portrait skeleton.
- AGOT GUI files use removed data functions, e.g. `FaithDoctrine.GetGroup.GetCategory` and the
  `container_tenet_item_small` type.

## What this means for Skonester

- Skonester Cheat Menu Gold and AGOT **can't be used together on 1.20** until AGOT releases a 1.20 build.
- Skonester's AGOT-aware code (government flags like `government_is_uninteractable` and `government_is_nw` in Force
  Vassal) is harmless without AGOT and stays as is.
- `agent.md` open task 3 (`tenet_monasticism` / `tenet_rite` kept commented until AGOT supports 1.20) still applies.

## What to look for in an AGOT update

Check these in the next AGOT release before testing Skonester with it:

1. `descriptor.mod` `supported_version` is `1.20.*`.
2. AGOT has `common/religion/faith_types/` (and probably `rite_types/`, `tenet_types/`).
3. AGOT has `common/law_groups/`, or its law files use `law_group_type`.
4. Its government files no longer use `religious =` / `administrative =` rules.

## How to re-test

1. Enable AGOT alone and start a game from a bookmark (loading to the main menu isn't enough).
2. If it crashes, check the newest `crashes/ck3_*/` folder: the last lines of `logs/error.log` show where it stopped.
3. In `error.log`, these counts should be zero: `Unexpected token: faiths`, `is not a valid faith for province
   history`, `Cannot find '…' in law database`, `Unexpected enum found`.
4. Once AGOT alone starts a game, add Skonester Cheat Menu Gold and repeat.
