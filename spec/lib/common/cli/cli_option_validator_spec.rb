# frozen_string_literal: true

require 'stringio'

require_relative '../../../spec_helper'
require_relative '../../../../lib/common/cli/cli_option_validator'

RSpec.describe Lich::Common::CLI::CliOptionValidator do
  around do |example|
    original_stdout = $stdout
    $stdout = StringIO.new
    example.run
    $stdout = original_stdout
  end

  describe '.extract_flag_value' do
    it 'returns nil when the flag is not present' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG', 'password'])

      value = described_class.extract_flag_value('--frontend', usage: 'usage')

      expect(value).to be_nil
    end

    it 'returns the value when the flag is present with no allow-list' do
      stub_const('ARGV', ['--frontend', 'wizard'])

      value = described_class.extract_flag_value('--frontend', usage: 'usage')

      expect(value).to eq('wizard')
    end

    it 'returns the value when it is present in the allow-list' do
      stub_const('ARGV', ['--game-code', 'DR'])

      value = described_class.extract_flag_value('--game-code', usage: 'usage', valid_values: %w[DR GS3])

      expect(value).to eq('DR')
    end

    it 'exits 1 when the flag is the last argument' do
      stub_const('ARGV', ['--frontend'])

      expect { described_class.extract_flag_value('--frontend', usage: 'usage') }.to raise_error(SystemExit)
    end

    it 'exits 1 when the flag is followed by another flag' do
      stub_const('ARGV', ['--frontend', '--game-code'])

      expect { described_class.extract_flag_value('--frontend', usage: 'usage') }.to raise_error(SystemExit)
    end

    it 'exits 1 when the value is not in the allow-list' do
      stub_const('ARGV', ['--game-code', 'ZZ'])

      expect {
        described_class.extract_flag_value('--game-code', usage: 'usage', valid_values: %w[DR GS3])
      }.to raise_error(SystemExit)
    end
  end
end
