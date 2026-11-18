// Remove generated backgrounds and export transparent masters and 120px previews. See iconkit/finish.v.
module main

import os
import iconkit

fn main() {
	iconkit.run_step('finish', @DIR, os.args[1..])
}
