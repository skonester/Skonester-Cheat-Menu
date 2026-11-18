module main

import compress.szip
import crypto.sha256
import encoding.utf8
import hash
import json
import os
import time

// szip bundles miniz. Its extraction callback lets verification hash each entry
// in chunks, without extracting files or loading a whole archive into memory.
type ExtractCallback = fn (voidptr, u64, voidptr, usize) usize

fn C.zip_entry_extract(&szip.Zip, ExtractCallback, voidptr) int

$if windows {
	#include <windows.h>

	fn C.MoveFileExW(&u16, &u16, u32) int
}

struct Settings {
	mods_dir   string
	output_dir string
}

struct Options {
mut:
	mods_dir    string
	output_dir  string
	selected    []string
	list_only   bool
	help        bool
	compression int = 6
}

struct SkippedFolder {
	folder string
	reason string
}

struct BackupError {
	folder string
	error  string
}

struct ModBackup {
	folder                     string
	name                       string
	version                    string
	source_directory           string
	zip                        string
	zip_bytes                  u64
	zip_sha256                 string
	source_files               int
	source_bytes               u64
	archive_files              int
	portable_path              string
	outer_descriptor_generated bool
	original_launcher_backup   string
	verified                   bool
	warnings                   []string
}

struct Manifest {
	started_utc    string
	mods_directory string
	layout         string = '<folder>.mod beside <folder>/descriptor.mod and all mod files'
	implementation string = 'V'
mut:
	finished_utc    string
	status          string = 'running'
	mods            []ModBackup
	errors          []BackupError
	skipped_folders []SkippedFolder
	total_zip_bytes u64
}

struct HashContext {
mut:
	digest hash.Hash
	failed bool
	bytes  u64
}

fn strip_bom(text string) !string {
	if !utf8.validate_str(text) {
		return error('Descriptor is not valid UTF-8')
	}
	return text.trim_string_left('\xef\xbb\xbf')
}

fn quoted_field(text string, key string) !string {
	mut found := false
	mut value := ''
	for line in text.split_into_lines() {
		if !line.contains('=') || line.all_before('=').trim_space() != key {
			continue
		}
		rhs := line.all_after('=').trim_space()
		if !rhs.starts_with('"') {
			continue
		}
		rest := rhs[1..]
		end := rest.index('"') or { continue }
		if found {
			return error('Multiple "${key}" fields in descriptor')
		}
		found = true
		value = rest[..end]
	}
	return value
}

fn portable_launcher(text string, folder string) !string {
	mut lines := []string{}
	mut replacements := 0
	for line in text.split('\n') {
		if line.contains('=') && line.all_before('=').trim_space() == 'path'
			&& line.all_after('=').trim_space().starts_with('"') {
			lines << 'path="mod/${folder}"'
			replacements++
		} else {
			lines << line
		}
	}
	if replacements > 1 {
		return error('Multiple path statements in launcher descriptor')
	}
	mut result := lines.join('\n').trim_right(' \t\r\n')
	if replacements == 0 {
		result += '\npath="mod/${folder}"'
	}
	return result + '\n'
}

fn canonical_path(input string) string {
	mut path := input
	if path == '~' {
		path = os.home_dir()
	} else if path.starts_with('~/') || path.starts_with('~\\') {
		path = os.join_path(os.home_dir(), path[2..])
	}
	absolute := os.abs_path(path)
	if os.exists(absolute) {
		return os.real_path(absolute)
	}
	parent := os.dir(absolute)
	if parent == absolute {
		return absolute
	}
	return os.join_path(canonical_path(parent), os.base(absolute))
}

fn path_inside(path string, parent string) bool {
	mut child := path.replace('\\', '/').trim_right('/')
	mut base := parent.replace('\\', '/').trim_right('/')
	$if windows {
		child = child.to_lower()
		base = base.to_lower()
	}
	return child == base || child.starts_with(base + '/')
}

