# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/markup'

# These behaviors had no coverage while they lived in global_defs.rb: that
# file cannot be required from a spec without redefining the script-facing
# DSL against production game infrastructure (see the note atop
# spec/lib/global_defs_spec.rb). Extracting the module is what makes them
# reachable.
RSpec.describe Lich::Common::Markup do
  before do
    $sftowiz_multiline = nil
    $strip_xml_multiline = {}
    $link_highlight_start = ''
    $link_highlight_end = ''
    $speech_highlight_start = ''
    $speech_highlight_end = ''
  end

  describe '.fb_to_sf' do
    it 'passes a bare newline through untouched' do
      expect(described_class.fb_to_sf("\r\n")).to eq("\r\n")
    end

    it 'strips the <c> marker' do
      expect(described_class.fb_to_sf("<c>look\r\n")).to eq("look\r\n")
    end

    it 'returns nil when only line endings remain' do
      expect(described_class.fb_to_sf("<c>\r\n")).to be_nil
    end
  end

  describe '.strip_xml' do
    it 'removes tags and decodes entities' do
      expect(described_class.strip_xml("<b>a &amp; b</b>\r\n")).to eq("a & b\r\n")
    end

    it 'returns nil for a bare newline' do
      expect(described_class.strip_xml("\r\n")).to be_nil
    end

    it 'returns nil when stripping leaves only whitespace' do
      expect(described_class.strip_xml("<pushBold/><popBold/>\r\n")).to be_nil
    end

    it 'drops streams presented elsewhere in the frontend' do
      line = %(<pushStream id="inv"/>a sack<popStream/>kept\r\n)
      expect(described_class.strip_xml(line)).to eq("kept\r\n")
    end

    it 'drops paired data elements with their content' do
      expect(described_class.strip_xml("<right>sword</right>kept\r\n")).to eq("kept\r\n")
    end

    context 'with a multiline type' do
      it 'buffers an unbalanced pushStream and strips once it closes' do
        expect(described_class.strip_xml(%(<pushStream id="talk"/>partial), type: 'main')).to be_nil
        expect(described_class.strip_xml("<popStream/>done\r\n", type: 'main')).to eq("done\r\n")
      end

      it 'keeps buffers for different types independent' do
        described_class.strip_xml(%(<pushStream id="a"/>one), type: 'first')
        expect(described_class.strip_xml("plain\r\n", type: 'second')).to eq("plain\r\n")
        expect($strip_xml_multiline['first']).to include('one')
      end

      it 'clears the buffer after a balanced line' do
        described_class.strip_xml(%(<pushStream id="talk"/>x), type: 'main')
        described_class.strip_xml("<popStream/>y\r\n", type: 'main')
        expect($strip_xml_multiline['main']).to be_nil
      end
    end
  end

  describe '.sf_to_wiz' do
    it 'passes a bare newline through untouched' do
      expect(described_class.sf_to_wiz("\r\n")).to eq("\r\n")
    end

    it 'converts bold markers to GSL escapes' do
      expect(described_class.sf_to_wiz("<pushBold/>orc<popBold/>\r\n"))
        .to eq("\034GSL\r\norc\034GSM\r\n\r\n")
    end

    it 'rewrites a thoughts stream into ESP prose' do
      line = %(<pushStream id="thoughts"/>[General] Someone: "hi"<popStream/>\r\n)
      expect(described_class.sf_to_wiz(line))
        .to include('You hear the faint thoughts of [General]-ESP echo in your mind:')
    end

    # Regression: the channel and the message must both be bound before
    # either is rewritten. gsub runs a match of its own, which resets $~, so
    # reading $2 after calling gsub on $1 yields nil -- and the rescue in
    # sf_to_wiz turns the resulting NoMethodError into a silently dropped
    # line. A multi-word channel is what forces the rewrite to happen.
    it 'hyphenates a multi-word thought channel and keeps the message' do
      line = %(<pushStream id="thoughts"/>[Rogue Guild] A: "x"<popStream/>\r\n)
      result = described_class.sf_to_wiz(line)
      expect(result).to include('[Rogue-Guild]-ESP')
      expect(result).to include('A: "x"')
    end

    it 'strips bold markers from inside a thought message' do
      line = %(<pushStream id="thoughts"/>[Gen] <pushBold/>A<popBold/>: "x"<popStream/>\r\n)
      result = described_class.sf_to_wiz(line)
      expect(result).to include('A: "x"')
      expect(result).not_to include('GSL')
    end

    it 'rewrites a Voln stream' do
      line = %(<pushStream id="voln"/>[Voln - Bob] "greetings"<popStream/>\r\n)
      expect(described_class.sf_to_wiz(line))
        .to include('The Symbol of Thought begins to burn in your mind and you hear Bob thinking, "greetings"')
    end

    it 'wraps a death stream in its GSL channel' do
      line = %(<pushStream id="death"/>Bob just died!<popStream/>\r\n)
      expect(described_class.sf_to_wiz(line))
        .to eq("\034GSw00003\r\nBob just died!\034GSw00004\r\n\r\n")
    end

    it 'wraps a room name in its GSL channel' do
      line = %(<style id="roomName" />[Town Square]<style id=""/>\r\n)
      expect(described_class.sf_to_wiz(line))
        .to eq("\034GSo\r\n[Town Square]\034GSp\r\n\r\n")
    end

    # The highlight markers land inside the description, but the generic
    # tag sweep at the end of sf_to_wiz removes anything angle-bracketed --
    # so a marker has to be non-tag-shaped to survive. That is existing
    # behavior, pinned here so the ordering is not changed by accident.
    it 'applies link highlights inside a room description' do
      $link_highlight_start = '>>'
      $link_highlight_end = '<<'
      line = %(<style id="roomDesc"/>You see a <a exist="1">door</a>.<style id=""/>\r\n)
      expect(described_class.sf_to_wiz(line)).to include('You see a >>door<<.')
    end

    it 'applies speech highlights' do
      $speech_highlight_start = '['
      $speech_highlight_end = ']'
      expect(described_class.sf_to_wiz(%(<preset id='speech'>hello</preset>\r\n)))
        .to eq("[hello]\r\n")
    end

    it 'decodes entities' do
      expect(described_class.sf_to_wiz("a &amp; b &lt;c&gt;\r\n")).to eq("a & b <c>\r\n")
    end

    it 'returns nil when nothing printable remains' do
      expect(described_class.sf_to_wiz("<prompt>&gt;</prompt>\r\n")).to be_nil
    end

    context 'buffering split elements' do
      it 'holds an unbalanced pushStream until it closes' do
        expect(described_class.sf_to_wiz(%(<pushStream id="death"/>Bob))).to be_nil
        expect(described_class.sf_to_wiz("just died!<popStream/>\r\n"))
          .to eq("\034GSw00003\r\nBobjust died!\034GSw00004\r\n\r\n")
      end

      it 'holds an unbalanced style element until it closes' do
        expect(described_class.sf_to_wiz(%(<style id="roomName" />[Town))).to be_nil
        expect(described_class.sf_to_wiz(%( Square]<style id=""/>\r\n)))
          .to eq("\034GSo\r\n[Town Square]\034GSp\r\n\r\n")
      end

      it 'bypasses the buffer when asked' do
        described_class.sf_to_wiz(%(<pushStream id="death"/>stuck))
        expect(described_class.sf_to_wiz("plain\r\n", bypass_multiline: true)).to eq("plain\r\n")
      end
    end
  end

  # Pre-existing behavior relocated by the extraction, previously unpinned.
  # The rescue exists so a malformed line can never take down the read loop:
  # it reports and drops the line rather than raising into the caller. The
  # return must be nil specifically -- callers feed it to String#split, which
  # NilClass#split makes safe (lib/common/class_exts/nilclass.rb).
  describe 'the rescue path' do
    # The shared $_CLIENT_ from spec_helper has no public #puts and
    # report_error calls one, so swap in a collector for the duration rather
    # than adding a singleton to the global object other specs rely on. A
    # plain object, not an rspec double: the swap happens in an around hook,
    # which runs outside the per-test mock lifecycle.
    let(:client) do
      Object.new.tap do |obj|
        obj.instance_variable_set(:@lines, [])
        def obj.puts(line) = @lines << line
        def obj.lines = @lines
      end
    end

    around do |example|
      previous = $_CLIENT_
      $_CLIENT_ = client
      example.run
    ensure
      $_CLIENT_ = previous
    end

    before { allow(Lich).to receive(:log) }

    # The failure is forced rather than provoked by a crafted input: these are
    # pure string ops with no naturally-reachable failure, so the honest way
    # to pin the handler is to make a call inside the body raise. Unary + is
    # required because this file is frozen_string_literal and a frozen string
    # cannot take the singleton that stubbing #gsub defines.
    let(:line) { +"text\r\n" }

    it 'reports and returns nil when fb_to_sf raises' do
      allow(line).to receive(:gsub).and_raise(StandardError, 'boom')
      expect(described_class.fb_to_sf(line)).to be_nil
      expect(client.lines).to include(a_string_matching(/Error: fb_to_sf/))
    end

    it 'reports and returns nil when sf_to_wiz raises' do
      allow(line).to receive(:gsub).and_raise(StandardError, 'boom')
      expect(described_class.sf_to_wiz(line)).to be_nil
      expect(client.lines).to include(a_string_matching(/Error: sf_to_wiz/))
    end

    it 'does not let the error escape to the caller' do
      allow(line).to receive(:gsub).and_raise(StandardError, 'boom')
      expect { described_class.fb_to_sf(line) }.not_to raise_error
    end
  end

  describe '.monsterbold_start / .monsterbold_end' do
    # Markup calls ::Frontend explicitly, so stub the methods on that exact
    # object. Replacing the constant with stub_const is not enough: whether
    # the real ::Frontend already exists depends on which specs ran first,
    # and once it does, a constant stub on a different object is ignored.
    before do
      stub_const('Frontend', Module.new) unless defined?(::Frontend)
      allow(::Frontend).to receive(:supports_gsl?).and_return(false)
      allow(::Frontend).to receive(:supports_xml?).and_return(false)
    end

    it 'emits GSL escapes for a GSL frontend' do
      allow(::Frontend).to receive(:supports_gsl?).and_return(true)
      expect(described_class.monsterbold_start).to eq("\034GSL\r\n")
      expect(described_class.monsterbold_end).to eq("\034GSM\r\n")
    end

    it 'emits bold tags for an XML frontend' do
      allow(::Frontend).to receive(:supports_xml?).and_return(true)
      expect(described_class.monsterbold_start).to eq('<pushBold/>')
      expect(described_class.monsterbold_end).to eq('<popBold/>')
    end

    it 'emits nothing for a plain frontend' do
      expect(described_class.monsterbold_start).to eq('')
      expect(described_class.monsterbold_end).to eq('')
    end
  end
end
