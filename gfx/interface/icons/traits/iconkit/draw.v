module iconkit

import os
import math

#flag -I @VEXEROOT/thirdparty/fontstash
#flag -DSTB_TRUETYPE_IMPLEMENTATION -DFONTSTASH_MALLOC=malloc -DFONTSTASH_FREE=free
#include "stb_truetype.h"

@[typedef]
struct C.stbtt_fontinfo {}

fn C.stbtt_InitFont(info &C.stbtt_fontinfo, data &u8, offset int) int
fn C.stbtt_GetFontOffsetForIndex(data &u8, index int) int
fn C.stbtt_ScaleForMappingEmToPixels(info &C.stbtt_fontinfo, pixels f32) f32
fn C.stbtt_GetFontVMetrics(info &C.stbtt_fontinfo, ascent &int, descent &int, gap &int)
fn C.stbtt_GetCodepointHMetrics(info &C.stbtt_fontinfo, cp int, advance &int, lsb &int)
fn C.stbtt_GetCodepointKernAdvance(info &C.stbtt_fontinfo, a int, b int) int
fn C.stbtt_GetCodepointBitmapBox(info &C.stbtt_fontinfo, cp int, sx f32, sy f32, x0 &int, y0 &int, x1 &int, y1 &int)
fn C.stbtt_MakeCodepointBitmap(info &C.stbtt_fontinfo, output &u8, w int, h int, stride int, sx f32, sy f32, cp int)

// Font is a TrueType face at a fixed pixel size (ImageFont.truetype).
@[heap]
pub struct Font {
mut:
	info  C.stbtt_fontinfo
	data  []u8
	scale f32
pub mut:
	ascent  int
	descent int
}

pub fn truetype(p string, size int) !&Font {
	mut f := &Font{
		data: os.read_bytes(p)!
	}
	offset := C.stbtt_GetFontOffsetForIndex(f.data.data, 0)
	if C.stbtt_InitFont(&f.info, f.data.data, offset) == 0 {
		return error('cannot open font ${p}')
	}
	f.scale = C.stbtt_ScaleForMappingEmToPixels(&f.info, f32(size))
	mut asc, mut desc, mut gap := 0, 0, 0
	C.stbtt_GetFontVMetrics(&f.info, &asc, &desc, &gap)
	f.ascent = int(math.ceil(asc * f.scale))
	f.descent = int(math.floor(desc * f.scale))
	return f
}

// windows_font loads a font from C:/Windows/Fonts, falling back to Arial.
pub fn windows_font(name string, size int) !&Font {
	for candidate in [name, 'arial.ttf'] {
		p := 'C:/Windows/Fonts/${candidate}'
		if os.exists(p) {
			return truetype(p, size)
		}
	}
	return error('font not found: ${name}')
}

fn (f &Font) advances(text string) ([]rune, []int) {
	runes := text.runes()
	mut pens := []int{cap: runes.len + 1}
	mut pen := 0
	for i, r in runes {
		if i > 0 {
			pen += int(math.round(C.stbtt_GetCodepointKernAdvance(&f.info, int(runes[i - 1]),
				int(r)) * f.scale))
		}
		pens << pen
		mut adv, mut lsb := 0, 0
		C.stbtt_GetCodepointHMetrics(&f.info, int(r), &adv, &lsb)
		pen += int(math.round(adv * f.scale))
	}
	pens << pen
	return runes, pens
}

// textlength is ImageDraw.textlength.
pub fn (f &Font) textlength(text string) int {
	_, pens := f.advances(text)
	return pens.last()
}

// render_mask draws text into an L image whose origin sits at (ox, oy) relative to the baseline start.
fn (f &Font) render_mask(text string, pad int) (Image, int, int) {
	runes, pens := f.advances(text)
	mut x0, mut y0, mut x1, mut y1 := 0, -f.ascent, pens.last(), -f.descent
	for i, r in runes {
		mut bx0, mut by0, mut bx1, mut by1 := 0, 0, 0, 0
		C.stbtt_GetCodepointBitmapBox(&f.info, int(r), f.scale, f.scale, &bx0, &by0, &bx1, &by1)
		x0 = math.min(x0, pens[i] + bx0)
		x1 = math.max(x1, pens[i] + bx1)
		y0 = math.min(y0, by0)
		y1 = math.max(y1, by1)
	}
	x0 -= pad
	y0 -= pad
	mut mask := new_image(.l, x1 - x0 + pad, y1 - y0 + pad, Color{})
	for i, r in runes {
		mut bx0, mut by0, mut bx1, mut by1 := 0, 0, 0, 0
		C.stbtt_GetCodepointBitmapBox(&f.info, int(r), f.scale, f.scale, &bx0, &by0, &bx1, &by1)
		gw, gh := bx1 - bx0, by1 - by0
		if gw <= 0 || gh <= 0 {
			continue
		}
		mut glyph := []u8{len: gw * gh}
		C.stbtt_MakeCodepointBitmap(&f.info, glyph.data, gw, gh, gw, f.scale, f.scale, int(r))
		for y in 0 .. gh {
			for x in 0 .. gw {
				o := (by0 - y0 + y) * mask.w + pens[i] + bx0 - x0 + x
				mask.data[o] = math.max(mask.data[o], glyph[y * gw + x])
			}
		}
	}
	return mask, x0, y0
}

