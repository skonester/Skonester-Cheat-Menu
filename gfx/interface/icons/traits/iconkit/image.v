module iconkit

import os
import math
import stbi
import hash.crc32
import compress.zlib
import encoding.binary

// Image is a small Pillow-like raster: L is 1 byte per pixel, RGB and RGBA use 4.
pub enum Mode {
	l
	rgb
	rgba
}

pub struct Image {
pub mut:
	w    int
	h    int
	mode Mode
	data []u8
	info map[string]string // PNG text chunks, like Pillow's Image.info
}

pub struct Color {
pub:
	r u8
	g u8
	b u8
	a u8 = 255
}

pub fn rgb(r u8, g u8, b u8) Color {
	return Color{r, g, b, 255}
}

// hex parses '#rrggbb' or '#rgb'.
pub fn hex(s string) Color {
	h := s.trim_left('#')
	full := if h.len == 3 {
		'${h[0..1]}${h[0..1]}${h[1..2]}${h[1..2]}${h[2..3]}${h[2..3]}'
	} else {
		h
	}
	v := u32(full.parse_uint(16, 32) or { 0 })
	return rgb(u8(v >> 16), u8(v >> 8), u8(v))
}

fn channels(m Mode) int {
	return if m == .l { 1 } else { 4 }
}

pub fn new_image(mode Mode, w int, h int, c Color) Image {
	mut img := Image{
		w:    w
		h:    h
		mode: mode
		data: []u8{len: w * h * channels(mode)}
	}
	if mode == .l {
		for i in 0 .. img.data.len {
			img.data[i] = c.r
		}
	} else {
		a := if mode == .rgb { u8(255) } else { c.a }
		for i := 0; i < img.data.len; i += 4 {
			img.data[i] = c.r
			img.data[i + 1] = c.g
			img.data[i + 2] = c.b
			img.data[i + 3] = a
		}
	}
	return img
}

// ---- loading ----

pub fn open_image(p string) !Image {
	buf := os.read_bytes(p)!
	return decode_image(buf) or { return error('cannot identify image file ${p}: ${err.msg()}') }
}

pub fn decode_image(buf []u8) !Image {
	if buf.len >= 4 && buf[0..4] == 'DDS '.bytes() {
		return decode_dds(buf)
	}
	mut mode := Mode.rgba
	mut info := map[string]string{}
	if buf.len > 8 && buf[0..8] == png_signature {
		mode, info = png_mode_and_text(buf)!
	}
	st := stbi.load_from_memory(buf.data, buf.len, desired_channels: 4)!
	mut img := Image{
		w:    st.width
		h:    st.height
		mode: mode
		data: unsafe { st.data.vbytes(st.width * st.height * 4) }.clone()
		info: info
	}
	st.free()
	if buf.len > 3 && buf[0] == 0xff && buf[1] == 0xd8 {
		img.mode = .rgb
	}
	if img.mode == .l {
		mut gray := []u8{len: img.w * img.h}
		for i in 0 .. gray.len {
			gray[i] = img.data[i * 4]
		}
		img.data = gray
	}
	return img
}

// ---- PNG ----

const png_signature = [u8(0x89), `P`, `N`, `G`, `\r`, `\n`, 0x1a, `\n`]

fn latin1(b []u8) string {
	mut runes := []rune{cap: b.len}
	for c in b {
		runes << rune(c)
	}
	return runes.string()
}

