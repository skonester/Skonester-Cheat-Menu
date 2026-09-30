# agent.md — Skonester Cheat Menu Gold: open work after the 1.20 port

Working notes for anyone (human or AI agent) picking up the mod after the port to
**CK3 1.20.0.2 "Crozier" / By God Alone**. The full list of 1.19 → 1.20 engine changes is in
`ck3-mod-base/README.md`.

## Status

- The mod is ported to 1.20: religion (Faith → Rite, tenet database, doctrine groups), laws/law groups,
  elections, governments, on-actions, GUI data types, and renamed traits and keys.
- **First test run** (vanilla + this mod, 2026-09-30): no crash. Errors dropped from 23,768 to 11,577, and every
  1.20-specific error class went to zero.
- **After that run**, the regressions it showed and a batch of long-standing bugs were fixed. That second pass
  **has not been tested in-game yet**, so start with *Verify* below.
- The decision in the Realm & Government Tools group is rebranded to "Skonester Cheat Menu Gold - By God Alone"
  (EN/DE/RU/ZH/TR).

## Rules for this codebase

- **AGOT compatibility.** The mod also runs under A Game of Thrones and other total conversions. Never delete
  trait, religion, faith, doctrine, tenet, title or culture references just because they error in vanilla.
  Convert them, add a guard (`?=`, `exists = …`), or comment them out with a note. Lines marked
  `# AGOT compatibility:` are intentional.
- **Compatibility-mod keys are expected to fail in vanilla.** Keys from 变身大明 / Daming (`e_greatming`,
  `sansizhi_government`, `*_gov` flags), Orient Empires, and AGOT (dragon traits, `government_is_nw`) show up
  in a vanilla-only error.log. That's normal; `common/scripted_triggers/skonester_compat_triggers.txt` gates them.
- **Don't overwrite vanilla files wholesale.** Chain on-actions through `on_actions = { }`; never add a second
  `effect` to a vanilla on-action, because only one survives. Use `id_override_priority` for event overrides,
  and keep whole-file overrides (`gui/*.gui`, `09_mpo_values.txt`, `debug_l_*.yml`) rebased on current vanilla.
- **Generated files.** Several `*_generated.txt` files and the faith editor (`skonester_acm_faith_*_effects.txt`,
  about 150k lines) come from generator scripts that aren't in this repo, except
  `tools/gen_cw_tradition_picker_lists.py`. Anything fixed by hand here is lost the next time they're
  regenerated; see task 6.

## Verify first

1. Launch CK3 with `-debug_mode`, start a new game (don't load a 1.19 save), and let it reach the map.
2. Read `Documents/Paradox Interactive/Crusader Kings III/logs/error.log`. Copy it before relaunching; the game
   overwrites it on every start.
3. Check these fixes from the second pass:
   - Faith editor: open it, pick core tenets (the tenet list should show) and a doctrine (the doctrine list should
     show). Add and remove a tenet and a doctrine.
   - The interaction menu shows the Puppet selector, and the height control (xa_height) still works.
   - Ultra force marry / betrothal / divorce on a concubine.
   - Military supply cheat: the replenish modifier applies without a "doesn't match expected type" error.
   - Holding conversion decisions (castle / city / temple) in Realm & Government Tools.
   - Culture picker options show real language and heritage names instead of raw keys.

## Open tasks

### 1. Decide on the duplicate event IDs `skonester_cheat_menu.3020`–`3024` (high)
Both `events/skonester_beauty_companion_generated.txt` and
`events/skonester_cast_culture_faith_generated.txt` define these five IDs, and both sets are culture-picker
pages. The later-loaded file silently wins. Decide which set is current and renumber or remove the other,
together with every `trigger_event` that points at it. This also needs fixing in the generator.

### 2. More Tenet Slots vs. the 1.20 core-tenet cap (decision)
1.20 caps core tenets with `FAITH_CORE_TENETS_CAP = 3` (`NReligion`). The 20 `tenet_zz_empty_*` placeholder
tenets (now in `common/religion/tenet_types/`) can't do anything under that cap. Options:
- Add `NReligion = { FAITH_CORE_TENETS_CAP = 23 }` in a separate defines file. This also changes the vanilla
  Rite creation screen for everyone using the mod.
- Or retire the empty-tenet system.

Empty-tenet cleanup now only runs from `on_faith_created`. Players creating a new **Rite** inside an existing
faith (`on_rite_created`) aren't covered yet.

### 3. `tenet_monasticism` and `tenet_rite` (low)
Both were removed from vanilla in 1.20 (monasticism is now the `doctrine_monasticism_*` doctrine group). The
faith editor has them commented out and tagged `CK3 1.20:`. Restore them if AGOT still defines them, or replace
the monasticism entry with the doctrine group.

### 4. Domicile cheat is non-functional (medium)
`common/scripted_effects/skonester_domicile_cheat_effects.txt` uses effects that don't exist (`every_domicile`,
`set_domicile_level`, `every_character`, a bare `limit`). It's reachable from
`events/skonester_domicile_cheat_events.txt`. It needs a rewrite on real domicile effects.

