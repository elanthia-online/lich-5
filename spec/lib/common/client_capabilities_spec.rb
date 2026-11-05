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
    @saved = [described_class.launch_capabilities, described_class.launch_feeds, $frontend]
  end

  after do
    client.close rescue nil
    described_class.launch_capabilities, described_class.launch_feeds, $frontend = @saved
    # A real declare hands the client to the script list feed, which may
    # start its thread (a streams session gets the window by default). Stop
    # it so it cannot outlive this example.
    Lich::Common::ScriptListFeed.reset!
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

  # Feeds (script_list) are resolved apart from the rewrites, so a client can
  # ask for one without restating, or losing, the rewrite set it gets now.
  describe 'feeds' do
    before { allow(Lich::Common::ScriptListFeed).to receive(:client_ready) }

    describe '.parse_all' do
      it 'splits rewrites, feeds and unknown names' do
        expect(described_class.parse_all('script_list Room_Element sparkles'))
          .to eq([[:room_element], [:script_list], ['sparkles']])
      end
    end

    describe '.parse' do
      it 'returns the rewrites only, and does not report a feed as unknown' do
        expect(described_class.parse('script_list game_links')).to eq([[:game_links], []])
      end
    end

    describe '.declare' do
      it 'leaves the rewrites alone when the line names only a feed' do
        $frontend = 'saga'
        described_class.declare(client, "SET_FRONTEND_CAPS script_list\n")
        expect(client.declared_capabilities).to be_nil
        expect(client.declared_feeds).to eq([:script_list])
        expect(described_class.group([client])).to eq({ %i[room_element game_links double_bold] => [client] })
      end

      it 'keeps an earlier rewrite declaration when a later line names only a feed' do
        described_class.declare(client, "SET_FRONTEND_CAPS game_links\n")
        described_class.declare(client, "SET_FRONTEND_CAPS script_list\n")
        expect(client.declared_capabilities).to eq([:game_links])
        expect(client.declared_feeds).to eq([:script_list])
      end

      it 'keeps the feeds when a later line names only rewrites' do
        described_class.declare(client, "SET_FRONTEND_CAPS script_list\n")
        described_class.declare(client, "SET_FRONTEND_CAPS room_element\n")
        expect(client.declared_capabilities).to eq([:room_element])
        expect(client.declared_feeds).to eq([:script_list])
      end

      it 'sets both from one line' do
        described_class.declare(client, "SET_FRONTEND_CAPS script_list double_bold\n")
        expect(client.declared_capabilities).to eq([:double_bold])
        expect(client.declared_feeds).to eq([:script_list])
      end

      it 'clears both on a bare line, as before feeds existed for the rewrites' do
        described_class.declare(client, "SET_FRONTEND_CAPS script_list game_links\n")
        described_class.declare(client, "SET_FRONTEND_CAPS\n")
        expect(client.declared_capabilities).to eq([])
        expect(client.declared_feeds).to eq([])
      end

      it 'tells the feed after storing the declaration' do
        described_class.declare(client, "SET_FRONTEND_CAPS script_list\n")
        expect(Lich::Common::ScriptListFeed).to have_received(:client_ready).with(client)
      end

      it 'does not tell the feed about a line that is not a declaration' do
        described_class.declare(client, "look\n")
        expect(Lich::Common::ScriptListFeed).not_to have_received(:client_ready)
      end
    end

    describe '.apply_launch_list' do
      it 'leaves the catalog rewrites in place for a list of feeds alone' do
        $frontend = 'saga'
        expect(described_class.apply_launch_list('script_list')).to eq([])
        expect(described_class.launch_capabilities).to be_nil
        expect(described_class.session_default).to eq(%i[room_element game_links double_bold])
        expect(described_class.session_feeds).to eq([:script_list])
      end

      it 'sets both from a mixed list and returns the unknown names' do
        expect(described_class.apply_launch_list('game_links,script_list,sparkles')).to eq(['sparkles'])
        expect(described_class.launch_capabilities).to eq([:game_links])
        expect(described_class.launch_feeds).to eq([:script_list])
      end

      it 'gives the empty set for both from an empty list, as before for the rewrites' do
        described_class.apply_launch_list('')
        expect(described_class.launch_capabilities).to eq([])
        expect(described_class.launch_feeds).to eq([])
      end
    end

    describe '.feeds_for' do
      it 'is what the client asked for, else the session feeds' do
        $frontend = 'genie'
        expect(described_class.feeds_for(client)).to eq([])
        described_class.launch_feeds = [:script_list]
        expect(described_class.feeds_for(client)).to eq([:script_list])
        client.declared_feeds = []
        expect(described_class.feeds_for(client)).to eq([])
      end

      # The stream window follows the streams capability (ScriptListFeed);
      # the only feed is the data element, which no catalog entry has.
      it 'gives no built-in front end a feed by default' do
        %w[saga stormfront wrayth genie profanity frostbite wizard avalon].each do |frontend|
          expect(described_class.session_feeds(frontend)).to eq([])
        end
      end

      it 'does not know script_window: the window is not a capability' do
        expect(described_class.parse_all('script_window')).to eq([[], [], ['script_window']])
      end

      it 'honours a GSL session client\'s own feeds' do
        $frontend = 'wizard'
        client.declared_feeds = [:script_list]
        expect(described_class.feeds_for(client)).to eq([:script_list])
      end
    end
  end
end
