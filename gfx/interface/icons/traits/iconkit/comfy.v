module iconkit

import os
import time
import rand
import net.http
import encoding.hex

// Run the prepared trait icons through local ComfyUI image-to-image.
pub const comfy_doc = 'Run the prepared trait icons through local ComfyUI image-to-image.

Requires a running ComfyUI at http://127.0.0.1:8188.
Example: v run run_comfy_batch.v --only skonester_trait_marriage_ban --run-name pilot
Existing completed outputs are skipped. Use a new --run-name for variations.'

pub const server = 'http://127.0.0.1:8188'
pub const checkpoint = 'DreamShaperXL_Turbo_v2_1.safetensors'
const negative =
	'photograph, photorealistic, portrait, person, face, hands, full body, scenery, ' +
	'landscape, room, floor, text, letters, words, watermark, logo, interface, ' +
	'multiple panels, grid, checkerboard, cropped, cut off, blurry, flat vector, ' +
	'plastic, neon, excessive glow, clutter, tiny intricate details'

// api calls a ComfyUI JSON route; `data` switches the request to POST.
pub fn api(route string, data ?Json) !Json {
	mut req := http.FetchConfig{
		url:          server + route
		method:       .get
		read_timeout: 30 * time.second
	}
	req.header.add(.content_type, 'application/json')
	if d := data {
		req.method = .post
		req.data = dumps(d, -1, true)
	}
	resp := http.fetch(req)!
	if resp.status_code >= 400 {
		return error(resp.body)
	}
	return parse_json(resp.body)!
}

fn quote_plus(s string) string {
	mut out := []u8{}
	for c in s.bytes() {
		if c.is_letter() || c.is_digit() || c in [`_`, `.`, `-`, `~`] {
			out << c
		} else if c == ` ` {
			out << `+`
		} else {
			out << '%${c:02X}'.bytes()
		}
	}
	return out.bytestr()
}

fn upload(p Paths, job Json, size int) !string {
	input := job.get('generation_input_png', job.at('input_png')).s()
	mut icon := open_image(path(p.base, input))!.convert(.rgba)
	if bounds := icon.channel(3).bbox() {
		icon = icon.crop(bounds[0], bounds[1], bounds[2], bounds[3])
	}
	target := py_round(f64(size) * .76)
	icon.thumbnail(target, target)
	// thumbnail does not enlarge the small source icons.
	scale := f64(size) * .76 / f64(if icon.w > icon.h { icon.w } else { icon.h })
	icon = icon.resize(py_round(f64(icon.w) * scale), py_round(f64(icon.h) * scale))
	mut canvas := new_image(.rgb, size, size, rgb(28, 27, 26))
	canvas.paste(icon, (size - icon.w) / 2, (size - icon.h) / 2)
	png := canvas.encode_png({})!
	boundary := hex.encode(rand.bytes(16)!)
	name := 'skonester_${job.at('trait_id').s()}_${size}.png'
	mut body := (
		'--${boundary}\r\nContent-Disposition: form-data; name="image"; filename="${name}"\r\n' +
		'Content-Type: image/png\r\n\r\n').bytes()
	body << png
	body << ('\r\n--${boundary}\r\nContent-Disposition: form-data; name="overwrite"\r\n\r\ntrue' +
		'\r\n--${boundary}--\r\n').bytes()
	mut req := http.FetchConfig{
		url:          server + '/upload/image'
		method:       .post
		data:         body.bytestr()
		read_timeout: 30 * time.second
	}
	req.header.add(.content_type, 'multipart/form-data; boundary=${boundary}')
	resp := http.fetch(req)!
	if resp.status_code >= 400 {
		return error(resp.body)
	}
	result := parse_json(resp.body)!
	return [result.get('subfolder', ''), result.at('name')].map(it.s()).filter(it != '').join('/')
}

pub struct GenOpts {
pub:
	run_name    string
	denoise     f64
	steps       int
	size        int
	seed_offset int
}