### 5. Remaining script errors in bundled sub-mods (medium)
Each needs its original author's intent, so none were changed:
- `common/decisions/X_decisions.txt`: `limit` used as a trigger; landed_title vs. province scope mix-ups.
- `common/decisions/ch_minor_decisions.txt`: `subject = root.culture`, missing `ch_barony_is_valid_for_*`
  triggers (tribal / temple_citadel / nomad).
- `common/decisions/pcm_decisions.txt` and `pcm_building_decisions.txt`: unknown culture traditions,
  `add_culture_modifier`, `music`.
- zhuge files (`common/traits/zhuge_*.txt`, `005_zhuge_qita_decisions.txt`, `99_zhuge_character_interaction.txt`,
  `zhuge_bloodline_god_events.txt`): old trait fields placed inside modifier blocks, `is_baby`, `hide_window`.
- daddy_pika files: `sort_order`, `death_reason`, `is_player`.
- tocmod (`zzzzzzzz_0toc_*`): `has_culture_group`, missing effects, missing loc.
- `common/scripted_character_templates/00_water_of_life_templates.txt` and
  `events/decisions_events/water_of_life_decisions_events.txt`: `add_trait`/`sexuality` in the wrong block.
- `common/men_at_arms_types/notvanilla.txt`: unknown terrains, `ai_will_do`.
- `gfx/portraits/trait_portrait_modifiers/beauty_traits_dna_modifiers.txt`: `morph` key.
- `00_special_gift_1-4.txt`: `target` used as an effect.

### 6. Put the generators under version control (medium)
Add the scripts that produce `skonester_acm_faith_*_effects.txt`, `skonester_ce_unl_doctrines.txt`,
`skonester_cast_culture_faith_generated.txt`, `skonester_beauty_companion_generated.txt`,
`skonester_global_pillars_on_selected_generated.txt`, etc. to `tools/`. Port them to the 1.20 rules below so
regeneration doesn't undo the port:
- Tenets use `has_tenet` / `add_tenet` / `remove_tenet`.
- Doctrines carry `doctrine_group_type`, `index` and `divergence`; CE ethics uses one group per slot
  (`doctrine_ethics_unl_<sins|virtues>_slot_N`).
- Event options use `language_*_name` / `heritage_*_name` loc keys.
- Removed faiths become `set_character_rite = rite:<key>`.
- The GUI uses `DoctrineType` / `TenetType`.

### 7. Faith editor: new 1.20 content (enhancement)
The tenet catalog doesn't include the 25 tenets added in 1.20 (e.g. `tenet_dulia`, `tenet_purgatory`,
`tenet_simony`, `tenet_miles_christi`). Consider Rite-level editing (`set_character_rite`, `rite_has_doctrine`),
Spiritual Fulfillment and personal tenets as new cheats.

### 8. Localization gaps (low)
- About 490 `Unrecognized loc key` lines remain, mostly sub-mod text (`X_*_tooltip`, `tocmod.*`,
  `skonester_cheat_menu.3091–3097` option texts, artifact names from other mods).
- The new English-only files need translations for DE/RU/ZH/TR:
  - `skonester_ce_unl_doctrine_names_l_english.yml`
  - `skonester_ce_unl_doctrine_groups_l_english.yml`
  - `skonester_1_20_faith_labels_l_english.yml`

### 9. Script lint warnings (low)
About 1,200 "variable/flag is used but never set" warnings. Most are values set from the GUI, which the checker
can't see. Clean them up only where a feature is actually dead.

### 10. Optional polish (low)
- `stress_impact` still works in 1.20, but `stress_and_fulfillment_impact` also moves Spiritual Fulfillment.
- The theocracy conversion cheats set `theocracy_government`. Christians get `ecclesiastical_government` in 1.20;
  consider picking the faith's own theocracy type.
- Sand Soldiers maps the removed `teutonic_knights` to `order_serjeants`. Consider also adding `order_knights`.

## Release checklist

- [ ] Verify pass above is clean.
- [ ] Task 1 resolved.
- [ ] Bump `version` in `descriptor.mod`. It still says `9.27.26-PreBGA`; `supported_version` is already `1.20.*`.
- [ ] Commit.
