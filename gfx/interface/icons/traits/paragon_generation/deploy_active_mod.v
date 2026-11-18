// Install this batch in the launcher's mod1 copy and repair the Mystic Seer icon.
module main

import os
import iconkit { Blob, Json, path }

const active = 'C:\\Users\\admin\\Documents\\Paradox Interactive\\Crusader Kings III\\mod\\mod1'

fn deploy() ! {
	base := os.real_path(@DIR)
	repo := iconkit.parents(base, 5)
	assets := path('gfx/interface/icons/traits')
	mut order := []string{}
	mut payload := map[string][]u8{}
	for name in ['super_governor', 'super', 'goodguy_toc'] {
		rel := path(assets, name + '.dds')
		order << rel
		payload[rel] = os.read_bytes(path(base, 'results/dds_100', name + '.dds'))!
	}
	// Ensure both distinct, already-reviewed intrigue images exist in the active mod.
	for name in ['savant_intrig', 'trait_ultimate_intrigue_master'] {
		rel := path(assets, name + '.dds')
		order << rel
		payload[rel] = os.read_bytes(path(repo, rel))!
	}
	definition := path('common/traits/skonester_intrigue_traits.txt')
	text := os.read_bytes(path(active, definition))!.bytestr()
	start, end := iconkit.trait_span(text, 'trait_ultimate_intrigue_master')!
	mut body := text[start..end]
	matches := iconkit.icon_refs(body)
	if matches.len != 1
		|| matches[0].value !in ['savant_intrig.dds', 'trait_ultimate_intrigue_master.dds'] {
		return error('Unexpected Mystic Seer icon mapping in active mod')
	}
	m := matches[0]
	body = body[..m.start] + 'trait_ultimate_intrigue_master.dds' + body[m.end..]
	order << definition
	payload[definition] = (text[..start] + body + text[end..]).bytes()
	savant := os.read_bytes(path(active, 'common/traits/savant_traits.txt'))!.bytestr()
	a, z := iconkit.trait_span(savant, 'savant_intrig')!
	if icon := iconkit.line_value(savant[a..z], 'icon', true) {
		if icon != 'savant_intrig.dds' {
			return error('Unexpected Savant icon mapping in active mod')
		}
	}

	mut changed_order := []string{}
	mut changed := map[string]Blob{}
	mut originals := map[string]Blob{}
	mut relatives := map[string]string{}
	for rel in order {
		target := path(active, rel)
		if !iconkit.is_relative_to(target, os.real_path(active)) {
			return error('Target outside active mod')
		}
		old := iconkit.read_blob(target)!
		data := Blob{true, payload[rel]}
		if old != data {
			changed_order << target
			changed[target] = data
			originals[target] = old
			relatives[target] = rel
		}
	}
	backup := path(base, 'active_mod_backups', iconkit.utc_stamp())
	if os.exists(backup) {
		return error('Backup folder already exists: ${backup}')
	}
	os.mkdir_all(backup)!
	mut records := []Json{}
	for target in changed_order {
		rel := relatives[target]
		old := originals[target] or { Blob{} }
		if old.exists {
			saved := path(backup, rel)
			iconkit.mkdirs(os.dir(saved))!
			os.write_file_array(saved, old.data)!
			if os.read_bytes(saved)! != old.data {
				return error('Backup verification failed: ${rel}')
			}
		}
		records << Json({
			'path':          Json(rel)
			'existed':       Json(old.exists)
			'before_sha256': if old.exists {
				Json(iconkit.digest(old.data))
			} else {
				Json(iconkit.Null{})
			}
			'after_sha256':  Json(iconkit.digest((changed[target] or { Blob{} }).data))
		})
	}
	iconkit.write_changes(changed_order, changed, originals, fn (target string, old Blob) ! {
		if iconkit.read_blob(target)! != old {
			return error('Active mod file changed during preparation: ${target}')
		}
	})!
	report := Json({
		'status':     Json('installed')
		'active_mod': Json(active)
		'backup':     Json(backup)
		'files':      Json(records)
		'fix':        Json('Mystic Seer now references trait_ultimate_intrigue_master.dds; Savant retains savant_intrig.dds.')
	})
	iconkit.write_text(path(backup, 'installation.json'), iconkit.dumps(report, 2, true))!
	iconkit.write_text(path(base, 'results/active_mod_installation.json'), iconkit.dumps(report, 2,
		true))!
	println('Installed ${changed.len} changed files in the launcher mod copy.')
	println('Backups: ${backup}')
}

fn main() {
	deploy() or {
		eprintln('Error: ${err.msg()}')
		exit(1)
	}
}
