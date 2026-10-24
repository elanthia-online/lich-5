# frozen_string_literal: true

require 'timeout'

# Per-example hang guard for the Genie specs. The engine's run
# loops (Interpreter#run, the flow harness, wait states fed by fake inputs) turn a broken
# line pointer or state transition into an endless loop; without a guard one such mutant
# hangs `rspec spec/lib/genie` forever (the review's line-pointer mutant hung
# flow_harness_spec:697, js_arrays_spec:199 and interpreter_wait_parse_spec:257). With it
# the example fails after GENIE_EXAMPLE_TIMEOUT seconds (default 30: the slowest Genie
# example takes well under a second, also under parallel_rspec -n 4) and the run goes on.
#
# Scoped by file path, so it only wraps examples under spec/lib/genie/, and required by every
# Genie spec file, so a file run alone is guarded too (require_relative loads it once).
module GenieSpecSupport
  EXAMPLE_TIMEOUT = Float(ENV.fetch('GENIE_EXAMPLE_TIMEOUT', '30'))

  # Raised instead of Timeout::Error so the failure says what happened. An Exception, not a
  # StandardError: Timeout raises it INSIDE the example, where the engine's own catch-alls
  # (`rescue StandardError` in MathEval/evalmath, waiteval_satisfied?, NetRegex.valid?,
  # Triggers.compile -- each a faithful port of a Remix catch (Exception)) would swallow a
  # StandardError and keep the loop spinning (once, a frozen-clock evalmath
  # loop ran 20 s and PASSED). RSpec still records an Exception as the example's failure.
  class ExampleHung < Exception; end # rubocop:disable Lint/InheritException

  # RSpec never rescues SystemExit, so one escaping a Genie example (a
  # worker thread ended by SystemExit and then joined -- Thread#join re-raises its exception in
  # the joiner) used to end the whole run with exit status 0 after a third of the suite. The
  # guard turns it into that example's failure and the run goes on.
  class EscapedExit < StandardError; end
end

RSpec.configure do |config|
  config.around(:example, file_path: %r{/spec/lib/genie/}) do |example|
    Timeout.timeout(GenieSpecSupport::EXAMPLE_TIMEOUT, GenieSpecSupport::ExampleHung,
                    "example hung for #{GenieSpecSupport::EXAMPLE_TIMEOUT}s (engine loop?)") { example.run }
  rescue SystemExit => e
    raise GenieSpecSupport::EscapedExit, "SystemExit (status #{e.status}) escaped the example: #{e.message}"
  end
end
