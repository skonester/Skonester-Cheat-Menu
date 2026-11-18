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
- The decision in the Realm & Government Tools group is now named "Skonester Cheat Menu Gold - Florin"
  (EN/DE/RU/ZH/TR).
- User-requested naming update: all associated information-decision/window titles, descriptions and tooltips
  use Florin in the five supported languages, including German hyphenated references. The displayed version
  is CK3 1.21 Florin. Keys and decision/event IDs remain unchanged. Audit:
  `tools/audits/2026-11-18/florin-information-rename`.
- Keep this information text brief in every language. The user requested less detail: the decision and
  window body now contain only a short CK3 1.21 Florin test-build note and GitHub bug-report request;
  tooltips are concise. Do not restore the old migration-history paragraph or reporting checklist.
  Copy audit: `tools/audits/2026-11-18/florin-information-copy`.

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

## Side work post BGA launch

Changelog for the 2026-10-21 session (committed). Same format as the milestone log: what changed, files
touched, what to check in-game. "Confirmed" means checked in a test run's `error.log` or reported working in
game; everything else still needs a test.

**S1: modifiers, event themes and `is_player` (done; confirmed in `error.log`).** Fixed the real errors the CK3
Language Support extension reported. Most of its ~96,500 diagnostics are style hints, and its unbalanced-brace
notices were false positives (every flagged file balances).
- Modifier names that don't exist in 1.20: `monthly_county_control_change_add` → `monthly_county_control_growth_add`;
  `hostile_scheme_resistance_add`, `personal_scheme_resistance_add` and `culture_conversion_speed` commented out
  with `# CK3 1.20:` notes.
- Event themes: `pilgrimage_activity` → `pilgrimage_destination` (6 events), `health` → `physical_health` (2),
  `romance` → `love` (3).
- `is_player` (not a CK3 trigger): removed where `NOT = { is_ai = yes }` already gates, otherwise `is_ai = no`.
- Files: `common/modifiers/X_modifiers.txt`, `common/modifiers/skonester_cheat_modifiers.txt`,
  `common/modifiers/skonester_authority_title_modifiers.txt`, `common/modifiers/skonester_expansion_title_modifiers.txt`,
  `events/skonester_cheat_menu_activity_events.txt`, `events/skonester_cheat_menu_edit_resources_events.txt`,
  `events/skonester_cheat_menu_events.txt`, `common/decisions/gender_Succession_decisions_mod.txt`.
- Left alone on purpose: `liuguan_*` triggers and other Great Ming leftovers (gated on `title:e_greatming`, never
  run in vanilla); the `gfx/.../distinct_generation/prompts/*.txt` image prompts (not game script).

**S2: issues found in the game's own `error.log` (done; not yet re-tested).**
- `e_skonester_authority_*`, `k_skonester_authority_regent`, `e_skonester_expansion_*` and
  `k_skonester_expansion_predator` aren't defined anywhere (no `common/landed_titles/`), and nothing calls their
  grant effects. Three `monthly_global_pulse` on_actions still ran `every_living_character` each month looking for
  them. The hook is commented out; re-enable it if the titles are ever added.
- The five `sol_unrestricted_warfare_expansion_cb_*` CBs used `group = sol_expansion`, which didn't exist. Added an
  empty (unrestricted) `sol_expansion` group. Vanilla `conquest` was rejected: it bans theocracies, pacifists,
  tributaries and herders.
