# agent.md — Skonester Cheat Menu Gold: open work after the 1.20 port

Working notes for anyone (human or AI agent) picking up the mod after the port to
**CK3 1.20.0.2 "Crozier" / By God Alone**. The full list of 1.19 → 1.20 engine changes is in
`ck3-mod-base/README.md`.

## Status

- The mod is ported to 1.20: religion (Faith → Rite, tenet database, doctrine groups), laws/law groups,
  elections, governments, on-actions, GUI data types, and renamed traits and keys.
- **First test run** (vanilla + this mod, 2026-09-30): no crash. Errors dropped from 23,768 to 11,577, and every
  1.20-specific error class went to zero.
- **After that run**, the regressions it showed and a batch of long-standing bugs were fixed (second pass,
  commit `52a8a5e`). Milestones M1–M14 below (2026-09-30, uncommitted) then cleared most of what the baseline log
  still blamed on the mod's own files. A load-and-reach-map test on 2026-09-30 20:37 passed (see M15); the features themselves
  still need clicking through, so use *Verify* below and the per-milestone Verify notes.
- AGOT 0.5.2.1 targets CK3 1.19.0.6 and crashes 1.20.0.2 at startup even without this mod (its religions use the
  pre-1.20 layout). AGOT compatibility can't be tested until AGOT ships a 1.20 build.
- The decision in the Realm & Government Tools group is rebranded to "Skonester Cheat Menu Gold - By God Alone"
  (EN/DE/RU/ZH/TR).

## Milestones

Work goes in milestones. Each one is small enough to review on its own and lists the files it touched, so a
bad milestone can be reverted without losing the others. Status: `todo`, `doing`, `done`, `blocked`.
Nothing below has been tested in-game unless it says so. Check the *Verify* list for each one after a launch.

| # | Milestone | Task | Status |
|---|---|---|---|
| M1 | Resolve duplicate event IDs `skonester_cheat_menu.3020`–`3028` | 1 | done |
| M2 | Rewrite the domicile cheat on real 1.20 effects | 4 | done |
| M3 | Sub-mod errors: `X_decisions`, `ch_minor_decisions`, pcm decisions | 5 | done |
| M4 | Sub-mod errors: zhuge, daddy_pika, tocmod | 5 | done |
| M5 | Sub-mod errors: water of life, `notvanilla` MAA, beauty DNA, special gifts | 5 | done |
| M6 | Empty-tenet cleanup also on `on_rite_created`; `tenet_monasticism` / `tenet_rite` | 2, 3 | done |
| M7 | Polish: faith-appropriate theocracy, Sand Soldiers `order_knights` | 10 | done |
| M8 | DE/RU/ZH/TR translations for the new 1.20 English loc files | 8 | done |
| M9 | Remaining unrecognized loc keys in the mod's own files | 8 | done |
| M10 | Tradition keys: CW tradition picker (generated) and cultural-polygamy tradition | — | done |
| M11 | Artifact editor runtime errors: craft, modify picker, steal picker | — | done |
| M12 | Misc script errors: LIT, domicile presets, activity cheats, legend master, military, innovation picker, auto marriage | — | done |
| M13 | Invalid modifier keys in traits and duchy buildings | — | done |
| M14 | GUI errors: doctrine picker layer, console helper anchor, religion picker tooltip | — | done |
| M15 | Fixes from the 2026-09-30 20:37 test run (vanilla + mod) | — | done |

M10–M13 come from mod files that the baseline log (first test run, before the second pass) still blames and that
the second-pass commit `52a8a5e` didn't touch.

Not scheduled: task 2's core-tenet cap is a design decision for the maintainer, and task 6 needs the generator
scripts, which aren't in the repo.

### Milestone log

Newest last. One entry per finished milestone: what changed, files touched, what to check in-game.

