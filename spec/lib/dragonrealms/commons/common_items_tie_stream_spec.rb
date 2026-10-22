# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load production code: the real DRC.bput and the real DRCI tie methods.
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common.rb')
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-items.rb')

# DRCI.tie_item_result through the real DRC.bput. The game stream is modelled
# as a queue of lines: each send queues that send's lines, get? reads them back
# in order, and clear empties the queue (as the real clear empties the script's
# buffer). Lines queued before the reply stand in for unsolicited text that
# arrives while the TIE waits: combat, spell wear-off, other scripts' replies.
RSpec.describe 'DRCI tie replies read through the real DRC.bput' do
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drci) { Lich::DragonRealms::DRCI }
  let(:buffer) { [] }
  let(:sent) { [] }

  def game(*lines_per_send)
    allow(drc).to receive(:waitrt?)
    allow(drc).to receive(:clear) { buffer.clear }
    allow(drc).to receive(:put) do |message|
      sent << message
      buffer.concat(Array(lines_per_send[sent.size - 1]))
    end
    allow(drc).to receive(:get?) { buffer.shift }
    allow(drc).to receive(:pause) { sleep(0.001) }
  end

  before { Lich::Messaging.clear_messages! }

  # tie_item_result passes no bput options, so a lost reply waits bput's full
  # 15 s timeout. Advance the clock one second per read instead of sleeping.
  def with_short_bput_timeout
    real_now = Time.now
    calls = 0
    allow(Time).to receive(:now) { real_now + ((calls += 1) * 1.0) }
    yield
  end

  [
    'You must be closer to use tactical abilities on your opponent.',
    "You feel the divinity seep from your bones as the previous blessing of Urrem'tier wanes.",
    'You untie a steel carving knife from the straps of your cotton odaj.',
    'You get a darkstone foil tied with an ornamental winterweave sword knot from inside your kirmiko pocket.'
  ].each do |line|
    it "reports the real failure, not :tied, when #{line.inspect} arrives first" do
      game([line, 'Tie what?'])
      expect(drci.tie_item_result('soft pouch')).to eq(:failed)
      expect(sent).to eq(['tie my soft pouch '])
    end

    it "reports the empty pouch, not :tied, when #{line.inspect} arrives first" do
      game([line, "Tie it off when it's empty?  Why?"])
      expect(drci.tie_item_result('soft pouch')).to eq(:empty)
    end

    it "does not report :tied on a lost reply when only #{line.inspect} arrives" do
      game([line])
      with_short_bput_timeout do
        expect(drci.tie_item_result('soft pouch')).to eq(:failed)
      end
    end
  end

  {
    'You tie up the soft gem pouch.'                                         => :tied,
    'You attach a loimic slender awl to a strap on your tailor\'s toolbelt.' => :tied,
    'You carefully tie your rope to your belt.'                              => :tied,
    'The soft gem pouch has already been tied off.'                          => :already_tied
  }.each do |reply, result|
    it "still reads #{reply.inspect} as #{result.inspect} after unrelated lines" do
      game(['You must be closer to use tactical abilities on your opponent.',
            'You untie your skates and slip them off of your feet.',
            reply])
      expect(drci.tie_item_result('soft pouch')).to eq(result)
    end
  end

  it 'tie_item? is false when a combat line precedes a real refusal' do
    game(['You must be closer to use tactical abilities on your opponent.',
          "There's no more free ties on the tailor's toolbelt for the knitting needles.  Try untying something first!"])
    expect(drci.tie_item?('knitting.needles', 'toolbelt')).to be false
    expect(sent).to eq(['tie my knitting.needles to my toolbelt'])
  end
end
