// Run the prepared trait icons through local ComfyUI image-to-image. See iconkit/comfy.v.
module main

import os
import iconkit

fn main() {
	iconkit.run_step('generate', @DIR, os.args[1..])
}
