require 'bounty/task'

class Bounty
  describe Task do
    it do
      expect(described_class.new.task).to be_nil
    end
  end
end