fn graph(p Paths, job Json, image string, o GenOpts) !Json {
	mut subject := job.at('prompt').s().all_after('Subject: ').all_before(' Use the supplied image')
	overrides_path := path(p.base, 'generation_overrides.json')
	overrides := if os.exists(overrides_path) {
		parse_json(read_text(overrides_path)!)!
	} else {
		Json(map[string]Json{})
	}
	trait := job.at('trait_id').s()
	override := overrides.get(trait, map[string]Json{})
	subject = override.get('subject', subject).s()
	if subject.starts_with('Choose a unique') {
		subject = job.at('name').s() + '. ' + job.at('description').s()
	}
	positive := '(single medieval game trait icon:1.2), ' + subject + ' ' +
		'medieval grand strategy hand-painted inventory icon, isolated centered emblem, ' +
		'aged gold and silver, rich muted pigments, painterly brushwork, dimensional sculpted shading, ' +
		'crisp readable silhouette, restrained highlights, one large clear symbol, ' +
		'plain uniform dark charcoal background, generous empty border, front view, high quality.'
	modulus := i64(1) << 48
	hash := i64(digest(trait.bytes())[..12].parse_uint(16, 64)!)
	seed := ((hash + o.seed_offset) % modulus + modulus) % modulus
	link := fn (node string, slot i64) Json {
		return Json([Json(node), Json(slot)])
	}
	node := fn (class string, inputs map[string]Json) Json {
		return Json({
			'class_type': Json(class)
			'inputs':     Json(inputs)
		})
	}
	return Json({
		'1': node('CheckpointLoaderSimple', {
			'ckpt_name': Json(checkpoint)
		})
		'2': node('LoadImage', {
			'image': Json(image)
		})
		'3': node('VAEEncode', {
			'pixels': link('2', 0)
			'vae':    link('1', 2)
		})
		'4': node('CLIPTextEncode', {
			'text': Json(positive)
			'clip': link('1', 1)
		})
		'5': node('CLIPTextEncode', {
			'text': Json(negative + override.get('negative', '').s())
			'clip': link('1', 1)
		})
		'6': node('KSampler', {
			'model':        link('1', 0)
			'positive':     link('4', 0)
			'negative':     link('5', 0)
			'latent_image': link('3', 0)
			'seed':         Json(seed)
			'steps':        Json(i64(o.steps))
			'cfg':          Json(2.0)
			'sampler_name': Json('dpmpp_sde')
			'scheduler':    Json('karras')
			'denoise':      override.get('denoise', o.denoise)
		})
		'7': node('VAEDecode', {
			'samples': link('6', 0)
			'vae':     link('1', 2)
		})
		'8': node('SaveImage', {
			'images':          link('7', 0)
			'filename_prefix': Json('Skonester/${o.run_name}/${trait}')
		})
	})
}

pub fn ints(values ...int) Json {
	return Json(values.map(Json(i64(it))))
}

// ui_workflow converts an API prompt into a ComfyUI editor workflow.
pub fn ui_workflow(prompt Json, info Json) Json {
	mut nodes := []map[string]Json{}
	mut links := [][]Json{}
	positions := {
		'1': ints(20, 20)
		'2': ints(20, 340)
		'3': ints(400, 740)
		'4': ints(400, 20)
		'5': ints(400, 370)
		'6': ints(820, 20)
		'7': ints(1170, 20)
		'8': ints(1500, 20)
	}
	for key, item in prompt.obj() {
		class := item.at('class_type').s()
		spec := info.at(class)
		size := if key in ['2', '4', '5', '8'] {
			ints(360, 300)
		} else if key == '6' {
			ints(310, 360)
		} else {
			ints(310, 260)
		}
		kinds := spec.at('output').arr()
		names := spec.get('output_name', kinds).arr()
		mut outputs := []Json{}
		for i, kind in kinds {
			if i < names.len {
				outputs << Json({
					'name':  names[i]
					'type':  kind
					'links': Json([]Json{})
				})
			}
		}
		mut inputs := []Json{}
		mut widgets := []Json{}
		for name, value in item.at('inputs').obj() {
			if value is []Json {
				source := value[0].s()
				slot := value[1].i()
				kind := info.at(prompt.at(source).at('class_type').s()).at('output').idx(int(slot))
				link := i64(links.len + 1)
				links << [Json(link), Json(source.i64()), Json(slot), Json(key.i64()),
					Json(i64(inputs.len)), kind]
				inputs << Json({
					'name': Json(name)
					'type': kind
					'link': Json(link)
				})
			}
		}
		for name, _ in spec.at('input').get('required', map[string]Json{}).obj() {
			inputs_map := item.at('inputs').obj()
			if value := inputs_map[name] {
				if value !is []Json {
					widgets << value
					if name == 'seed' {
						widgets << Json('fixed')
					}
				}
			}
		}
		if class == 'LoadImage' {
			widgets << Json('image')
		}
		nodes << {
			'id':             Json(key.i64())
			'type':           Json(class)
			'pos':            positions[key] or { ints(0, 0) }
			'size':           size
			'flags':          Json(map[string]Json{})
			'order':          Json(key.i64() - 1)
			'mode':           Json(i64(0))
			'inputs':         Json(inputs)
			'outputs':        Json(outputs)
			'properties':     Json({
				'Node name for S&R': Json(class)
			})
			'widgets_values': Json(widgets)
		}
	}
	for l in links {
		for mut n in nodes {
			if n['id'] or { Json(i64(-1)) }.i() == l[1].i() {
				mut outs := n['outputs'] or { Json([]Json{}) }.arr()
				slot := int(l[2].i())
				mut o := outs[slot].obj()
				mut ls := o['links'] or { Json([]Json{}) }.arr()
				ls << l[0]
				o['links'] = Json(ls)
				outs[slot] = Json(o)
				n['outputs'] = Json(outs)
			}
		}
	}
	return Json({
		'last_node_id': Json(i64(8))
		'last_link_id': Json(i64(links.len))
		'nodes':        Json(nodes.map(Json(it)))
		'links':        Json(links.map(Json(it)))
		'groups':       Json([]Json{})
		'config':       Json(map[string]Json{})
		'extra':        Json(map[string]Json{})
		'version':      Json(0.4)
	})
}

