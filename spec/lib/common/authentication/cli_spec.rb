# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require 'yaml'
require 'fileutils'

# Load login_spec_helper FIRST - it sets up Lich::Util and other mocks
# before any source files are required
require_relative '../../../login_spec_helper'

# Now require the source file (after mocks are in place)
require_relative '../../../../lib/common/authentication/cli'

# Extend mocks with additional methods needed for CLI tests
module Lich
  module Common
    module Authentication
      module CLIPassword
        def self.validate_master_password_available
          true
        end
      end unless defined?(Lich::Common::Authentication::CLIPassword)

      module LoginHelpers
        class << self
          def symbolize_keys(hash)
            hash
          end

          def find_character_by_name_game_and_frontend(*_args)
            []
          end

          def select_best_fit(*_args)
            nil
          end
        end
      end unless defined?(Lich::Common::Authentication::LoginHelpers)

      module LaunchData
        def self.prepare(*_args)
          ['GAME=GS3']
        end
      end unless defined?(Lich::Common::Authentication::LaunchData)
    end
  end
end

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

    context 'with successful authentication' do
      let(:char_entry) do
        {
          username: 'TESTUSER',
          password: 'encrypted-pass',
          char_name: 'TestChar',
          game_code: 'GS3',
          frontend: 'stormfront',
          custom_launch: nil,
          custom_launch_dir: nil
        }
      end

      before do
        File.write(yaml_file, { 'accounts' => {} }.to_yaml)

        allow(Lich).to receive(:log)
        allow(Lich::Common::Authentication::CLIPassword).to receive(:validate_master_password_available).and_return(true)
        allow(Lich::Common::Authentication::LoginHelpers).to receive(:symbolize_keys).and_return({})
        allow(Lich::Common::Authentication::LoginHelpers).to receive(:find_character_by_name_game_and_frontend).and_return([char_entry])
        allow(Lich::Common::Authentication::LoginHelpers).to receive(:select_best_fit).and_return(char_entry)
        allow(Lich::Common::Authentication::EntryStore).to receive(:decrypt_password).and_return('plain-pass')
        allow(Lich::Common::Authentication).to receive(:authenticate).and_return('ok' => true)
        allow(Lich::Common::Authentication::LaunchData).to receive(:prepare).and_return(['GAME=GS3'])
      end

      it 'does not emit Hello World when cli_hello_world_demo is disabled' do
        allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:cli_hello_world_demo).and_return(false)
        expect(described_class).not_to receive(:puts).with('Hello World')

        result = described_class.execute('TestChar', data_dir: data_dir)

        expect(result).to eq(['GAME=GS3'])
        expect(Lich).not_to have_received(:log).with('info: Hello World')
      end

      it 'emits Hello World when cli_hello_world_demo is enabled' do
        allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:cli_hello_world_demo).and_return(true)
        expect(described_class).to receive(:puts).with('Hello World')

        result = described_class.execute('TestChar', data_dir: data_dir)

        expect(result).to eq(['GAME=GS3'])
        expect(Lich).to have_received(:log).with('info: Hello World')
      end
    end
  end
end
