// Reuse the established ComfyUI pipeline in ../distinct_generation for this batch.
module main

import os
import iconkit

fn main() {
	actions := ['generate', 'finish', 'collect', 'install']
	if os.args.len < 2 || os.args[1] !in actions {
		eprintln('Usage: v run pipeline.v generate|finish|collect|install [options]')
		exit(1)
	}
	iconkit.run_step(os.args[1], @DIR, os.args[2..])
}