fn png_mode_and_text(buf []u8) !(Mode, map[string]string) {
	mut info := map[string]string{}
	mut mode := Mode.rgba
	mut has_trns := false
	mut pos := 8
	for pos + 8 <= buf.len {
		size := int(binary.big_endian_u32(buf[pos..pos + 4]))
		kind := buf[pos + 4..pos + 8].bytestr()
		if pos + 12 + size > buf.len {
			break
		}
		data := buf[pos + 8..pos + 8 + size]
		match kind {
			'IHDR' {
				mode = match data[9] {
					0 { Mode.l }
					2, 3 { Mode.rgb }
					else { Mode.rgba }
				}
			}
			'tRNS' {
				has_trns = true
			}
			'tEXt' {
				k := data.index(0)
				if k > 0 {
					info[latin1(data[..k])] = latin1(data[k + 1..])
				}
			}
			'zTXt' {
				k := data.index(0)
				if k > 0 {
					info[latin1(data[..k])] = latin1(zlib.decompress(data[k + 2..]) or { []u8{} })
				}
			}
			'iTXt' {
				k := data.index(0)
				if k > 0 && k + 3 < data.len {
					compressed := data[k + 1] == 1
					mut rest := data[k + 3..]
					rest = rest[rest.index(0) + 1..] // language tag
					rest = rest[rest.index(0) + 1..] // translated keyword
					text := if compressed { zlib.decompress(rest) or { []u8{} } } else { rest }
					info[latin1(data[..k])] = text.bytestr()
				}
			}
			'IEND' {
				break
			}
			else {}
		}

		pos += 12 + size
	}
	if has_trns && mode != .l {
		mode = .rgba
	}
	return mode, info
}

fn png_chunk(mut out []u8, kind string, data []u8) {
	mut len := []u8{len: 4}
	binary.big_endian_put_u32(mut len, u32(data.len))
	out << len
	mut body := kind.bytes()
	body << data
	out << body
	mut crc := []u8{len: 4}
	binary.big_endian_put_u32(mut crc, crc32.sum(body))
	out << crc
}

fn paeth(a int, b int, c int) int {
	p := a + b - c
	pa := math.abs(p - a)
	pb := math.abs(p - b)
	pc := math.abs(p - c)
	return if pa <= pb && pa <= pc {
		a
	} else if pb <= pc {
		b
	} else {
		c
	}
}

// encode_png writes an 8-bit PNG with adaptive row filters and optional text chunks.
pub fn (img Image) encode_png(text map[string]string) ![]u8 {
	bpp, color := match img.mode {
		.l { 1, u8(0) }
		.rgb { 3, u8(2) }
		.rgba { 4, u8(6) }
	}

	stride := img.w * bpp
	mut raw := []u8{cap: (stride + 1) * img.h}
	mut prev := []u8{len: stride}
	mut row := []u8{len: stride}
	mut best := []u8{len: stride}
	mut cand := []u8{len: stride}
	src_bpp := channels(img.mode)
	for y in 0 .. img.h {
		for x in 0 .. img.w {
			for c in 0 .. bpp {
				row[x * bpp + c] = img.data[(y * img.w + x) * src_bpp + c]
			}
		}
		mut best_filter := u8(0)
		mut best_score := u64(-1)
		for f in 0 .. 5 {
			mut score := u64(0)
			for i in 0 .. stride {
				a := if i >= bpp { int(row[i - bpp]) } else { 0 }
				b := int(prev[i])
				c := if i >= bpp { int(prev[i - bpp]) } else { 0 }
				predictor := match f {
					0 { 0 }
					1 { a }
					2 { b }
					3 { (a + b) / 2 }
					else { paeth(a, b, c) }
				}

				v := u8(int(row[i]) - predictor)
				cand[i] = v
				score += u64(if v < 128 { int(v) } else { 256 - int(v) })
			}
			if score < best_score {
				best_score = score
				best_filter = u8(f)
				unsafe {
					best, cand = cand, best
				}
			}
		}
		raw << best_filter
		raw << best
		unsafe {
			prev, row = row, prev
		}
	}
	mut out := png_signature.clone()
	mut ihdr := []u8{len: 13}
	binary.big_endian_put_u32(mut ihdr, u32(img.w))
	binary.big_endian_put_u32_at(mut ihdr, u32(img.h), 4)
	ihdr[8] = 8
	ihdr[9] = color
	png_chunk(mut out, 'IHDR', ihdr)
	for key, value in text {
		runes := value.runes()
		if runes.all(it < 256) {
			mut data := key.bytes()
			data << 0
			for r in runes {
				data << u8(r)
			}
			png_chunk(mut out, 'tEXt', data)
		} else {
			mut data := key.bytes()
			data << [u8(0), 0, 0, 0, 0]
			data << value.bytes()
			png_chunk(mut out, 'iTXt', data)
		}
	}
	png_chunk(mut out, 'IDAT', zlib.compress(raw)!)
	png_chunk(mut out, 'IEND', []u8{})
	return out
}

