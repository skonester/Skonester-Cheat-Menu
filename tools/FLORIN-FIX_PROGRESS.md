# CK3 1.21 repair progress

Work proceeds one numbered part at a time, with a fresh in-game error-log checkpoint after every two parts, as requested. Additional issues found during verification will receive their own numbered parts when needed. A part marked implemented still needs the batch's runtime check.

## Parts and checkpoints

| Batch | Part | Scope | Status |
| --- | ---: | --- | --- |
| 1 | 1 | Rebase the character window onto 1.21, preserving cheat panels and EPE layout adjustments | Targeted fresh-log check passed |
| 1 | 2 | Rebase the interaction menu and fix its renamed visibility function | Targeted fresh-log check passed |
| 2 | 3 | Prosperity/popular-opinion APIs, election weights, innovation references and affected script-value overrides | Targeted fresh-log check passed |
| 2 | 4 | Tax and control modifiers, preserving each cheat's intended scope and behavior | Targeted fresh-log check passed |
| 3 | 5 | Custom duchy building definitions and their district wrappers | Targeted fresh-log check passed |
| 3 | 6 | Main building-cheat catalogs and district-aware construction/upgrade effects | Targeted fresh-log check passed |
| 4 | 7 | Foreman, PCM and X building decisions and their district scopes | Targeted fresh-log check passed |
| 4 | 8 | Domicile cleanup dispatched by actual chain lengths | Targeted fresh-log check passed |
| 5 | 9 | Scripted-helper arguments, council reshuffles and artifact creation | Load fixes pass; played session exposed a separate bulk-artifact tooltip flood |
| 5 | 10 | Government conversion, dynamic title creation and missing succession rule | Load fixes pass; R1/R2 runtime conversion follow-up implemented and tested; user log pending |
| 6 | 11 | Remaining broken interaction/event references and scope errors | Queued |
| 6 | 12 | Localization, formatting, missing graphics and encoding cleanup | Queued |

Optional AGOT/Daming/Orient compatibility references stay preserved. Vanilla-origin candidates require a separate baseline run before assigning responsibility. The descriptor's supported version remains unchanged until the port is validated.

User preference: **do not add a Herder conversion/realm option**. Keep existing handling of vanilla herder holdings as conversion inputs where needed. The latest remaining-work inventory is in [remaining-review/README.md](remaining-review/README.md).

Separate visual investigation: [portrait-framing-review.md](portrait-framing-review.md) records the reported spouse portrait framing change. Main/spouse camera and template settings are unchanged between vanilla 1.20 and 1.21, and the recent rebase preserved the old top portrait layout exactly. No portrait files were changed during that investigation; it does not consume a numbered repair part.

**Current focus — actual logged errors:** the user has finished the earlier feature-test drills. Do not launch more disposable-world fixtures or request repeated menu exercises. Read the ordinary user log and fix the concrete remaining sources.

The latest captured log has **2,534 entries through 15:53:18**: **1,406 analyzer notices**, **1,076 other startup records**, and **52 later UI/runtime messages**. The earlier artifact/GUI/court/guardian/population/land-limit/perspective floods are absent, confirming O7/O8's fresh-log checkpoint. **O9/O10** repair invalid brand markup and leave 13 undefined optional YYZ bindings unbound, preserving Ctrl+Y and their commands. Those two sources account for 31 of the 52 later messages; no post-edit runtime total is claimed. Next priorities are 20 `yongsheng_xiuzheng` invalid-character operations, one merchant-event scope error, and the missing-definition/localization startup groups. See [current-error-inventory/README.md](current-error-inventory/README.md). No Herder option; portrait work remains deferred.

## Batch 1 — parts 1 and 2

### Part 1: character window

Changed `gui/window_character.gui` using a three-way merge: original Skonester, vanilla `base/1.20.0.2`, and vanilla `base/1.21.0.0` from `ck3-mod-base`.

- Restored current `hbox_trade_posts` and `hbox_profit_routes` types and the corresponding character-view content. The missing trade-post type was also breaking the vanilla trade and republic screens.
- Included the current theocratic-lessee tooltip, merchant/company information, modifier displays and other upstream character-window changes.
- Preserved all seven groups of Skonester/EPE custom edits exactly relative to the new vanilla source, including seven named cheat controls and all 473 scripted-GUI hook calls.

### Part 2: interaction menu

Changed `gui/interaction_menu_window.gui` using the same merge process. The only vanilla change to this file between those tags is the corrected function spelling and its placement:

```text
CharacterInteractionMenuWindow.AreMoreInteractionsVisisble
    -> CharacterInteractionMenuWindow.AreMoreInteractionsVisible
```

