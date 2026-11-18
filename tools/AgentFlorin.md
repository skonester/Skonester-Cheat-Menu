# CK3 / Skonester error-log audit — 2026-11-18

The main problem is an incomplete **CK3 1.20 → 1.21 migration**. The running executable identifies itself as `release/1.21.0` in `system.log:1`; both Skonester descriptors still declare `supported_version="1.20.*"`. The enabled-mods file lists only `mod/mod1.mod`.

This document records the original investigation before repairs. Subsequent changes and their verification are tracked in [FIX_PROGRESS.md](FIX_PROGRESS.md); the log snapshot below remains the original baseline.

**Latest count:** **2,534 logged entries through 15:53:18**, including 1,406 analyzer notices, 1,076 other startup records and 52 UI/runtime messages. Earlier runtime floods are absent. The user has finished the feature-test drills; focus on ordinary logs and concrete remaining errors. O9/O10 address the invalid brand markup and undefined optional YYZ bindings. See [the current inventory and fixes](current-error-inventory/README.md).

## Evidence and counting

- [Preserved error log](error.snapshot.log): **5,440 timestamped error records**, from 10:21:12 through 10:29:12 in the November 18 session. Multiline messages count once. Repeated validation messages are included; this is not 5,440 independent bugs.
- [System log](system.snapshot.log) and [enabled mods](enabled-mods.snapshot.json) preserve the version/playset evidence.
- [Every parsed record](records.json), [grouped signatures](error-groups.json), and [counts by engine/file](summary.json) retain the complete inventory, including smaller issues omitted from the priority list below.
- **1,210** records say a variable/flag is used but never set; **67** report orphaned events; **25** report unused modifiers. These are lower-priority static diagnostics, not proof that a feature fails at runtime. GUI-set variables and console-only events need individual review.
- 2,676 records name a file present in this mod; 952 name a vanilla file; 1,812 contain no recognizable script path. These are location counts, not responsibility counts: vanilla helpers also fail when a mod expands them with invalid arguments.

Reference checkout: `C:/Users/admin/Documents/GitHub/ck3-mod-base`. Its `base/.ck3-version.json` identifies 1.21.0 Florin. Use **`base/game/`**, not the repository's example `mod/` directory. The principal guide is [1.21.md](<C:/Users/admin/Documents/GitHub/ck3-mod-base/1.21.md>), particularly sections 4–7, 18 and 23. Exact shipped source takes precedence over a guessed rename.

## 1. Rebase the character and interaction windows first

### Missing `hbox_trade_posts` — confirmed mod override problem

Five records complain that `hbox_trade_posts` is invalid in vanilla `window_government_republic.gui:2015` and `window_trade.gui:336`.

The missing type is actually defined in **vanilla `gui/window_character.gui:4761`**. Skonester replaces that entire file with an older version that contains no `hbox_trade_posts` definition. The vanilla character GUI in `ck3-mod-base` is byte-identical to the installed character GUI, which supports this diagnosis.

**Repair:** rebase Skonester's `gui/window_character.gui` onto `base/game/gui/window_character.gui`, then reapply its portrait/menu additions. Preserve the new trade-post type and other current character-view content. Fixing the two complaining vanilla screens would miss the cause.

### Removed interaction function — exact replacement verified

`gui/interaction_menu_window.gui:516` calls:

```text
CharacterInteractionMenuWindow.AreMoreInteractionsVisisble
```

The current vanilla file, line 451, uses:

```text
CharacterInteractionMenuWindow.AreMoreInteractionsVisible
```

This produces six records across two evaluations (missing function, failed conversion, failed property parsing). Correct the spelling and rebase the surrounding interaction window onto current vanilla.

Other runtime overrides to review are `gui/frontend_ingame_menu.gui`, `gui/interaction_confirmation.gui`, `common/script_values/09_mpo_values.txt`, and `common/on_action/dlc/tgp/tgp_china_minister_on_action.txt`. A matching filename replaces vanilla content even if the mod's intended change is small.

## 2. Rebuild building cheats around districts

This is the largest concentration of functional errors. The log contains:

| Symptom | Error records |
| --- | ---: |
| `has_building` trigger failures | 748 |
| Missing building targets in `upgrade_building_effect` | 352 |
| Missing building targets in `start_building_construction_for_holder` | 205 |
| Province/district effect-scope mismatch | 112 |
| Missing targets in `can_start_building_construction_for_owner` | 41 |
| `has_building_or_higher` trigger failures | 29 |