pub fn (img Image) save_png(p string, text map[string]string) ! {
	os.write_file_array(p, img.encode_png(text)!)!
}

pub fn (img Image) save_jpeg(p string, quality int) ! {
	mut buf := []u8{len: img.w * img.h * 3}
	for i in 0 .. img.w * img.h {
		for c in 0 .. 3 {
			buf[i * 3 + c] = if img.mode == .l { img.data[i] } else { img.data[i * 4 + c] }
		}
	}
	stbi.stbi_write_jpg(p, img.w, img.h, 3, buf.data, quality)!
}

// ---- DDS ----

fn u32_at(b []u8, off int) u32 {
	return binary.little_endian_u32(b[off..off + 4])
}

fn color565(c u32) (int, int, int) {
	mut r := int((c >> 11) & 0x1f)
	mut g := int((c >> 5) & 0x3f)
	mut b := int(c & 0x1f)
	return (r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)
}

fn decode_bc_color(mut img Image, blk []u8, bx int, by int, separate_alpha bool) {
	c0 := u32(blk[0]) | u32(blk[1]) << 8
	c1 := u32(blk[2]) | u32(blk[3]) << 8
	r0, g0, b0 := color565(c0)
	r1, g1, b1 := color565(c1)
	mut p := [[r0, g0, b0, 255], [r1, g1, b1, 255], [0, 0, 0, 255],
		[0, 0, 0, 0]]
	if c0 > c1 || separate_alpha {
		p[2] = [(2 * r0 + r1) / 3, (2 * g0 + g1) / 3, (2 * b0 + b1) / 3, 255]
		p[3] = [(r0 + 2 * r1) / 3, (g0 + 2 * g1) / 3, (b0 + 2 * b1) / 3, 255]
	} else {
		p[2] = [(r0 + r1) / 2, (g0 + g1) / 2, (b0 + b1) / 2, 255]
	}
	lut := u32_at(blk, 4)
	for i in 0 .. 16 {
		x := bx + i % 4
		y := by + i / 4
		if x >= img.w || y >= img.h {
			continue
		}
		c := p[(lut >> (2 * i)) & 3]
		o := (y * img.w + x) * 4
		img.data[o] = u8(c[0])
		img.data[o + 1] = u8(c[1])
		img.data[o + 2] = u8(c[2])
		if !separate_alpha {
			img.data[o + 3] = u8(c[3])
		}
	}
}

fn decode_bc3_alpha(mut img Image, blk []u8, bx int, by int) {
	a0 := int(blk[0])
	a1 := int(blk[1])
	mut a := [a0, a1, 0, 0, 0, 0, 0, 0]
	if a0 > a1 {
		for i in 2 .. 8 {
			a[i] = ((8 - i) * a0 + (i - 1) * a1) / 7
		}
	} else {
		for i in 2 .. 6 {
			a[i] = ((6 - i) * a0 + (i - 1) * a1) / 5
		}
		a[7] = 255
	}
	mut bits := u64(0)
	for i in 0 .. 6 {
		bits |= u64(blk[2 + i]) << (8 * i)
	}
	for i in 0 .. 16 {
		x := bx + i % 4
		y := by + i / 4
		if x < img.w && y < img.h {
			img.data[(y * img.w + x) * 4 + 3] = u8(a[(bits >> (3 * i)) & 7])
		}
	}
}

