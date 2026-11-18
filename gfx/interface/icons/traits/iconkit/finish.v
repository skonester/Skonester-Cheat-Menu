module iconkit

import os
import strconv

pub const finish_doc = 'Remove generated backgrounds and export transparent masters and 120px previews.

Uses the U2Net model distributed by https://github.com/danielgatis/rembg.
Requires onnxruntime.dll (CPU). Originals and generated RGB masters are retained.'

pub const default_model = 'C:\\Users\\admin\\Downloads\\ComfyUI_windows_portable_nvidia\\ComfyUI_windows_portable\\ComfyUI\\models\\background_removal\\u2net.onnx'

const rank_families = [
	['skonester_trait_yannian_dan', 'skonester_trait_yannian_dan_mid',
		'skonester_trait_yannian_dan_best'],
	['first_bloodline1', 'second_bloodline2', 'third_bloodline3', 'fourth_bloodline4',
		'fifth_bloodline5'],
	['toc_patrilinealblood', 'toc_patrilinealblood2', 'toc_patrilinealblood3'],
	['bloodline_god_1', 'bloodline_god_2'],
]

// u2net_mask predicts a foreground mask for an RGB image at its own size.
fn u2net_mask(session &OrtSession, rgb_img Image) !Image {
	shrunk := rgb_img.resize(320, 320)
	mut peak := f32(0)
	for i in 0 .. 320 * 320 {
		for c in 0 .. 3 {
			peak = if shrunk.data[i * 4 + c] > peak { f32(shrunk.data[i * 4 + c]) } else { peak }
		}
	}
	if peak < 1e-6 {
		peak = 1e-6
	}
	mean := [f32(.485), .456, .406]
	std := [f32(.229), .224, .225]
	mut tensor := []f32{len: 3 * 320 * 320}
	for i in 0 .. 320 * 320 {
		for c in 0 .. 3 {
			tensor[c * 320 * 320 + i] = (f32(shrunk.data[i * 4 + c]) / peak - mean[c]) / std[c]
		}
	}
	prediction := session.run(tensor, [i64(1), 3, 320, 320], 320 * 320)!
	mut lo, mut hi := prediction[0], prediction[0]
	for v in prediction {
		lo = if v < lo { v } else { lo }
		hi = if v > hi { v } else { hi }
	}
	span := if hi - lo > 1e-6 { hi - lo } else { f32(1e-6) }
	mut mask := new_image(.l, 320, 320, Color{})
	for i, v in prediction {
		mut m := (v - lo) / span
		m = if m < 0 {
			f32(0)
		} else if m > 1 {
			f32(1)
		} else {
			m
		}
		mask.data[i] = u8(m * 255)
	}
	return mask.resize(rgb_img.w, rgb_img.h)
}