These rows describe separate log messages, including related failures from the same underlying call. Additional `PostValidate ... returned false` records repeat many of the failures.

Start with:

- `common/scripted_effects/skonester_crozier_cheats_effects.txt:2`: the giant generated upgrade pass and its later build/upgrade paths. This file accounts for 1,073 location-attributed records overall.
- `common/scripted_effects/skonester_foreman_building_effects.txt:1`: old building chains, `upgrade_guildhall`, `upgrade_tradeport`, and callers of `add_next_building_tier_effect`.
- `common/decisions/pcm_building_decisions.txt`: 314 location-attributed records overall, including district scope and old building targets.
- `common/decisions/X_decisions.txt:73`: province-scoped building effects.
- Building operations in `events/skonester_cheat_menu_events.txt` and government-conversion helpers.

**Repair:** use the current district and building databases together. Select/create the appropriate district, then apply its building operations in the correct scope. Rebuild catalogs from active 1.21 definitions and actual `next_building` chains, including separate handling for holding, regular, special, duchy and great districts. Confirm available engine effects/scopes with a fresh 1.21 script-documentation dump before writing the iterator.

`base/game/common/scripted_effects/00_building_effects.txt:1166` shows why restoring an old helper is insufficient: `add_next_building_tier_effect` now expands `$BUILDING$_1` through `_5` and starts construction. Skonester still supplies old chains and assumes old behavior. The 656 records naming this vanilla file need their Skonester callers fixed.

The six unknown `upgrade_guildhall` and six unknown `upgrade_tradeport` errors likewise require new district-specific behavior, not revival of old province helpers.

References: `1.21.md` section 7; `base/game/common/districts/_districts.info`; `base/game/common/buildings/_buildings.info`; current `00_building_effects.txt`. `_old_buildings.info` is documentation, not an active database.

## 3. Port custom duchy buildings, modifiers and economy tools together

### Custom buildings have the old definition layout

There are **72** `Unexpected token: type` records in the custom `DB_duchy_*.txt` buildings. For example, `DB_duchy_Common.txt` still places `type = duchy_capital` on the building.

**Repair:** create wrapping district definitions with `type = duchy_capital` and the intended `primary_building`, following `base/game/common/districts/duchy_capital_districts.txt`. Remove the old type field from the building only as part of that conversion. Review availability, costs, upgrades and scope-dependent conditions. Add district names/descriptions and migrate building localization from `building_<key>` to `<key>` where required by the current UI. Simply deleting the rejected field would not restore correct placement or accessibility.

### Removed modifier types

All **179** unknown-modifier records fall into these groups:

| Old name | Records | Repair |
| --- | ---: | --- |
| `development_growth_factor` | 63 | `prosperity_growth_factor` |
| `development_growth` | 11 | `prosperity_growth` |
| `county_opinion_add` | 54 | `popular_opinion_add` |
| `county_opinion_add_even_if_baron` | 3 | `popular_opinion_add_even_if_baron` |
| `different_faith_county_opinion_mult` and `_even_if_baron` | 4 | Corresponding `different_faith_popular_opinion_*` names |
| `tax_mult` | 24 | Choose a supported all/category tax modifier for the actual scope and intent |
| `monthly_county_control_growth_*`, including baron variants | 18 | Redesign with control baseline/convergence modifiers |
| `character_capital_county_monthly_development_growth_add` | 2 | Verify the supported Prosperity capital modifier and its scope |

Affected files include `common/traits/knightBlood.txt`, `common/modifiers/DP_modifiers.txt`, `common/modifiers/zzzzzzzz_00_toc_modifiers.txt`, and the `DB_duchy_*.txt` files. The complete per-file inventory is in `records.json`.

There are also **47** records rejecting `monthly_income` in a **province** modifier. Use an appropriate `monthly_<category>_tax`, such as `monthly_generic_tax`, after checking intent. Keep valid **character** `monthly_income` modifiers.

Old control-growth bonuses need a behavior choice: `control_baseline_add` changes the target control; convergence modifiers change how control approaches it. Do not copy the old number into an unrelated new field.

### Development APIs and election weights

Confirmed failures include `change_development_level`, `change_development_progress_with_overflow`, `development_level`, and `county_opinion`.

Apply the current equivalents where the scope and behavior match:

