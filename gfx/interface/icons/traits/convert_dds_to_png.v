// Convert this folder's DDS icons to PNG.
//
// Run: v run convert_dds_to_png.v
// Existing PNGs are skipped; use --overwrite to replace them.
module main

import os
import iconkit

const doc = "Convert this folder's DDS icons to PNG.

Run: v run convert_dds_to_png.v
Existing PNGs are skipped; use --overwrite to replace them."

fn convert(path string, output string) ! {
	rgba := iconkit.open_image(path)!.convert(.rgba)
	rgba.save_png(output, {})!
	check := iconkit.open_image(output)!.convert(.rgba)
	if check.w != rgba.w || check.h != rgba.h || check.data != rgba.data {
		return error('PNG pixel verification failed')
	}
}

fn main() {
	cli := iconkit.parse_cli('convert_dds_to_png', doc, 'convert_dds_to_png [-h] [--overwrite]',
		os.args[1..], ['overwrite'], [], [])
	source := os.real_path(@DIR)
	destination := os.join_path(source, 'png')
	files := iconkit.files_with_ext(source, '.dds')
	if files.len == 0 {
		eprintln('No DDS files found beside the script.')
		exit(1)
	}
	iconkit.mkdirs(destination) or { panic(err) }
	mut converted, mut skipped, mut failed := 0, 0, 0
	for path in files {
		output := os.join_path(destination, iconkit.stem(path) + '.png')
		if os.exists(output) && !cli.has('overwrite') {
			skipped++
			continue
		}
		convert(path, output) or {
			println('FAILED ${os.file_name(path)}: ${err.msg()}')
			failed++
			continue
		}
		converted++
	}
	println('Converted and verified: ${converted}; skipped: ${skipped}; failed: ${failed}')
	println('PNG folder: ${destination}')
	exit(if failed > 0 { 1 } else { 0 })
}
