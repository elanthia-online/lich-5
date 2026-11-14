# frozen_string_literal: true

# Terminal fence for the spec suite.
#
# Rule: specs never read the developer's terminal. The CLI password prompts
# read a terminal with echo off and wait for a line, so an example that stubs
# only `$stdin.gets` would hang when rspec itself is run from a terminal, and
# pass in CI where stdin is not one. With the fence, `$stdin` is not a terminal
# in any example, on any host. Loaded for every rspec process through `.rspec`
# and `.rspec_parallel`, so it does not depend on a spec file requiring
# spec_helper.
#
# An example that needs a terminal passes its own stand-in (an object whose
# `tty?` is true) to the code under test, or assigns one to `$stdin`; the fence
# only covers the process's original stdin.
#
# The stub is installed through RSpec::Mocks directly, not through the
# example's `allow` and `receive`, because an example group may define helper
# methods with those names.
RSpec.configure do |config|
  config.before do
    RSpec::Mocks.allow_message($stdin, :tty?).and_return(false)
  end
end
