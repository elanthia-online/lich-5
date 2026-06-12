# frozen_string_literal: true

require_relative '../../spec_helper'

# TextStripper's load-time block calls Lich::Util.install_gem_requirements and
# requires kramdown (already in the bundle). Stub the installer so loading the
# file in specs does not try to install gems.
module Lich
  module Util
    def self.install_gem_requirements(*_args, **_kwargs); end
  end
end

require 'util/textstripper'

# These specs pin TextStripper's XML mode (issue #1393 item 6). The mode was
# evaluated REXML-vs-Ox across adversarial inputs and the two backends matched
# everywhere except HTML-only entities: REXML treated &nbsp; as an undefined XML
# entity (parse fails -> CDATA fallback -> returned verbatim), while Ox decodes
# it. XML mode now uses Ox so &nbsp; (and other HTML named entities) are parsed.
# The cases below cover entities, CDATA, namespaces, mixed content, the
# parse-failure CDATA fallback, and whitespace -- the fixtures gathered during
# that evaluation.
RSpec.describe Lich::Util::TextStripper do
  describe '.strip with XML mode (Ox-backed)' do
    # U+00A0 (nbsp) and other non-ASCII expected values are built via pack to
    # keep this source file ASCII-only (enforced by the custom RuboCop cop).
    let(:nbsp)   { [0x00A0].pack('U') } # non-breaking space, what &nbsp; decodes to
    let(:eacute) { [0x00E9].pack('U') } # e-acute, what &#233; decodes to
    let(:rsquo)  { [0x2019].pack('U') } # right single quote, what &#8217; decodes to

    def strip(text)
      described_class.strip(text, :xml)
    end

    it 'returns empty string for nil or empty input' do
      expect(described_class.strip(nil, :xml)).to eq('')
      expect(described_class.strip('', :xml)).to eq('')
    end

    it 'strips a single element to its text' do
      expect(strip('<item>data</item>')).to eq('data')
    end

    it 'extracts text from deeply nested elements' do
      expect(strip('<a><b><c>deep</c></b></a>')).to eq('deep')
    end

    it 'keeps text from mixed content' do
      expect(strip('pre <b>bold</b> post')).to eq('pre bold post')
    end

    it 'ignores namespace declarations' do
      expect(strip("<item xmlns='http://example.com'>data</item>")).to eq('data')
    end

    it 'decodes the predefined XML entities' do
      expect(strip('a &amp; b &lt;c&gt; &quot;d&quot; &apos;e&apos;')).to eq(%q{a & b <c> "d" 'e'})
    end

    it 'decodes numeric character references' do
      expect(strip('cafe &#233; and &#8217;')).to eq("cafe #{eacute} and #{rsquo}")
    end

    it 'parses HTML-only entities such as &nbsp; (Ox-backed behavior)' do
      expect(strip('a&nbsp;b')).to eq("a#{nbsp}b")
    end

    it 'returns explicit CDATA content verbatim, including special chars' do
      expect(strip('<![CDATA[Special <chars> & stuff]]>')).to eq('Special <chars> & stuff')
    end

    it 'falls back to verbatim text when unescaped < and & break parsing' do
      expect(strip('5 < 10 & 3 > 1')).to eq('5 < 10 & 3 > 1')
    end

    it 'preserves verbatim whitespace between words' do
      expect(strip('two  spaces  here')).to eq('two  spaces  here')
    end

    it 'trims leading and trailing whitespace' do
      expect(strip('  trimmed  ')).to eq('trimmed')
    end
  end
end
