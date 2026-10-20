# frozen_string_literal: true

# Finds live DRExpMonitor reporter threads by their stack rather than by
# reading the module's class variables, so a spec sees every reporter that is
# actually running, including one the module has lost track of.
#
# Plain Ruby with no spec_helper dependency: the hot reload and do_client
# child processes run from the repository root and load it with
# `require './spec/support/drexpmonitor_reporters'`.
module DRExpMonitorReporters
  # @return [Array<Thread>] live threads, other than the caller, that are
  #   executing lib/dragonrealms/drinfomon/drexpmonitor.rb
  def self.threads
    Thread.list.select do |t|
      t != Thread.current && t.alive? &&
        t.backtrace&.any? { |l| l.include?('drinfomon/drexpmonitor.rb') }
    end
  end
end
