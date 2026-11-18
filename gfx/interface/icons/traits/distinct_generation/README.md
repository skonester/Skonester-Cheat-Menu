> Installation complete: 42 transparent 100x100 DDS files are installed and the 11 shared references are updated. See `results/installation.json` for the backup location. The preparation audit below describes the original state.

# Traits needing distinct artwork

42 per-trait inputs selected from 73 original PNGs.

Inputs are copies of the current artwork, NOT newly generated images. Originals remain untouched.
Each input is named for its trait ID, including traits currently sharing one DDS filename.

Use inputs/ for the image batch. Pair each image with its matching prompts/<trait_id>.txt.
The prompt files are generation briefs; ComfyUI must be configured to load the corresponding prompt for each image.
manifest.json contains the trait meanings, duplicate groups, source mappings and proposed output names.

Every member of a reused-artwork group is included so you can decide which version to retain.
Related tiers should receive coordinated variations rather than unrelated symbols.
Selection uses exact decoded pixels and trait icon references; similar but nonidentical images are not assessed.

After generation, clean the alpha channel and export DDS. For rows marked yes below,
the trait definition must later point to the proposed unique DDS filename.
No trait definitions have been changed during preparation.

| Trait ID | Display name | Current DDS | Change icon reference later |
|---|---|---|---|
| build_speed_cheat | Reincarnation of Villard de Honnecourt | build_speed_cheat.dds | no |
| tyranny_gain_remove | Team of Top Lawyers | tyranny_gain_remove.dds | no |
| zg_buxiu | Immortal | zg_buxiu.dds | no |
| immortality | Immortal | immortality.dds | no |
| super_general | Warlord Anointed | super_general.dds | no |
| savant_intrig | Savant (Intrigue) | savant_intrig.dds | no |
| skonester_trait_immortal_ageless | Ageless Immortal | immortality.dds | yes |
| skonester_trait_yannian_dan | Longevity Elixir | water_of_life.dds | yes |
| skonester_trait_yannian_dan_mid | Refined Longevity Elixir | zg_buxiu.dds | yes |
| skonester_trait_yannian_dan_best | Supreme Longevity Elixir | toc_immortal.dds | yes |
| skonester_trait_marriage_ban | Marriage Restricted | water_of_life.dds | yes |
| trait_eternal_nether_lord | Eternal Nether Lord | crazyminded_psycho.dds | yes |
| trait_great_builder_god | Divine Builder | build_speed_cheat.dds | yes |
| trait_ultimate_intrigue_master | Mystic Seer | savant_intrig.dds | yes |
| trait_nether_conspiracy_lord | Nether Conspiracy Lord | zhuge_kill_02.dds | yes |
| trait_warlord_eternal | Eternal Warlord | super_general.dds | yes |
| trait_wealth_sovereign_max | Wealth Sovereign | boost_daiming.dds | yes |
| water_of_life | Sentinel of the Word | water_of_life.dds | no |
| bloodline_god_2 | Barbara's Royal Blood | bloodline_god_2.dds | no |
| bloodline_god_1 | Barbara's Spirit Blood | bloodline_god_1.dds | no |
| zhuge_kill_02 | King's Wine | zhuge_kill_02.dds | no |
| greatest_lord_np | Steward of the Realm | greatest_lord_np.dds | no |
| greatest_lord_t | Lord of the High Houses | greatest_lord_t.dds | no |
| insane_generale | Captain of the West | insane_generale.dds | no |
| insane_opinion_fv | Terror of the Nine | insane_opinion_fv.dds | no |
| insane_opinion_fa | Shadow of the Unseen | insane_opinion_fa.dds | no |
| crazyminded_psycho | Morgoth's Taint | crazyminded_psycho.dds | no |
| pantokratorus_a | High King | pantokratorus_a.dds | no |
| pantokratorus_ablood | Lineage of Kings | pantokratorus_ablood.dds | no |
| borntorule_seed | True Heir of Isildur | borntorule_seed.dds | no |
| first_bloodline1 | Kin of the Free Peoples | first_bloodline1.dds | no |
| second_bloodline2 | Scion of the High Houses | second_bloodline2.dds | no |
| third_bloodline3 | Legacy of Arnor | third_bloodline3.dds | no |
| fourth_bloodline4 | Heir of Westernesse | fourth_bloodline4.dds | no |
| fifth_bloodline5 | Blood of Elendil | fifth_bloodline5.dds | no |
| toc_gamerblood0 | Whispers of Orthanc | toc_gamerblood0.dds | no |
| toc_gamer0 | Master of Deceit | toc_gamer0.dds | no |
| toc_patrilinealblood | Ancestral Line of the Fathers | toc_patrilinealblood.dds | no |
| toc_patrilinealblood2 | Sovereign Paternal Legacy | toc_patrilinealblood2.dds | no |
| toc_patrilinealblood3 | Eternal House of the West | toc_patrilinealblood3.dds | no |
| toc_immortalblood | Spark of the Ainur | toc_immortalblood.dds | no |
| toc_immortal | Undying Spirit | toc_immortal.dds | no |