fn options_from_args(args []string, here string) !Options {
	config_path := os.join_path(here, 'backup_settings.json')
	mut settings := Settings{}
	if os.exists(config_path) {
		settings = json.decode(Settings, os.read_file(config_path)!)!
	}
	mut opts := Options{
		mods_dir:   if settings.mods_dir != '' {
			settings.mods_dir
		} else {
			os.join_path(os.home_dir(), 'Documents', 'Paradox Interactive', 'Crusader Kings III',
				'mod')
		}
		output_dir: if settings.output_dir != '' {
			settings.output_dir
		} else {
			os.join_path(here, 'runs')
		}
	}
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg in ['--help', '-h'] {
			opts.help = true
		} else if arg == '--list' {
			opts.list_only = true
		} else if arg in ['--mods-dir', '--output-dir', '--mod', '--compression'] {
			i++
			if i >= args.len || args[i] == '' {
				return error('Missing value for ${arg}')
			}
			value := args[i]
			match arg {
				'--mods-dir' {
					opts.mods_dir = value
				}
				'--output-dir' {
					opts.output_dir = value
				}
				'--mod' {
					opts.selected << value.to_lower()
				}
				'--compression' {
					if value.len != 1 || value[0] < `1` || value[0] > `9` {
						return error('Compression must be an integer from 1 to 9')
					}
					opts.compression = value.int()
				}
				else {}
			}
		} else {
			return error('Unknown argument: ${arg}; use --help')
		}
		i++
	}
	opts.mods_dir = canonical_path(opts.mods_dir)
	opts.output_dir = canonical_path(opts.output_dir)
	return opts
}

fn discover(mods_dir string) !([]string, []SkippedFolder) {
	mut folders := []string{}
	mut skipped := []SkippedFolder{}
	mut names := os.ls(mods_dir)!
	names.sort(a.to_lower() < b.to_lower())
	for name in names {
		folder := os.join_path(mods_dir, name)
		if !os.is_dir(folder) {
			continue
		}
		lower := name.to_lower()
		mut reason := ''
		if os.is_link(folder) {
			reason = 'Linked directory needs manual review'
		} else if lower.starts_with('ugc_') || lower.starts_with('pdx_') {
			reason = 'Downloaded subscription'
		} else if os.is_file(os.join_path(folder, 'descriptor.mod'))
			|| os.is_file(os.join_path(mods_dir, name + '.mod')) {
			folders << folder
		} else {
			reason = 'No local mod descriptors'
		}
		if reason != '' {
			skipped << SkippedFolder{
				folder: name
				reason: reason
			}
		}
	}
	return folders, skipped
}

fn collect_files(folder string, relative string, mut files []string) ! {
	for name in os.ls(os.join_path(folder, relative))! {
		rel := if relative == '' { name } else { relative + '/' + name }
		path := os.join_path(folder, rel)
		if os.is_link(path) {
			return error('Linked files or folders need manual review: ${path}')
		}
		if os.is_dir(path) {
			collect_files(folder, rel, mut files)!
		} else if os.is_file(path) {
			files << rel
		} else {
			return error('Cannot read source path: ${path}')
		}
	}
}

fn source_files(folder string) ![]string {
	mut files := []string{}
	collect_files(folder, '', mut files)!
	files.sort(a.to_lower() < b.to_lower())
	return files
}

fn sha256_file(path string) !string {
	mut stream := os.open(path)!
	defer { stream.close() }
	mut digest := sha256.new()
	mut buffer := []u8{len: 1024 * 1024}
	for {
		count := stream.read(mut buffer) or {
			if stream.eof() { break
			 }
			return err
		}
		if count == 0 { break
		 }
		digest.write(buffer[..count])!
	}
	return digest.sum([]u8{}).hex()
}

fn zip_add_bytes(mut archive szip.Zip, name string, data []u8) ! {
	archive.open_entry(name)!
	defer { archive.close_entry() }
	archive.write_entry(data)!
}

fn zip_add_file(mut archive szip.Zip, name string, path string) !string {
	archive.open_entry(name)!
	defer { archive.close_entry() }
	mut stream := os.open(path)!
	defer { stream.close() }
	mut digest := sha256.new()
	mut buffer := []u8{len: 1024 * 1024}
	for {
		count := stream.read(mut buffer) or {
			if stream.eof() { break
			 }
			return err
		}
		if count == 0 { break
		 }
		archive.write_entry(buffer[..count])!
		digest.write(buffer[..count])!
	}
	return digest.sum([]u8{}).hex()
}

fn hash_extract_chunk(arg voidptr, offset u64, data voidptr, size usize) usize {
	mut context := unsafe { &HashContext(arg) }
	if context.failed || offset != context.bytes || size > usize(2147483647) {
		context.failed = true
		return 0
	}
	chunk := unsafe { data.vbytes(int(size)) }
	context.digest.write(chunk) or {
		context.failed = true
		return 0
	}
	context.bytes += u64(size)
	return size
}

