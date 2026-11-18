module iconkit

import os
import dl

// Minimal onnxruntime C API binding, loaded from onnxruntime.dll at runtime.
// Indices are positions in the append-only OrtApi function table (ORT_API_VERSION 20).
const ort_api_version = u32(20)
const ort_get_error_message = 2
const ort_create_env = 3
const ort_create_session = 7
const ort_run = 9
const ort_create_session_options = 10
const ort_set_intra_op_num_threads = 24
const ort_session_get_input_name = 36
const ort_session_get_output_name = 37
const ort_create_tensor_with_data = 49
const ort_get_tensor_mutable_data = 51
const ort_create_cpu_memory_info = 69
const ort_get_allocator = 78

type FnGetApiBase = fn () &OrtApiBase

type FnGetApi = fn (u32) &voidptr

type FnErrorMessage = fn (voidptr) &char

type FnCreateEnv = fn (int, &char, &voidptr) voidptr

type FnCreateOptions = fn (&voidptr) voidptr

type FnSetThreads = fn (voidptr, int) voidptr

type FnCreateSession = fn (voidptr, &u16, voidptr, &voidptr) voidptr

type FnGetAllocator = fn (&voidptr) voidptr

type FnSessionName = fn (voidptr, usize, voidptr, &&char) voidptr

type FnCpuMemoryInfo = fn (int, int, &voidptr) voidptr

type FnCreateTensor = fn (voidptr, voidptr, usize, &i64, usize, int, &voidptr) voidptr

type FnRun = fn (voidptr, voidptr, &&char, &voidptr, usize, &&char, usize, &voidptr) voidptr

type FnTensorData = fn (voidptr, &voidptr) voidptr

struct OrtApiBase {
	get_api     FnGetApi = unsafe { nil }
	get_version voidptr
}

pub struct OrtSession {
	api     &voidptr = unsafe { nil }
	session voidptr
	input   &char = unsafe { nil }
	output  &char = unsafe { nil }
}

fn (s &OrtSession) fn_at(i int) voidptr {
	return unsafe { s.api[i] }
}

fn (s &OrtSession) check(status voidptr) ! {
	if status != unsafe { nil } {
		f1 := unsafe { FnErrorMessage(s.fn_at(ort_get_error_message)) }
		msg := f1(status)
		return error('onnxruntime: ${unsafe { cstring_to_vstring(msg) }}')
	}
}

// find_onnxruntime looks for onnxruntime.dll: explicit path, environment, then Python's package.
pub fn find_onnxruntime(explicit string) string {
	if explicit != '' {
		return explicit
	}
	if env := os.getenv_opt('ONNXRUNTIME_DLL') {
		return env
	}
	local := os.getenv('LOCALAPPDATA')
	for version in ['313', '312', '311', '310'] {
		p := os.join_path(local, 'Programs', 'Python', 'Python${version}', 'Lib', 'site-packages',
			'onnxruntime', 'capi', 'onnxruntime.dll')
		if os.exists(p) {
			return p
		}
	}
	return 'onnxruntime.dll'
}

pub fn ort_open(dll string, model string, threads int) !&OrtSession {
	handle := dl.open_opt(dll, dl.rtld_now) or {
		return error('cannot load ${dll}; pass --onnxruntime or set ONNXRUNTIME_DLL')
	}
	sym := dl.sym_opt(handle, 'OrtGetApiBase')!
	f2 := unsafe { FnGetApiBase(sym) }
	base := f2()
	api := base.get_api(ort_api_version)
	if api == unsafe { nil } {
		return error('onnxruntime at ${dll} does not support API version ${ort_api_version}')
	}
	mut s := &OrtSession{
		api: api
	}
	mut env := unsafe { nil }
	f3 := unsafe { FnCreateEnv(s.fn_at(ort_create_env)) }
	s.check(f3(2, c'skonester', &env))!
	mut options := unsafe { nil }
	f4 := unsafe { FnCreateOptions(s.fn_at(ort_create_session_options)) }
	s.check(f4(&options))!
	f5 := unsafe { FnSetThreads(s.fn_at(ort_set_intra_op_num_threads)) }
	s.check(f5(options, threads))!
	mut session := unsafe { nil }
	f6 := unsafe { FnCreateSession(s.fn_at(ort_create_session)) }
	s.check(f6(env, model.to_wide(), options, &session))!
	mut allocator := unsafe { nil }
	f7 := unsafe { FnGetAllocator(s.fn_at(ort_get_allocator)) }
	s.check(f7(&allocator))!
	mut input := &char(unsafe { nil })
	mut output := &char(unsafe { nil })
	f8 := unsafe { FnSessionName(s.fn_at(ort_session_get_input_name)) }
	s.check(f8(session, 0, allocator, &input))!
	f9 := unsafe { FnSessionName(s.fn_at(ort_session_get_output_name)) }
	s.check(f9(session, 0, allocator, &output))!
	return &OrtSession{
		api:     api
		session: session
		input:   input
		output:  output
	}
}

// run feeds one float tensor and returns the first output's first `count` floats.
pub fn (s &OrtSession) run(data []f32, shape []i64, count int) ![]f32 {
	mut info := unsafe { nil }
	f10 := unsafe { FnCpuMemoryInfo(s.fn_at(ort_create_cpu_memory_info)) }
	s.check(f10(1, 0, &info))!
	mut tensor := unsafe { nil }
	f11 := unsafe { FnCreateTensor(s.fn_at(ort_create_tensor_with_data)) }
	s.check(f11(info, data.data, usize(data.len * 4), shape.data, usize(shape.len), 1, &tensor))!
	mut result := unsafe { nil }
	f12 := unsafe { FnRun(s.fn_at(ort_run)) }
	s.check(f12(s.session, unsafe { nil }, &s.input, &tensor, 1, &s.output, 1, &result))!
	mut ptr := unsafe { nil }
	f13 := unsafe { FnTensorData(s.fn_at(ort_get_tensor_mutable_data)) }
	s.check(f13(result, &ptr))!
	mut out := []f32{len: count}
	unsafe { vmemcpy(out.data, ptr, count * 4) }
	return out
}