fn dilate(mask Image, r int) Image {
	mut out := new_image(.l, mask.w, mask.h, Color{})
	for y in 0 .. mask.h {
		for x in 0 .. mask.w {
			mut v := u8(0)
			for dy in -r .. r + 1 {
				for dx in -r .. r + 1 {
					sx, sy := x + dx, y + dy
					if dx * dx + dy * dy <= r * r && sx >= 0 && sy >= 0 && sx < mask.w
						&& sy < mask.h {
						v = math.max(v, mask.data[sy * mask.w + sx])
					}
				}
			}
			out.data[y * mask.w + x] = v
		}
	}
	return out
}

// fill_mask paints `c` through an L mask, following Pillow's fill_mask_L blending.
fn (mut img Image) fill_mask(mask Image, dx int, dy int, c Color) {
	ink := [c.r, c.g, c.b, c.a]
	n := if img.mode == .rgba { 4 } else { 3 }
	for y in 0 .. mask.h {
		ty := dy + y
		if ty < 0 || ty >= img.h {
			continue
		}
		for x in 0 .. mask.w {
			tx := dx + x
			m := mask.data[y * mask.w + x]
			if tx < 0 || tx >= img.w || m == 0 {
				continue
			}
			o := (ty * img.w + tx) * 4
			for i in 0 .. n {
				mut cm := u32(m)
				if img.mode == .rgba && i != 3 {
					cm = 255 - (255 - cm) * (u32(img.data[o + 3]) / 255)
				}
				img.data[o + i] = div255(u32(img.data[o + i]) * (255 - cm) + u32(ink[i]) * cm)
			}
		}
	}
}

@[params]
pub struct TextOpts {
pub:
	anchor       string = 'la'
	stroke_width int
	stroke_fill  Color
}

// text is ImageDraw.text with the 'la' or 'mm' anchor and an optional stroke.
pub fn (mut img Image) text(x int, y int, s string, fill Color, font &Font, opts TextOpts) {
	mut ox, mut baseline := x, y + font.ascent
	if opts.anchor == 'mm' {
		ox = x - font.textlength(s) / 2
		baseline = y + (font.ascent + font.descent) / 2
	}
	mask, mx, my := font.render_mask(s, opts.stroke_width)
	if opts.stroke_width > 0 {
		img.fill_mask(dilate(mask, opts.stroke_width), ox + mx, baseline + my, opts.stroke_fill)
	}
	img.fill_mask(mask, ox + mx, baseline + my, fill)
}

fn (mut img Image) set(x int, y int, c Color) {
	if x < 0 || y < 0 || x >= img.w || y >= img.h {
		return
	}
	o := (y * img.w + x) * 4
	img.data[o] = c.r
	img.data[o + 1] = c.g
	img.data[o + 2] = c.b
	if img.mode == .rgba {
		img.data[o + 3] = c.a
	}
}

@[params]
pub struct EllipseOpts {
pub:
	fill    ?Color
	outline ?Color
	width   int = 1
}

// ellipse is ImageDraw.ellipse over the inclusive box (x0, y0, x1, y1).
pub fn (mut img Image) ellipse(x0 f64, y0 f64, x1 f64, y1 f64, opts EllipseOpts) {
	l, t, r, b := int(x0), int(y0), int(x1), int(y1)
	cx, cy := f64(l + r + 1) / 2.0, f64(t + b + 1) / 2.0
	a, bb := f64(r - l + 1) / 2.0, f64(b - t + 1) / 2.0
	w := f64(opts.width)
	inside := fn (px f64, py f64, a f64, b f64) bool {
		return a > 0 && b > 0 && (px * px) / (a * a) + (py * py) / (b * b) <= 1.0
	}
	for py in t .. b + 1 {
		for px in l .. r + 1 {
			dx, dy := f64(px) + 0.5 - cx, f64(py) + 0.5 - cy
			if !inside(dx, dy, a, bb) {
				continue
			}
			if c := opts.outline {
				if !inside(dx, dy, a - w, bb - w) {
					img.set(px, py, c)
					continue
				}
			}
			if c := opts.fill {
				img.set(px, py, c)
			}
		}
	}
}

// line is ImageDraw.line for one segment with flat ends.
pub fn (mut img Image) line(x0 f64, y0 f64, x1 f64, y1 f64, c Color, width int) {
	dx, dy := x1 - x0, y1 - y0
	len2 := dx * dx + dy * dy
	half := f64(width) / 2.0
	for py in int(math.min(y0, y1) - half) - 1 .. int(math.max(y0, y1) + half) + 2 {
		for px in int(math.min(x0, x1) - half) - 1 .. int(math.max(x0, x1) + half) + 2 {
			qx, qy := f64(px) + 0.5 - x0, f64(py) + 0.5 - y0
			t := if len2 == 0 { 0.0 } else { (qx * dx + qy * dy) / len2 }
			if t < 0 || t > 1 {
				continue
			}
			ex, ey := qx - t * dx, qy - t * dy
			if ex * ex + ey * ey <= half * half {
				img.set(px, py, c)
			}
		}
	}
}