pub fn finish_comfy_icons(p Paths, argv []string) ! {
	cli := parse_cli('finish_comfy_icons', finish_doc,
		'finish_comfy_icons [-h] [--run-name RUN_NAME] [--model MODEL] [--onnxruntime DLL]', argv,
		[], ['run-name', 'model', 'onnxruntime'], [])
	run_name := cli.get('run-name', 'v1')
	if !safe_name(run_name) {
		cli.fail('Invalid run name')
	}
	source := path(p.base, 'generated', run_name)
	files := files_with_ext(source, '.png')
	if files.len == 0 {
		cli.fail('No generated PNGs in the selected run')
	}
	destination := path(source, 'transparent')
	small_dir := path(source, 'icons_120')
	mkdirs(destination)!
	mkdirs(small_dir)!
	session := ort_open(find_onnxruntime(cli.get('onnxruntime', '')), cli.get('model',
		default_model), 4)!
	mut report := []Json{}
	for i, file in files {
		name := os.file_name(file)
		trait := stem(file)
		original := open_image(file)!
		mut metadata := map[string]string{}
		for key in ['prompt', 'workflow'] {
			if v := original.info[key] {
				metadata[key] = v
			}
		}
		rgb_img := original.convert(.rgb)
		// Remove extremely faint background residue while retaining antialiasing.
		mask := u2net_mask(session, rgb_img)!.point(fn (v int) int {
			return if v < 8 {
				0
			} else if v > 247 {
				255
			} else {
				v
			}
		})
		mut rgba := rgb_img.convert(.rgba)
		rgba.putalpha(mask)
		bbox := mask.bbox() or { return error('Empty foreground mask: ${name}') }
		mut rank := 0
		for family in rank_families {
			if trait in family {
				rank = family.index(trait) + 1
			}
		}
		mut cropped := rgba.crop(bbox[0], bbox[1], bbox[2], bbox[3])
		wscale := 880.0 / f64(cropped.w)
		hscale := (if rank > 0 { 810.0 } else { 880.0 }) / f64(cropped.h)
		scale := if wscale < hscale { wscale } else { hscale }
		cropped = cropped.resize(py_round(f64(cropped.w) * scale), py_round(f64(cropped.h) * scale))
		mut master := new_image(.rgba, 1024, 1024, Color{0, 0, 0, 0})
		top := if rank > 0 { (940 - cropped.h) / 2 } else { (1024 - cropped.h) / 2 }
		master.alpha_composite(cropped, (1024 - cropped.w) / 2, top)
		if rank > 0 {
			// Explicit UI rank markers stay countable after downscaling.
			for n in 0 .. rank {
				x := 512.0 + (f64(n) - f64(rank - 1) / 2.0) * 64.0
				master.ellipse(x - 20, 925 - 20, x + 20, 925 + 20,
					fill:    hex('#d8b46b')
					outline: hex('#47341e')
					width:   5
				)
				master.ellipse(x - 9, 912, x + 1, 922, fill: hex('#fff0bf'))
			}
		}
		if trait == 'skonester_trait_marriage_ban' {
			// The generated rings need an unambiguous prohibition mark.
			master.line(230, 810, 794, 214, hex('#472c20'), 66)
			master.line(230, 810, 794, 214, hex('#c6a16a'), 54)
			master.line(230, 810, 794, 214, hex('#9f322c'), 38)
			master.line(225, 803, 789, 207, hex('#e1735a'), 8)
		}
		if trait == 'skonester_trait_stats_100_locked' {
			// Typeset the exact attribute value on the generated lock faceplate.
			master.ellipse(270, 445, 754, 770,
				fill:    hex('#30271c')
				outline: hex('#b99653')
				width:   10
			)
			master.ellipse(286, 461, 738, 754, outline: hex('#665034'), width: 4)
			numeral := windows_font('georgiab.ttf', 200)!
			master.text(512, 604, '100', hex('#ead49a'), numeral,
				anchor:       'mm'
				stroke_width: 3
				stroke_fill:  hex('#17120e')
			)
		}
		master.save_png(path(destination, name), metadata)!
		shrunk := master.resize(120, 120)
		shrunk.save_png(path(small_dir, name), metadata)!
		check := open_image(path(small_dir, name))!
		lo, hi := check.alpha_extrema()
		if check.mode != .rgba || check.w != 120 || check.h != 120 || lo != 0 || hi != 255 {
			return error('Preview verification failed: ${name}')
		}
		coverage := f64(mask.data.filter(it > 127).len) / mask.data.len
		rounded := strconv.atof64('${coverage:.4f}')!
		report << Json({
			'trait_id':            Json(trait)
			'foreground_coverage': Json(rounded)
			'foreground_bbox':     ints(bbox[0], bbox[1], bbox[2], bbox[3])
			'review_mask':         Json(coverage < .03 || coverage > .8)
		})
		println('[${i + 1}/${files.len}] Transparent: ${trait}')
	}

	font := windows_font('segoeui.ttf', 16)!
	mut jobs := map[string]Json{}
	for j in parse_json(read_text(path(p.base, 'manifest.json'))!)!.at('jobs').arr() {
		jobs[j.at('trait_id').s()] = j
	}
	// Keep individual review sheets manageable, with originals beside the new icons.
	for start := 0; start < files.len; start += 12 {
		page := start / 12 + 1
		subset := files[start..if start + 12 < files.len { start + 12 } else { files.len }]
		mut sheet := new_image(.rgb, 1200, ((subset.len + 2) / 3) * 225, rgb(37, 35, 34))
		for i, file in subset {
			x, y := i % 3 * 400, i / 3 * 225
			job := jobs[stem(file)] or { return error('No manifest job for ${stem(file)}') }
			mut icon := open_image(path(p.base, job.at('input_png').s()))!.convert(.rgba)
			icon.thumbnail(120, 120)
			sheet.paste(icon, x + 20 + (120 - icon.w) / 2, y + 25 + (120 - icon.h) / 2)
			sheet.paste(open_image(path(small_dir, os.file_name(file)))!.convert(.rgba), x + 190,

				y + 25)
			sheet.text(x + 23, y + 152, 'Original', hex('#aaa69f'), font)
			sheet.text(x + 195, y + 152, 'Redrawn', hex('#d6bd8d'), font)
			label := job.at('name').s().runes()
			sheet.text(x + 18, y + 183,
				label[..if label.len > 42 { 42 } else { label.len }].string(), hex('#ffffff'), font)
		}
		sheet.save_jpeg(path(source, 'comparison_${page:02}.jpg'), 92)!
	}
	write_text(path(source, 'alpha_report.json'), dumps(Json(report), 2, true))!
	println('Finished ${files.len} icons. Review sheets: ${source}')
}
