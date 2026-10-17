# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/class_exts/synchronizedsocket'
require 'common/client_capabilities'
require_relative '../../../lib/common/front-end'

RSpec.describe Lich::Common::ClientCapabilities do
  let(:delegate) { instance_double('raw_client_socket', closed?: false, close: nil, write: nil) }
  let(:client) { Lich::Common::SynchronizedSocket.new(delegate, role: :detachable) }

  before do
    allow(Lich).to receive(:log)
    @saved = [described_class.launch_capabilities, $frontend]
  end

  after do
    client.close rescue nil
    described_class.launch_capabilities, $frontend = @saved
  end

  describe '.declaration?' do
    ['SET_FRONTEND_CAPS room_element', "SET_FRONTEND_CAPS room_element game_links\r\n",
     "SET_FRONTEND_CAPS\n", 'SET_FRONTEND_CAPS', "SET_FRONTEND_CAPS \t \n"].each do |line|
      it "is true for #{line.inspect}" do
        expect(described_class.declaration?(line)).to be true
      end
    end

    # Anything else a client sends goes to the game as before.
    ['set_frontend_caps room_element', 'SET_FRONTEND_CAPSX room_element', ' SET_FRONTEND_CAPS room_element',
     'say SET_FRONTEND_CAPS room_element', "<c>SET_FRONTEND_CAPS room_element\n", 'SET_FRONTEND_PID 1234',
     "SET_FRONTEND_CAPS a\nlook", '', nil].each do |line|
      it "is false for #{line.inspect}" do
        expect(described_class.declaration?(line)).to be false
      end
    end
  end

  describe '.parse' do
    it 'returns the known names in canonical order, whatever order and case they came in' do
      expect(described_class.parse('Double_Bold room_element')).to eq([%i[room_element double_bold], []])
    end

    it 'splits on commas as well as spaces and tabs, and drops duplicates' do
      expect(described_class.parse("game_links,room_element\tgame_links ,")).to eq([%i[room_element game_links], []])
    end

    it 'keeps the unknown names apart' do
      expect(described_class.parse('room_element xml future_thing')).to eq([[:room_element], %w[xml future_thing]])
    end

    it 'gives the empty set for nothing' do
      expect(described_class.parse(nil)).to eq([[], []])
      expect(described_class.parse('')).to eq([[], []])
    end

    it 'returns a frozen set' do
      expect(described_class.parse('game_links').first).to be_frozen
    end
  end

  describe '.declare' do
    it 'stores the declared set on the client and consumes the line' do
      expect(described_class.declare(client, "SET_FRONTEND_CAPS game_links double_bold\r\n")).to be true
      expect(client.declared_capabilities).to eq(%i[game_links double_bold])
    end

    it 'replaces an earlier declaration' do
      described_class.declare(client, 'SET_FRONTEND_CAPS room_element game_links double_bold')
      described_class.declare(client, 'SET_FRONTEND_CAPS double_bold')
      expect(client.declared_capabilities).to eq([:double_bold])
    end

    # A declaration with nothing Lich knows still counts: the client asked
    # for the legacy stream, it did not fall back to the frontend's set.
    it 'declares the empty set for a bare line or only unknown names' do
      described_class.declare(client, "SET_FRONTEND_CAPS\n")
      expect(client.declared_capabilities).to eq([])
      described_class.declare(client, 'SET_FRONTEND_CAPS none')
      expect(client.declared_capabilities).to eq([])
    end

    it 'logs what was declared and what was ignored' do
      described_class.declare(client, 'SET_FRONTEND_CAPS game_links sparkles')
      expect(Lich).to have_received(:log).with('info: client declared capabilities [game_links] (ignored unknown: sparkles)')
    end

    it 'leaves the client alone and returns false for any other line' do
      expect(described_class.declare(client, "look\n")).to be false
      expect(client.declared_capabilities).to be_nil
    end

    it 'consumes a declaration from a client that cannot hold one' do
      expect(described_class.declare(Object.new, 'SET_FRONTEND_CAPS game_links')).to be true
      expect(described_class.declare(nil, 'SET_FRONTEND_CAPS game_links')).to be true
    end
  end

  describe '.session_default' do
    it "is the catalog's set for the session's frontend" do
      expect(described_class.session_default('saga')).to eq(%i[room_element game_links double_bold])
      expect(described_class.session_default('genie')).to eq([])
      expect(described_class.session_default('profanity')).to eq([])
      expect(described_class.session_default(nil)).to eq([])
    end

    it 'is the launch flag set instead, when one was given' do
      described_class.launch_capabilities = %i[double_bold game_links]
      expect(described_class.session_default('genie')).to eq(%i[game_links double_bold])
      described_class.launch_capabilities = []
      expect(described_class.session_default('saga')).to eq([])
    end
  end

  describe '.group' do
    let(:other_delegate) { instance_double('raw_client_socket', closed?: false, close: nil, write: nil) }
    let(:other) { Lich::Common::SynchronizedSocket.new(other_delegate, role: :detachable) }

    after { other.close rescue nil }

    it 'puts clients that declared nothing in the session set' do
      $frontend = 'genie'
      expect(described_class.group([client, other])).to eq({ [] => [client, other] })
    end

    it 'gives a declaring client its own set, ahead of the launch flag' do
      $frontend = 'genie'
      described_class.launch_capabilities = [:double_bold]
      client.declared_capabilities = %i[room_element game_links double_bold]
      expect(described_class.group([client, other])).to eq(
        { %i[room_element game_links double_bold] => [client], [:double_bold] => [other] }
      )
    end

    it 'groups clients with the same declared set together' do
      $frontend = 'saga'
      client.declared_capabilities = [:game_links]
      other.declared_capabilities = [:game_links]
      expect(described_class.group([client, other])).to eq({ [:game_links] => [client, other] })
    end

    # Wizard's GSL conversion keeps state across lines, so it runs once.
    it 'ignores declarations in a GSL session' do
      $frontend = 'wizard'
      client.declared_capabilities = %i[room_element game_links double_bold]
      expect(described_class.group([client, other])).to eq({ [] => [client, other] })
    end

    it 'returns the session set with no clients, so the line is still processed' do
      $frontend = 'saga'
      expect(described_class.group([])).to eq({ %i[room_element game_links double_bold] => [] })
    end

    it 'treats a client object without the accessor as undeclared' do
      $frontend = 'genie'
      plain = Object.new
      expect(described_class.group([plain])).to eq({ [] => [plain] })
    end
  end
end
