module iconkit

import encoding.utf8

// Token is one lexeme of a Paradox script file, with its byte span.
pub struct Token {
pub:
	text  string
	start int
	end   int
}

// ident_len is the byte length of the [\w.-] character at s[i], or 0 when it is not one.
// Non-ASCII characters count only when they are Unicode letters or digits, as in Python.
fn ident_len(s string, i int) int {
	c := s[i]
	if c < 0x80 {
		return if c.is_letter() || c.is_digit() || c in [`_`, `.`, `-`] { 1 } else { 0 }
	}
	n := utf8_char_len(c)
	if n == 0 || i + n > s.len {
		return 0
	}
	r := s[i..i + n].runes()[0]
	return if utf8.is_letter(r) || utf8.is_number(r) { n } else { 0 }
}

// ident_end returns the index just past the run of [\w.-] characters starting at i.
fn ident_end(s string, i int) int {
	mut j := i
	for j < s.len {
		n := ident_len(s, j)
		if n == 0 {
			break
		}
		j += n
	}
	return j
}

fn is_space(c u8) bool {
	return c in [` `, `\t`, `\n`, `\r`, 11, 12]
}

// tokenize splits quoted strings, braces, '=' and identifiers; comments are dropped.
pub fn tokenize(text string) []Token {
	mut tokens := []Token{}
	mut i := 0
	for i < text.len {
		c := text[i]
		if c == `"` {
			mut j := i + 1
			for j < text.len && text[j] != `"` {
				j += if text[j] == `\\` { 2 } else { 1 }
			}
			if j < text.len {
				tokens << Token{text[i..j + 1], i, j + 1}
				i = j + 1
				continue
			}
		} else if c == `#` {
			for i < text.len && text[i] != `\n` {
				i++
			}
			continue
		} else if c in [`{`, `}`, `=`] {
			tokens << Token{text[i..i + 1], i, i + 1}
		} else if ident_len(text, i) > 0 {
			j := ident_end(text, i)
			tokens << Token{text[i..j], i, j}
			i = j
			continue
		}
		i += if c < 0x80 { 1 } else { int_max(1, utf8_char_len(c)) }
	}
	return tokens
}

pub struct Block {
pub:
	name  string
	start int
	end   int
}

// blocks yields every top-level `name = { ... }` with the span of its body.
pub fn blocks(text string) []Block {
	tokens := tokenize(text)
	mut out := []Block{}
	mut depth := 0
	mut name := ''
	mut start := 0
	for i, token in tokens {
		if token.text == '{' {
			if depth == 0 {
				k := if i >= 2 { i - 2 } else { tokens.len + i - 2 }
				name, start = tokens[k].text, token.end
			}
			depth++
		} else if token.text == '}' {
			depth--
			if depth == 0 {
				out << Block{name, start, token.start}
			}
		}
	}
	return out
}

pub fn trait_span(text string, name string) !(int, int) {
	found := blocks(text).filter(it.name == name)
	if found.len != 1 {
		return error('Expected exactly one trait definition for ${name}, found ${found.len}')
	}
	return found[0].start, found[0].end
}

// line_value is re.search(r'^\s*KEY\s*=\s*"([^"]+)"', body, re.M) when quoted,
// or r'^\s*KEY\s*=\s*([\w.-]+)' otherwise.
pub fn line_value(body string, key string, quoted bool) ?string {
	for p in 0 .. body.len {
		if p > 0 && body[p - 1] != `\n` {
			continue
		}
		mut i := p
		for i < body.len && is_space(body[i]) {
			i++
		}
		if !body[i..].starts_with(key) {
			continue
		}
		i += key.len
		for i < body.len && is_space(body[i]) {
			i++
		}
		if i >= body.len || body[i] != `=` {
			continue
		}
		i++
		for i < body.len && is_space(body[i]) {
			i++
		}
		if quoted {
			if i >= body.len || body[i] != `"` {
				continue
			}
			i++
			mut j := i
			for j < body.len && body[j] != `"` {
				j++
			}
			if j > i && j < body.len {
				return body[i..j]
			}
		} else {
			j := ident_end(body, i)
			if j > i {
				return body[i..j]
			}
		}
	}
	return none
}

pub struct IconRef {
pub:
	value string
	start int
	end   int
}

// icon_refs is re.finditer(r'(?m)^([ \t]*icon[ \t]*=[ \t]*")([^"\r\n]+)(")', body), group 2.
pub fn icon_refs(body string) []IconRef {
	mut out := []IconRef{}
	mut p := 0
	for p < body.len {
		mut i := p
		for i < body.len && body[i] in [` `, `\t`] {
			i++
		}
		if body[i..].starts_with('icon') {
			i += 4
			for i < body.len && body[i] in [` `, `\t`] {
				i++
			}
			if i < body.len && body[i] == `=` {
				i++
				for i < body.len && body[i] in [` `, `\t`] {
					i++
				}
				if i < body.len && body[i] == `"` {
					mut j := i + 1
					for j < body.len && body[j] !in [`"`, `\r`, `\n`] {
						j++
					}
					if j > i + 1 && j < body.len && body[j] == `"` {
						out << IconRef{body[i + 1..j], i + 1, j}
					}
				}
			}
		}
		next := body.index_after('\n', p) or { break }
		p = next + 1
	}
	return out
}

// parse_localization collects `key:0 "value"` lines from a CK3 .yml file.
pub fn parse_localization(text string, mut loc map[string]string) {
	for line in text.split('\n') {
		mut i := 0
		for i < line.len && is_space(line[i]) {
			i++
		}
		k := i
		i = ident_end(line, i)
		if i == k || i >= line.len || line[i] != `:` {
			continue
		}
		key := line[k..i]
		i++
		for i < line.len && line[i].is_digit() {
			i++
		}
		for i < line.len && is_space(line[i]) {
			i++
		}
		if i >= line.len || line[i] != `"` {
			continue
		}
		close := line.last_index('"') or { continue }
		if close > i {
			loc[key] = line[i + 1..close]
		}
	}
}

// substitute_vars replaces every $key$ with its localization, keeping unknown ones.
pub fn substitute_vars(value string, loc map[string]string) string {
	mut out := []u8{cap: value.len}
	mut i := 0
	for i < value.len {
		if value[i] == `$` {
			j := ident_end(value, i + 1)
			if j > i + 1 && j < value.len && value[j] == `$` {
				name := value[i + 1..j]
				out << (loc[name] or { value[i..j + 1] }).bytes()
				i = j + 1
				continue
			}
		}
		out << value[i]
		i++
	}
	return out.bytestr()
}
