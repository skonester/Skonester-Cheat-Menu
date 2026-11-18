module iconkit

import os
import math
import time
import strconv
import crypto.sha256

// Paths mirrors the BASE / TRAITS / ROOT globals of the original scripts.
pub struct Paths {
pub:
	base   string
	traits string
	root   string
}

pub fn new_paths(base string) Paths {
	b := os.real_path(base)
	traits := os.dir(b)
	return Paths{
		base:   b
		traits: traits
		root:   parents(traits, 4)
	}
}

pub fn parents(path string, n int) string {
	mut p := path
	for _ in 0 .. n {
		p = os.dir(p)
	}
	return p
}

// path joins segments that may contain forward slashes into a native path.
pub fn path(base string, rest ...string) string {
	return os.norm_path(os.join_path(base, ...rest))
}

pub fn stem(p string) string {
	name := p.all_after_last('/').all_after_last('\\')
	i := name.last_index('.') or { return name }
	return if i == 0 { name } else { name[..i] }
}

pub fn same_path(a string, b string) bool {
	return os.norm_path(a).to_lower() == os.norm_path(b).to_lower()
}

pub fn is_relative_to(p string, base string) bool {
	a := os.norm_path(os.real_path(p)).to_lower()
	b := os.norm_path(base).to_lower()
	return a == b || a.starts_with(b.trim_right('\\/') + os.path_separator)
}

pub fn relative_to(p string, base string) string {
	a := os.norm_path(p)
	b := os.norm_path(base).trim_right('\\/')
	return if a.len > b.len { a[b.len + 1..] } else { '' }
}

pub fn posix(p string) string {
	return p.replace('\\', '/')
}

// files_with_ext lists files sorted the way pathlib sorts them on Windows.
pub fn files_with_ext(dir string, ext string) []string {
	names := os.ls(dir) or { return [] }
	mut out := []string{}
	for name in names {
		full := os.join_path(dir, name)
		if name.to_lower().ends_with(ext) && os.is_file(full) {
			out << full
		}
	}
	out.sort(a.to_lower() < b.to_lower())
	return out
}

// read_text matches Path.read_text: optional BOM removal and universal newlines.
pub fn read_text(p string) !string {
	mut s := os.read_file(p)!
	if s.starts_with('\xef\xbb\xbf') {
		s = s[3..]
	}
	return s.replace('\r\n', '\n').replace('\r', '\n')
}

// write_text matches Path.write_text, which writes CRLF on Windows.
pub fn write_text(p string, s string) ! {
	$if windows {
		os.write_file(p, s.replace('\n', '\r\n'))!
	} $else {
		os.write_file(p, s)!
	}
}

pub fn mkdirs(p string) ! {
	if !os.is_dir(p) {
		os.mkdir_all(p)!
	}
}

pub fn copy2(src string, dst string) ! {
	os.cp(src, dst)!
	mtime := int(os.file_last_mod_unix(src))
	os.utime(dst, mtime, mtime) or {}
}

// Blob stands in for Python's `bytes | None`.
pub struct Blob {
pub:
	exists bool
	data   []u8
}

pub fn read_blob(p string) !Blob {
	if !os.exists(p) {
		return Blob{}
	}
	return Blob{true, os.read_bytes(p)!}
}

pub fn (a Blob) == (b Blob) bool {
	return a.exists == b.exists && a.data == b.data
}

pub fn digest(data []u8) string {
	return sha256.sum(data).hex()
}

pub fn html_escape(s string) string {
	return s.replace_each(['&', '&amp;', '<', '&lt;', '>', '&gt;', '"', '&quot;', "'", '&#x27;'])
}

// py_round is Python's round(): halves go to the even neighbour.
pub fn py_round(x f64) int {
	f := math.floor(x)
	d := x - f
	if d > 0.5 || (d == 0.5 && i64(f) % 2 != 0) {
		return int(f) + 1
	}
	return int(f)
}

pub fn utc_stamp() string {
	t := time.utc()
	return '${t.year:04}${t.month:02}${t.day:02}T${t.hour:02}${t.minute:02}${t.second:02}${t.nanosecond / 1000:06}Z'
}

pub fn safe_name(s string) bool {
	if s.len == 0 {
		return false
	}
	for c in s {
		if !(c.is_letter() || c.is_digit() || c == `_` || c == `-`) {
			return false
		}
	}
	return true
}

// Cli is a small argparse replacement: --flag, --opt value, --opt=value, --list a b c.
pub struct Cli {
pub:
	prog  string
	usage string
pub mut:
	values map[string][]string
}

pub fn (c Cli) fail(msg string) {
	eprintln('usage: ${c.usage}')
	eprintln('${c.prog}: error: ${msg}')
	exit(2)
}

pub fn parse_cli(prog string, doc string, usage string, argv []string, switches []string, options []string, lists []string) Cli {
	mut c := Cli{
		prog:  prog
		usage: usage
	}
	mut i := 0
	for i < argv.len {
		arg := argv[i]
		i++
		if arg in ['-h', '--help'] {
			println('usage: ${usage}\n\n${doc.trim_space()}')
			exit(0)
		}
		if !arg.starts_with('--') {
			c.fail('unrecognized arguments: ${arg}')
		}
		name := arg[2..].all_before('=')
		if name in switches {
			c.values[name] = []
		} else if name in options {
			if arg.contains('=') {
				c.values[name] = [arg.all_after('=')]
			} else if i < argv.len {
				c.values[name] = [argv[i]]
				i++
			} else {
				c.fail('argument --${name}: expected one argument')
			}
		} else if name in lists {
			mut items := []string{}
			for i < argv.len && !argv[i].starts_with('--') {
				items << argv[i]
				i++
			}
			if items.len == 0 {
				c.fail('argument --${name}: expected at least one argument')
			}
			c.values[name] = items
		} else {
			c.fail('unrecognized arguments: ${arg}')
		}
	}
	return c
}

pub fn (c Cli) has(name string) bool {
	return name in c.values
}

pub fn (c Cli) get(name string, default string) string {
	return if v := c.values[name] { v[0] } else { default }
}

pub fn (c Cli) list(name string) []string {
	return c.values[name] or { []string{} }
}

pub fn (c Cli) int(name string, default int) int {
	v := c.values[name] or { return default }
	return strconv.atoi(v[0]) or {
		c.fail("argument --${name}: invalid int value: '${v[0]}'")
		0
	}
}

pub fn (c Cli) float(name string, default f64) f64 {
	v := c.values[name] or { return default }
	return strconv.atof64(v[0]) or {
		c.fail("argument --${name}: invalid float value: '${v[0]}'")
		0
	}
}

// run_step dispatches the shared ComfyUI pipeline steps for any batch folder.
pub fn run_step(action string, base string, argv []string) {
	p := new_paths(base)
	match action {
		'generate' { run_comfy_batch(p, argv) or { die(err) } }
		'finish' { finish_comfy_icons(p, argv) or { die(err) } }
		'collect' { assemble_results(p) or { die(err) } }
		'install' { install_dds_icons(p, argv) or { die(err) } }
		else { die(error('Unknown action: ${action}')) }
	}
}

fn die(err IError) {
	eprintln('Error: ${err.msg()}')
	exit(1)
}