Preserved the adjustable height, scrollable additional interactions, portrait customization, folding categories, and all six scripted-GUI hook calls. The applied diff adds and removes one line.

### Static verification

- Both three-way merges completed without conflicts.
- The custom changes relative to 1.20 are exactly the custom changes relative to the merged 1.21 files; no custom edit was lost or altered.
- Quoted strings and brace-delimited GUI blocks balance, no merge markers remain, and each restored trade widget type is defined once.
- Original UTF-8 BOM and per-file newline styles are preserved.
- Original files, applied diffs, source snapshots, hashes and check results are saved in [batch-01](batch-01/). See [validation.json](batch-01/validation.json).

These checks establish source integrity. In-game rendering and behavior are not yet verified.

### Runtime checkpoint — targeted log check passed

The fresh November 18 session beginning at 10:43:57 contains none of the three targeted error families and no errors naming either changed GUI file. The preserved checkpoint snapshot through 10:45:18 has **5,409** records; an earlier read had 5,408 before the running game appended another record. See [the saved result](batch-01/after/result.json) and [fresh error-log snapshot](batch-01/after/error.snapshot.log).

This passes the targeted loading/log check. Visual behavior was not independently verified; these remain useful smoke checks:

1. Open your character window and another character's window. Check portraits, the Skonester buttons and panels, and ordinary character information.
2. Open a character's right-click interaction menu. Open additional interactions, resize the menu and fold/unfold a category.
3. Open the trade screen and a republic government screen if available, so those widget definitions are exercised.
4. Leave the new log in place for comparison before another launch overwrites it.

The targeted comparison is:

| Signature family | Original records | Fresh-session records |
| --- | ---: | --- |
| Invalid `hbox_trade_posts` widget/type/property | 5 | 0 |
| `AreMoreInteractionsVisisble` function/conversion/property failures | 6 | 0 |
| Unlocalized `CV_THEOCRACY_LESSEE_TOOLTIP` in the character window | 1 | 0 |

Also check for any new errors naming either changed file or the restored trade widgets. Most building/economy errors will still exist until their later parts are implemented, so the overall count alone does not determine whether this batch passed.

**Checkpoint result: targeted log check passed. Parts 3 and 4 proceeded after this check.**

## Batch 2 — parts 3 and 4

### Part 3: economy APIs, elections and innovation references

Implemented the verified 1.21 replacements for Development/Prosperity effects, triggers, values, the low-Prosperity threshold and renamed decision cooldown targets. Updated Peasant Elective's vote calculation and localized concept links to Prosperity and popular opinion.

The four `innovation_development_*` entries now target the corresponding `innovation_prosperity_*` definitions throughout catalogs, requirements and add/remove operations. The old Bombards picker entry now targets `innovation_gunpowder`, whose actual 1.21 definition uses the Bombards artwork and unlocks the current late-medieval gunpowder units. Saved picker flags, event IDs and custom localization keys remain unchanged.

Visigothic Codes checks now use `has_cultural_tradition = tradition_visigothic_codes`, matching its actual database. Verification also found four references to an undefined legacy `innovation_theme_system`. That legacy option and its obsolete gating branches are preserved as comments; the existing working Primogeniture unlock option remains available. Whole standalone trigger blocks were commented together so an empty culture block would not accidentally open a succession gate.

`common/script_values/09_mpo_values.txt` was rebased from vanilla 1.20.0.2 onto 1.21.0.0. Its custom bloodline loyalty bonuses are preserved exactly.

Part 3 changed 24 files. Its [manifest](batch-02/part-03/manifest.json), original files and applied diffs are saved alongside the recorded migration script.

### Part 4: modifiers, income and control

Migrated all **179** obsolete modifier properties identified in the checkpoint log, preserving custom modifier IDs and their saved references. Prosperity modifiers now use current Prosperity icons; popular-opinion modifiers and the DP editor's vanilla label aliases use current names.

Converted **47 province-scoped** `monthly_income` properties to `monthly_generic_tax`. Character-scoped `monthly_income` values remain unchanged. Broad tax multipliers use the supported `all_tax_mult` property.

Control behavior was adapted to the new baseline model:

- Ordinary growth bonuses and penalties now affect recovery **below the control baseline**, using the supported additive or multiplier field. Their numerical strengths are retained.
- Six existing extreme full-control bonuses also add `control_baseline_add = 100`, allowing them to recover toward maximum control rather than stop at the ordinary baseline of 35. This includes the strong X, PCM, wealth and equivalent cheat bonuses.
- The legacy baron-inclusive controls now adjust `control_baseline_add_even_if_baron`, the supported baron-inclusive field. Flat editor steps remain ±0.1 baseline points. Legacy ±0.1 multiplier steps become ±10 baseline points. Their labels now describe the baseline and omit the obsolete multiplier tag.

