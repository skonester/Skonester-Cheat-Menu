// Collect reviewed ComfyUI runs into one named set and a local comparison gallery. See iconkit/assemble.v.
module main

import os
import iconkit

fn main() {
	iconkit.run_step('collect', @DIR, os.args[1..])
}
