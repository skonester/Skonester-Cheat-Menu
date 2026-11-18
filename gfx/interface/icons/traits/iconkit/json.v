module iconkit

import math
import strconv
import strings

// Json is an ordered, dynamically typed JSON value whose output matches Python's json.dumps.
pub struct Null {}

pub type Json = Null | []Json | bool | f64 | i64 | map[string]Json | string

pub fn (j Json) obj() map[string]Json {
	return if j is map[string]Json { j } else { panic('JSON value is not an object') }
}

pub fn (j Json) arr() []Json {
	return if j is []Json { j } else { panic('JSON value is not an array') }
}

pub fn (j Json) s() string {
	return if j is string { j } else { panic('JSON value is not a string') }
}

pub fn (j Json) i() i64 {
	return match j {
		i64 { j }
		f64 { i64(j) }
		bool { i64(j) }
		else { panic('JSON value is not a number') }
	}
}

pub fn (j Json) f() f64 {
	return match j {
		i64 { f64(j) }
		f64 { j }
		else { panic('JSON value is not a number') }
	}
}

pub fn (j Json) b() bool {
	return match j {
		bool { j }
		i64 { j != 0 }
		else { panic('JSON value is not a boolean') }
	}
}

pub fn (j Json) has(key string) bool {
	return j is map[string]Json && key in j
}

// at is Python's dict[key]; it fails loudly like a KeyError.
pub fn (j Json) at(key string) Json {
	m := j.obj()
	return m[key] or { panic('KeyError: ${key}') }
}

pub fn (j Json) get(key string, default Json) Json {
	if j is map[string]Json {
		return j[key] or { default }
	}
	return default
}

pub fn (j Json) idx(i int) Json {
	return j.arr()[i]
}

pub fn jstrs(items []string) Json {
	return Json(items.map(Json(it)))
}

// ---- parsing ----

struct JsonParser {
	src string
mut:
	pos int
}

pub fn parse_json(src string) !Json {
	mut p := JsonParser{
		src: if src.starts_with('\xef\xbb\xbf') { src[3..] } else { src }
	}
	v := p.value()!
	p.ws()
	if p.pos != p.src.len {
		return error('Extra data at offset ${p.pos}')
	}
	return v
}

fn (mut p JsonParser) ws() {
	for p.pos < p.src.len && p.src[p.pos] in [` `, `\t`, `\n`, `\r`] {
		p.pos++
	}
}

fn (mut p JsonParser) value() !Json {
	p.ws()
	if p.pos >= p.src.len {
		return error('Unexpected end of JSON')
	}
	c := p.src[p.pos]
	match c {
		`{` {
			p.pos++
			mut m := map[string]Json{}
			p.ws()
			if p.pos < p.src.len && p.src[p.pos] == `}` {
				p.pos++
				return m
			}
			for {
				p.ws()
				key := p.string()!
				p.ws()
				p.expect(`:`)!
				m[key] = p.value()!
				p.ws()
				if p.pos < p.src.len && p.src[p.pos] == `,` {
					p.pos++
					continue
				}
				p.expect(`}`)!
				return m
			}
		}
		`[` {
			p.pos++
			mut a := []Json{}
			p.ws()
			if p.pos < p.src.len && p.src[p.pos] == `]` {
				p.pos++
				return a
			}
			for {
				a << p.value()!
				p.ws()
				if p.pos < p.src.len && p.src[p.pos] == `,` {
					p.pos++
					continue
				}
				p.expect(`]`)!
				return a
			}
		}
		`"` {
			return p.string()!
		}
		else {}
	}

	for word, val in {
		'true':  Json(true)
		'false': Json(false)
		'null':  Json(Null{})
	} {
		if p.src[p.pos..].starts_with(word) {
			p.pos += word.len
			return val
		}
	}
	start := p.pos
	mut is_float := false
	for p.pos < p.src.len && p.src[p.pos] in '+-0123456789.eE'.bytes() {
		if p.src[p.pos] in [`.`, `e`, `E`] {
			is_float = true
		}
		p.pos++
	}
	text := p.src[start..p.pos]
	if text.len == 0 {
		return error('Expecting value at offset ${start}')
	}
	if !is_float {
		if v := strconv.parse_int(text, 10, 64) {
			return v
		}
	}
	return strconv.atof64(text)!
}

fn (mut p JsonParser) expect(c u8) ! {
	if p.pos >= p.src.len || p.src[p.pos] != c {
		return error('Expecting `${c.ascii_str()}` at offset ${p.pos}')
	}
	p.pos++
}

fn (mut p JsonParser) hex4() !int {
	if p.pos + 4 > p.src.len {
		return error('Invalid \\u escape')
	}
	v := strconv.parse_int(p.src[p.pos..p.pos + 4], 16, 32)!
	p.pos += 4
	return int(v)
}

