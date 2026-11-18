module iconkit

import os

pub const install_doc = 'Export selected icons as 100x100 RGBA DDS; use --install to replace game assets.

Backs up every changed file before installation. Existing
unrelated textures and trait settings are preserved. Run without --install
to prepare and verify exports and trait-file patches only.'

// write_changes writes every file, restoring the originals if any write fails.
pub fn write_changes(order []string, changed map[string]Blob, originals map[string]Blob, verify fn (string, Blob) !) ! {
	mut written := []string{}
	for target in order {
		written << target
		write_attempt(target, changed[target] or { Blob{} }, originals[target] or { Blob{} },
			verify) or {
			for restore in written.reverse() {
				old := originals[restore] or { Blob{} }
				if old.exists {
					os.write_file_array(restore, old.data) or {}
				} else {
					os.rm(restore) or {}
				}
			}
			return err
		}
	}
}

fn write_attempt(target string, data Blob, old Blob, verify fn (string, Blob) !) ! {
	verify(target, old)!
	mkdirs(os.dir(target))!
	os.write_file_array(target, data.data)!
	if os.read_bytes(target)! != data.data {
		return error('Installed file verification failed: ${target}')
	}
}

pub fn install_dds_icons(p Paths, argv []string) ! {
	cli := parse_cli('install_dds_icons', install_doc, 'install_dds_icons [-h] [--install]', argv, [
		'install',
	], [], [])
	selected := parse_json(read_text(path(p.base, 'results/selection.json'))!)!.arr()
	mut jobs := map[string]Json{}
	for j in parse_json(read_text(path(p.base, 'manifest.json'))!)!.at('jobs').arr() {
		jobs[j.at('trait_id').s()] = j
	}
	dds_dir, png_dir := path(p.base, 'results/dds_100'), path(p.base, 'results/png_100')
	mkdirs(dds_dir)!
	mkdirs(png_dir)!
	mut edits := map[string]Blob{}
	mut originals := map[string]Blob{}
	mut reference_updates := []Json{}
	mut targets := map[string]bool{}
	for selection in selected {
		trait := selection.at('trait_id').s()
		job := jobs[trait] or { return error('KeyError: ${trait}') }
		filename := job.at('proposed_output_dds').s()
		if os.file_name(filename) != filename || !filename.ends_with('.dds') || filename in targets {
			return error('Invalid or repeated output name: ${filename}')
		}
		targets[filename] = true
		rgba :=
			open_image(path(p.base, 'results/masters', '${trait}.png'))!.convert(.rgba).resize(100, 100)
		lo, hi := rgba.alpha_extrema()
		if lo != 0 || hi != 255 {
			return error('Missing full transparency or opaque foreground: ${trait}')
		}
		rgba.save_png(path(png_dir, '${trait}.png'), {})!
		export := path(dds_dir, filename)
		// Legacy DDS with uncompressed 32-bit BGRA, straight alpha, one surface.
		// This preserves every resized pixel and avoids BC compression artifacts.
		os.write_file_array(export, rgba.encode_dds())!
		check := open_image(export)!
		if check.w != 100 || check.h != 100 || check.convert(.rgba).data != rgba.data {
			return error('DDS round-trip mismatch: ${trait}')
		}
		target := path(p.traits, filename)
		originals[target] = read_blob(target)!
		edits[target] = Blob{true, os.read_bytes(export)!}

		definition := path(p.root, job.at('definition_file').s())
		if !is_relative_to(definition, path(p.root, 'common/traits')) {
			return error('Trait definition outside common/traits: ${definition}')
		}
		if job.at('requires_icon_reference_change').b() {
			if definition !in originals {
				originals[definition] = read_blob(definition)!
			}
			text := (edits[definition] or { originals[definition] or { Blob{} } }).data.bytestr()
			start, end := trait_span(text, trait)!
			body := text[start..end]
			matches := icon_refs(body)
			if matches.len != 1 {
				return error('Expected one explicit icon reference for ${trait}')
			}
			m := matches[0]
			if m.value != job.at('source_icon').s() && m.value != filename {
				return error('Unexpected current icon for ${trait}: ${m.value}')
			}
			updated := body[..m.start] + filename + body[m.end..]
			edits[definition] = Blob{true, (text[..start] + updated + text[end..]).bytes()}
			reference_updates << Json({
				'trait_id': Json(trait)
				'file':     job.at('definition_file')
				'previous': Json(m.value)
				'new':      Json(filename)
			})
		} else {
			text := os.read_bytes(definition)!.bytestr()
			start, end := trait_span(text, trait)!
			actual_icon := line_value(text[start..end], 'icon', true) or { trait + '.dds' }
			if actual_icon != filename {
				return error('Trait ${trait} resolves to ${actual_icon}, not ${filename}')
			}
		}
	}

	stage := path(p.base, 'results/trait_patches')
	for target, data in edits {
		if !same_path(os.dir(target), p.traits) {
			staged := path(stage, relative_to(target, p.root))
			mkdirs(os.dir(staged))!
			os.write_file_array(staged, data.data)!
		}
	}
	mut changed := map[string]Blob{}
	for target, data in edits {
		if (originals[target] or { Blob{} }) != data {
			changed[target] = data
		}
	}
	mut files := map[string]bool{}
	for r in reference_updates {
		files[r.at('file').s()] = true
	}
	println('Exported and pixel-verified ${selected.len} transparent 100x100 DDS files.')
	println('Prepared ${reference_updates.len} icon references in ${files.len} trait files.')
	println('Pending file changes: ${changed.len}')
	if !cli.has('install') {
		println('Prepared only. Run with --install to back up and install.')
		return
	}
	if changed.len == 0 {
		println('Already installed; no files changed.')
		return
	}

	// Detect edits made while preparing, before any game files are replaced.
	for target, _ in changed {
		if read_blob(target)! != (originals[target] or { Blob{} }) {
			return error('File changed during preparation: ${target}')
		}
	}
	backup := path(p.base, 'backups', utc_stamp())
	if os.exists(backup) {
		return error('Backup folder already exists: ${backup}')
	}
	os.mkdir_all(backup)!
	mut records := []Json{}
	for target, data in changed {
		relative := relative_to(target, p.root)
		old := originals[target] or { Blob{} }
		if old.exists {
			saved := path(backup, relative)
			mkdirs(os.dir(saved))!
			os.write_file_array(saved, old.data)!
			if os.read_bytes(saved)! != old.data {
				return error('Backup verification failed: ${target}')
			}
		}
		records << Json({
			'path':          Json(posix(relative))
			'existed':       Json(old.exists)
			'before_sha256': if old.exists { Json(digest(old.data)) } else { Json(Null{}) }
			'after_sha256':  Json(digest(data.data))
		})
	}
	mut record := {
		'status':                 Json('backed_up')
		'export_size':            ints(100, 100)
		'format':                 Json('32-bit BGRA DDS, straight alpha, no mipmaps')
		'files':                  Json(records)
		'icon_reference_updates': Json(reference_updates)
	}
	report_path := path(backup, 'installation.json')
	write_text(report_path, dumps(Json(record), 2, true))!
	write_changes(changed.keys(), changed, originals, fn (_ string, _ Blob) ! {}) or {
		record['status'] = Json('rolled_back')
		write_text(report_path, dumps(Json(record), 2, true))!
		return err
	}
	record['status'] = Json('installed')
	write_text(report_path, dumps(Json(record), 2, true))!
	mut result := record.clone()
	result['backup'] = Json(backup)
	write_text(path(p.base, 'results/installation.json'), dumps(Json(result), 2, true))!
	println('Installed ${selected.len} DDS icons and updated their trait references.')
	println('Backup: ${backup}')
}
