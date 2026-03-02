# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require 'yaml'
require 'fileutils'

# Mock dependencies before requiring
DATA_DIR = Dir.mktmpdir unless defined?(DATA_DIR)

module Lich
  def self.log(_message)
    # no-op for tests
  end
end unless defined?(Lich)

# Mock the required modules - all with guards to prevent overwriting real implementations
module Lich
  module Common
    module Authentication
      module EntryStore
        def self.yaml_file_path(data_dir)
          File.join(data_dir, 'entry.yaml')
        end
      end unless defined?(Lich::Common::Authentication::EntryStore)

      module CLIPassword
        def self.validate_master_password_available
          true
        end
      end unless defined?(Lich::Common::Authentication::CLIPassword)

      module LoginHelpers
        def self.symbolize_keys(hash)
          hash
        end

        def self.find_character_by_name_game_and_frontend(*_args)
          []
        end

        def self.select_best_fit(*_args)
          nil
        end
      end unless defined?(Lich::Common::Authentication::LoginHelpers)

      # Only define stub authenticate if not already defined
      unless respond_to?(:authenticate)
        def self.authenticate(*_args)
          { 'key' => 'test123' }
        end
      end

      module LaunchData
        def self.prepare(*_args)
          ['GAME=GS3']
        end
      end unless defined?(Lich::Common::Authentication::LaunchData)
    end
  end
end

require_relative '../../../../lib/common/authentication/cli'

RSpec.describe Lich::Common::Authentication::CLI do
  let(:data_dir) { Dir.mktmpdir }
  let(:yaml_file) { File.join(data_dir, 'entry.yaml') }

  after do
    FileUtils.rm_rf(data_dir) if File.exist?(data_dir)
  end

  describe '.execute' do
    context 'with missing character name' do
      it 'returns nil when character_name is nil' do
        allow(Lich).to receive(:log)

        result = described_class.execute(nil, data_dir: data_dir)

        expect(result).to be_nil
        expect(Lich).to have_received(:log).with(/Character name is required/)
      end

      it 'returns nil when character_name is empty' do
        allow(Lich).to receive(:log)

        result = described_class.execute('', data_dir: data_dir)

        expect(result).to be_nil
        expect(Lich).to have_received(:log).with(/Character name is required/)
      end
    end

    context 'with missing YAML file' do
      it 'returns nil when entry.yaml does not exist' do
        allow(Lich).to receive(:log)
        allow(Lich::Common::Authentication::CLIPassword).to receive(:validate_master_password_available).and_return(true)

        result = described_class.execute('TestChar', data_dir: data_dir)

        expect(result).to be_nil
        expect(Lich).to have_received(:log).with(/No saved entries YAML file found/)
      end
    end

    context 'with master password validation failure' do
      it 'returns nil when master password validation fails' do
        allow(Lich).to receive(:log)
        allow(Lich::Common::Authentication::CLIPassword).to receive(:validate_master_password_available).and_return(false)

        result = described_class.execute('TestChar', data_dir: data_dir)

        expect(result).to be_nil
        expect(Lich).to have_received(:log).with(/Master password validation failed/)
      end
    end

    context 'with valid YAML file' do
      before do
        yaml_data = {
          'accounts' => {
            'TESTUSER' => {
              'password'   => 'testpass',
              'characters' => [
                { 'char_name' => 'TestChar', 'game_code' => 'GS3', 'frontend' => 'stormfront' }
              ]
            }
          }
        }
        File.write(yaml_file, yaml_data.to_yaml)
      end

      it 'returns nil when no matching character is found' do
        allow(Lich).to receive(:log)
        allow(Lich::Common::Authentication::CLIPassword).to receive(:validate_master_password_available).and_return(true)
        allow(Lich::Common::Authentication::LoginHelpers).to receive(:symbolize_keys).and_return({})
        allow(Lich::Common::Authentication::LoginHelpers).to receive(:find_character_by_name_game_and_frontend).and_return([])

        result = described_class.execute('NonExistent', data_dir: data_dir)

        expect(result).to be_nil
        expect(Lich).to have_received(:log).with(/No matching character found/)
      end
    end

    context 'with YAML load error' do
      before do
        File.write(yaml_file, "invalid: yaml: content: [")
      end

      it 'returns nil and logs error' do
        allow(Lich).to receive(:log)
        allow(Lich::Common::Authentication::CLIPassword).to receive(:validate_master_password_available).and_return(true)

        result = described_class.execute('TestChar', data_dir: data_dir)

        expect(result).to be_nil
        expect(Lich).to have_received(:log).with(/Failed to load YAML data/)
      end
    end
  end
end