pub fn run_comfy_batch(p Paths, argv []string) ! {
	cli := parse_cli('run_comfy_batch', comfy_doc,
		'run_comfy_batch [-h] [--only ONLY [ONLY ...]] [--run-name RUN_NAME] [--denoise DENOISE] [--steps STEPS] [--size SIZE] [--seed-offset SEED_OFFSET]',
		argv, [], ['run-name', 'denoise', 'steps', 'size', 'seed-offset'], ['only'])
	o := GenOpts{
		run_name:    cli.get('run-name', 'v1')
		denoise:     cli.float('denoise', .88)
		steps:       cli.int('steps', 8)
		size:        cli.int('size', 1024)
		seed_offset: cli.int('seed-offset', 0)
	}
	if !safe_name(o.run_name) {
		cli.fail('run-name must contain only letters, numbers, underscores or hyphens')
	}
	mut jobs := parse_json(read_text(path(p.base, 'manifest.json'))!)!.at('jobs').arr()
	only := cli.list('only')
	if only.len > 0 {
		known := jobs.map(it.at('trait_id').s())
		mut unknown := only.filter(it !in known)
		if unknown.len > 0 {
			unknown.sort()
			cli.fail('Unknown traits: ${unknown}')
		}
		jobs = jobs.filter(it.at('trait_id').s() in only)
	}
	out := path(p.base, 'generated', o.run_name)
	mkdirs(out)!
	info := api('/object_info', none)!
	models :=
		info.at('CheckpointLoaderSimple').at('input').at('required').at('ckpt_name').idx(0).arr().map(it.s())
	if checkpoint !in models {
		return error('Model is not ready in ComfyUI: ${checkpoint}')
	}
	for index, job in jobs {
		trait := job.at('trait_id').s()
		output := path(out, trait + '.png')
		if os.exists(output) {
			println('[${index + 1}/${jobs.len}] Already generated: ${trait}')
			continue
		}
		image := upload(p, job, o.size)!
		prompt := graph(p, job, image, o)!
		workflow := ui_workflow(prompt, info)
		write_text(path(out, trait + '.api.json'), dumps(prompt, 2, true))!
		write_text(path(out, trait + '.workflow.json'), dumps(workflow, 2, true))!
		queued := api('/prompt', Json({
			'prompt':     prompt
			'client_id':  Json('skonester-trait-batch')
			'extra_data': Json({
				'extra_pnginfo': Json({
					'workflow': workflow
				})
			})
		}))!
		prompt_id := queued.at('prompt_id').s()
		println('[${index + 1}/${jobs.len}] Generating ${trait}: ${prompt_id}')
		started := time.new_stopwatch()
		mut last := 0.0
		for {
			history := api('/history/' + prompt_id, none)!
			if history.has(prompt_id) {
				result := history.at(prompt_id)
				if result.get('status', map[string]Json{}).get('status_str', '').s() == 'error' {
					return error(dumps(result.at('status'), -1, true))
				}
				saved := result.at('outputs').at('8').at('images').idx(0)
				mut query := []string{}
				for k, v in saved.obj() {
					value := if v is string { v } else { dumps(v, -1, true) }
					query << '${quote_plus(k)}=${quote_plus(value)}'
				}
				resp := http.fetch(
					url:          server + '/view?' + query.join('&')
					read_timeout: 30 * time.second
				)!
				data := resp.body.bytes()
				check := decode_image(data)!
				if check.w != o.size || check.h != o.size {
					return error('Unexpected generated image size: (${check.w}, ${check.h})')
				}
				os.write_file_array(output, data)!
				write_text(path(out, trait + '.result.json'), dumps(result, 2, true))!
				println('  Saved and verified ${os.file_name(output)} (${started.elapsed().seconds():.0f}s)')
				break
			}
			elapsed := started.elapsed().seconds()
			if elapsed > 1800 {
				return error('ComfyUI job still pending: ${prompt_id}; check queue before retrying')
			}
			if elapsed - last > 30 {
				println('  Waiting for ${trait}: ${elapsed:.0f}s')
				last = elapsed
			}
			time.sleep(3 * time.second)
		}
	}
	println('Completed ${jobs.len} requested traits. Output: ${out}')
}