**M1: duplicate event IDs (done).** The clash was 3020–3028 (nine IDs), not 3020–3024. The beauty-companion
culture picker keeps 3000–3034. The culture-reform heritage hub in `skonester_cast_culture_faith_generated.txt`
moved to 3186–3194, next to its 3100–3185 detail pages. The hub's Back and Close options had an `else_if` that
closed right after its `limit`, so they always removed `skonester_culture_reform_pick` and fired event 0021,
even on the companion path (two events at once). Fixed in all 104 options.
- Files: `events/skonester_cast_culture_faith_generated.txt`, `events/skonester_cheat_menu_events.txt` (0021
  "Browse all cultures" now opens 3186), `localization/*/skonester_cast_culture_faith_hotfix_l_*.yml`.
- Generator note: when the cast/culture generator is recovered, change its hub base from 3020 to 3186 and fix
  the `else_if` template.
- Verify: culture editor → Browse all cultures opens the heritage list (not a Marathi–Portuguese companion
  page); Back returns to the culture editor; the companion culture picker still pages through 3020–3028.

**M2: domicile cheat (done).** `skonester_domicile_cheat_effects.txt` now calls the main menu's working
`skonester_cheat_menu_estate_edit_full_effect` for each character with an estate, Japanese manor or East Asian
estate, then adds the tradition pool to the owner's culture. "Own family" walks `every_dynasty_member`, and
"worldwide" walks `every_living_character` that has a domicile. Each character is processed once
(`skonester_domicile_cheat_done` variable), because the full effect also grants 50,000 gold or treasury. The
event's Tours & Tournaments gate was removed; it never matched estates.
- Files: `common/scripted_effects/skonester_domicile_cheat_effects.txt`, `events/skonester_domicile_cheat_events.txt`.
- Nothing triggers `skonester_domicile_cheat.0100`; it's console-only (`event skonester_domicile_cheat.0100`).
  Wire it into a menu if it should be player-facing.
- Verify: run the console event and pick "Upgrade All Family Estates" on an administrative character with an
  estate; the estate maxes out and the culture gains the eight traditions. No errors from either file.