- Removed `has_game_rule = change_Realm_succession_law_game_mod_on` (rule doesn't exist) from the Realm Succession
  decision.
- Files: `common/on_action/skonester_expansion_title_monthly.txt`, `common/casus_belli_groups/sol_casus_belli_groups.txt`
  (new), `common/decisions/gender_Succession_decisions_mod.txt`.
- Verify: the next `error.log` has no `Failed to fetch a valid landed title 'e_skonester_…'`,
  `Failed to read key reference sol_expansion` or `change_Realm_succession_law_game_mod_on` lines.

**S3: War Without Bounds in the regular menu (done; not yet tested).** Split into two interactions:
- `sol_war_without_bounds_interaction`: visible menu entry. Needs the Skonester tools menu open, Open Cheats used
  (`bone_cheat_interactions_flag`) and a player actor. Sets `sol_war_without_bounds_open` for 1 day, then
  `open_interaction_window` → `sol_expansion_war_interaction`.
- `sol_expansion_war_interaction`: the declare-war window, now `hidden = yes` (never listed) and gated on the same
  flags. No longer `debug_only`.
- The five CBs require `sol_war_without_bounds_open` in `valid_to_start` (not `allowed_for_character`, which can be
  re-checked mid-war and invalidate an heir's war), and `on_declaration` removes it. They don't appear in vanilla's
  Declare War.
- Known gap: cancelling the window while paused leaves the flag up to 1 game day, so vanilla Declare War also shows
  these CBs until it expires.
- Files: `common/character_interactions/99_sol_unrestricted_warfare.txt`,
  `common/casus_belli_types/sol_unrestricted_warfare_expansion_cb_*.txt`,
  `localization/english/zz_sol_unrestricted_warfare_l_english.yml`.
- Verify: entry hidden before Open Cheats, listed once after; it opens the war screen with the CBs; vanilla
  Declare War doesn't list them.

**S4: Spawn Character in the regular menu (done; not yet tested).**
- `toc_spawn_character_interaction` is no longer `debug_only`; it uses the regular-menu conditions (tools menu
  open, `bone_cheat_interactions_flag`, player actor).
- `tocmod.1000.i` is the menu's Close option, but EN/ZH/TR duplicated `.h` ("Spawn Male Sage (Age 100)"). Now
  Close / 关闭 / Kapat. DE and RU were already right.
- Files: `common/character_interactions/zzzzzzzz_0toc_deb_int.txt`, `localization/english/new_tocmod_l_english.yml`,
  `localization/simp_chinese/fully_consolidated_l_simp_chinese.yml`, `localization/turkish/fully_consolidated_l_turkish.yml`.
- Verify: listed without debug mode; the last option reads Close and closes the menu.

**S5: Special Governments page uses the 1.20 governments (done; not yet tested).**
- Government Menu page 4 (`skonester_quick_modifications.1413`): Mercenary Company and Adventurer (they need a
  landless company/camp and do nothing on a landed ruler) replaced with `ecclesiastical_government` and
  `monastic_holy_order_government`, the two governments 1.20 added. Every other 1.20 government was already on
  pages 1–3.
- Page description updated in EN/DE/RU/ZH/TR. Button names come from vanilla loc (none for Turkish, same as the
  existing Holy Order button).
- Both new types use `sticky_government`; choosing them turns the Skonester government lock off, as Theocracy and
  Holy Order already do.
- Files: `events/skonester_quick_modification_events.txt`,
  `localization/*/skonester_character_interaction_menus_l_*.yml`.
- Verify: apply each, let a few months pass, government unchanged.

**S6: Force Vassal as a true cheat (done; reported working in game).**
- `daddy_pika_offer_vassal_inter` now accepts any ruler (`is_ruler = yes`, landed or landless), including heads of
  faith, holy/monastic orders, mercenary companies, herders and landless adventurers. `cannot_be_vassal_or_liege`
  is only a script flag, so it's ignored. AGOT dummy holders, the Night's Watch, confederation members and enemies
  at war are still excluded.
- Tier rule relaxed from `<` to `<=`, so a king can vassalize the Pope (`k_papal_state`). Strictly higher tiers are
  still refused.
- After `resolve_title_and_vassal_change`, the interaction checks `is_vassal_of`; if the engine refused, it sends a
  "Vassalization Refused" toast (EN/DE/RU/ZH/TR).
- Files: `common/character_interactions/99_daddy_pika_character_interaction.txt`,
  `localization/english/DP_interactions_l_english.yml`, `localization/german/DP_interactions_l_german.yml`,
  `localization/russian/DP_interactions_l_russian.yml`,
  `localization/simp_chinese/fully_consolidated_l_simp_chinese.yml`,
  `localization/turkish/fully_consolidated_l_turkish.yml`.
- Open question: which target types (mercenaries, adventurers, holy orders) still trigger the toast. If mercenaries
  or adventurers are refused, the fallback is converting them to feudal first, which likely dissolves the
  company/camp.

10-22-26

Add GUI Portrait Cheat Menu, if using EPE have this mod loaded underneath it or it won't show

## CK3 1.21 repair batches — 2026-11-18

The user requested sequential numbered fixes with an in-game error-log checkpoint after every two parts.
The original 1.21 audit and preserved logs are in `tools/audits/2026-11-18/README.md`.
The active plan, changes, rollback copies and checkpoint status are tracked in
`tools/audits/2026-11-18/FIX_PROGRESS.md`.

- Parts 1 and 2 are implemented: `gui/window_character.gui` and `gui/interaction_menu_window.gui` are
  rebased from vanilla 1.20.0.2 to 1.21.0.0, preserving all Skonester/EPE custom edits. The character
  window restores trade-post/profit-route widgets and other current vanilla changes. The interaction
  menu uses `AreMoreInteractionsVisible`.
- Batch 1 passed its targeted fresh-log check in the November 18 10:43:57 session: all three target
  families and errors naming either changed GUI file are absent. The saved checkpoint has 5,409 records.
  Visual interactions were not independently verified.
- Parts 3 and 4 are implemented: current Prosperity/opinion APIs and innovation targets, the 1.21
  `09_mpo_values.txt` rebase preserving bloodline bonuses, 179 modifier properties, 47 province income
  fields, and adapted control-baseline/recovery behavior. Custom IDs and character income are preserved.
  Static verification passed; see `batch-02/validation.json` and the progress file for behavior details.
- Batch 2 passed its targeted fresh-log check in the November 18 10:58:29 session. The saved snapshot
  through 11:01:16 has 4,967 records; all five target families are zero and the GUI fixes remain clean.
  See `batch-02/after/result.json` for the comparison and newly observed runtime signatures.
- The new run also exposed 40 invalid-character-scope records in the unchanged Daming hook
  `yan_on_action.txt` / `yongsheng_xiuzheng`; preserve its IDs but guard execution in the later compatibility
  cleanup. Other vanilla-located runtime candidates still need attribution against a vanilla baseline.
- The next user session (11:04:23) had 4,909 records and all earlier target families remained clear.
- Parts 5 and 6 are implemented: 72 custom DB building tiers now have 26 duchy district wrappers,
  current building/district localization exists in all five languages, and the removed lighthouse water
  helper is replaced with its exact original coastal-or-riverside condition. Other building data is retained.
- The main Crozier building passes now traverse actual district/building instances using documented 1.21
  commands. Public effect IDs, 369 unrelated effect bodies and the ten-pass realm action are preserved.
  The helper source is generated by `tools/gen_skonester_121_building_cheats.py`.
- A fresh engine script reference is saved under `batch-03/engine-docs`. Static checks passed, and the
  corrected headless history/post-history load exited with code 0. All five batch-3 target families are
  zero; neither new file reports errors. See `batch-03/engine-check/result.json` for the detailed evidence.
- Batch 3 passed the targeted fresh user-log check in the 12:10:08 session. The saved review through
  12:16:44 has 3,816 records; all prior target families and both new implementation files remain clear.
  Actual visual/button behavior was not independently observed. See `remaining-review/README.md` and JSON.
- **Parts 7 and 8 are now implemented:** remaining Foreman/PCM/X building tools, holding-base repairs,
  six current holding-construction checks, and domicile cleanup dispatched by actual chain lengths.
  The 48 building-family adapters use current districts/roots; the PCM max-existing decision traverses
  actual buildings. Forty-five domicile base chains supply their real tier maximum; nineteen existing
  branch cleanup calls were validated. No Herder destination was added. See `batch-04/README.md`.
- Batch 4 source checks passed. A prefixed headless 1.21 load with EPE then Skonester completed history
  and post-history and exited 0. All targeted errors, all seven changed game-source file locations and
  earlier batch target families are zero. The ordinary user's error log was preserved. This is not a
  gameplay-button test. The subsequent **12:58:02 user session passes the targeted Skonester part-7/8
  log check**: all seven changed game-source file locations and domicile/building helper errors are clear.
- That user session loads Skonester then local `feudalestates` (EPE disabled). Its 2,602 records include
  three charter district-scope errors and two unknown Merchant modifiers attributable to Feudal Estates,
  plus sixteen Merchant preregistration errors. The generic batch-4 checker is globally false because it
  counts those external matches; see `batch-04/after/README.md` for the attribution.
- **Separate Feudal compatibility checkpoint:** FE1 updates the active local Feudal Estates government
  registration list and badge override for 1.21 Merchant; FE2 moves three charter city-tier additions to
  holding_district. Three game-source files changed under sibling `mod/feudalestates`, with originals,
  hashes/diffs and verification saved in `tools/audits/2026-11-18/feudal-estates`. Both custom government
  keys/badges, all 21 vanilla government keys and all other charter logic are preserved. No descriptors
  were changed. Source checks and a prefixed combined headless history/post-history load pass, exiting 0;
  all 21 attributable Feudal records and all prior Skonester targets are zero. The ordinary user log was
  preserved. The **13:15:50 fresh user session passes FE1/FE2**: all 21 prior Feudal records and all earlier
  Skonester targets are zero. The saved snapshot has 2,572 records through 13:17:40. Actual charter/tier
  carry behavior was not independently observed. See `feudal-estates/after/README.md`.
- **Parts 9 and 10 are now implemented** in 13 files. Eight HQ calls retain their unused CHECK values as
  comments; all CHANGE values/hooks remain. Eight Kurultai checks now pass the other-three-seat arguments,
  with the vanilla nomadic-only position gate. The branch relic receives the owner's religion.
- PCM personal artifacts use current types/slots/modifiers; its helper passes the existing illustrious
  100/100 quality/wealth scopes. Three named Chinese sword rewards use unique mod-local helper replacements
  for incomplete referenced historical helpers; no vanilla helper/file is overridden. Six new localized
  keys per language preserve those rewards. See `batch-05/README.md` for the exact fallback modifier choices.
- Nine noble-title creation calls now save the required scope, eight Japanese comparisons use
  culture:japanese, and the missing succession-menu rule is restored with default off/normal innovation
  gates. Its eight existing checks and five existing localized keys per language are preserved.
- Batch 5 source checks and the corrected prefixed headless history/post-history load pass, exiting 0.
  All targeted helper/artifact/title/culture/succession errors and all earlier Skonester/Feudal targets are
  zero. The 91 other GM/Daming records have unchanged signatures and stay queued for part 11. The ordinary
  user log is preserved. The subsequent 13:33 played session kept the load fixes clear but exposed the
  runtime follow-ups recorded below.
  Saved evidence, rollback copies and manifests are under `tools/audits/2026-11-18/batch-05`.
- **Government checkpoint: user subsequently confirmed R1/R2 worked.** The 13:33:17–
  13:36:07 user snapshot has 15,737 records, including 12 rejected government calls, 15 redundant holding
  changes and 33 native state-faith visibility errors. It is saved under `batch-05/after`.
- R1 adds twelve native government transition adapters, preparing incompatible capitals and using native
  temporary Japanese eligibility flags while preserving pre-existing flags. Seven old root family-estate
  paths now preserve a matching domicile or use native conversion for a different type. Mandala/Wanua no
  longer receive unsupported estate creation. R2 moves eleven county holding-preparation loops before the
  changes, uses current primary holding types and guards repeats. Existing decision IDs/metadata, landless
  adventurer behavior, protected mass-conversion branches and private Herder handling are preserved.
- One mod-local override of native `adopt_state_faith` guards the state-rite lookup inside the actual title
  scope with an existence check; its other properties/effects match the native definition. Wrapping the old
  right-side target in trigger_if alone did not stop eager invalid target evaluation; the scoped form does.
- Verification now includes **actual execution**, not only parsing: a date-isolated disposable Munster world
  runs the current effect bodies through all twelve target governments, landed vassals, domicile types,
  repeat conversions, native flag cleanup/preservation and state-faith visibility. Final result: **46 passed,
  zero failed, zero targeted runtime records**, normal exit. No user save was touched. The release engine
  does not expose the shipped scripted_tests console command, so the fixture uses a temporary hidden
  bookmark/date-gated hook/character event. All fixtures and the probe are archived out of load paths.
- A subsequent ordinary headless startup with current Skonester/Feudal Estates exits 0 after post-history;
  all four changed game-source files, earlier target families and Feudal targets remain clear. Ordinary user
  error.log stayed byte-identical throughout. Original-to-final diffs, rollback copies, fixture sources,
  native source comparisons and results are under `tools/audits/2026-11-18/government-runtime-review`.
- **Next runtime issue after the R1/R2 checkpoint:** bulk artifact decision `Artifact_1000` produces 12,950
  invalid-artifact records while building its tooltip, plus 51 armor-feature warnings (50 after startup).
  Source stacks point through the bulk decision's visible creation effects. Do not claim artifact gameplay
  fully verified or silently discard the flood. Address this separately before the broad part-11/12 cleanup.
  The optional Daming/GM errors and localization diagnostics remain queued. No portrait work was done.
- **User preference: do not add a Herder conversion/realm option.** Existing herder-holding input handling
  may remain for vanilla compatibility; the user did not request deleting those references.
- Part 12 must rebase the mod's English/German `debug_l_*.yml` overrides. Current vanilla contains the
  merchant debug-tooltip keys missing from the old replacement; these errors have a confirmed mod-side
  localization cause, rather than an unexplained vanilla origin.
- Separate spouse-portrait framing investigation: no GUI/camera files changed. Main/spouse templates and
  their cameras are identical between vanilla 1.20.0.2 and 1.21.0.0, installed files match the reference,
  and the top 480 lines of the mod window are unchanged from before batch 1. The spouse/main views use
  different render sizes and camera angle/vertical offsets; existing EPE-marked layout edits were preserved.
  See `tools/audits/2026-11-18/portrait-framing-review.md`. Do not claim a new 1.21 zoom change or a confirmed
  EPE cause without further visual comparison. Follow the current numbered-batch status above.
- EPE-enabled follow-up: the 12:27:27 session loads EPE then Skonester. Current Workshop EPE's first 480
  character-window lines and complete secondary portrait/widget type definitions match Skonester exactly.
  EPE does not override the shared portrait template or named camera file; the captured log has no references
  to those portrait files. Live paused inspection shows the main/spouse frame swap, without confirming a new
  abnormal-proportions regression. No gameplay files/settings changed. Evidence is in `epe-portrait-review`;
  the user's assessment with EPE enabled remains pending. The user subsequently deferred portrait work
  and requested focus on error-log fixes; leave the visual concern open without further camera/GUI edits.

- **Officials O1/O2 checkpoint: no recurrence in the captured Byzantine log before saturation.** The user confirmed
  government fixes and clicked many Officials decisions. The preserved 14:25:37?14:27:55 session has 3,069
  records: 534 court-management tooltip-variable errors, three court-management execution/toast errors,
  and seven missing Officials requirement perspectives. O1 protects non-revocable councillors in both
  dismissal paths, gates knight-status changes, hides stateful decision effects behind a localized summary,
  and safely defaults the temporary cap value. O2 adds positive text for all 31 trigger-localization entries
  (17 distinct requirements, five languages) and fills empty completion descriptions.
- Officials validation: **15 positive disposable-world assertions, zero failures/targeted errors**; all temporary
  fixtures archived outside load paths. Normal startup completes post-history with 2,413 records and no
  changed-file errors. Prior parts 1?10 target checks pass. Ordinary user error.log remained byte-identical
  during both auxiliary processes. Details, backups, diffs, hashes and reproducible checks are under
  `tools/audits/2026-11-18/officials-runtime-review`. The captured playset is Skonester only (FE/EPE off).
- **Next: check the fresh user UI/log after this O1/O2 pair.** Revisit Court Management, imprison-vassals,
  governor purge and title grants. Headless tests do not establish tooltip/toast rendering. Remaining runtime
  diagnostics include 14 native prisoner-release `none_scope_equal` text errors needing attribution,
  18 `skonester` format tags and 13 missing yyz shortcuts. The earlier artifact tooltip flood remains open
  although it is absent from the latest session. Optional Daming/GM and broader parts 11/12 remain queued;
  no Herder conversion option and no further portrait work.

- **Officials O3/O4 checkpoint passed in the fresh 14:59-15:00 user log.** The previous Byzantine
  14:39:09-14:40:27 log reached exactly 100,000 records (50.7 MB): 94,254 missing-parent errors in world
  cleanup tooltips, 38 land-limit title-scope errors, and 3,200 invalid-character GUI records. O1/O2 do not
  reappear in the captured portion; saturation can hide later errors. Playset remains Skonester only.
- O3 uses native child/grandchild predicates in both cleanup paths, hides stateful population work behind
  the existing explicit tooltips, checks live quota/batch counters per candidate, and excludes rulers as
  required by native silent_disappearance_effect. O4 fixes holder.primary_title in the title iterator and
  counts actual county titles instead of one boolean child in calc_true_if. Four source files changed.
- **32 Byzantine administrative runtime assertions passed**, including exact quota-one removal, a 25-person
  batch with five remaining from quota 30, descendant protections, dynasty culling, and actual county/duchy
  enforcement preserving the primary title. Normal startup after all temporary fixtures were archived
  completes post-history with 2,413 records and zero targeted errors. Prior batch checks pass, and all O1/O2
  files are unchanged. User saves were not loaded; ordinary error.log remained byte-identical in each check.
- Evidence/backups/diffs/hashes and fixture attempts: `tools/audits/2026-11-18/officials-byzantine-review`.
  The next user check should repeat Population and Administration cleanup and the Officials land-limit
  action as Byzantium, including hovering all world quota options. UI rendering and a long campaign remain
  unverified. Next pair should address invalid-character scripted-GUI visibility (15 entries, 3,200 records)
  and remaining formatting/shortcut/localization work. Native prisoner-release text, optional Daming/GM and
  the separately captured artifact-tooltip flood remain open. No Herder option; portrait work deferred.

- **Officials O5 passed; O6's Boolean visibility guard was insufficient in the next user log.** The 14:59:00-
  15:00:51 Byzantine log has 7,023 records and zero population/land-limit errors. It exposes 1,500 guardian
  tooltip axis errors, 252 remaining Court Management tooltip count errors, 2,693 invalid-character GUI
  records and nine exact-perspective warnings. O3/O4 source hashes remain unchanged.
- O5 uses optional guardian-axis equality, safe court count/cap values, a hidden guardian decision effect
  with its existing localized summary, and all six explicit perspective fields for 31 trigger entries.
  Hiding effects alone did not prevent every nested tooltip condition from being queried in the real UI.
- O6 guards 14 GUI visibility calls with GetPlayer.IsValid and defers culture/religion catalogue loading
  until that player exists. Layouts, camera/portrait code and existing action/visibility helper bodies stay
  unchanged. Referenced GUI generators were not found under tools; preserve guards if they are recovered.
- **38 Byzantine court/guardian runtime checks and 25 source checks pass.** Normal startup after archiving
  fixtures completes post-history with 2,413 records and no targeted errors; previous batch target checks
  pass. The ordinary user error.log was byte-identical during both checks; no user save was loaded.
  Headless tests do not verify rendered tooltips or invalid-player GUI queries during frontend/loading.
- Evidence, 21-file manifest, backups, diffs and reproducer are under
  `tools/audits/2026-11-18/officials-post-O4-review`. Next: restart/load Byzantium, hover/execute Court
  Management and bulk guardian assignment, open culture/religion pickers and another editor, then check
  the new log. This is the two-part checkpoint; do not claim the live GUI warnings are verified gone yet.
- Remaining: formatting and yyz shortcuts; 20 invalid-scope yongsheng_xiuzheng records in bundled
  yan_on_action.txt; native generated-company/prisoner text; optional Daming/GM startup diagnostics;
  previously captured artifact tooltip flood; broader parts 11/12. No Herder option or portrait work.

- **Officials O7/O8 fresh-log checkpoint passed in the subsequent ordinary user session.** The previous
  15:13:49-15:16:03 session has 47,683 records: 43,253 Artifact_1000 invalid-artifact tooltip errors, 1,560
  invalid-character visibility errors and 167 armor-property warnings. Court, guardian, population,
  land-limit and exact-perspective errors are zero. Playset is Skonester only.
- O7 keeps Artifact_1000 metadata and dispatches its whole effect through hidden character event
  skonester_cheat_execution.1000. Three mod-local adapters fix generic chess/Go descriptions (five languages)
  and permitted incense-burner features in court versus portable modes. Other catalogue logic is preserved.
- O8 replaces the insufficient Boolean guard with 13 rootless visibility queries at 14 GUI call sites.
  GuiScope.AddScope passes skonester_gui_player; exists and optional scope entry guard the unchanged original
  flag/list conditions. No character root is supplied before a player exists. Original action IDs and
  layouts remain unchanged, as do the already successful O6 deferred catalogue initialization states.
- **57 runtime assertions and 45 source checks pass.** Tests exercise missing-player, closed/open/locked
  conditions in a rootless context, the full artifact catalogue, both incense-burner modes and regional Go.
  Normal startup after fixture removal completes post-history with 2,415 records and zero targeted errors;
  prior batch targets pass. Two additional static notices say skonester_gui_player is never set because
  the analyzer cannot see GUI AddScope assignments; do not invent a dummy script setter to quiet them.
- Evidence, final 23-file manifest, original-to-final diffs and check scripts are under
  `tools/audits/2026-11-18/officials-post-O6-review`. Numbered attempts preserve rejected scalar visibility
  experiments, debug-log formatting probes without a local scope, and fixture-negation corrections. Final
  safe-query-map.json and diffs are authoritative; the initial staging migration is not the final GUI code.
- No user save was loaded. Final auxiliary checks leave ordinary error.log unchanged; earlier concurrent
  user appends were accepted only after validating the unchanged original byte prefix. All fixtures are
  archived outside load paths. Live rendering/public decision event dispatch still need the user checkpoint.
- Next: restart, open/close editors and catalogues, then hover/execute the bulk artifact grant and inspect
  the fresh log. Formatting/YYZ shortcuts, bundled yan/Daming/GM scopes, native company/prisoner text and
  broader parts 11/12 remain queued. No Herder conversion option or portrait work.

- **User workflow change: done with the earlier feature-test drills.** Focus on the errors in the actual
  ordinary error.log. Do not launch further disposable-world fixtures or request repeated menu-test
  exercises. Source review is sufficient for the small O9/O10 edits; no game process was launched here.
- **Decision-title preference:** do not prefix the PCM action titles with Skonester. The user rejected the
  visible branding added during O9's markup repair. All 68 affected titles now omit the entire brand
  prefix, preserving their action wording and localization keys. See
  `tools/audits/2026-11-18/decision-title-cleanup` for correction preimages/diffs/hashes. Do not reintroduce
  the brand while fixing formatting; the mod's name elsewhere is outside this request.
- **Current measured count: 2,534 entries through 15:53:18.** The first snapshot had 2,513; 21 more arrived
  while reviewing. Mutually exclusive accounting: 1,212 used-without-visible-setter notices, 102 set-but-
  unused notices, 67 orphan-event notices, 25 unused modifiers, 1,076 other startup records and 52 later
  UI/runtime messages. The first four groups total 1,406 diagnostics, not proven independent feature bugs.
- The actual fresh log has zero prior artifact, GUI visibility, court, guardian, population, land-limit or
  exact-perspective error families. O7/O8's fresh-log checkpoint passes. Only Skonester is enabled.
- O9 repairs 68 invalid #Skonester brand-format occurrences across eight existing localization files using
  native #high formatting while preserving keys/text. O10 comments 13 undefined optional YYZ binding lines
  and removes the unregistered NO_DEFAULT_KEY fallback. IDs remain in comments; commands and base Ctrl+Y
  (redo) are preserved. No new keys were assigned. An optional binding add-on must define the names and
  restore those lines. Ten production files have preimages, diffs and hashes; source checks pass.
- Evidence/counts/changes: `tools/audits/2026-11-18/current-error-inventory`. The 2,534 count is measured
  before those edits; do not claim a new runtime total or that historical log entries disappear. The next
  ordinary user log supplies updated counts without returning to artificial feature tests.
- **Next actual-error priorities:** 20 invalid-character operations in bundled yan_on_action.txt handler
  yongsheng_xiuzheng; one merchant ongoing-event scope failure; then the 1,076 other startup records
  (notably 185 missing-title links, 60 missing preset-character references, optional governments/traits,
  callback/namespace issues and old debug-localization overrides). Attribute native locations before
  assigning a vanilla-only cause. Preserve optional compatibility IDs and avoid fake setters merely to
  silence diagnostics. No Herder conversion option; portrait work remains deferred.