Part 4 changed 23 files. Across both parts, **42 unique files** changed. See its [manifest](batch-02/part-04/manifest.json) and the [combined validation](batch-02/validation.json).

### Static verification

- Source block structure and the per-part backup/hash chain passed.
- Every static innovation target in active `common/` and `events/` script resolves in the current vanilla innovation database.
- None of the targeted obsolete engine APIs or modifier properties remain active. Stable custom IDs using older words are intentionally retained.
- Character income, custom modifier IDs and all localization keys are preserved.
- Each introduced modifier property, localization alias and replacement icon was checked against current `ck3-mod-base` definitions.
- These source checks were followed by the fresh-session log check below; visual and gameplay behavior were not independently verified.

### Runtime checkpoint — targeted log check passed

The user restarted CK3 with the same Skonester-only playset. The fresh November 18 log starts at **10:58:29**; the saved snapshot through **11:01:16** has **4,967 records**, compared with 5,409 at the prior checkpoint. All five targeted error families are absent. No GUI-factory or data-factory errors are present, and none of the batch-1 GUI signatures returned. The edited files also match the validated source hashes.

Comparison against [the recorded targets](batch-02/targets.json):

| Error family | Pre-batch records | Observed fresh-session records |
| --- | ---: | ---: |
| Unknown modifier types | 179 | 0 |
| Province `monthly_income` rejected | 47 | 0 |
| Targeted old Development effect/trigger names | 19 | 0 |
| Innovation add/check/remove database errors | 110 | 0 |
| Old election concept function failures | 6 | 0 |

The full result, including newly observed runtime signatures, is saved in [batch-02/after/result.json](batch-02/after/result.json). The [error-log snapshot](batch-02/after/error.snapshot.log) is preserved so another launch cannot overwrite this checkpoint.

### Remaining errors and newly exercised runtime paths

The major queued building issues remain: **72** rejected old custom-building `type` fields, **112** province/district effect-scope failures, **352** missing upgrade targets and **205** missing construction targets, plus associated validation messages. These belong to parts 5–7.

This run also exercised `yongsheng_xiuzheng` in `common/on_action/yan_on_action.txt`, producing **40** invalid-character-scope records from `move_to_pool` and `random_living_character`. Its hardcoded Daming characters are absent in vanilla. This is an execution guard problem to investigate in the compatibility/event cleanup, not merely expected missing-database noise. Preserve the references and guard the hook/nullable character scopes when fixing it. This file was unchanged by parts 3 and 4.

Other newly observed gameplay signatures point into vanilla court-position, succession, religion, movement-petition and interaction content. They are recorded for comparison; a vanilla baseline is still needed before assigning their cause. No new unknown-modifier, old-economy-API, GUI-factory or data-factory failures were found.

**Checkpoint result: targeted log check passed. Next queued batch is parts 5 and 6: custom duchy districts, then the main building-cheat catalogs and effects. No additional gameplay files were changed during this log check.**

## Batch 3 — parts 5 and 6

### New pre-batch log check

The user's next session, beginning November 18 at 11:04:23, had **4,909 records** when captured. All five batch-2 target families and the batch-1 GUI regressions remained at zero. It is preserved in [batch-03/before-logs](batch-03/before-logs/).

### Part 5: custom duchy districts

Converted the **72 existing building tiers across 26 chains** in the four `DB_duchy_*.txt` files. Their old `type = duchy_capital` fields are now `flag = duchy_building`, matching current vanilla buildings. Added one wrapping duchy-capital district per chain in `common/districts/skonester_db_duchy_districts.txt`.

The wrappers retain the original first-tier construction conditions and use vanilla's duchy-holder enablement check. Existing building IDs, upgrade chains, costs, bonuses, faith/culture restrictions and innovation requirements are retained. No vanilla holding file was replaced.

The first parser run caught a removed lighthouse terrain helper. Its original 1.20 body was exactly `is_coastal = yes OR is_riverside_province = yes`. This same condition is now inlined in all three lighthouse tiers and their district wrapper. The current vanilla port helper also imposes a county-capital condition, so it was not substituted for the original water rule.

Added **196 new localization keys per language** in English, German, Russian, Simplified Chinese and Turkish, providing the current direct building names/descriptions and district labels. Existing localized text and old keys are retained; unavailable translations use the existing English wording.

The [part-5 manifest](batch-03/part-05/manifest.json) records all original files, hashes and district chains. Its recorded migration script and diffs are saved alongside it.

### Part 6: main building cheat

