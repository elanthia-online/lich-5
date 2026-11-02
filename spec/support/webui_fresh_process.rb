# frozen_string_literal: true

require 'open3'
require 'rbconfig'

# Fresh-process helper for WebUI load-order examples. A child gets a deadline so a
# hang fails by name, not by job timeout. Include in an example group to use it.
module WebUIFreshProcess
  FRESH_PROCESS_DEADLINE = 60

  # Runs Ruby code in a fresh process, killing it at the deadline.
  # @param code [String] script passed to ruby -e
  # @param ruby_args [Array<String>] extra interpreter arguments placed before -e
  # @return [Array(String, String, Process::Status, nil)] output, errors, and status;
  #   status is nil when the deadline killed the child
  def run_ruby_with_deadline(code, *ruby_args)
    Open3.popen3(RbConfig.ruby, *ruby_args, '-I', LIB_DIR, '-e', code) do |stdin, stdout, stderr, waiter|
      stdin.close
      readers = [Thread.new { stdout.read }, Thread.new { stderr.read }]
      finished = waiter.join(FRESH_PROCESS_DEADLINE)
      unless finished
        begin
          Process.kill('KILL', waiter.pid)
        rescue Errno::ESRCH
          nil
        end
        waiter.join
      end
      [readers.first.value, readers.last.value, (waiter.value if finished)]
    end
  end

  # Fails with the child's captured streams when the deadline killed it.
  # @param status [Process::Status, nil] status from run_ruby_with_deadline
  # @param output [String] child stdout
  # @param errors [String] child stderr
  # @param label [String] name of the example's child process
  # @return [void]
  def expect_child_within_deadline(status, output, errors, label)
    expect(status).not_to be_nil,
                          "#{label} exceeded #{FRESH_PROCESS_DEADLINE}s; output=#{output.inspect} errors=#{errors.inspect}"
  end
end