fn verify_archive(path string, expected map[string]string) ! {
	mut archive := szip.open(path, .no_compression, .read_only)!
	defer { archive.close() }
	if archive.total()! != expected.len {
		return error('Archive entry count differs from source')
	}
	mut seen := map[string]bool{}
	for index in 0 .. expected.len {
		archive.open_entry_by_index(index)!
		// szip.name() borrows miniz's buffer, which close_entry() releases.
		name := archive.name().clone()
		if name !in expected || name in seen {
			archive.close_entry()
			return error('Unexpected or duplicate ZIP entry: ${name}')
		}
		size := archive.size()
		mut context := HashContext{
			digest: sha256.new()
		}
		result := C.zip_entry_extract(archive, hash_extract_chunk, &context)
		archive.close_entry()
		if result < 0 || context.failed || context.bytes != size {
			return error('Archive integrity check failed: ${name}')
		}
		if context.digest.sum([]u8{}).hex() != expected[name] {
			return error('Archive content differs from source: ${name}')
		}
		seen[name] = true
	}
}

fn write_archive(path string, folder string, files []string, launcher string, compression int) !(map[string]string, u64) {
	mut archive := szip.open(path, unsafe { szip.CompressionLevel(compression) }, .write)!
	defer { archive.close() }
	base := os.base(folder)
	mut expected := map[string]string{}
	zip_add_bytes(mut archive, base + '.mod', launcher.bytes())!
	expected[base + '.mod'] = sha256.hexhash(launcher)
	mut source_bytes := u64(0)
	for relative in files {
		source := os.join_path(folder, relative)
		before := os.stat(source)!
		name := base + '/' + relative
		expected[name] = zip_add_file(mut archive, name, source)!
		after_hash := sha256_file(source)!
		after := os.stat(source)!
		if before.size != after.size || before.mtime != after.mtime || expected[name] != after_hash {
			return error('File changed during backup; retry: ${source}')
		}
		source_bytes += u64(before.size)
	}
	return expected, source_bytes
}

fn write_new(path string, data string) ! {
	// This destination belongs to a newly created, unique backup run.
	if os.exists(path) {
		return error('Refusing to replace an existing launcher backup: ${path}')
	}
	mut stream := os.open_file(path, 'wb')!
	defer { stream.close() }
	stream.write_string(data)!
}

fn package_mod(folder string, run_dir string, compression int) !ModBackup {
	base := os.base(folder)
	inner_path := os.join_path(folder, 'descriptor.mod')
	if !os.is_file(inner_path) {
		return error('Missing internal descriptor: ${inner_path}')
	}
	inner_original := os.read_file(inner_path)!
	inner := strip_bom(inner_original)!
	name := quoted_field(inner, 'name')!
	if name == '' {
		return error('Internal descriptor must have a quoted name field')
	}
	outer_path := os.join_path(os.dir(folder), base + '.mod')
	has_outer := os.is_file(outer_path)
	outer_original := if has_outer { os.read_file(outer_path)! } else { inner_original }
	outer := strip_bom(outer_original)!
	if quoted_field(outer, 'archive')! != '' {
		return error('Archive-based launcher descriptor needs manual review')
	}
	mut warnings := []string{}
	for field in ['name', 'version', 'supported_version', 'remote_file_id'] {
		if quoted_field(inner, field)! != quoted_field(outer, field)! {
			warnings << 'Internal and external ${field} differ; existing values preserved'
		}
	}
	launcher := portable_launcher(outer, base)!
	files := source_files(folder)!
	final_zip := os.join_path(run_dir, 'zips', base + '.zip')
	partial := final_zip + '.partial'
	if os.exists(final_zip) || os.exists(partial) {
		return error('Backup archive already exists: ${final_zip}')
	}
	expected, source_bytes := write_archive(partial, folder, files, launcher, compression)!
	if source_files(folder)! != files {
		return error('Files were added or removed during backup; retry')
	}
	if expected[base + '/descriptor.mod'] != sha256.hexhash(inner_original) {
		return error('Internal descriptor changed during packaging')
	}
	verify_archive(partial, expected)!
	if has_outer {
		write_new(os.join_path(run_dir, 'original_launchers', base + '.mod'), outer_original)!
	}
	os.rename(partial, final_zip)!
	return ModBackup{
		folder:                     base
		name:                       name
		version:                    quoted_field(inner, 'version')!
		source_directory:           folder
		zip:                        'zips/' + base + '.zip'
		zip_bytes:                  os.file_size(final_zip)
		zip_sha256:                 sha256_file(final_zip)!
		source_files:               files.len
		source_bytes:               source_bytes
		archive_files:              expected.len
		portable_path:              'mod/' + base
		outer_descriptor_generated: !has_outer
		original_launcher_backup:   if has_outer {
			'original_launchers/' + base + '.mod'
		} else {
			''
		}
		verified:                   true
		warnings:                   warnings
	}
}

