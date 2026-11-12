# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::AssessIds do
  # A synthetic ASSESS target pattern of the shape such scripts use: the facing line with
  # the id captured from `[#nnn]`. The point of the shim is that a pattern like this matches
  # the enriched line unchanged.
  let(:assess_target) { /^You .*facing .*\[#(\d+)\]/ }

  # install! registers a persistent DownstreamHook when Lich's hook class is loaded (another
  # spec file may have loaded it); the examples drive the hook body (observe) themselves.
  before { allow(Lich::Common::DownstreamHook).to receive(:add) if defined?(Lich::Common::DownstreamHook) }

  after do
    described_class.instance_variable_set(:@buffer, nil)
    described_class.instance_variable_set(:@active, nil)
    described_class.instance_variable_set(:@installed, nil)
    described_class.instance_variable_set(:@in_assess, nil)
  end

  describe '.enrich' do
    it 'splices the exist-id after the creature name so the script pattern matches' do
      raw = "You (incredibly balanced) are facing " \
            "<d cmd='look #78195083'>an elder Adan'f sorcerer</d> (2) at melee range."
      line = described_class.enrich(raw)
      expect(line).to eq('You (incredibly balanced) are facing an elder ' \
                         "Adan'f sorcerer [#78195083] (2) at melee range.")
      m = assess_target.match(line)
      expect(m).not_to be_nil
      expect(m[1]).to eq('78195083') # the captured target id
    end

    it 'handles a name-first flanking line (double-quoted cmd)' do
      raw = '<d cmd="look #78195079">An elder Adan\'f sorcerer</d> ' \
            '(1: stunned and very badly balanced) is flanking you at melee range.'
      expect(described_class.enrich(raw)).to eq(
        "An elder Adan'f sorcerer [#78195079] (1: stunned and very badly balanced) " \
        'is flanking you at melee range.'
      )
    end

    it 'returns nil for a line with no creature link (header/blank)' do
      expect(described_class.enrich('You assess your combat situation...')).to be_nil
      expect(described_class.enrich('')).to be_nil
    end
  end

  describe '.enrich_block' do
    it 'enriches every creature line and drops the rest' do
      block = <<~ASSESS
        <pushStream id='assess'/>You assess your combat situation...
        You (incredibly balanced) are facing <d cmd='look #78195083'>an elder Adan'f sorcerer</d> (2) at melee range.
        <d cmd='look #78195087'>An elder Adan'f sorcerer</d> (3: nimbly balanced) is behind you at melee range.
        <popStream/>
      ASSESS
      lines = described_class.enrich_block(block)
      expect(lines.length).to eq(2)
      expect(lines[0]).to match(assess_target)
      expect(lines[0][assess_target, 1]).to eq('78195083')
      expect(lines[1]).to eq("An elder Adan'f sorcerer [#78195087] (3: nimbly balanced) " \
                             'is behind you at melee range.')
    end
  end

  describe '.observe (line-based, chunking-robust)' do
    before do
      allow(described_class).to receive(:enabled?).and_return(true)
      described_class.install! # arms @active (no DownstreamHook headless)
    end

    # DR's current form: each assess line is its own <popStream/><pushStream
    # id="assess"/>...\r\n (the shape of a recorded session).
    let(:per_line) do
      [
        %(<popStream/><pushStream id="assess"/>You (adeptly balanced) are facing ) +
          %(<d cmd='look #86948248'>a jeol moradu</d> (3) at melee range.\r\n),
        %(<popStream/><pushStream id="assess"/><d cmd='look #86947613'>A jeol moradu</d> ) +
          %{(1: friendly, cursed, and off balance) is behind } +
          %(<d cmd='look #86948982'>a jeol moradu</d> (5) at melee range.  | ) +
          %(<d cmd='face #86947613'>F</d>  | <d cmd='face #86948982'>F</d>\r\n),
        %(<popStream/><pushStream id="assess"/><d cmd='look #86948248'>A jeol moradu</d> ) +
          %((3: nimbly balanced) is facing you at melee range.  | <d cmd='face #86948248'>F</d>\r\n)
      ]
    end

    it 'enriches every assess line when each arrives in its own chunk' do
      delivered = []
      allow(described_class).to receive(:deliver) { |lines| delivered.concat(lines) }
      per_line.each { |chunk| described_class.observe(chunk) }
      expect(delivered.length).to eq(3)
      expect(delivered[0][assess_target, 1]).to eq('86948248') # the target line
      expect(delivered[1]).to include('A jeol moradu [#86947613]').and include('a jeol moradu [#86948982]')
      expect(delivered[2]).to include('A jeol moradu [#86948248]')
    end

    it 'enriches every assess line when the whole block arrives in ONE chunk' do
      # The regression: the old block-buffer dropped all but the first line here.
      delivered = []
      allow(described_class).to receive(:deliver) { |lines| delivered.concat(lines) }
      described_class.observe(per_line.join)
      expect(delivered.length).to eq(3)
      expect(delivered[0][assess_target, 1]).to eq('86948248')
      expect(delivered[2]).to include('A jeol moradu [#86948248]')
    end

    it 'ignores a look-tagged line outside the assess stream' do
      allow(described_class).to receive(:deliver)
      described_class.observe("You glance at <d cmd='look #99'>a rock</d> here.\r\n")
      expect(described_class).not_to have_received(:deliver)
    end

    it 'is inert when not armed' do
      described_class.instance_variable_set(:@active, false)
      allow(described_class).to receive(:deliver)
      described_class.observe("<pushStream id='assess'/><d cmd='look #1'>a foo</d> (1) is behind you at melee range.\r\n")
      expect(described_class).not_to have_received(:deliver)
    end
  end

  # PR #1813 review: the enriched lines go to Genie scripts only -- the in-Lich engine's intake
  # while the engine is on, or a native Genie front end -- and never to a .lic script.
  describe '.deliver' do
    let(:pushed) { [] }
    let(:taken) { [] }
    let(:engine) { [true] }

    before do
      log = pushed
      stub_const('Script', Class.new { define_singleton_method(:new_downstream) { |line| log << line } })
      intake = taken
      allow(Lich::Genie).to receive(:text_listener).and_return(->(lines) { intake << lines })
      on = engine
      allow(Lich::Genie).to receive(:engine_active?) { on[0] }
    end

    it "hands the batch, in order, to the engine's intake and pushes nothing to the Lich scripts" do
      described_class.deliver(['a [#1] x', 'b [#2] y'])
      expect([pushed, taken]).to eq([[], [['a [#1] x', 'b [#2] y']]])
    end

    it 'delivers nothing while the engine is off, or when its gate fails, or for an empty batch' do
      described_class.deliver([])
      engine[0] = false
      described_class.deliver(['c [#3]'])
      allow(Lich::Genie).to receive(:engine_active?).and_raise(RuntimeError, 'db gone')
      described_class.deliver(['c [#3]'])
      expect([pushed, taken]).to eq([[], []])
    end

    it 'sends the line to the client stream under native Genie, never to the engine or the Lich scripts' do
      saved = $frontend
      $frontend = +'genie'
      engine[0] = false # native Genie in front of Lich: the in-Lich engine need not run
      allow(described_class).to receive(:safe_client)
      described_class.deliver(['d [#4]'])
      expect([pushed, taken]).to eq([[], []])
      expect(described_class).to have_received(:safe_client).with('d [#4]')
    ensure
      $frontend = saved
    end
  end

  # The opt-in flag (off by default) gates both paths: nothing is observed or delivered until
  # a player turns it on, and turning it off stops it at once.
  describe 'the opt-in flag' do
    let(:assess_chunk) do
      %(<pushStream id="assess"/>You (1) are facing <d cmd='look #78195083'>an elder Adan'f sorcerer</d> (2).\r\n)
    end

    it 'does not arm the shim while the flag is off, even when install! is called' do
      allow(described_class).to receive(:enabled?).and_return(false)
      allow(described_class).to receive(:deliver)
      described_class.install!
      described_class.observe(assess_chunk)
      expect(described_class.active?).to be(false)
      expect(described_class).not_to have_received(:deliver)
    end

    it 'disarms at once when turned off, dropping a half-received line' do
      flag = [true]
      allow(described_class).to receive(:enabled?) { flag[0] }
      allow(described_class).to receive(:write_flag) { |_key, value| flag[0] = value }
      allow(described_class).to receive(:deliver)
      described_class.enabled = true
      described_class.observe(%(<pushStream id="assess"/>You (1) are facing ))
      described_class.enabled = false
      described_class.observe(%(<d cmd='look #78195083'>a goblin</d> (2).\r\n))
      expect(described_class.active?).to be(false)
      expect(described_class).not_to have_received(:deliver)
    end
  end

  # End to end, headless: the assess rows as a server sends them -> the shim -> the engine's
  # intake -> a real Genie script's matchre, which captures the id.
  describe 'a Genie script matching the enriched line' do
    def run_genie(source, lines)
      clock = [0.0]
      echoes = []
      Lich::Genie::Engine.run(source, name: 't', input: GenieSpecSupport::TimedInput.new(lines, clock: clock, gap: 0.02),
                                      echo: ->(t) { echoes << t }, clock: -> { clock[0] })
      echoes
    end

    def shim_output(enabled:, engine:)
      taken = []
      allow(described_class).to receive(:enabled?).and_return(enabled)
      allow(Lich::Genie).to receive(:engine_active?).and_return(engine)
      allow(Lich::Genie).to receive(:text_listener).and_return(->(lines) { taken.concat(lines) })
      described_class.install!
      described_class.observe(%(<pushStream id="assess"/>You assess your combat situation...\r\n))
      described_class.observe(%(You (1) are facing <d cmd='look #78195083'>an elder Adan'f sorcerer</d> (2).\r\n))
      described_class.observe(%(<popStream/><prompt time="1">&gt;</prompt>\r\n))
      taken
    end

    let(:script) { "matchre Got ^You .*facing .*\\[#(\\d+)\\]\nmatchwait 1\necho none\nexit\nGot:\necho target=$1\n" }

    it 'matches with the flag on and the engine on' do
      lines = shim_output(enabled: true, engine: true)
      expect(lines).to eq(["You (1) are facing an elder Adan'f sorcerer [#78195083] (2)."])
      expect(run_genie(script, lines)).to include('target=78195083')
    end

    it 'gets nothing with the engine off or the flag off' do
      expect(shim_output(enabled: true, engine: false)).to eq([])
      described_class.instance_variable_set(:@in_assess, nil)
      expect(shim_output(enabled: false, engine: true)).to eq([])
      expect(run_genie(script, [])).to include('none')
    end
  end

  describe '.enabled? default' do
    it 'defaults to false with no persistence available' do
      expect(described_class.enabled?).to be(false)
    end
  end
end
