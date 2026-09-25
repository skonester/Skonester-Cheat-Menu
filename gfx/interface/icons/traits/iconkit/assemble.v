module iconkit

import os

// Collect reviewed ComfyUI runs into one named set and a local comparison gallery.

const review_head = '<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Skonester · Trait icon review</title>
<style>
:root{color-scheme:dark;font-family:Segoe UI,Arial,sans-serif;background:#181716;color:#e8e3da}
*{box-sizing:border-box}body{margin:0 auto;max-width:1500px;padding:38px 28px}
h1{font-family:Georgia,serif;font-size:36px;font-weight:400;margin:0 0 12px;color:#e4cda4}
.intro{max-width:850px;color:#bcb5a8;line-height:1.6}header{margin-bottom:30px}
.controls{display:flex;gap:14px;align-items:center;flex-wrap:wrap;margin:24px 0}
input{background:#252320;color:#fff;border:1px solid #5f5340;padding:12px 16px;border-radius:5px;font:inherit;min-width:320px}
button{background:#3b3329;color:#f3dec0;border:1px solid #776347;border-radius:5px;padding:12px 16px;cursor:pointer}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:20px}
article{background:#252320;border:1px solid #403a30;border-radius:8px;padding:22px}
h2{font-size:18px;font-weight:500;margin:0 0 6px;color:#e5cfaa}
.id{font-family:monospace;font-size:11px;color:#9d968a;overflow-wrap:anywhere;margin:0 0 20px}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:10px}figure{margin:0}
.image{height:150px;display:flex;align-items:center;justify-content:center;background:#211f1d;border-radius:4px}
.image img{max-width:120px;max-height:120px;object-fit:contain}figcaption{font-size:12px;text-align:center;margin:9px 0;color:#b5aa98}
.description{font-size:13px;line-height:1.5;min-height:42px;color:#b7b0a4}
nav{display:flex;gap:15px;font-size:12px;flex-wrap:wrap}a{color:#d7b980;text-decoration:none}a:hover{text-decoration:underline}
.light .image{background:#e8e4db}footer{margin:30px 0;color:#938b7d;font-size:13px}
</style><header><h1>Skonester · Trait icon review</h1>
<p class="intro">__TRAIT_COUNT__ distinct redraws, generated locally from the existing icons. Compare each original with its replacement at 120 pixels. Click a new icon to inspect the transparent 1024-pixel master.</p>
<p class="intro">Each redraw has a trait-specific subject and a transparent background. The original PNGs are preserved for comparison. DDS installation is a separate step, recorded in installation.json when completed.</p>
<div class="controls"><input id="search" type="search" placeholder="Find a trait…" aria-label="Find a trait"><button id="background">Toggle light background</button><span id="count">__TRAIT_COUNT__ traits</span></div></header>
<main class="grid">'

const review_tail = "</main>
<footer>DreamShaper XL · image-to-image · transparent PNGs · per-trait ComfyUI workflows</footer>
<script>
document.getElementById('search').addEventListener('input',e=>{
const term=e.target.value.toLowerCase();let n=0;
document.querySelectorAll('article').forEach(card=>{const show=card.dataset.search.includes(term);card.hidden=!show;if(show)n++;});
document.getElementById('count').textContent=n+' traits';
});
document.getElementById('background').addEventListener('click',()=>document.body.classList.toggle('light'));
</script></html>"

pub fn assemble_results(p Paths) ! {
	jobs := parse_json(read_text(path(p.base, 'manifest.json'))!)!.at('jobs').arr()
	destination := path(p.base, 'results')
	for directory in ['masters', 'png', 'renders', 'workflows'] {
		mkdirs(path(destination, directory))!
	}
	overrides_file := path(p.base, 'selected_runs.json')
	overrides := if os.exists(overrides_file) {
		parse_json(read_text(overrides_file)!)!
	} else {
		Json(map[string]Json{})
	}
	info := api('/object_info', none)!
	mut selections := []Json{}
	mut fingerprints := map[string]bool{}
	mut cards := []string{}
	font := windows_font('segoeui.ttf', 16)!
	mut sheets := []Image{}

	for index, job in jobs {
		trait := job.at('trait_id').s()
		default_run := if os.exists(path(p.base, 'generated/refined', '${trait}.png')) {
			'refined'
		} else {
			'v1'
		}
		run := overrides.get(trait, default_run).s()
		folder := path(p.base, 'generated', run)
		prompt := parse_json(read_text(path(folder, '${trait}.api.json'))!)!
		workflow := ui_workflow(prompt, info)
		metadata := {
			'prompt':   dumps(prompt, -1, true)
			'workflow': dumps(workflow, -1, true)
		}
		for spec in [['transparent', 'masters', '1024'], ['icons_120', 'png', '120']] {
			input_folder, output_folder, size := spec[0], spec[1], spec[2].int()
			image := open_image(path(folder, input_folder, '${trait}.png'))!
			lo, hi := image.alpha_extrema()
			if image.w != size || image.h != size || image.mode != .rgba || lo != 0 || hi != 255 {
				return error('Unexpected ${input_folder} image: ${trait}')
			}
			image.save_png(path(destination, output_folder, '${trait}.png'), metadata)!
			if size == 120 {
				fingerprint := digest(image.data)
				if fingerprint in fingerprints {
					return error('Duplicate result: ${trait}')
				}
				fingerprints[fingerprint] = true
			}
		}
		copy2(path(folder, '${trait}.png'), path(destination, 'renders', '${trait}.png'))!
		write_text(path(destination, 'workflows', '${trait}.json'), dumps(workflow, 2, true))!
		sampler := prompt.at('6').at('inputs')
		selections << Json({
			'trait_id':                       Json(trait)
			'name':                           job.at('name')
			'selected_run':                   Json(run)
			'original_dds':                   job.at('source_icon')
			'proposed_dds':                   job.at('proposed_output_dds')
			'requires_icon_reference_change': job.at('requires_icon_reference_change')
			'seed':                           sampler.at('seed')
			'denoise':                        sampler.at('denoise')
			'positive_prompt':                prompt.at('4').at('inputs').at('text')
		})
		name := job.at('name').s()
		safe_title := html_escape(name)
		safe_description := html_escape(job.at('description').s())
		search := html_escape((name + ' ' + trait).to_lower())
		input_png := job.at('input_png').s()
		cards << '<article data-search="${search}">
<h2>${safe_title}</h2><p class="id">${trait}</p>
<div class="pair"><figure><div class="image"><img src="../${input_png}" alt="Original ${safe_title}"></div><figcaption>Original</figcaption></figure>
<figure><div class="image"><a href="masters/${trait}.png"><img src="png/${trait}.png" alt="Redrawn ${safe_title}"></a></div><figcaption>Redrawn · 120 px</figcaption></figure></div>
<p class="description">${safe_description}</p><nav><a href="masters/${trait}.png">1024 px PNG</a><a href="png/${trait}.png">120 px PNG</a><a href="workflows/${trait}.json">Workflow</a></nav></article>'
		page, cell := index / 12, index % 12
		if cell == 0 {
			sheets << new_image(.rgb, 1200, 900, rgb(37, 35, 34))
		}
		x, y := cell % 3 * 400, cell / 3 * 225
		mut old := open_image(path(p.base, input_png))!.convert(.rgba)
		old.thumbnail(120, 120)
		sheets[page].paste(old, x + 20 + (120 - old.w) / 2, y + 25 + (120 - old.h) / 2)
		sheets[page].paste(open_image(path(destination, 'png', '${trait}.png'))!, x + 190, y + 25)
		sheets[page].text(x + 23, y + 152, 'Original', hex('#aaa69f'), font)
		sheets[page].text(x + 195, y + 152, 'Redrawn', hex('#d6bd8d'), font)
		mut label := name.runes()
		for font.textlength(label.string()) > 365 {
			label = label[..if label.len > 2 { label.len - 2 } else { 0 }]
		}
		sheets[page].text(x + 18, y + 183, label.string(), hex('#ffffff'), font)
	}

	for i, sheet in sheets {
		page := i + 1
		count := if jobs.len - i * 12 < 12 { jobs.len - i * 12 } else { 12 }
		sheet.crop(0, 0, 1200, ((count + 2) / 3) * 225).save_jpeg(path(destination,
			'comparison_${page:02}.jpg'), 94)!
	}

	document := (review_head + cards.join('\n') + review_tail).replace('__TRAIT_COUNT__',
		jobs.len.str())
	write_text(path(destination, 'review.html'), document)!
	write_text(path(destination, 'selection.json'), dumps(Json(selections), 2, false))!
	if files_with_ext(path(destination, 'png'), '.png').len != jobs.len {
		return error('Result PNG count does not match the manifest')
	}
	println('Collected and verified ${jobs.len} unique transparent icons, masters, workflows and review gallery.')
	println(destination)
}