**M3: X, ch_minor and pcm decisions (done).**
- `X_decisions.txt`: removed `limit` from inside `any_*` triggers, and moved `has_holding`, `has_holding_type`
  and `building_slots` into `title_province` (they're province triggers); `is_capital_barony` stays on the
  barony. `X_unify` used `set_faith`, which isn't a CK3 effect; it's now `set_character_faith`. Behavior is
  otherwise unchanged. The pre-edit file is not kept; use git to compare.
- `ch_minor_decisions.txt`: dropped `NOT = { has_government = non_government }` (not a government in 1.20;
  `is_landed = yes` already gates) and the stray `subject = root.culture culture = { }`. `add_character_flag =
  covt_menu` was inside `title_province`; it now runs on the character. Added the missing
  `ch_barony_is_valid_for_{nomad,tribal,temple_citadel}_trigger` to `00_ch_scripted_triggers.txt`, same shape
  as the castle/city/temple ones.
- `pcm_decisions.txt`: the two hand-made banners used a visual type, modifier and loc keys that don't exist;
  they now use vanilla's `create_artifact_wall_banner_effect` with `banner_from_house` / `banner_from_dynasty`,
  like `historical_artifacts_events.txt`. Raw-text `custom_tooltip`s became loc keys (`pcm_artifact_cheat_tt`,
  `pcm_culture_cheat_tt`, new `skonester_pcm_tooltips_l_*.yml` in all five languages). `music` (not a decision
  field) and `add_culture_modifier` (not an effect; the block was also malformed) are commented out.
  `tradition_zhuge_chuantong` → `zhuge_chuantong` (the mod's real key). 47 `add/remove_culture_tradition`
  lines naming traditions that exist nowhere (not vanilla, this mod or AGOT) are commented out in place.
- `pcm_building_decisions.txt`: the logged `barony_valid` error was already fixed in the second pass.
- Verify: X_city / X_temple / X_castle / X_build / X_unify show up and work in Realm & Government Tools;
  the ch_* holding conversions (including nomad, tribal, temple citadel) accept a barony; "Recover the Gifts"
  gives a house banner and a dynasty banner; "Establish Cultural Supremacy" runs without errors.

**M4: zhuge, daddy_pika, tocmod (done).**
- **tocmod was replacing vanilla interactions.** `zzzzzzzz_0toc_deb_int.txt` defined `castrate_interaction` and
  `blind_interaction`, the same keys as vanilla's prison interactions, as `debug_only` copies. The file loads
  last, so players without debug mode lost castration and blinding entirely. They're renamed to
  `tocmod_castrate_interaction` / `tocmod_blind_interaction` (names reuse vanilla's loc via
  `skonester_tocmod_interactions_l_*.yml`) and ported to vanilla 1.20's effects
  (`blind_castrate_and_disfigure_effect`, `torture_blind_castrate_disfigure_opinion_effect`,
  `is_eunuch_trigger`). The file still overrides `marry_off_interaction` and ten debug/test interactions on
  purpose; see open task 11.
- zhuge traits: commented out fields that are neither trait properties nor modifiers (`charinfo`, `instabuild`,
  `is_highlighted`, `end_schemes`, `ai_will_do`, `random`, `inheritable`, `ai_can_have`, `ruler_opinion`,
  `learning_gain_mult`, etc.). Converted where a real field matches: `male_only` → `valid_sex = male`;
  plague immunity's `inheritability = 0.8` / `male = yes` → `inherit_chance = 80` /
  `child_inheritance_sex = male`. Removed `good = yes` from the two non-genetic traits the log warned about.
- zhuge bloodline events never fired: they hooked `on_character_born` (not an on_action; now `on_birth_child`)
  and required `is_male` and `is_female` at once. Also `hide_window` → `hidden`, `is_baby` → `age < 1`, and a
  `NOT` over two traits → `NOR`. **Behavior change:** sons of bloodline fathers now actually roll for the trait.
- zhuge misc: `prestige` → `prestige_gain_mult` in `zhuge_huangzu`; `disease_resistance` and death reasons'
  `death_reason` commented out; tradition `can_pick` uses `scope:character ?= { is_ai = no }`;
  `005_zhuge_qita_decisions.txt` lost `major`, the history-only `create_character` keys, and a duplicate
  `is_shown` (merged); `has_artifact_modifier` now runs through `any_character_artifact`; bare-number
  `ai_will_do` / `ai_potential` became blocks. `99_zhuge_character_interaction.txt`: a literal `	always` and
  a dead `upgrade_artifact_rarity_effect` block.
- daddy_pika: `is_player` → `is_ai = no`; `sort_order` commented out (not an interaction field); a bare
  `death_reason` outside any `death` block commented out. The AGOT government flags stay.
- Left alone: Daming keys (`e_greatming`, `ming_city_holding`, `sansizhi_government`) and AGOT flags, which
  are gated compatibility keys; duplicate loc `strong_test_hook` (vanilla vs zhuge).
- Verify: the vanilla Castrate / Blind prison interactions are back for a non-debug game; in debug mode the
  tocmod copies also appear in the debug menu. A son born to a `bloodline_god_3` father gets `bloodline_god_3`
  or `_2`. No errors from the zhuge trait files.

**M5: water of life, MAA, beauty DNA, special gifts (done).**
- Water of life: character templates and `create_character` take `trait = x`, not `add_trait = x` (six template
  lines plus event `water_of_life_decisions_events.txt`). A bare `order_member = {}` outside
  `random_traits_list` became `trait = order_member`; `sexuality` commented out (not a template field). So
  Clavius and the loyal subjects now actually spawn with their traits.
- `notvanilla.txt` MAA: `hills_with_terraces` → `terraced_hills`; `floodplains_dry` / `floodplains_wet` and
  `ai_will_do` (not MAA fields) commented out.
- `beauty_traits_dna_modifiers.txt`: 1.20 nests morphs under a species key, so both `dna_modifiers` blocks now
  wrap their morphs in `human = { }`. The beauty modifier's `weight` is `base = 0` with every modifier commented
  out, so it still never applies; that was already the case.
- `00_special_gift_1..4.txt`: removed stray `target = scope:actor` lines inside `scope:recipient` blocks, and
  `ai_frequency = 0`, which did nothing without `ai_targets`.
- Verify: finish the water-of-life decision chain and check that the hooded old man has Water of Life and
  Blood Knight; the special gift interactions give the trait and friendship.

**M6: rite cleanup, monasticism/rite tenets (done).**
- `skonester_mts_religion_on_actions.txt` now also hooks `on_rite_created` (ROOT = creator, `rite` = the new
  rite) and removes any `tenet_zz_empty_*` from the new rite with `remove_rite_tenet = tenet:<key>`, guarded by
  `rite_has_tenet`. That closes the gap noted in task 2; the core-tenet cap decision is still open.
- `tenet_monasticism` / `tenet_rite` stay commented out. AGOT defines both, but only in its 1.19 format
  (tenets as doctrines in `doctrine_types/30_core_tenets.txt`), and AGOT doesn't load on 1.20 yet. Revisit when
  AGOT ships a 1.20 build.
- Adding vanilla's new `doctrine_monasticism_*` group (absent / forbidden / accepted / encouraged) to the faith
  editor is not done: each doctrine is wired through about 12 places in the generated faith-editor files,
  including per-group exclusion logic. Moved to task 7; do it in the generator, not by hand.
- Verify: create a new Rite inside an existing faith and check that no "Empty" tenets are left on it.

**M7: theocracy type, order knights (done).**
- `skonester_convert_character_to_theocracy_government_effect` now uses `faith.faith_theocratic_goverment_type`
  (vanilla's spelling), the same link vanilla's `pam_clergy_events` use, so Christians get
  `ecclesiastical_government`; `theocracy_government` is the fallback. `skone_theocratic_inheritance.txt` calls
  the same effect. Both governments carry `government_is_theocracy`, so the existing guards still hold.
- Sand Soldiers: added `order_knights` (vanilla stack 50) next to `order_serjeants`: catalog `list_all` and
  `list_cavalry`, the stack-size branch, the spawn branch, and a GUI button cloned from the serjeants one with
  the heavy-cavalry icon.
- Not done: `stress_impact` → `stress_and_fulfillment_impact`. The old effect still works; switching would
  also move Spiritual Fulfillment, which is a design choice.
- Verify: convert a Catholic vassal to theocracy from the government tools and check that they become
  Ecclesiastical; Sand Soldiers lists Order Knights and spawns them.

**M8: translations (done).** Added German, Russian, Simplified Chinese and Turkish versions of
`skonester_ce_unl_doctrine_names`, `skonester_ce_unl_doctrine_groups` and `skonester_1_20_faith_labels`
(about 6,000 lines each). The English files are about ten sentence templates repeated per trait (trait names come
from the game's own loc via `$trait_x$`), so the translations are template-based: `m8_translate.py`-style
regexes, not hand-edited lines. `tenet_zz_empty_*` keys were skipped because every language already has them.
Native speakers should skim the wording, especially "slot" terminology.

**M9: loc gaps (done).**
- **Loc files with nonstandard names were renamed** (with `git mv`, so they show as renames):
  `fully_consolidated_l_simp_chinese.yaml` → `.yml`, and three `*_l_<lang>..yml` (double dot) → `.yml`. CK3
  loads `*_l_<language>.yml`; the `.yaml` file alone holds 2,773 Chinese keys that no other file defines, so if
  it wasn't loading, Chinese players saw raw keys for all of them. None of the renamed files share a key with
  the rest of their language, so no new duplicates.
- New `skonester_missing_loc_fixes_l_<lang>.yml` (five languages, 32 keys): the activity-menu options and
  tooltips (3091/3092/3097), the fast-phase toast title (the loc files only had `..._Fast_phase_title` with a
  capital F), artifact picker tooltips, LIT trait-XP tooltips, the DP character editor's culture-group and
  regional-innovation options, `tocmod.0005`, and `merge_titles.1.desc` (hidden event, empty string).
- Raw-text strings turned into loc keys: RSE's "Unlock Innovation" / "Innovation" / "Theme System" / "Close"
  (and "Hereditary Rule" / "Heraldry" / "Primogeniture" now reuse vanilla's `innovation_*` names), DP's
  "Dragon Birth", and the special-gift toast title.
- The language/heritage picker options noted in the old log were already converted to `*_name` keys in the
  second pass; only `heritage_hmongic` / `heritage_tai` still use the bare key, which vanilla also defines.
- Left: `trait_dragon_*` option names in `dp_char_editor.txt` (AGOT supplies them), and about 490 older log
  entries that no longer reproduce statically. A static scan of option names, titles, descs and tooltips
  across events, decisions, interactions and scripted effects now finds nothing else missing in English.

**M10: tradition keys (done).**
- `zz_skonester_variations_of_cultural_polygamy.txt`: the hybridization checks referenced four-, five- and
  nine-wives variants that the mod never defines; those six `NOT` blocks are gone. The two- and three-wives
  traditions are unchanged.
- `skonester_cw_tradition_picker_lists_generated.txt`: reran `tools/gen_cw_tradition_picker_lists.py` against
  vanilla 1.20 and AGOT 0.5.2.1. Output is identical to what's committed (199 vanilla, 283 AGOT), so the list
  is current. All 135 logged errors are `tradition_agot_*` keys in the AGOT-only list, which is expected in a
  vanilla game (the list is only used when AGOT is loaded).

**M11: artifact editor (done).**
- Steal and modify pickers sorted artifacts with `order_by = artifact_wealth`, which isn't a value in 1.20;
  they now use `artifact_rarity`, as vanilla does. Most-valuable-first ordering is roughly preserved.
- The modify picker's paging used `skonester_acm_modify_page_offset_value`, which was never defined. It's now
  in `skonester_steal_artifact_values.txt`, same shape as the steal picker's (page × 3).
- Craft panel: `skonester_acm_clamp_craft_slot_layers_to_quality_effect` and
  `skonester_acm_sync_craft_layer_quality_body_effect` read `var:skonester_craft_mN` and
  `var:skonester_acm_craft_quality_wealth` before the panel sets them (GUI tooltips evaluate early). Both now
  check `has_variable` first; unset falls through to the one-layer default.
- The picker tooltips (`skonester_acm_modify.8001.pick_N_tt`) were added in M9.
- Verify: Artifact Editor → Modify lists artifacts, page 2 works, and the craft panel's tooltips don't log
  "Failed to fetch variable".

**M12: misc script errors (done).**
- **Estate "clear external buildings" presets:** 1.20's branch chains (`workshop_textile`, `storage_granary`,
  `stable_kennel`, `garden_fruit`, …) start at tier 03 or 04, so `$CHAIN$_01` didn't exist. New
  `skonester_domicile_clear_external_branch_chain_fully_effect` steps them down with vanilla's
  `destroy_or_downgrade_estate_building_{2_4,2_6,3_6}_replacement_effect`, and branches are now cleared before
  their base chain. `health` / `courier_posthouse` / `night_watch` were dropped from the plain-estate list; they
  only exist as East Asian estate buildings, which have their own list.
- **Activity cheats:** four activity types were renamed in 1.20 (`activity_hike` → `activity_roaming`,
  `activity_inspection` → `activity_survey`, `activity_university_visit` → `activity_adult_education`,
  `activity_monument_expedition` → `activity_journey`). The Host buttons for those four now work.
- **Court cabinet:** `aptitude:councillor_*` doesn't exist (aptitude is for court positions); candidates are
  ranked by the seat's skill instead (chancellor → diplomacy, marshal → martial, and so on).
- **Legend master:** the "clear legends" loop called `destroy_legend`, which doesn't exist, so it spun to the
  engine's iteration cap on every click; it's gone (the effect still runs `stop_promoting_legend`). The three
  god-based legends passed `faith.high_god_name`, which isn't a link; they now use `flag:the_angels`, which
  works under any faith and in AGOT. The missing `motion_divine` chronicle became `sacred_birth`
  (reason `auspicious`) for "Divine Avatar". The Red Hand of Ulster seed now uses `d_ulster` (`k_ulster` is gone).
  Event theme `fame` → `legend`.
- Innovation picker: `innovation_bombard` → `innovation_bombards`. Auto marriage: `is_child = yes` →
  `is_adult = no`.
- Already fixed by the second pass (log is older): LIT tooltips (loc added in M9), military supply modifier.
- Verify: estate editor "clear exterior" on an estate with a textile workshop and a kennel; host a hike /
  survey / university visit / monument journey from the activity menu; legend master's clear and the
  divine-blood / fate-weaver / divine-avatar legends.

**M13: invalid modifier and trait keys (done).** Keys the log rejected, mapped to their 1.20 equivalents where
one exists and commented out in place otherwise (each line says what it was):
- `intrigue_scheme_power` / `hostile_scheme_power_add` → `owned_hostile_scheme_success_chance_add` (same value);
  `personal_scheme_power_add` → `owned_personal_scheme_success_chance_add`.
- `intrigue_scheme_resistance = N` → `enemy_hostile_scheme_success_chance_add = -N`;
  `hostile_scheme_resistance_mult = X` → `enemy_hostile_scheme_success_chance_add = -100·X` (capped at -100).
- `monthly_county_control_change_factor` → `monthly_county_control_growth_factor`.
- `fame = yes` → `category = fame` where the trait had no category.
- Commented out, no 1.20 equivalent: the per-skill `*_scheme_power` and `*_scheme_power_mult` keys,
  `personal_scheme_resistance_mult`, `forced_portrait_age_index`, and `congenital = no` / `education = no`.
- Files: `knightBlood.txt`, `pcm_traits.txt`, `zzzzzzzz_realistoc_traits.txt`, the six `skonester_*_trait(s).txt`
  cheat traits, `DB_duchy_Common.txt`.
- Not touched: `levy_screen`, `siege_weapon_max_size_mult`, `negate_martial_penalty_add`,
  `cultural_head_fascination_add`, `owned_legend_spread_add`. No vanilla trait uses them, but the game didn't
  reject them either.
- Balance note: the scheme mappings are approximations (old "scheme power" is now success chance), so cheat
  traits like `super` and `pantokratorus_*` behave a little differently than in 1.19.

**M14: GUI errors (done).** `skonester_acm_faith_doctrine_picker.gui` used `layer = popup`, which isn't defined;
it's now `windows_layer`, like the other ACM pickers, so it still opens above the faith editor (`middle`).
`skonester_console_helper.gui` used `parentanchor = fill`, which isn't an anchor; the background widget now
uses `size = { 100% 100% }`. The religion picker's expand button pointed at the removed
`RULER_DESIGNER_LIST_FAITH_ENTRY_TOOLTIP`; it now has its own `skonester_acm_religion_picker_expand_tt` (five
languages). The logged `decision_view_widget_ch_convert_holding.gui` and `Faith.GetTenetBackgroundIcon` errors
were already fixed by the second pass.

**M15: second test run (2026-09-30 20:37, vanilla + mod via `mod/mod1`, a copy of this repo with M1–M14).**
Reached the map with no crash. **2,767 errors, down from 11,577.** Against the baseline, 8,796 are gone and only
11 entries (9 distinct) are new; all nine are fixed here:
- Mine from M4/M13: `prestige_gain_mult` isn't a modifier either → `monthly_prestige_gain_mult`; the renamed
  tocmod interactions had `ai_potential` without `ai_frequency` (removed).
- The heritage hub renumber (M1) collided on one loc key, `skonester_cheat_menu.3190.desc`, with an orphaned
  "Custom Accolades" block in `skonester_military_manage_l_*.yml` (no event 3190 exists). Dropped the hub's
  unused placeholder.
- Uncovered once earlier errors were gone: tocmod's `marry_off_interaction` used `is_diplomatically_available`
  (removed from vanilla, which only checks `is_imprisoned` now); `CH_SELECT_HOLDING_TOOLTIP` loc still called
  `DecisionViewWidgetCreateHolyOrder.HasValidBaronies` → `DecisionViewWidgetSelectBarony.HasValidTitles`
  (five languages); `parentanchor = fill` in `skonester_lifestyle.gui`; `good = yes` on non-genetic zhuge traits.
- Also cleared from that run: `parentanchor = fill` in four more GUI files; `DP_modifiers.txt` scheme
  power/resistance keys (mapped like M13); pcm artifact `VISUALS` → `sword` / `armor` / `crown` /
  `regalia_court`; stray `CHECK` argument to `HQ_change` in `zhuge_curry_interactions.txt`.
- What remains in the mod's own files (about 700) is expected: Daming keys (`yan_on_action`, `GM_value_on_action`,
  `bianshen_daming`), AGOT keys (AGOT tradition list, dragon traits in `dp_char_editor`), and the mod's own
  expansion/authority titular titles, which are created at runtime. Plus 1,206 "flag/variable used but never set"
  lint lines (task 9).

**Faith editor tooltips (2026-09-30, from in-game testing).** The faith editor works: clicking a core-tenet
card fills the right-hand list and picking an entry replaces the tenet. But the tooltips opened over the
picker list (`tooltip_ne`), and with tooltip locking they blocked the choices. Picker-list rows now use
`tooltip_ws` (open to the left, like vanilla's rite creation list); left-panel tenet cards and doctrine rows
use `tooltip_sw`; the separate `skonester_acm_faith_pick_panel.gui` list (docked left of the vanilla faith
window) uses `tooltip_es`. Verify: hovering any list entry no longer covers other entries.

**Find Spouse restored (2026-09-30, task 11).** Deleted tocmod's copy of `marry_off_interaction` from
`zzzzzzzz_0toc_deb_int.txt` (302 lines, a note left in its place). It used vanilla's key, so it replaced Find Spouse
for every player; it only appeared while the Skonester interaction menu was open, and it was a pre-1.20 copy missing
landless-adventurer and puppet handling. Vanilla's 1.20 Find Spouse is back. The cheat version is Force Betrothal
(`daddy_pika_arrange_marriage_inter`: auto-accept, wider candidate list). Verify: with the Skonester menu closed,
right-click an unmarried child; Find Spouse appears under Diplomacy and the AI can refuse.

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

### 1. ~~Decide on the duplicate event IDs `skonester_cheat_menu.3020`–`3024`~~ (done in M1)
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

### 3. `tenet_monasticism` and `tenet_rite` (low; decided in M6: keep commented until AGOT supports 1.20)
Both were removed from vanilla in 1.20 (monasticism is now the `doctrine_monasticism_*` doctrine group). The
faith editor has them commented out and tagged `CK3 1.20:`. Restore them if AGOT still defines them, or replace
the monasticism entry with the doctrine group.

### 4. ~~Domicile cheat is non-functional~~ (done in M2)
`common/scripted_effects/skonester_domicile_cheat_effects.txt` uses effects that don't exist (`every_domicile`,
`set_domicile_level`, `every_character`, a bare `limit`). It's reachable from
`events/skonester_domicile_cheat_events.txt`. It needs a rewrite on real domicile effects.

### 5. ~~Remaining script errors in bundled sub-mods~~ (done in M3–M5)
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
Add the `doctrine_monasticism_*` group (it replaced `tenet_monasticism`). The tenet catalog doesn't include the
25 tenets added in 1.20 (e.g. `tenet_dulia`, `tenet_purgatory`,
`tenet_simony`, `tenet_miles_christi`). Consider Rite-level editing (`set_character_rite`, `rite_has_doctrine`),
Spiritual Fulfillment and personal tenets as new cheats.

### 8. Localization gaps (low; mostly done in M8/M9)
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
- ~~Theocracy conversions should use the faith's own theocracy type~~ (done in M7).
- ~~Sand Soldiers: add `order_knights`~~ (done in M7).

### 11. ~~tocmod overrides `marry_off_interaction`~~ (done: copy deleted 2026-09-30)
`common/character_interactions/zzzzzzzz_0toc_deb_int.txt` redefines vanilla's `marry_off_interaction` under the
same key, and the file loads last, so it replaces vanilla's for every player. It's an old copy with cheat
tweaks, so it will drift from vanilla each patch. Either rename it (like the castrate/blind fix in M4) or rebase
it on vanilla 1.20's version.

## Release checklist

- [ ] Verify pass above is clean.
- [x] Task 1 resolved (M1).
- [x] Task 11 resolved (tocmod's Find Spouse copy deleted).
- [ ] Decide task 2 (core-tenet cap).
- [ ] Bump `version` in `descriptor.mod` (currently `9.30.26-BGA1`; `supported_version` is already `1.20.*`).
- [ ] Commit.