fn (mut p JsonParser) string() !string {
	p.expect(`"`)!
	mut sb := strings.new_builder(32)
	for p.pos < p.src.len {
		c := p.src[p.pos]
		p.pos++
		if c == `"` {
			return sb.str()
		}
		if c != `\\` {
			sb.write_u8(c)
			continue
		}
		e := p.src[p.pos]
		p.pos++
		match e {
			`n` {
				sb.write_u8(`\n`)
			}
			`t` {
				sb.write_u8(`\t`)
			}
			`r` {
				sb.write_u8(`\r`)
			}
			`b` {
				sb.write_u8(8)
			}
			`f` {
				sb.write_u8(12)
			}
			`u` {
				mut cp := p.hex4()!
				if cp >= 0xd800 && cp < 0xdc00 && p.src[p.pos..].starts_with('\\u') {
					p.pos += 2
					low := p.hex4()!
					cp = 0x10000 + ((cp - 0xd800) << 10) + (low - 0xdc00)
				}
				sb.write_string(utf32_to_str(u32(cp)))
			}
			else {
				sb.write_u8(e)
			}
		}
	}
	return error('Unterminated string')
}

// ---- dumping (json.dumps compatible) ----

// dumps mirrors json.dumps(value, indent=indent, ensure_ascii=ascii); indent < 0 means None.
pub fn dumps(j Json, indent int, ascii bool) string {
	mut sb := strings.new_builder(1024)
	dump_value(mut sb, j, indent, 0, ascii)
	return sb.str()
}

fn newline(mut sb strings.Builder, indent int, level int) {
	if indent >= 0 {
		sb.write_u8(`\n`)
		sb.write_string(' '.repeat(indent * level))
	}
}

fn dump_value(mut sb strings.Builder, j Json, indent int, level int, ascii bool) {
	sep := if indent >= 0 { ',' } else { ', ' }
	match j {
		Null {
			sb.write_string('null')
		}
		bool {
			sb.write_string(if j { 'true' } else { 'false' })
		}
		i64 {
			sb.write_string(j.str())
		}
		f64 {
			sb.write_string(py_float(j))
		}
		string {
			dump_string(mut sb, j, ascii)
		}
		[]Json {
			if j.len == 0 {
				sb.write_string('[]')
				return
			}
			sb.write_u8(`[`)
			for n, item in j {
				if n > 0 {
					sb.write_string(sep)
				}
				newline(mut sb, indent, level + 1)
				dump_value(mut sb, item, indent, level + 1, ascii)
			}
			newline(mut sb, indent, level)
			sb.write_u8(`]`)
		}
		map[string]Json {
			if j.len == 0 {
				sb.write_string('{}')
				return
			}
			sb.write_u8(`{`)
			mut n := 0
			for key, item in j {
				if n > 0 {
					sb.write_string(sep)
				}
				n++
				newline(mut sb, indent, level + 1)
				dump_string(mut sb, key, ascii)
				sb.write_string(': ')
				dump_value(mut sb, item, indent, level + 1, ascii)
			}
			newline(mut sb, indent, level)
			sb.write_u8(`}`)
		}
	}
}

fn dump_string(mut sb strings.Builder, s string, ascii bool) {
	sb.write_u8(`"`)
	for r in s.runes() {
		match r {
			`"` {
				sb.write_string('\\"')
			}
			`\\` {
				sb.write_string('\\\\')
			}
			`\n` {
				sb.write_string('\\n')
			}
			`\r` {
				sb.write_string('\\r')
			}
			`\t` {
				sb.write_string('\\t')
			}
			rune(8) {
				sb.write_string('\\b')
			}
			rune(12) {
				sb.write_string('\\f')
			}
			else {
				if r < 0x20 || (ascii && r > 0x7e) {
					if r > 0xffff {
						v := int(r) - 0x10000
						sb.write_string('\\u${0xd800 + (v >> 10):04x}\\u${0xdc00 + (v & 0x3ff):04x}')
					} else {
						sb.write_string('\\u${int(r):04x}')
					}
				} else {
					sb.write_string(r.str())
				}
			}
		}
	}
	sb.write_u8(`"`)
}

// py_float reproduces Python's repr() of a float.
pub fn py_float(f f64) string {
	if math.is_nan(f) {
		return 'NaN'
	}
	if math.is_inf(f, 0) {
		return if f > 0 { 'Infinity' } else { '-Infinity' }
	}
	if f == 0 {
		return if math.signbit(f) { '-0.0' } else { '0.0' }
	}
	// Shortest digits that round-trip, from scientific notation.
	mut sci := ''
	for p in 1 .. 18 {
		sci = strconv.format_es(f, strconv.BF_param{
			len0:         p - 1
			pad_ch:       ` `
			positive:     true
			sign_flag:    false
			align:        .right
			rm_tail_zero: false
		})
		if strconv.atof64(sci) or { 0 } == f {
			break
		}
	}
	neg := sci.starts_with('-')
	body := sci.trim_left('-+')
	mantissa := body.all_before('e')
	exp := body.all_after('e').int()
	digits := mantissa.replace('.', '').trim_right('0')
	d := if digits.len == 0 { '0' } else { digits }
	mut out := ''
	if exp >= -4 && exp < 16 {
		if exp >= 0 {
			whole := if d.len > exp + 1 { d[..exp + 1] } else { d + '0'.repeat(exp + 1 - d.len) }
			frac := if d.len > exp + 1 { d[exp + 1..] } else { '0' }
			out = whole + '.' + frac
		} else {
			out = '0.' + '0'.repeat(-exp - 1) + d
		}
	} else {
		m := if d.len > 1 { d[..1] + '.' + d[1..] } else { d }
		sign := if exp < 0 { '-' } else { '+' }
		out = '${m}e${sign}${math.abs(exp):02}'
	}
	return if neg { '-' + out } else { out }
}