```text
development_level        -> prosperity_level
change_development_level -> change_prosperity_level
county_opinion           -> popular_opinion
innovation_development_01 ... _04 -> innovation_prosperity_01 ... _04
```

`common/succession_election/99_peasant_elective.txt:18–29` still calculates votes using Development and county opinion. Convert both the trigger/value expressions and the explanatory localization in `localization/*/skone_succession_laws_l_*.yml`; its old bracketed concepts currently cause localization data-function errors too.

Rebase `common/script_values/09_mpo_values.txt:2934`, and update sorting in `skonester_official_land_cap_effects.txt:530` and `skonester_replace_official_effects.txt:1384`.

References: `1.21.md` sections 4, 5, 6, 7 and 18. Avoid a global replacement of the English word “development”; custom IDs and some surviving game APIs use it legitimately.

## 4. Repair domicile cleanup and innovation catalogs

### Domicile cleanup uses a six-tier helper on shorter chains

The log contains **41** missing domicile-building targets in `lower_domicile_building_no_refund`, 41 invalid `has_domicile_building` validations, and 82 corresponding `PostValidate` failures: 164 records naming vanilla `domicile_effects.txt`.

The caller is `skonester_domicile_clear_external_chain_fully_effect` near the end of `common/scripted_effects/skonester_cheat_menu_domicile_preset_effects.txt`. It always expands `destroy_or_downgrade_estate_building_6_effect`, which generates checks/effects for tiers that do not exist on several base chains.

Examples verified against `base/game/common/domiciles/buildings/00_estate_buildings.txt`: base `workshop` and `storage` have `_01` and `_02`; base `garden` and `stable` have `_01` through `_03`; their specialized branches use separate IDs. Existing branch-specific logic already acknowledges this distinction.

**Repair:** dispatch each base chain to its real two-/three-/other-tier helper, or generate cleanup from actual definitions. Preserve the branch-before-base order. A runtime `if` does not prevent the parser from validating an invalid hardcoded building target.

### Innovation add/remove/requirements need a current inventory

There are **59** missing-target `add_innovation` records, **39** invalid `has_innovation` records, and **12** missing-target `remove_innovation` records, plus downstream validation failures.

The four `innovation_development_*` IDs have verified `innovation_prosperity_*` replacements. `innovation_bombards` in `skonester_cw_innovation_picker_sgui.txt` and `innovation_visigothic_codes` in `gender_Succession_decisions_mod.txt` also do not exist in the current vanilla innovation files; inspect their intended replacement instead of guessing one. Some innovation errors originate in the custom building definitions and shared catalogs, so review callers beyond the picker GUI.

## 5. Fix smaller, concrete script failures

| Location | Finding | Repair supported by current source/log |
| --- | --- | --- |
| `skonester_government_mass_conversion_effects.txt:262`, 273, 334, 345, 383, 394, 432, 443 | `culture = japanese` parsed as an invalid event-target link | Use `culture = culture:japanese`, matching vanilla usage |
| `common/decisions/003_daddy_pikas_decisions.txt:22` and eight other creation blocks | Nine new noble-family titles lack `save_scope_as` | Add a suitable unique saved scope inside each creation block; see `10_dlc_tgp_scripted_effects.txt:4373` |
| `common/decisions/pcm_decisions.txt:595` | Branch relic helper missing `RELIGION` | Pass the intended religion scope as well as `OWNER`; see `00_ep1_inspiration_effects.txt:1352` |
| `skonester_positions_mass_reshuffle_effects.txt:285` and seven similar calls | `can_be_kurultai_trigger` missing `CP1`, `CP2`, `CP3` | Supply the other three council seats for each destination seat, following `00_council_positions.txt:3067`; do not give every call the same seat exclusions |
| `skonester_ultra_force_marry_effect.txt:123`, 126 | `add_opinion` has `opinion = 200` but no modifier | Define/reuse an opinion modifier with the intended value and pass its key using the supported modifier field |
| `common/decisions/005_zhuge_qita_decisions.txt:126–153` | Character has no location/employer; death block has an invalid reason/type and `killer = none` | Give the character a valid location/employer; use the current death schema and a valid death reason; omit an absent killer |
| `events/skonester_create_titular_events.txt:187`, 329 | Description read twice | Merge the competing description definitions into one supported description structure |
| `events/skonester_char_design_events.txt:39631` | `create_title_and_vassal_change` has no type | Set the change type appropriate to the actual transfer; compare current vanilla examples |
| `common/character_interactions/99_skonester_consolidated.txt:1624`, 1695 | `holy_dynasty.0004` / `.0003` referenced but not defined | Restore the intended events or correct their IDs and entry conditions |
| `events/Realm_Succession_events_mod.txt` | Eight invalid `change_Realm_succession_law_game_mod_on` checks | Remove obsolete gates where the menu already supplies the restriction, or implement the intended rule; a previous fix only covered the decision file |
| `localization/*/pcm*_decisions_l_*.yml` | `#Skonester` is interpreted as an unknown formatting tag; 18 records in the active language | Use plain text or a real format, e.g. `#bold Skonester:#!`; preserve translated wording |
| `common/casus_belli_groups/sol_casus_belli_groups.txt` | Missing UTF-8 BOM | Save as UTF-8 with BOM |