fn mask_value(px u32, mask u32) u8 {
	if mask == 0 {
		return 255
	}
	shift := u32(0)
	mut s := shift
	for (mask >> s) & 1 == 0 {
		s++
	}
	mut bits := 0
	for (mask >> (s + u32(bits))) & 1 == 1 && s + u32(bits) < 32 {
		bits++
	}
	v := (px & mask) >> s
	return if bits == 8 { u8(v) } else { u8(v * 255 / ((u32(1) << bits) - 1)) }
}

pub fn decode_dds(b []u8) !Image {
	if b.len < 128 {
		return error('truncated DDS header')
	}
	h := int(u32_at(b, 12))
	w := int(u32_at(b, 16))
	pf_flags := u32_at(b, 80)
	fourcc := b[84..88].bytestr()
	bitcount := int(u32_at(b, 88))
	masks := [u32_at(b, 92), u32_at(b, 96), u32_at(b, 100), u32_at(b, 104)]
	data := b[128..]
	mut img := new_image(.rgba, w, h, Color{0, 0, 0, 255})
	if pf_flags & 0x4 != 0 {
		block := match fourcc {
			'DXT1' { 8 }
			'DXT3', 'DXT5' { 16 }
			else { return error('Unimplemented DDS pixel format ${fourcc}') }
		}

		bw := (w + 3) / 4
		bh := (h + 3) / 4
		if data.len < bw * bh * block {
			return error('truncated DDS data')
		}
		for by in 0 .. bh {
			for bx in 0 .. bw {
				blk := data[(by * bw + bx) * block..(by * bw + bx + 1) * block]
				match fourcc {
					'DXT1' {
						decode_bc_color(mut img, blk, bx * 4, by * 4, false)
					}
					'DXT3' {
						decode_bc_color(mut img, blk[8..], bx * 4, by * 4, true)
						for i in 0 .. 16 {
							x := bx * 4 + i % 4
							y := by * 4 + i / 4
							if x < w && y < h {
								nib := (blk[i / 2] >> (4 * (i % 2))) & 0xf
								img.data[(y * w + x) * 4 + 3] = nib * 17
							}
						}
					}
					else {
						decode_bc_color(mut img, blk[8..], bx * 4, by * 4, true)
						decode_bc3_alpha(mut img, blk, bx * 4, by * 4)
					}
				}
			}
		}
		return img
	}
	if pf_flags & 0x40 == 0 && pf_flags & 0x20000 == 0 {
		return error('Unsupported DDS pixel format')
	}
	step := bitcount / 8
	if step < 1 || data.len < w * h * step {
		return error('truncated DDS data')
	}
	has_alpha := pf_flags & 0x1 != 0
	luminance := pf_flags & 0x20000 != 0
	for i in 0 .. w * h {
		mut px := u32(0)
		for k in 0 .. step {
			px |= u32(data[i * step + k]) << (8 * k)
		}
		o := i * 4
		if luminance {
			v := mask_value(px, masks[0])
			img.data[o], img.data[o + 1], img.data[o + 2] = v, v, v
		} else {
			img.data[o] = mask_value(px, masks[0])
			img.data[o + 1] = mask_value(px, masks[1])
			img.data[o + 2] = mask_value(px, masks[2])
		}
		img.data[o + 3] = if has_alpha { mask_value(px, masks[3]) } else { 255 }
	}
	if !has_alpha {
		img.mode = .rgb
	}
	return img
}

// encode_dds writes uncompressed 32-bit BGRA with straight alpha, as Pillow does.
pub fn (img Image) encode_dds() []u8 {
	src := img.convert(.rgba)
	mut out := []u8{len: 128 + src.w * src.h * 4}
	fields := {
		0:   u32(0x20534444) // 'DDS '
		4:   124
		8:   0x100f // CAPS | HEIGHT | WIDTH | PITCH | PIXELFORMAT
		12:  u32(src.h)
		16:  u32(src.w)
		20:  u32(src.w * 4)
		76:  32
		80:  0x41 // RGB | ALPHAPIXELS
		88:  32
		92:  0x00ff0000
		96:  0x0000ff00
		100: 0x000000ff
		104: 0xff000000
		108: 0x1000 // DDSCAPS_TEXTURE
	}
	for off, v in fields {
		binary.little_endian_put_u32_at(mut out, v, off)
	}
	for i in 0 .. src.w * src.h {
		out[128 + i * 4] = src.data[i * 4 + 2]
		out[128 + i * 4 + 1] = src.data[i * 4 + 1]
		out[128 + i * 4 + 2] = src.data[i * 4]
		out[128 + i * 4 + 3] = src.data[i * 4 + 3]
	}
	return out
}