Replaced the two obsolete catalog implementations in `skonester_crozier_cheats_effects.txt` with calls to `common/scripted_effects/skonester_121_building_cheats_effects.txt`. The public effect IDs, **369 unrelated effect bodies**, GUI entry points and original **ten-pass** realm action are unchanged.

The new upgrade helper iterates actual buildings in active regular districts and the holding, duchy-capital, special, great and entrepot districts. It checks `can_building_be_upgraded` before applying the building-scoped `upgrade_this_building` effect. This resolves buildings from the running database, including compatible mod additions, rather than retaining a fixed list of obsolete IDs.

The build helper uses the current province-level random-building constructor with the actual saved district scope. It attempts three valid additions per existing district per pass and uses the existing AI construction selector where free regular district slots are available. Normal construction eligibility still applies. Foreign-owned trade posts are outside this holding-building action.

The source is reproducible with `tools/gen_skonester_121_building_cheats.py`. The [part-6 manifest](batch-03/part-06/manifest.json) records the preserved public IDs, pass count, original file and exact required engine commands.

### Verification

Generated a fresh 1.21 `script_docs` reference using the documented command-line console-action option with separate prefixed logs; see [engine-docs](batch-03/engine-docs/). Every new engine command and scope bridge was checked against this dump. The temporary headless documentation process was closed after its output was preserved.

Static checks passed for all 13 modified/added implementation files: original building data and unaffected effects are preserved; district roots/chains resolve; new localized keys are unique and their aliases resolve; the helper generator reproduces the saved source; braces and file hashes match. See [validation.json](batch-03/validation.json).

After correcting the lighthouse helper, a second headless startup completed history and post-history setup and exited normally with **exit code 0**. It used `-debug_mode -nographics -suppress_error_log -shutdown_after_history` and separate `skonester_batch03_check2_` logs. The ordinary user `error.log` remained byte-identical to the preserved pre-batch log.

| Targeted error family | Pre-batch user log | Headless load after fixes |
| --- | ---: | ---: |
| Custom building `type` rejected | 72 | 0 |
| Missing upgrade target in the Crozier catalog | 352 | 0 |
| Invalid building checks in that catalog | 352 | 0 |
| Corresponding failed upgrade validation | 352 | 0 |
| Removed lighthouse water helper | 3 | 0 |

Neither the new district file nor the new building helper file reports errors. Unknown-modifier errors also remain at zero. Full evidence is in [engine-check/result.json](batch-03/engine-check/result.json) and its preserved logs. This headless run has 3,697 records; its total is not directly comparable with a played UI session.

Two pre-existing records in the original Crozier file still concern an unrelated missing decision-cooldown target. The **112** province/district scope errors in the other building tools also remain queued for part 7. They are separate from this batch's repaired catalog.

### In-game checkpoint — targeted log check passed

The headless load validates parsing and setup, but does not click the cheat or inspect construction menus. Start a fresh debug game with Skonester, then:

1. Open construction in a duchy capital whose holder meets the custom building's faith/culture/innovation requirements. Check that its custom district and building names, costs and tooltips appear.
2. Exercise the realm building action in the portrait cheat menu, preferably in a small realm for this check. Verify that valid building chains advance and available district building slots fill. Requirements and available slots still limit construction.
3. Reopen the character/right-click menus to recheck earlier fixes, then leave the fresh error log available for comparison.

The next comparison uses [batch-03/targets.json](batch-03/targets.json), checks both new files for errors and rechecks all earlier target families. Existing old saves containing the old building layout need a separate migration assessment; this batch was checked against new-game history setup.

The fresh user session beginning at **12:10:08** passes all batch-3 target checks. The latest saved review through **12:16:44** has **3,816 records**; all earlier target families also remain at zero. Neither new implementation file reports errors. See [remaining-review/result.json](remaining-review/result.json) and its preserved snapshot. Visual behavior and button execution were not independently observed.

**Checkpoint result: targeted fresh-log check passed. Parts 7 and 8 are next. No gameplay files were changed during this review.**

### Separate portrait follow-up with EPE loaded

The 12:27:27 session confirms EPE followed by Skonester. Current installed EPE's first 480 character-window lines and complete secondary portrait/widget types match Skonester exactly; EPE does not override the shared portrait templates or named main/spouse camera file. The 3,782-record snapshot has no portrait-window/camera references. Live paused inspection confirms the main/spouse frame swap, but does not establish an abnormal proportion regression. No implementation files changed. See [portrait-framing-review.md](portrait-framing-review.md) and [epe-portrait-review/result.json](epe-portrait-review/result.json). Parts 7 and 8 remain next; this is not a numbered repair batch.
