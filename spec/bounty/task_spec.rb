require 'bounty'

shared_examples "task predicate examples" do
  let(:falsey_types) { Bounty::KNOWN_TASKS - truthy_types }

  it "truthy types" do
    truthy_types.each do |type|
      t = described_class.new(type: type, requirements: requirements)
      expect(t.send(predicate)).to be_truthy, "expected #{predicate} for :#{type} to be true"
    end
  end

  it "falsey types" do
    falsey_types.each do |type|
      t = described_class.new(type: type, requirements: requirements)
      expect(t.send(predicate)).to be_falsey, "expected #{predicate} for :#{type} to be false"
    end
  end
end

class Bounty
  describe Task do
    let(:requirements) { {} }

    describe "#bandit?" do
      let(:predicate) { :bandit? }
      let(:truthy_types) { [:bandit, :bandit_assignment] }

      include_examples "task predicate examples"
    end

    describe "#creature?" do
      let(:predicate) { :creature? }
      let(:truthy_types) { [:creature_assignment, :cull, :dangerous, :dangerous_spawned, :rescue, :heirloom] }

      include_examples "task predicate examples"
    end

    describe "#cull?" do
      let(:predicate) { :cull? }
      let(:truthy_types) { [:cull] }

      include_examples "task predicate examples"
    end

    describe "#dangerous?" do
      let(:predicate) { :dangerous? }
      let(:truthy_types) { [:dangerous, :dangerous_spawned] }

      include_examples "task predicate examples"
    end

    describe "#escort?" do
      let(:predicate) { :escort? }
      let(:truthy_types) { [:escort, :escort_assignment] }

      include_examples "task predicate examples"
    end

    describe "#gem?" do
      let(:predicate) { :gem? }
      let(:truthy_types) { [:gem, :gem_assignment] }

      include_examples "task predicate examples"
    end

    describe "#heirloom?" do
      let(:predicate) { :heirloom? }
      let(:truthy_types) { [:heirloom, :heirloom_assignment, :heirloom_found] }

      include_examples "task predicate examples"
    end

    describe "#heirloom_found?" do
      let(:predicate) { :heirloom_found? }
      let(:truthy_types) { [:heirloom_found] }

      include_examples "task predicate examples"
    end

    describe "#search_heirloom?" do
      let(:predicate) { :search_heirloom? }
      let(:truthy_types) { [:heirloom] }
      let(:requirements) { {action: "search"}}

      include_examples "task predicate examples"
    end

    describe "#loot_heirloom?" do
      let(:predicate) { :loot_heirloom? }
      let(:truthy_types) { [:heirloom] }
      let(:requirements) { {action: "loot"}}

      include_examples "task predicate examples"
    end

    describe "#herb?" do
      let(:predicate) { :herb? }
      let(:truthy_types) { [:herb, :herb_assignment] }

      include_examples "task predicate examples"
    end

    describe "#skin?" do
      let(:predicate) { :skin? }
      let(:truthy_types) { [:skin, :skin_assignment] }

      include_examples "task predicate examples"
    end

    describe "#rescue?" do
      let(:predicate) { :rescue? }
      let(:truthy_types) { [:rescue, :rescue_assignment, :rescue_spawned] }

      include_examples "task predicate examples"
    end

    describe "#done?" do
      let(:predicate) { :done? }
      let(:truthy_types) { [:taskmaster, :guard, :failed, :heirloom_found] }

      include_examples "task predicate examples"
    end

    describe "#spawned?" do
      let(:predicate) { :spawned? }
      let(:truthy_types) { [:rescue_spawned, :dangerous_spawned, :escort] }

      include_examples "task predicate examples"
    end

    describe "#none?" do
      let(:predicate) { :none? }
      let(:truthy_types) { [nil, :none] }

      include_examples "task predicate examples"
    end

    describe "#any?" do
      let(:predicate) { :any? }
      let(:truthy_types) {
        [
          :bandit, :bandit_assignment,
          :creature_assignment, :cull, :dangerous, :dangerous_spawned,
          :escort,
          :failed,
          :gem, :gem_assignment,
          :guard,
          :heirloom, :heirloom_assignment, :heirloom_found,
          :herb, :herb_assignment,
          :rescue, :rescue_assignment, :rescue_spawned,
          :skin, :skin_assignment,
          :taskmaster
        ]
      }
    end

    describe "#guard?" do
      let(:predicate) { :guard? }
      let(:truthy_types) { [:guard, :bandit_assignment, :creature_assignment, :heirloom_assignment, :heirloom_found, :rescue_assignment] }

      include_examples "task predicate examples"
    end

    describe "#assigned?" do
      let(:predicate) { :assigned? }
      let(:truthy_types) { [:bandit_assignment, :creature_assignment, :gem_assignment, :heirloom_assignment, :herb_assignment, :rescue_assignment, :skin_assignment] }

      include_examples "task predicate examples"
    end

    describe "#ready?" do
      let(:predicate) { :ready? }
      let(:truthy_types) { [:bandit, :escort, :escort_assignment, :cull, :dangerous, :gem, :herb, :skin, :heirloom, :rescue] }

      include_examples "task predicate examples"
    end

    describe "#help?" do
      subject(:task) { described_class.new(description: desc) }

      context "when a help task" do
        let(:desc) { "You have been tasked to help Buddy suppress bandit activity in the grasslands between Wehnimer's Landing and Solhaven.  You need to kill 18 of them to complete your task." }

        it { expect(task.help?).to be_truthy }
      end

      context "when not a help task" do
        let(:desc) { "You have been tasked to suppress bandit activity near Widowmaker's Road near Kraken's Fall.  You need to kill 11 more of them to complete your task." }

        it { expect(task.help?).to be_falsey }
      end
    end
  end
end