// ---- conversions and pixel operations ----

pub fn (img Image) convert(mode Mode) Image {
	if img.mode == mode {
		return img
	}
	mut out := Image{
		w:    img.w
		h:    img.h
		mode: mode
		info: img.info
	}
	if img.mode == .l {
		out.data = []u8{len: img.w * img.h * 4}
		for i, v in img.data {
			out.data[i * 4], out.data[i * 4 + 1], out.data[i * 4 + 2], out.data[i * 4 + 3] = v, v, v, 255
		}
		return out
	}
	if mode == .l {
		out.data = []u8{len: img.w * img.h}
		for i in 0 .. out.data.len {
			r, g, b := u32(img.data[i * 4]), u32(img.data[i * 4 + 1]), u32(img.data[i * 4 + 2])
			out.data[i] = u8((r * 19595 + g * 38470 + b * 7471 + 0x8000) >> 16)
		}
		return out
	}
	out.data = img.data.clone()
	for i := 3; i < out.data.len; i += 4 {
		out.data[i] = 255 // RGBA -> RGB drops alpha; RGB -> RGBA is opaque
	}
	return out
}

pub fn (img Image) channel(c int) Image {
	mut out := Image{
		w:    img.w
		h:    img.h
		mode: .l
		data: []u8{len: img.w * img.h}
	}
	for i in 0 .. out.data.len {
		out.data[i] = if img.mode == .l { img.data[i] } else { img.data[i * 4 + c] }
	}
	return out
}

pub fn (mut img Image) putalpha(mask Image) {
	for i in 0 .. img.w * img.h {
		img.data[i * 4 + 3] = mask.data[i]
	}
}

// extrema returns (min, max) of a single channel image.
pub fn (img Image) extrema() (int, int) {
	mut lo, mut hi := 255, 0
	for v in img.data {
		lo = math.min(lo, int(v))
		hi = math.max(hi, int(v))
	}
	return lo, hi
}

pub fn (img Image) alpha_extrema() (int, int) {
	return img.channel(3).extrema()
}

// bbox of the non-zero area of a single channel image; none when fully zero.
pub fn (img Image) bbox() ?[]int {
	mut x0, mut y0, mut x1, mut y1 := img.w, img.h, -1, -1
	for y in 0 .. img.h {
		for x in 0 .. img.w {
			if img.data[y * img.w + x] != 0 {
				x0 = math.min(x0, x)
				y0 = math.min(y0, y)
				x1 = math.max(x1, x)
				y1 = math.max(y1, y)
			}
		}
	}
	if x1 < 0 {
		return none
	}
	return [x0, y0, x1 + 1, y1 + 1]
}

pub fn (img Image) point(f fn (int) int) Image {
	mut lut := []u8{len: 256}
	for v in 0 .. 256 {
		lut[v] = u8(f(v))
	}
	mut out := Image{
		...img
	}
	out.data = img.data.map(lut[it])
	return out
}

pub fn (img Image) crop(x0 int, y0 int, x1 int, y1 int) Image {
	ch := channels(img.mode)
	mut out := new_image(img.mode, x1 - x0, y1 - y0, Color{0, 0, 0, 0})
	for y in 0 .. out.h {
		sy := y0 + y
		if sy < 0 || sy >= img.h {
			continue
		}
		for x in 0 .. out.w {
			sx := x0 + x
			if sx < 0 || sx >= img.w {
				continue
			}
			for c in 0 .. ch {
				out.data[(y * out.w + x) * ch + c] = img.data[(sy * img.w + sx) * ch + c]
			}
		}
	}
	return out
}

