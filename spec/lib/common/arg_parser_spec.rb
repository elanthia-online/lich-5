# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/arg_parser'

RSpec.describe Lich::Common::ArgParser do
  let(:parser) { described_class.new }
  let(:tmpdir) { Dir.mktmpdir('arg-parser-test') }

  let(:simple_defs) do
    [
      [
        { name: 'target', regex: /\w+/, optional: false, description: 'Target name' },
      ]
    ]
  end

  let(:optional_defs) do
    [
      [
        { name: 'debug', regex: /^debug$/i, optional: true, description: 'Enable debug' },
        { name: 'verbose', regex: /^verbose$/i, optional: true, description: 'Verbose output' },
      ]
    ]
  end

  let(:options_defs) do
    [
      [
        { name: 'town', options: %w[crossing shard], optional: false, description: 'Town' },
      ]
    ]
  end

  before do
    stub_const('SCRIPT_DIR', tmpdir)
    allow(parser).to receive(:echo)
    allow(parser).to receive(:respond)
    FileUtils.mkdir_p(File.join(tmpdir, 'profiles'))
  end

  after { FileUtils.remove_entry(tmpdir) }

  describe '#parse_args' do
    context 'with a matching required argument' do
      it 'returns the matched arg in an OpenStruct' do
        allow(parser).to receive(:variable).and_return(['goblin', 'goblin'])
        result = parser.parse_args(simple_defs)
        expect(result.target).to eq('goblin')
      end
    end

    context 'with optional arguments' do
      it 'returns matched optional args' do
        allow(parser).to receive(:variable).and_return(['debug', 'debug'])
        result = parser.parse_args(optional_defs)
        expect(result.debug).to eq('debug')
        expect(result.verbose).to be_nil
      end

      it 'returns with no args provided (all optional)' do
        allow(parser).to receive(:variable).and_return([nil])
        result = parser.parse_args(optional_defs)
        expect(result.debug).to be_nil
      end
    end

    context 'with options-based definitions' do
      it 'matches against options list' do
        allow(parser).to receive(:variable).and_return(['crossing', 'crossing'])
        result = parser.parse_args(options_defs)
        expect(result.town).to eq('crossing')
      end
    end

    context 'with help argument' do
      it 'calls display_args and exits' do
        allow(parser).to receive(:variable).and_return(['help', 'help'])
        allow(parser).to receive(:exit)
        expect(parser).to receive(:display_args)
        parser.parse_args(simple_defs)
      end
    end

    context 'with flex_args' do
      it 'captures extra args in flex' do
        allow(parser).to receive(:variable).and_return(['goblin extra1', 'goblin', 'extra1'])
        allow(parser).to receive(:checkname).and_return('TestChar')
        result = parser.parse_args(simple_defs, true)
        expect(result.target).to eq('goblin')
        expect(result.flex).to eq(['extra1'])
      end
    end

    context 'with no match' do
      it 'calls display_args and exits' do
        allow(parser).to receive(:variable).and_return([nil])
        allow(parser).to receive(:exit)
        expect(parser).to receive(:display_args)
        parser.parse_args(simple_defs)
      end
    end
  end

  describe '#display_args' do
    let(:script_mock) { OpenStruct.new(name: 'test-script') }

    before do
      allow(Script).to receive(:current).and_return(script_mock)
    end

    it 'outputs script call format' do
      expect(parser).to receive(:respond).with(/;test-script/).at_least(:once)
      parser.display_args(simple_defs)
    end

    it 'skips display for bootstrap script' do
      allow(Script).to receive(:current).and_return(OpenStruct.new(name: 'bootstrap'))
      expect(parser).not_to receive(:respond).with(/;bootstrap/)
      parser.display_args(simple_defs)
    end
  end
end
