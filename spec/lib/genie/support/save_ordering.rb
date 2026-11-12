# frozen_string_literal: true

module GenieSpecSupport
  # Two threads saving one list at once (a script's `#class save`, a #trigger body's) must not
  # let the older snapshot land last (the ordering lock Triggers#save and
  # GlobalStore#save have). Every list writes through ConfigFile.write_lines, which this stubs:
  # the first save blocks inside the writer, the list changes, and a second save must wait for
  # the first write to finish before it even takes its snapshot. Without the save lock the
  # second save snapshots and writes while the first is still writing, and the first then
  # overwrites it with older rows.
  module SaveOrdering
    # @param first [Proc] puts the list in the state the first save writes
    # @param second [Proc] changes the list after the first save has taken its snapshot
    # @param first_marker [String] text only the first state writes
    # @param second_marker [String] text the second state writes
    # @param save [Proc] runs one save, returning its result
    def expect_ordered_saves(first:, second:, first_marker:, second_marker:, save:)
      first.call
      order = Queue.new
      entered = Queue.new
      release = Queue.new
      allow(Lich::Genie::ConfigFile).to receive(:write_lines) do |_path, lines|
        text = lines.join("\n")
        entered << text
        release.pop if text.include?(first_marker) && !text.include?(second_marker)
        order << text
      end
      first_save = Thread.new { save.call }
      second_save = nil
      begin
        expect(entered.pop).to include(first_marker)
        second.call # the list's own lock is free while the first save writes
        second_save = Thread.new { save.call }
        expect(second_save.join(0.2)).to be_nil # still waiting for the first write
        expect(entered.size).to eq(0)
      ensure
        release << true
      end
      expect([first_save, second_save].compact.map { |t| t.join(2)&.value }).to eq([true, true])
      written = Array.new(order.size) { order.pop }
      expect(written.length).to eq(2)
      expect(written.first).to include(first_marker)
      expect(written.last).to include(second_marker)
    end
  end
end