fn div255(v u32) u8 {
	t := v + 128
	return u8(((t >> 8) + t) >> 8)
}

// paste blends src onto img using src's alpha as the mask (Image.paste(im, box, im)).
pub fn (mut img Image) paste(src Image, dx int, dy int) {
	n := if img.mode == .rgba { 4 } else { 3 }
	for y in 0 .. src.h {
		ty := dy + y
		if ty < 0 || ty >= img.h {
			continue
		}
		for x in 0 .. src.w {
			tx := dx + x
			if tx < 0 || tx >= img.w {
				continue
			}
			s := (y * src.w + x) * 4
			m := u32(src.data[s + 3])
			o := (ty * img.w + tx) * 4
			for c in 0 .. n {
				img.data[o + c] =
					div255(u32(img.data[o + c]) * (255 - m) + u32(src.data[s + c]) * m)
			}
		}
	}
}

fn shift_div255(a u32) u32 {
	return ((a >> 8) + a) >> 8
}

// alpha_composite places src over img at (dx, dy) (Image.alpha_composite).
pub fn (mut img Image) alpha_composite(src Image, dx int, dy int) {
	for y in 0 .. src.h {
		ty := dy + y
		if ty < 0 || ty >= img.h {
			continue
		}
		for x in 0 .. src.w {
			tx := dx + x
			if tx < 0 || tx >= img.w {
				continue
			}
			s := (y * src.w + x) * 4
			o := (ty * img.w + tx) * 4
			sa := u32(src.data[s + 3])
			if sa == 0 {
				continue
			}
			blend := u32(img.data[o + 3]) * (255 - sa)
			outa255 := sa * 255 + blend
			coef1 := sa * 255 * 255 * 128 / outa255
			coef2 := 255 * 128 - coef1
			for c in 0 .. 3 {
				t := u32(src.data[s + c]) * coef1 + u32(img.data[o + c]) * coef2
				img.data[o + c] = u8(shift_div255(t + (0x80 << 7)) >> 7)
			}
			img.data[o + 3] = u8(shift_div255(outa255 + 0x80))
		}
	}
}

// ---- Lanczos resampling (Pillow's two-pass fixed point algorithm) ----

const precision_bits = 22

fn sinc(x f64) f64 {
	if x == 0.0 {
		return 1.0
	}
	y := x * math.pi
	return math.sin(y) / y
}

fn lanczos(x f64) f64 {
	return if x >= -3.0 && x < 3.0 { sinc(x) * sinc(x / 3.0) } else { 0.0 }
}

struct Coeffs {
	ksize  int
	bounds []int
	kk     []int
}

fn precompute(in_size int, out_size int) Coeffs {
	scale := f64(in_size) / out_size
	filterscale := if scale > 1.0 { scale } else { 1.0 }
	support := 3.0 * filterscale
	ksize := int(math.ceil(support)) * 2 + 1
	mut kk := []int{len: out_size * ksize}
	mut bounds := []int{len: out_size * 2}
	mut w := []f64{len: ksize}
	for xx in 0 .. out_size {
		center := (xx + 0.5) * scale
		mut xmin := int(center - support + 0.5)
		if xmin < 0 {
			xmin = 0
		}
		mut xmax := int(center + support + 0.5)
		if xmax > in_size {
			xmax = in_size
		}
		xmax -= xmin
		mut ww := 0.0
		for x in 0 .. xmax {
			w[x] = lanczos((x + xmin - center + 0.5) / filterscale)
			ww += w[x]
		}
		for x in 0 .. xmax {
			v := if ww != 0.0 { w[x] / ww } else { w[x] }
			kk[xx * ksize + x] = if v < 0 {
				int(-0.5 + v * (1 << precision_bits))
			} else {
				int(0.5 + v * (1 << precision_bits))
			}
		}
		bounds[xx * 2] = xmin
		bounds[xx * 2 + 1] = xmax
	}
	return Coeffs{ksize, bounds, kk}
}

