# CK3 Localization Files Reference

_Updated: 2026-04-26_

## Master Consolidated File

All localization entries from this mod have been unified into a single master file for performance and easier maintenance:

- **File Path:** `mod1/data_binding/fully_consolidated_l_english.yml`
- **Consolidation Tool:** `mod1/data_binding/rebuild_loc_mod1.py`
- **Total Source Files Unified:** 55

## Usage Instructions

When you add new localization files or change existing ones, you should re-run the consolidation script to update the master file:

1. Open a terminal (PowerShell or CMD).
2. Run the script using Python:
   ```powershell
   python "c:\Users\admin\Documents\Paradox Interactive\Crusader Kings III\mod\mod1\data_binding\rebuild_loc_mod1.py"
   ```
3. The script will output the number of keys processed and update the `fully_consolidated_l_english.yml` file.

## Complete List of Unified Files

The following files were scanned and their unique keys were merged into the master consolidated file:

- DB_buildings_l_english.yml
- DP_char_editor_events_l_english.yml
- DP_char_spawn_events_l_english.yml
- DP_currency_menu_events_l_english.yml
- DP_information_l_english.yml
- DP_interactions_l_english.yml
- DP_traits_l_english.yml
- auto_marriage_l_english.yml
- bone_interactions_l_english.yml
- ch_specialinteractions_l_english.yml
- cheateb_amain_l_english.yml
- cheateb_event_l_english.yml
- debug_l_english.yml
- debug_start_era_of_crusades_interaction_interactions_l_english.yml
- dlc_zhuge_l_english.yml
- eka_impregnate_l_english.yml
- fake_dlc_l_english.yml
- house_guard_l_english.yml
- jkm_send_courtier_abroad_l_english.yml
- knightBlood_l_english.yml
- leech_mc_events_l_english.yml
- leech_mc_l_english.yml
- missing_localization_l_english.yml
- my_mod_l_english.yml
- new_tocmod_l_english.yml
- optroop_interaction_l_english.yml
- pcm_b_decisions_l_english.yml
- pcm_characterinteractionwindow_l_english.yml
- pcm_decision_group_types_l_english.yml
- pcm_decisions_l_english.yml
- pcm_main_l_english.yml
- pcm_traits_l_english.yml
- savant_l_english.yml
- skone_succession_laws_l_english.yml
- skonester_char_design_events_l_english.yml
- skonester_collapse_xaction_l_english.yml
- skonester_create_titular_l_english.yml
- skonester_holy_dynasty_l_english.yml
- skonester_merge_kingdoms_l_english.yml
- skonester_taurus_update_l_english.yml
- skonester_yyz_l_english.yml
- special_gift_l_english.yml
- water_of_life_decisions_l_english.yml
- water_of_life_events_l_english.yml
- zhueg_traits_l_english.yml
- zhuge_character_interaction_l_english.yml
- zhuge_chuantong_l_english.yml
- zhuge_curry_menu_events_l_english.yml
- zhuge_deathreasons_l_english.yml
- zhuge_health_modifiers_l_english.yml
- zhuge_qita_decisions_l_english.yml
- zz_skonester_aquarius_update_l_english..yml
- zz_skonester_cultural_polygamy_l_english.yml
- zz_skonester_pisces_update_l_english..yml
- zz_sol_unrestricted_warfare_l_english.yml

## Functional Categories

### Character Management & Cheats

- `cheateb_amain_l_english.yml` / `cheateb_event_l_english.yml`: Main cheat menu and event logic.
- `skonester_char_design_events_l_english.yml`: Character designer and transformation events.
- `DP_char_editor_events_l_english.yml`: Core character editor functionalities.
- `pcm_main_l_english.yml` / `pcm_traits_l_english.yml`: Immortality, traits, and enhancement options.

### Buildings & Holdings

- `DB_buildings_l_english.yml`: Custom building definitions.
- `pcm_b_decisions_l_english.yml`: Decision-based building construction and management.
- `ch_specialinteractions_l_english.yml`: Holding type conversion and specialization.

### Systems & Mechanics

- `auto_marriage_l_english.yml`: Automated marriage and eugenics system.
- `skonester_holy_dynasty_l_english.yml`: Holy dynasty and religious role mechanics.
- `skone_succession_laws_l_english.yml`: Custom succession law logic.
- `zz_sol_unrestricted_warfare_l_english.yml`: Unrestricted conquest and warfare system.

### 2026 Updates (Taurus/Aries Season)

- `skonester_taurus_update_l_english.yml`: Recent fixes and religion/culture expansion.
- `zz_skonester_pisces_update_l_english..yml`: Previous seasonal feature additions.
- `zz_skonester_aquarius_update_l_english..yml`: Early 2026 system refinements.

## Maintenance Note

When adding new localization keys, it is recommended to add them to their respective functional files and then re-run the consolidation script to update the master file. The game engine reads the master file from the `data_binding` folder for optimized access.
