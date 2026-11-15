# frozen_string_literal: true

# Shared by the specs' stand-in terminals. io/console's IO#noecho runs its
# block with echo off, and a password must be read inside it. A stand-in that
# simply yields cannot tell a hidden read from a visible one, so a reader that
# skipped echo-off (and the Ctrl-Z handling around it) would still pass.
#
# Include this in a stand-in terminal and call require_hidden! at the top of
# its getpass: a read outside noecho then raises and fails the example.
module HiddenTerminalGuard
  def noecho
    @echo_off = true
    yield
  ensure
    @echo_off = false
  end

  private

  def require_hidden!
    raise 'a terminal password was read with echo on (getpass outside noecho)' unless @echo_off
  end
end
