# frozen_string_literal: true

require 'open3'

# Asserts that the code under test starts no external program. Kernel's
# process methods are private instance methods, so a bare `system(...)` or
# backtick inside a module or object calls them on that receiver, not on
# Kernel itself: each receiver the code runs as must be stubbed too.
module NoProcessExpectations
  KERNEL_PROCESS_METHODS = %i[system spawn ` exec fork open].freeze
  OPEN3_METHODS = %i[popen3 popen2 popen2e capture3 capture2 capture2e pipeline pipeline_r pipeline_w pipeline_rw pipeline_start].freeze

  # @param receivers [Array<Object>] modules or objects the code runs as
  # @return [void]
  def expect_no_process(*receivers)
    [Kernel, *receivers].each do |receiver|
      KERNEL_PROCESS_METHODS.each { |name| expect(receiver).not_to receive(name) }
    end
    %i[spawn fork exec].each { |name| expect(Process).not_to receive(name) }
    expect(IO).not_to receive(:popen)
    OPEN3_METHODS.each { |name| expect(Open3).not_to receive(name) }
  end
end
