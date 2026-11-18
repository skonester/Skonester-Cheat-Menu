// Export selected icons as 100x100 RGBA DDS; use --install to replace game assets. See iconkit/install.v.
module main

import os
import iconkit

fn main() {
	iconkit.run_step('install', @DIR, os.args[1..])
}
