# frozen_string_literal: true

require_relative '../../../../lib/genie'

# The glue specs load lib/genie/genie_script.rb into a process with no Lich session and drive its
# taps themselves: loading it must not install the game-state tap onto Lich's Script the way the
# lich.rbw load does (GenieScript.install_at_lich_load!). The explicit opt-out the glue honours;
# kept across a reload of lib/genie.rb.
Lich::Genie.autoinstall = false
