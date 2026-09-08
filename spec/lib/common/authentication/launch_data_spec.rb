# frozen_string_literal: true

# NOTE: This spec intentionally does NOT require spec_helper.
# It tests LaunchData parsing in isolation to verify the data structure
# is correctly populated from launch parameters without game dependencies.

require 'rspec'

# Mock Lich module before requiring the file
module Lich
  module Common
    module Authentication
    end
  end
end unless defined?(Lich::Common::Authentication)

require_relative '../../../../lib/common/front-end'
require_relative '../../../../lib/common/authentication/launch_data'

RSpec.describe Lich::Common::Authentication::LaunchData do
  describe '.prepare' do
    let(:auth_data) do
      {
        'key'          => 'abc123',
        'server'       => 'eaccess.play.net',
        'gamecode'     => 'GS3',
        'gameport'     => '7900',
        'gamehost'     => 'gamer.simutronics.com',
        'game'         => 'STORM',
        'gamefile'     => 'STORMFRONT.EXE',
        'fullgamename' => 'GemStone IV'
      }
    end

    context 'with stormfront frontend' do
      it 'returns launch data unchanged' do
        result = described_class.prepare(auth_data, 'stormfront')

        expect(result).to include('KEY=abc123')
        expect(result).to include('GAMECODE=GS3')
        expect(result).to include('GAME=STORM')
        expect(result).to include('GAMEFILE=STORMFRONT.EXE')
        expect(result).to include('FRONTEND=stormfront')
      end
    end

    context 'without a frontend selection' do
      it 'keeps legacy launch data free of an empty frontend identity' do
        result = described_class.prepare(auth_data, nil)

        expect(result).not_to include(a_string_starting_with('FRONTEND='))
        expect(result).to include('GAME=STORM')
      end
    end

    context 'with wizard frontend' do
      it 'modifies launch data for wizard' do
        result = described_class.prepare(auth_data, 'wizard')

        expect(result).to include('GAMEFILE=WIZARD.EXE')
        expect(result).to include('GAME=WIZ')
        expect(result).to include('FULLGAMENAME=Wizard Front End')
      end
    end

    context 'with avalon frontend' do
      it 'modifies game to AVALON' do
        result = described_class.prepare(auth_data, 'avalon')

        expect(result).to include('GAME=AVALON')
        expect(result).not_to include('GAME=STORM')
      end
    end

    context 'with saga frontend' do
      it 'modifies game to SAGA' do
        result = described_class.prepare(auth_data, 'saga')

        expect(result).to include('GAME=SAGA')
        expect(result).not_to include('GAME=STORM')
      end
    end

    context 'with suks frontend' do
      it 'modifies launch data for suks' do
        result = described_class.prepare(auth_data, 'suks')

        expect(result).to include('GAMEFILE=WIZARD.EXE')
        expect(result).to include('GAME=SUKS')
      end
    end

    context 'with custom launch' do
      it 'adds CUSTOMLAUNCH to launch data' do
        result = described_class.prepare(auth_data, 'stormfront', '/usr/bin/warlock')

        expect(result).to include('CUSTOMLAUNCH=/usr/bin/warlock')
      end

      it 'adds CUSTOMLAUNCHDIR if provided' do
        result = described_class.prepare(auth_data, 'stormfront', '/usr/bin/warlock', '/home/user')

        expect(result).to include('CUSTOMLAUNCH=/usr/bin/warlock')
        expect(result).to include('CUSTOMLAUNCHDIR=/home/user')
      end

      it 'does not add CUSTOMLAUNCHDIR if custom_launch_dir is nil' do
        result = described_class.prepare(auth_data, 'stormfront', '/usr/bin/warlock', nil)

        expect(result).to include('CUSTOMLAUNCH=/usr/bin/warlock')
        expect(result.any? { |line| line.start_with?('CUSTOMLAUNCHDIR=') }).to be false
      end

      it 'prefers a character-specific custom launch over a registered frontend command' do
        allow(Lich::Common::Frontend).to receive(:definition_for).with('vellum').and_return(
          id: 'vellum',
          capabilities: [:xml],
          metadata: {
            launcher_adapter: :custom,
            launch_command: '/opt/vellum',
            launch_directory: '/opt'
          }
        )

        result = described_class.prepare(auth_data, 'vellum', '/home/me/client %port% %key%', '/home/me')

        expect(result).to include('FRONTEND=vellum')
        expect(result).to include('CUSTOMLAUNCH=/home/me/client %port% %key%')
        expect(result).to include('CUSTOMLAUNCHDIR=/home/me')
      end

      it 'replaces stale authentication launch fields with explicit custom launch values' do
        stale_auth_data = auth_data.merge(
          customlaunch: '/old/client',
          customlaunchdir: '/old',
          customlaunchargv: '["/old/client"]'
        )

        result = described_class.prepare(stale_auth_data, 'stormfront', '/new/client', '/new')

        expect(result.grep(/\ACUSTOMLAUNCH=/)).to eq(['CUSTOMLAUNCH=/new/client'])
        expect(result.grep(/\ACUSTOMLAUNCHDIR=/)).to eq(['CUSTOMLAUNCHDIR=/new'])
        expect(result.grep(/\ACUSTOMLAUNCHARGV=/)).to be_empty
      end
    end

    context 'with a registered custom frontend' do
      it 'does not accept process-local argv instructions from authentication data' do
        result = described_class.prepare(auth_data.merge(customlaunchargv: '["untrusted.exe"]'), 'stormfront')
        expect(result.grep(/\ACUSTOMLAUNCHARGV=/)).to be_empty
      end

      it 'carries Windows argv as process-local structured data without flattening arguments' do
        allow(Lich::Common::Frontend).to receive(:definition_for).with('local-client').and_return(
          id: 'local-client', metadata: { launcher_adapter: :custom, launch_command: '"C:\\Client Files\\client.exe"',
                                         additional_arguments: ['', '  profile  ', '--port=%port%'] }
        )
        allow(Lich::Common::Frontend).to receive(:platform_key).and_return(:windows)
        result = described_class.prepare(auth_data, 'local-client')
        argv_field = result.find { |line| line.start_with?('CUSTOMLAUNCHARGV=') }
        expect(JSON.parse(argv_field.split('=', 2).last)).to eq(['C:\\Client Files\\client.exe', '', '  profile  ', '--port=%port%'])
        expect(result.grep(/\ACUSTOMLAUNCH=/)).to be_empty
        expect(Lich::Common::FrontendLauncher.native_session_data(result).grep(/\ACUSTOMLAUNCHARGV=/)).to be_empty
      end

      it 'derives custom launch data and the stable frontend identity from its definition' do
        allow(Lich::Common::Frontend).to receive(:definition_for).with('vellum').and_return(
          id: 'vellum',
          capabilities: %i[xml streams],
          metadata: {
            launcher_adapter: :custom,
            launch_command: '/opt/vellum',
            launch_directory: '/opt/vellum-home',
            additional_arguments: ['--connect=%port%', '--key=%key%']
          }
        )

        result = described_class.prepare(auth_data, 'vellum')

        expect(result).to include('FRONTEND=vellum')
        expect(result).to include('CUSTOMLAUNCH=/opt/vellum --connect=%port% --key=%key%')
        expect(result).to include('CUSTOMLAUNCHDIR=/opt/vellum-home')
      end
    end
  end

  describe '.create_entry' do
    it 'creates a properly formatted entry hash' do
      result = described_class.create_entry(
        char_name: 'TestChar',
        game_code: 'GS3',
        game_name: 'GemStone IV',
        user_id: 'testuser',
        password: 'testpass',
        frontend: 'stormfront'
      )

      expect(result[:char_name]).to eq('TestChar')
      expect(result[:game_code]).to eq('GS3')
      expect(result[:game_name]).to eq('GemStone IV')
      expect(result[:user_id]).to eq('testuser')
      expect(result[:password]).to eq('testpass')
      expect(result[:frontend]).to eq('stormfront')
      expect(result[:custom_launch]).to be_nil
      expect(result[:custom_launch_dir]).to be_nil
    end

    it 'includes custom launch parameters when provided' do
      result = described_class.create_entry(
        char_name: 'TestChar',
        game_code: 'GS3',
        game_name: 'GemStone IV',
        user_id: 'testuser',
        password: 'testpass',
        frontend: 'stormfront',
        custom_launch: '/usr/bin/warlock',
        custom_launch_dir: '/home/user'
      )

      expect(result[:custom_launch]).to eq('/usr/bin/warlock')
      expect(result[:custom_launch_dir]).to eq('/home/user')
    end
  end
end
