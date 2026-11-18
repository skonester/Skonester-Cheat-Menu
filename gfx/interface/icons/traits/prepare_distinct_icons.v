// Prepare per-trait regeneration inputs for reused artwork.
//
// Run beside the DDS files after convert_dds_to_png.v. No game files are edited.
module main

import os
import iconkit { Json, path }

fn localized(key string, loc map[string]string) string {
	mut value := loc[key] or { '' }
	for _ in 0 .. 8 {
		updated := iconkit.substitute_vars(value, loc)
		if updated == value {
			break
		}
		value = updated
	}
	return value
}

fn first_nonempty(values ...string) string {
	for v in values {
		if v != '' {
			return v
		}
	}
	return ''
}

fn prepare() ! {
	base := os.real_path(@DIR)
	root := iconkit.parents(base, 4)
	out := path(base, 'distinct_generation')

	mut loc := map[string]string{}
	for file in iconkit.files_with_ext(path(root, 'localization/english'), '.yml') {
		iconkit.parse_localization(iconkit.read_text(file)!, mut loc)
	}

	mut images := map[string]string{}
	mut signatures := map[string]string{}
	mut groups := map[string][]string{}
	for file in iconkit.files_with_ext(path(base, 'png'), '.png') {
		rgba := iconkit.open_image(file)!.convert(.rgba)
		signature := '(${rgba.w}, ${rgba.h}):' + iconkit.digest(rgba.data)
		name := iconkit.stem(file)
		images[name] = file
		signatures[name] = signature
		mut members := groups[signature] or { []string{} }
		members << name
		groups[signature] = members
	}

	mut traits := []map[string]Json{}
	mut users := map[string][]string{}
	for file in iconkit.files_with_ext(path(root, 'common/traits'), '.txt') {
		text := iconkit.read_text(file)!
		for block in iconkit.blocks(text) {
			trait := block.name
			body := text[block.start..block.end]
			icon := if v := iconkit.line_value(body, 'icon', true) { iconkit.stem(v) } else { trait }
			if icon !in images {
				continue
			}
			mut label := if v := iconkit.line_value(body, 'name', false) {
				localized(v, loc)
			} else {
				''
			}
			label = first_nonempty(label, localized('trait_' + trait, loc), localized(trait, loc),
				trait)
			description := first_nonempty(localized('trait_' + trait + '_desc', loc), localized(
				trait + '_desc', loc))
			traits << {
				'trait_id':        Json(trait)
				'name':            Json(label)
				'description':     Json(description)
				'source_icon':     Json(icon + '.dds')
				'definition_file': Json(iconkit.posix(iconkit.relative_to(file, root)))
			}
			mut list := users[signatures[icon]] or { []string{} }
			list << trait
			users[signatures[icon]] = list
		}
	}

	// Art direction proposals, based on the actual localized trait meanings.
	mut subjects := {
		'skonester_trait_marriage_ban':     'Two separated wedding rings divided by a stern iron seal; no chalice or potion.'
		'skonester_trait_yannian_dan':      'A simple jade elixir bottle with one small gold bead.'
		'skonester_trait_yannian_dan_mid':  'An ornate jade elixir bottle with two gold beads; same silhouette as the basic longevity elixir.'
		'skonester_trait_yannian_dan_best': 'An imperial jade elixir bottle with three gold beads and a restrained golden halo; same family as the lesser elixirs.'
		'skonester_trait_immortal_ageless': 'An unbroken golden ring enclosing an evergreen sprig and a still hourglass.'
		'trait_eternal_nether_lord':        'A dark sovereign crown enclosing a cold violet flame, imposing and composed.'
		'trait_nether_conspiracy_lord':     'A black dagger passing behind a veiled crown, with a subtle violet shadow.'
		'trait_ultimate_intrigue_master':   'An open watchful eye inside a silver divination mirror, with a concealed dagger below.'
		'trait_great_builder_god':          'A golden mason compass over a precisely cut stone arch, with restrained divine light.'
		'trait_warlord_eternal':            'A crowned steel helmet before crossed war banners, with a restrained golden halo.'
		'trait_wealth_sovereign_max':       'A royal treasury chest overflowing with a few large gold coins beneath a small crown.'
		'tyranny_gain_remove':              'Balanced justice scales over a sealed legal parchment.'
		'insane_generale':                  'A western captain helmet above a sword and a small white-tree heraldic motif.'
		'insane_opinion_fv':                'A faceless black hood beneath nine small iron crown points.'
		'insane_opinion_fa':                'A shadowed iron gauntlet gripping an oath chain.'
		'crazyminded_psycho':               'A cracked dark heart pierced by an iron thorn, with a restrained ember glow.'
		'water_of_life':                    'A sacred chalice before an open illuminated scripture, with soft holy light.'
		'toc_gamer0':                       'A deceptive half-mask with a concealed dagger.'
		'toc_gamerblood0':                  'A dark tower enclosing a crimson blood gem and faint whispering wisps.'
		'toc_immortal':                     'A pale undying flame inside a silver ring.'
		'toc_immortalblood':                'A luminous blood droplet enclosing a tiny star, framed by ancestral branches.'
		'immortality':                      'A golden infinity knot surrounding a living green leaf.'
		'greatest_lord_np':                 'A stewardship key laid across a stone keep.'
		'greatest_lord_t':                  'A noble coronet above three small heraldic shields.'
		'pantokratorus_a':                  'A single high king crown above a royal sceptre.'
		'pantokratorus_ablood':             'A royal crown above a blood gem with branching ancestral roots.'
		'borntorule_seed':                  'A reforged sword beneath a seven-pointed star and a small heir coronet.'
	}
	for i, trait in ['first_bloodline1', 'second_bloodline2', 'third_bloodline3', 'fourth_bloodline4',
		'fifth_bloodline5'] {
		n := i + 1
		subjects[trait] = 'A western heraldic tree with a blood-red gem, tier ${n} of five; use ${n} clear gold rank studs and progressively richer branches. Keep the family silhouette consistent.'
	}
	for i, trait in ['toc_patrilinealblood', 'toc_patrilinealblood2', 'toc_patrilinealblood3'] {
		n := i + 1
		subjects[trait] = 'A paternal ancestral tree growing from a signet ring, tier ${n} of three, with ${n} prominent silver rank studs and progressively richer heraldry.'
	}
	for n in [1, 2] {
		subjects['bloodline_god_${n}'] = 'A sacred blood droplet inside a radiant ancestral crest, rank ${n} of the Barbara bloodline; ${n} clear gold rank studs. Preserve family resemblance while making the rank readable.'
	}

	iconkit.mkdirs(path(out, 'inputs'))!
	iconkit.mkdirs(path(out, 'prompts'))!
	mut selected := []map[string]Json{}
	for record_ in traits {
		mut record := record_.clone()
		trait := record['trait_id'] or { Json('') }.s()
		icon := iconkit.stem(record['source_icon'] or { Json('') }.s())
		signature := signatures[icon]
		trait_users := users[signature] or { []string{} }
		group := groups[signature] or { []string{} }
		if trait_users.len < 2 && group.len < 2 {
			continue
		}
		record['same_artwork_files'] = iconkit.jstrs(group.map(it + '.dds'))
		record['same_artwork_traits'] = iconkit.jstrs(trait_users)
		record['input_png'] = Json('inputs/${trait}.png')
		record['proposed_output_dds'] = Json(trait + '.dds')
		record['requires_icon_reference_change'] = Json(trait != icon)
		record['reason'] = Json('Multiple traits resolve to identical decoded RGBA artwork.')
		subject := subjects[trait] or {
			'Choose a unique medieval emblem expressing this specific trait meaning.'
		}
		prompt :=
			'Create a distinct Crusader Kings III style trait icon for ${record['name'] or {
			Json('')
		}.s()}. ' +
			'Trait meaning: ${record['description'] or { Json('') }.s()} ' +
			'Subject: ${subject} ' +
			'Use the supplied image as a reference for icon format, palette and painted finish; ' +
			'replace its borrowed subject where it conflicts with this trait. ' +
			'One clear centered emblem, refined hand-painted shading, restrained highlights, ' +
			'strong silhouette and generous edge padding, readable at small game UI size. ' +
			'No lettering, no watermark, no scenery, no checkerboard pattern. ' +
			'Keep related bloodline and elixir tiers visually related but visibly distinguishable.'
		record['prompt'] = Json(prompt)
		target := path(out, 'inputs/${trait}.png')
		source := os.read_bytes(images[icon])!
		if os.exists(target) {
			if os.read_bytes(target)! != source {
				return error('Refusing to overwrite changed input: ${target}')
			}
		} else {
			iconkit.copy2(images[icon], target)!
		}
		if os.read_bytes(target)! != source {
			return error('Input copy verification failed: ${target}')
		}
		iconkit.write_text(path(out, 'prompts', trait + '.txt'), prompt + '\n')!
		selected << record
	}

	mut duplicate_groups := []Json{}
	for _, names in groups {
		if names.len > 1 {
			duplicate_groups << iconkit.jstrs(names)
		}
	}
	report := Json({
		'scope':                 Json('Exact decoded RGBA duplicates and shared icon references within this mod; not a visual near-duplicate or vanilla-asset audit.')
		'source_png_count':      Json(i64(images.len))
		'mapped_trait_count':    Json(i64(traits.len))
		'selected_trait_count':  Json(i64(selected.len))
		'duplicate_file_groups': Json(duplicate_groups)
		'jobs':                  Json(selected.map(Json(it)))
	})
	iconkit.write_text(path(out, 'manifest.json'), iconkit.dumps(report, 2, false) + '\n')!
	mut lines := [
		'# Traits needing distinct artwork',
		'',
		'${selected.len} per-trait inputs selected from ${images.len} original PNGs.',
		'',
		'Inputs are copies of the current artwork, NOT newly generated images. Originals remain untouched.',
		'Each input is named for its trait ID, including traits currently sharing one DDS filename.',
		'',
		'Use inputs/ for the image batch. Pair each image with its matching prompts/<trait_id>.txt.',
		'The prompt files are generation briefs; ComfyUI must be configured to load the corresponding prompt for each image.',
		'manifest.json contains the trait meanings, duplicate groups, source mappings and proposed output names.',
		'',
		'Every member of a reused-artwork group is included so you can decide which version to retain.',
		'Related tiers should receive coordinated variations rather than unrelated symbols.',
		'Selection uses exact decoded pixels and trait icon references; similar but nonidentical images are not assessed.',
		'',
		'After generation, clean the alpha channel and export DDS. For rows marked yes below,',
		'the trait definition must later point to the proposed unique DDS filename.',
		'No trait definitions have been changed during preparation.',
		'',
		'| Trait ID | Display name | Current DDS | Change icon reference later |',
		'|---|---|---|---|',
	]
	mut reference_changes := 0
	for record in selected {
		change := (record['requires_icon_reference_change'] or { Json(false) }).b()
		if change {
			reference_changes++
		}
		cells := ['trait_id', 'name', 'source_icon'].map((record[it] or { Json('') }).s())
		lines << '| ${cells[0]} | ${cells[1]} | ${cells[2]} | ${if change { 'yes' } else { 'no' }} |'
	}
	iconkit.write_text(path(out, 'README.md'), lines.join('\n') + '\n')!
	println('Prepared and verified ${selected.len} per-trait PNG inputs and matching prompts.')
	println('Duplicate file groups: ${duplicate_groups.len}')
	println('Later icon reference changes: ${reference_changes}')
	println(out)
}

fn main() {
	prepare() or {
		eprintln('Error: ${err.msg()}')
		exit(1)
	}
}
