# frozen_string_literal: true

require 'rspec'

# Mock Lich module before requiring the file
module Lich
  module Common
    module Authentication
    end
  end
end unless defined?(Lich::Common::Authentication)

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