fn clip8(v int) u8 {
	r := v >> precision_bits
	return if r < 0 {
		u8(0)
	} else if r > 255 {
		255
	} else {
		u8(r)
	}
}

fn resample(src []u8, sw int, sh int, ch int, dw int, dh int) []u8 {
	mut data := unsafe { src }
	mut w := sw
	if dw != sw {
		cf := precompute(sw, dw)
		mut out := []u8{len: dw * sh * ch}
		for y in 0 .. sh {
			for x in 0 .. dw {
				xmin := cf.bounds[x * 2]
				xmax := cf.bounds[x * 2 + 1]
				k := x * cf.ksize
				for c in 0 .. ch {
					mut ss := 1 << (precision_bits - 1)
					for i in 0 .. xmax {
						ss += int(data[(y * w + xmin + i) * ch + c]) * cf.kk[k + i]
					}
					out[(y * dw + x) * ch + c] = clip8(ss)
				}
			}
		}
		data = unsafe { out }
		w = dw
	}
	if dh != sh {
		cf := precompute(sh, dh)
		mut out := []u8{len: w * dh * ch}
		for y in 0 .. dh {
			ymin := cf.bounds[y * 2]
			ymax := cf.bounds[y * 2 + 1]
			k := y * cf.ksize
			for x in 0 .. w {
				for c in 0 .. ch {
					mut ss := 1 << (precision_bits - 1)
					for i in 0 .. ymax {
						ss += int(data[((ymin + i) * w + x) * ch + c]) * cf.kk[k + i]
					}
					out[(y * w + x) * ch + c] = clip8(ss)
				}
			}
		}
		data = unsafe { out }
	}
	return data
}

// resize uses Lanczos; RGBA is resampled premultiplied, like Pillow.
pub fn (img Image) resize(w int, h int) Image {
	if w == img.w && h == img.h {
		return img
	}
	ch := channels(img.mode)
	mut src := unsafe { img.data }
	if img.mode == .rgba {
		src = img.data.clone()
		for i := 0; i < src.len; i += 4 {
			a := u32(src[i + 3])
			if a == 0 {
				src[i], src[i + 1], src[i + 2] = 0, 0, 0
			} else if a != 255 {
				for c in 0 .. 3 {
					src[i + c] = div255(u32(src[i + c]) * a)
				}
			}
		}
	}
	mut data := resample(src, img.w, img.h, ch, w, h)
	if img.mode == .rgba {
		for i := 0; i < data.len; i += 4 {
			a := u32(data[i + 3])
			if a != 0 && a != 255 {
				for c in 0 .. 3 {
					data[i + c] = u8(math.min(u32(255), 255 * u32(data[i + c]) / a))
				}
			}
		}
	}
	return Image{
		w:    w
		h:    h
		mode: img.mode
		data: data
		info: img.info
	}
}

// thumbnail shrinks in place to fit the box, preserving aspect ratio; it never enlarges.
pub fn (mut img Image) thumbnail(bw int, bh int) {
	if bw >= img.w && bh >= img.h {
		return
	}
	aspect := f64(img.w) / f64(img.h)
	mut x, mut y := bw, bh
	if f64(x) / f64(y) >= aspect {
		v := f64(y) * aspect
		lo, hi := int(math.floor(v)), int(math.ceil(v))
		pick := if math.abs(aspect - f64(lo) / f64(y)) <= math.abs(aspect - f64(hi) / f64(y)) {
			lo
		} else {
			hi
		}
		x = if pick < 1 { 1 } else { pick }
	} else {
		v := f64(x) / aspect
		lo, hi := int(math.floor(v)), int(math.ceil(v))
		dlo := if lo == 0 { 0.0 } else { math.abs(aspect - f64(x) / f64(lo)) }
		dhi := if hi == 0 { 0.0 } else { math.abs(aspect - f64(x) / f64(hi)) }
		pick := if dlo <= dhi { lo } else { hi }
		y = if pick < 1 { 1 } else { pick }
	}
	img = img.resize(x, y)
}