Also review the invalid PCM artifact modifier IDs, missing `FAITH_WINDOW_TENET_TOOLTIP` and `CV_THEOCRACY_LESSEE_TOOLTIP` localization, custom blood-trait labels, missing building icons, and duplicate `strong_test_hook` / `UNCATEGORIZED_ACTIONS` localization. These are recorded with their exact evidence in the JSON inventory.

## 6. Keep optional compatibility data separate from core repairs

**135** records name the AGOT tradition list in `skonester_cw_tradition_picker_lists_generated.txt`. Daming/Orient integration produces additional missing governments, titles, characters, traits, events and on-actions in `yan_on_action.txt`, `GM_value_on_action.txt`, and related files. `agent.md` explicitly says to preserve these references and their compatibility behavior.

Do not delete all unknown IDs to make a vanilla log quiet. Runtime guards can prevent execution while still allowing load-time database validation errors. Keep the guards and distinguish compatibility-only records when comparing logs; optional modules/submods are an architectural option if completely clean vanilla loading is required.

The **185** title-link records are a mixture: external compatibility titles and Skonester's own undefined authority/expansion titles. The latter need real definitions or disabled/unreachable features; they should not all be excused as AGOT noise. The old authority/expansion monthly hooks were already discussed in `agent.md`, but definitions in unused helpers can still validate at load time.

## 7. Vanilla-origin candidates need a baseline run

The following errors point into current vanilla content and have no direct file override in this mod:

- Generated map object count mismatch in `gfx/map/map_object_data/great_wall_china_gate.txt`.
- Four invalid-character `save_scope_as` evaluations in `common/character_interactions/gdp_republic_interactions.txt:3503`.
- Missing debug/merchant localization was initially placed here, but the subsequent review found that the mod's old English/German `debug_l_*.yml` replacements omit current vanilla keys. See [the remaining-work review](remaining-review/README.md); rebase those overrides in part 12.
- Dynamic trigger localization missing `house_dynasty_equal_third` / `house_dynasty_equal`.

These are **candidates**, not proven vanilla bugs. Reproduce them with the same CK3 version and DLC set, no mods, and a new game before changing vanilla behavior. This audit did not interrupt the running game or launch a second baseline session.

The `hbox_trade_posts` errors are intentionally excluded from this list: their mod-side cause was found in section 1.

## Repair and verification order

1. Rebase the character and interaction GUI, preserving Skonester additions.
2. Port building catalogs/effects and custom duchy districts as one coherent migration.
3. Migrate economy modifiers, election weights and innovation references; decide the intended control and tax behavior.
4. Correct domicile tier dispatch, helper parameters, government/title creation and the smaller script/localization issues.
5. Start a fresh debug game with just Skonester. Exercise the interaction menu, character/trade/republic screens, build/max-building tools, Foreman, custom duchy construction, estate presets, innovation add/remove, Peasant Elective, government changes and artifact creation. Then save/reload and compare the new log to this preserved snapshot.
6. Run a vanilla baseline for the candidates above and supported total-conversion playsets separately. Generated-file changes must also be applied to their generators when available, as `agent.md` warns.
7. Update `supported_version` in both `descriptor.mod` and `../mod1.mod` to `1.21.*` only after the port is validated. Changing the descriptor alone fixes none of these errors.

The existing `logs/effects.log` and `logs/triggers.log` are dated November 7, before this installed 1.21 session. Regenerate them in the target version before using them as authority for new engine schemas.