fn save_manifest(run_dir string, manifest Manifest) ! {
	path := os.join_path(run_dir, 'manifest.json')
	temporary := path + '.tmp'
	os.write_file(temporary, json.encode_pretty(manifest) + '\n')!
	$if windows {
		// Replace only this run's manifest, atomically. Existing backups are separate runs.
		if C.MoveFileExW(temporary.to_wide(), path.to_wide(), u32(1 | 8)) == 0 {
			return error('Cannot replace backup manifest: ${path}')
		}
	} $else {
		os.rename(temporary, path)!
	}
}

fn usage() {
	println('CK3 mod upload backups (native V executable)\n')
	println('backup_mods.exe [--list] [--mod FOLDER ...] [--mods-dir PATH]')
	println('                [--output-dir PATH] [--compression 1-9]\n')
	println('Without options, back up every local mod using backup_settings.json.')
	println('Each ZIP contains <folder>.mod beside <folder>/descriptor.mod and all mod files.')
	println('Output defaults to a new dated folder under runs beside the executable.')
}

fn run_backup(opts Options) !int {
	if !os.is_dir(opts.mods_dir) {
		return error('Mod directory does not exist: ${opts.mods_dir}; use --mods-dir or backup_settings.json')
	}
	if path_inside(opts.output_dir, opts.mods_dir) {
		return error('Put backups outside the installed mod directory')
	}
	discovered, skipped := discover(opts.mods_dir)!
	mut folders := discovered.clone()
	if opts.selected.len > 0 {
		folders = discovered.filter(os.base(it).to_lower() in opts.selected)
		for selected in opts.selected {
			if !folders.any(os.base(it).to_lower() == selected) {
				return error('Unknown local mod folder: ${selected}')
			}
		}
	}
	if opts.list_only {
		for folder in folders {
			println(os.base(folder))
		}
		println('\n${folders.len} local mods; ${skipped.len} non-mod or downloaded folders skipped.')
		return 0
	}
	if folders.len == 0 { return error('No local mods found') }
	started := time.utc()
	run_name := 'backup_' + started.custom_format('YYYY-MM-DD_HH-mm-ss') +
		'_${started.unix_micro()}Z'
	run_dir := os.join_path(opts.output_dir, run_name)
	os.mkdir_all(opts.output_dir)!
	os.mkdir(run_dir)!
	os.mkdir(os.join_path(run_dir, 'zips'))!
	os.mkdir(os.join_path(run_dir, 'original_launchers'))!
	mut manifest := Manifest{
		started_utc:     started.format_rfc3339_micro()
		mods_directory:  opts.mods_dir
		skipped_folders: skipped
	}
	save_manifest(run_dir, manifest)!
	println('Backup folder: ${run_dir}')
	for index, folder in folders {
		println('[${index + 1}/${folders.len}] ${os.base(folder)} ...')
		backup := package_mod(folder, run_dir, opts.compression) or {
			manifest.errors << BackupError{
				folder: os.base(folder)
				error:  err.msg()
			}
			eprintln('  FAILED: ${err}')
			save_manifest(run_dir, manifest)!
			continue
		}
		manifest.mods << backup
		manifest.total_zip_bytes += backup.zip_bytes
		println('  Verified ${backup.archive_files} files; ${f64(backup.zip_bytes) / 1_000_000:.2f} MB')
		for warning in backup.warnings {
			println('  NOTE: ${warning}')
		}
		save_manifest(run_dir, manifest)!
	}
	manifest.finished_utc = time.utc().format_rfc3339_micro()
	manifest.status = if manifest.errors.len == 0 { 'complete' } else { 'completed_with_errors' }
	save_manifest(run_dir, manifest)!
	mut summary := [
		'Verified: ${manifest.mods.len}/${folders.len} local mods',
		'Failed: ${manifest.errors.len}',
		'ZIP files: ' + os.join_path(run_dir, 'zips'),
		'Layout: each ZIP contains <folder>.mod beside <folder>/descriptor.mod.',
		'Installed source files were not changed.',
		'',
	]
	for backup in manifest.mods {
		summary << 'OK  ${backup.folder}.zip - ${backup.name}'
	}
	for failure in manifest.errors {
		summary << 'FAILED  ${failure.folder}: ${failure.error}'
	}
	os.write_file(os.join_path(run_dir, 'summary.txt'), summary.join('\n') + '\n')!
	println('\n' + summary[..6].join('\n'))
	return if manifest.errors.len == 0 { 0 } else { 1 }
}

fn main() {
	here := os.dir(os.executable())
	opts := options_from_args(os.args[1..], here) or {
		eprintln('Error: ${err}')
		exit(2)
	}
	if opts.help {
		usage()
		return
	}
	status := run_backup(opts) or {
		eprintln('Error: ${err}')
		exit(2)
	}
	exit(status)
}
