# frozen_string_literal: true

require_relative '../spec_helper'
require 'socket'
require 'timeout'

# Load production code
require "ox"
require "common/class_exts/synchronizedsocket"
require "common/detachable_client_registry"
require "common/sharedbuffer"
require "common/shutdown_coordinator"
require "common/xmlparser"
require "games"
require "gemstone/wounds"
require "gemstone/scars"
require "gemstone/gift"

RSpec.describe Lich::GameBase do
  describe Lich::GameBase::XMLCleaner do
    it 'cleans nested single quotes' do
      # Use +@ to unfreeze string for in-place modification
      input = +"<link id='2' value='Ever wondered about the time you've spent in Elanthia?  Check the PLAYED verb!' cmd='played' echo='played' />"
      output = Lich::GameBase::XMLCleaner.clean_nested_quotes(input)
      expect(output).to include("&apos;ve")
    end

    it 'cleans nested double quotes' do
      # Use +@ to unfreeze string for in-place modification
      input = +'<subtitle=" - [Avlea\'s Bows, "The Straight and Arrow"]">'
      output = Lich::GameBase::XMLCleaner.clean_nested_quotes(input)
      expect(output).to include('&quot;The')
    end

    it 'removes bell characters' do
      # Use +@ to unfreeze string for in-place modification
      input = +"\aYOU HAVE BEEN IDLE TOO LONG. PLEASE RESPOND.\a\n"
      output = Lich::GameBase::XMLCleaner.fix_invalid_characters(input)
      expect(output).not_to include("\a")
    end

    it 'fixes open-ended XML tags' do
      # Use +@ to unfreeze string for in-place modification
      input = +"<component id='room objs'>  You also see a granite altar with several candles and a water jug on it, and a granite font.\r\n"
      output = Lich::GameBase::XMLCleaner.fix_xml_tags(input)
      expect(output).to include("</component>")
    end

    it 'removes dangling closing tags' do
      # Use +@ to unfreeze string for in-place modification
      input = +"</component>\r\n"
      output = Lich::GameBase::XMLCleaner.fix_xml_tags(input)
      expect(output).to eq("")
    end
  end

  describe Lich::GameBase::Game do
    before do
      allow(Lich).to receive(:log)
      allow(XMLData).to receive(:tag_start)
      allow(XMLData).to receive(:tag_end)
      allow(XMLData).to receive(:text)
    end

    it 'maps stream desync errors to shutdown reason' do
      error = Lich::GameBase::GameStreamDesyncError.new('Missing end tag')

      expect(described_class.shutdown_reason_for_thread_exit(error)).to eq(:game_stream_desync)
    end

    it 'returns a read timeout sentinel when the game socket has no readable data' do
      socket = instance_double(TCPSocket)
      described_class.instance_variable_set(:@socket, socket)

      allow(IO).to receive(:select).with([socket], nil, nil, 0.01).and_return(nil)
      allow(socket).to receive(:gets)

      expect(described_class.read_server_string(read_timeout: 0.01)).to equal(Lich::GameBase::Game::READ_TIMEOUT)
      expect(socket).not_to have_received(:gets)
    end

    it 'reads a game line when the socket is readable' do
      socket = instance_double(TCPSocket)
      described_class.instance_variable_set(:@socket, socket)

      allow(IO).to receive(:select).with([socket], nil, nil, 0.01).and_return([[socket], [], []])
      allow(socket).to receive(:gets).and_return("<prompt/>\r\n")

      expect(described_class.read_server_string(read_timeout: 0.01)).to eq("<prompt/>\r\n")
    end

    it 'preserves nil reads as game EOF after the socket becomes readable' do
      socket = instance_double(TCPSocket)
      described_class.instance_variable_set(:@socket, socket)

      allow(IO).to receive(:select).with([socket], nil, nil, 0.01).and_return([[socket], [], []])
      allow(socket).to receive(:gets).and_return(nil)

      expect(described_class.read_server_string(read_timeout: 0.01)).to be_nil
    end

    it 'handles connection reset as a recognized fatal disruption without a backtrace log' do
      error = Errno::ECONNRESET.new
      error.set_backtrace(['games.rb:1'])

      expect(described_class.handle_thread_error(error)).to be(false)
      expect(Lich).to have_received(:log).with(/info: server_thread: Errno::ECONNRESET:/)
      expect(Lich).to have_received(:log).with('info: connection error - will not retry')
      expect(Lich).not_to have_received(:log).with(/error: server_thread:.*\n\t/m)
      expect(Lich).not_to have_received(:log).with(/debug: server_thread backtrace:/)
    end

    it 'logs recognized disruption backtraces only when shutdown diagnostics are enabled' do
      error = Errno::ECONNRESET.new
      error.set_backtrace(['games.rb:1'])
      allow(ARGV).to receive(:include?).with('--debug').and_return(true)

      expect(described_class.handle_thread_error(error)).to be(false)
      expect(Lich).to have_received(:log).with("debug: server_thread backtrace: games.rb:1")
    end

    it 'handles repeated timeout as a recognized fatal disruption after threshold' do
      error = IO::TimeoutError.new('read timed out')

      expect(described_class.handle_thread_error(error)).to be(false)
      expect(Lich).to have_received(:log).with('info: server_thread: IO::TimeoutError: read timed out')
      expect(Lich).to have_received(:log).with('info: game timeout - will not retry')
      expect(described_class.shutdown_reason_for_thread_exit(error)).to eq(:game_timeout)
    end

    it 'reports total elapsed no-data time for consecutive read timeouts' do
      expect(described_class.total_read_timeout_seconds).to eq(300)
      expect(described_class.total_read_timeout_seconds(2)).to eq(200)
    end

    it 'keeps stream desync disruption logging to one line in the thread handler' do
      error = Lich::GameBase::GameStreamDesyncError.new("Missing end tag\nLine: 2")

      expect(described_class.handle_thread_error(error)).to be(false)
      expect(Lich).to have_received(:log).with('info: server_thread: GameStreamDesyncError: Missing end tag')
      expect(Lich).to have_received(:log).with('info: game stream desync detected - will not retry')
    end

    describe 'bounded parser queue' do
      before do
        Lich::Common::ShutdownCoordinator.reset!
        described_class.instance_variable_set(:@server_queue, SizedQueue.new(1))
      end

      after do
        described_class.thread&.kill
        described_class.instance_variable_set(:@socket, nil)
        described_class.initialize_buffers
        Lich::Common::ShutdownCoordinator.reset!
      end

      it 'raises instead of blocking or dropping input when full' do
        described_class.enqueue_server_string('first', 1.0)

        expect { described_class.enqueue_server_string('second', 2.0) }
          .to raise_error(Lich::GameBase::Game::ServerQueueOverflow)
      end

      it 'maps queue overflow to an unrecoverable shutdown' do
        error = Lich::GameBase::Game::ServerQueueOverflow.new('full')

        expect(described_class.handle_thread_error(error)).to be false
        expect(described_class.shutdown_reason_for_thread_exit(error)).to eq(:unrecoverable_game_thread_error)
      end

      it 'stops the session after an unexpected parser exception' do
        socket = instance_double(TCPSocket, close: nil)
        described_class.instance_variable_set(:@socket, socket)
        allow(described_class).to receive(:process_server_string).and_raise(RuntimeError, 'broken parser state')

        described_class.start_server_processor_thread
        described_class.server_queue << ['bad input', Process.clock_gettime(Process::CLOCK_MONOTONIC)]
        described_class.thread.join(1)

        expect(described_class.thread).not_to be_alive
        expect(socket).to have_received(:close)
        expect(Lich::Common::ShutdownCoordinator.reason).to eq(:unrecoverable_game_thread_error)
        expect(Lich::Common::ShutdownCoordinator.current.source).to eq('game_parser')
      end
    end
  end
end

RSpec.describe Lich::GameBase::GameInstance do
  describe Lich::GameBase::GameInstance::Base do
    let(:game_instance) { Lich::GameBase::GameInstance::Base.new }

    it 'initializes with default values' do
      expect(game_instance.combat_count).to eq(0)
      expect(game_instance.atmospherics).to eq(false)
    end

    it 'raises NotImplementedError for abstract methods' do
      expect { game_instance.clean_serverstring("test") }.to raise_error(NotImplementedError)
      expect { game_instance.handle_combat_tags("test") }.to raise_error(NotImplementedError)
      expect { game_instance.handle_atmospherics("test") }.to raise_error(NotImplementedError)
      expect { game_instance.get_documentation_url }.to raise_error(NotImplementedError)
      expect { game_instance.process_game_specific_data("test") }.to raise_error(NotImplementedError)
      expect { game_instance.modify_room_display("test", nil, nil) }.to raise_error(NotImplementedError)
      expect { game_instance.process_room_display("test") }.to raise_error(NotImplementedError)
    end
  end
end

RSpec.describe Lich::Gemstone::GameInstance do
  before do
    XMLData.reset
    XMLData.game = 'GS'
  end

  let(:game_instance) { Lich::Gemstone::GameInstance.new }

  describe '#clean_serverstring' do
    it 'fixes The Rift, Scatter issue' do
      # Use +@ to unfreeze string for in-place modification
      input = +"Some room description  <compDef id='room text'></compDef>"
      output = game_instance.clean_serverstring(input)
      expect(output).to include("<compDef id='room desc'>Some room description</compDef>")
    end

    it 'returns the string unchanged if no issues' do
      input = +"Normal string with no issues"
      output = game_instance.clean_serverstring(input)
      expect(output).to eq(input)
    end
  end

  describe '#handle_combat_tags' do
    it 'tracks combat count correctly' do
      # Use +@ to unfreeze strings for in-place modification
      input1 = +"Combat text<pushStream id=\"combat\" />more combat"
      game_instance.handle_combat_tags(input1)
      expect(game_instance.combat_count).to eq(1)

      # Check if combat tags are handled correctly
      input2 = +"End combat<prompt>prompt</prompt>"
      output2 = game_instance.handle_combat_tags(input2)
      expect(output2).to include("<popStream id=\"combat\" />")
      expect(game_instance.combat_count).to eq(0)
    end
  end

  describe '#handle_atmospherics' do
    it 'handles atmospherics correctly' do
      # Use +@ to unfreeze strings for in-place modification
      input1 = +"Some text<pushStream id=\"atmospherics\" />atmospheric text"
      game_instance.handle_atmospherics(input1)
      expect(game_instance.atmospherics).to be true

      # Check if the next string gets the popStream
      input2 = +"More text without popStream"
      output2 = game_instance.handle_atmospherics(input2)
      expect(output2).to include("<popStream id=\"atmospherics\" />")
      expect(game_instance.atmospherics).to be false
    end
  end

  describe '#get_documentation_url' do
    it 'returns the correct documentation URL for Gemstone' do
      expect(game_instance.get_documentation_url).to eq("https://gswiki.play.net/Lich:Software/Installation")
    end
  end

  describe '#modify_room_display' do
    it 'modifies room display correctly for Gemstone' do
      Lich.display_lichid = true
      Lich.display_uid = true

      # Use +@ to unfreeze string for in-place modification
      alt_string = +"[Test Room] (123)"

      result = game_instance.modify_room_display(alt_string)
      expect(result).to include(" - 1234]") # why 1234?
    end
  end
end

RSpec.describe Lich::DragonRealms::GameInstance do
  before do
    XMLData.reset
    XMLData.game = 'DR'
    XMLData.name = 'testing'
    XMLData.room_title = "[Test DR Room]"
  end

  let(:game_instance) { Lich::DragonRealms::GameInstance.new }

  describe '#clean_serverstring' do
    it 'removes superfluous tags' do
      # Use +@ to unfreeze string for in-place modification
      input = +"Some text<pushStream id=\"combat\" /><popStream id=\"combat\" />more text"
      output = game_instance.clean_serverstring(input)
      expect(output).to eq("Some textmore text")
    end

    it 'fixes combat wrapping components' do
      # Use +@ to unfreeze string for in-place modification
      input = +"Some text<pushStream id=\"combat\" /><component id='test'>content</component>"
      output = game_instance.clean_serverstring(input)
      expect(output).to include("<component id='test'>")
      expect(output).not_to include("<pushStream id=\"combat\" />")
    end
  end

  describe '#get_documentation_url' do
    it 'returns the correct documentation URL for DragonRealms' do
      expect(game_instance.get_documentation_url).to eq("https://github.com/elanthia-online/lich-5/wiki/Documentation-for-Installing-and-Upgrading-Lich")
    end
  end

  describe '#modify_room_display' do
    it 'modifies room display correctly for DragonRealms' do
      Lich.display_uid = true

      # Use +@ to unfreeze string for in-place modification
      alt_string = +"Room [Test Room] (**)"

      result = game_instance.modify_room_display(alt_string)
      expect(result).not_to include("(**)")
    end
  end

  describe '#process_room_display' do
    it 'adds DR-specific room number information' do
      Lich.display_lichid = true
      Lich.display_uid = true
      XMLData.room_id = 789
      # Frontend.client is mocked in spec_helper

      # Use +@ to unfreeze string for in-place modification
      alt_string = +"Room prompt"
      result = game_instance.process_room_display(alt_string)

      expect(result).to include("Room Number: 1234 - (u789)")
    end
  end
end

# Unit coverage for the shared formatting mixin, exercised on a throwaway host
# class so the helpers are tested in isolation from the game instances.
RSpec.describe Lich::GameBase::RoomFormatter do
  # The formatting helpers are private (they add no public surface to the game
  # instances). Re-publicize them on this throwaway host class so the unit
  # examples can drive each one directly instead of reaching through .send.
  let(:formatter) do
    Class.new do
      include Lich::GameBase::RoomFormatter
      public :room_mono?, :room_links?, :room_styled,
             :room_stringproc_entries, :room_exit_entries, :prepend_room_lines
    end.new
  end

  before do
    XMLData.reset
    XMLData.game = 'DR'
    Lich.display_lichid = false
    Lich.display_uid = false
    Lich.display_exits = false
    Lich.display_stringprocs = false
    Lich.display_room_links = false
    Lich.display_room_mono = false
    allow(Frontend).to receive(:supports_mono?).and_return(false)
  end

  # Reset the shared mock accessors so per-example toggles do not leak into other
  # describe blocks (the suite runs in random order).
  after do
    Lich.display_lichid = nil
    Lich.display_uid = nil
    Lich.display_exits = nil
    Lich.display_stringprocs = nil
    Lich.display_room_links = nil
    Lich.display_room_mono = nil
  end

  describe '#room_styled' do
    it 'wraps the body in mono tags when mono is on and the frontend supports it' do
      Lich.display_room_mono = true
      allow(Frontend).to receive(:supports_mono?).and_return(true)

      expect(formatter.room_styled('Room Exits: go door'))
        .to eq('<output class="mono"/>Room Exits: go door<output class=""/>')
    end

    it 'returns the body unchanged when mono is off' do
      Lich.display_room_mono = false

      expect(formatter.room_styled('Room Exits: go door')).to eq('Room Exits: go door')
    end

    it 'returns the body unchanged when mono is on but the frontend lacks mono support' do
      Lich.display_room_mono = true
      allow(Frontend).to receive(:supports_mono?).and_return(false)

      expect(formatter.room_styled('Room Exits: go door')).to eq('Room Exits: go door')
    end
  end

  describe '#room_exit_entries' do
    before do
      map = double('map', wayto: { 1 => 'north', 2 => 'go arched door' }, timeto: {}, id: 100)
      allow(Map).to receive(:current).and_return(map)
    end

    it 'returns an empty array when the exits toggle is off' do
      Lich.display_exits = false

      expect(formatter.room_exit_entries).to eq([])
    end

    it 'renders clickable command links when links are on' do
      Lich.display_exits = true
      Lich.display_room_links = true

      expect(formatter.room_exit_entries).to eq(["<d cmd='go arched door'>go arched door</d>"])
    end

    it 'renders plain text and no <d> tags when links are off' do
      Lich.display_exits = true
      Lich.display_room_links = false

      expect(formatter.room_exit_entries).to eq(['go arched door'])
    end

    it 'filters out obvious compass/up/down/out exits' do
      Lich.display_exits = true
      Lich.display_room_links = false

      expect(formatter.room_exit_entries).not_to include('north')
    end

    it 'excludes StringProc exits (those are handled separately)' do
      sp = StringProc.new('nil')
      allow(Map).to receive(:current).and_return(double('map', wayto: { 3 => sp }, timeto: { 3 => 5 }, id: 100))
      Lich.display_exits = true

      expect(formatter.room_exit_entries).to eq([])
    end

    it 'coerces a non-String wayto value via to_s instead of raising on #dump' do
      # An Integer responds to #to_s but not #dump; the defensive to_s keeps the
      # downstream hook from crashing if a non-String value ever reaches here.
      allow(Map).to receive(:current).and_return(double('map', wayto: { 5 => 123 }, timeto: {}, id: 100))
      Lich.display_exits = true
      Lich.display_room_links = false

      expect { formatter.room_exit_entries }.not_to raise_error
      expect(formatter.room_exit_entries).to eq(['123'])
    end
  end

  describe '#room_stringproc_entries' do
    let(:stringproc) { StringProc.new('nil') }

    before do
      allow(Map).to receive(:[]).with(42).and_return(double('dest', title: ['[Dest Room]'], id: 99))
    end

    it 'returns an empty array when the stringprocs toggle is off' do
      Lich.display_stringprocs = false

      expect(formatter.room_stringproc_entries).to eq([])
    end

    it 'includes routable StringProcs (numeric timeto) as go2 links when links are on' do
      allow(Map).to receive(:current).and_return(double('map', wayto: { 42 => stringproc }, timeto: { 42 => 5 }, id: 100))
      Lich.display_stringprocs = true
      Lich.display_room_links = true

      expect(formatter.room_stringproc_entries).to eq(["<d cmd=';go2 42'>Dest Room</d>"])
    end

    it 'shows the destination title (not raw source) as plain text when links are off' do
      allow(Map).to receive(:current).and_return(double('map', wayto: { 42 => stringproc }, timeto: { 42 => 5 }, id: 100))
      Lich.display_stringprocs = true
      Lich.display_room_links = false

      expect(formatter.room_stringproc_entries).to eq(['Dest Room'])
    end

    it 'appends the lich id when display_lichid is on' do
      allow(Map).to receive(:current).and_return(double('map', wayto: { 42 => stringproc }, timeto: { 42 => 5 }, id: 100))
      Lich.display_stringprocs = true
      Lich.display_room_links = false
      Lich.display_lichid = true

      expect(formatter.room_stringproc_entries).to eq(['Dest Room(99)'])
    end

    it 'includes a StringProc whose timeto StringProc returns a numeric' do
      allow(Map).to receive(:current).and_return(double('map', wayto: { 42 => stringproc }, timeto: { 42 => StringProc.new('5') }, id: 100))
      Lich.display_stringprocs = true
      Lich.display_room_links = false

      expect(formatter.room_stringproc_entries).to eq(['Dest Room'])
    end

    it 'filters out StringProcs whose timeto is not numeric (not routable)' do
      allow(Map).to receive(:current).and_return(double('map', wayto: { 42 => stringproc }, timeto: { 42 => nil }, id: 100))
      Lich.display_stringprocs = true

      expect(formatter.room_stringproc_entries).to eq([])
    end

    it 'skips a dangling wayto reference (destination missing from the mapdb) without raising' do
      allow(Map).to receive(:current).and_return(double('map', wayto: { 42 => stringproc }, timeto: { 42 => 5 }, id: 100))
      allow(Map).to receive(:[]).with(42).and_return(nil)
      Lich.display_stringprocs = true

      expect { formatter.room_stringproc_entries }.not_to raise_error
      expect(formatter.room_stringproc_entries).to eq([])
    end

    it 'detects StringProcs via is_a? even though StringProc reports Proc for class/kind_of?' do
      # Guards the core StringProc quirk: it overrides #class and #kind_of? but not #is_a?.
      allow(Map).to receive(:current).and_return(double('map', wayto: { 42 => stringproc }, timeto: { 42 => 5 }, id: 100))
      Lich.display_stringprocs = true
      Lich.display_room_links = false

      expect(formatter.room_stringproc_entries).to eq(['Dest Room'])
    end
  end

  describe '#prepend_room_lines' do
    let(:stringproc) { StringProc.new('nil') }

    before do
      allow(Map).to receive(:current).and_return(double('map', wayto: { 2 => 'go door', 42 => stringproc }, timeto: { 42 => 5 }, id: 100))
      allow(Map).to receive(:[]).with(42).and_return(double('dest', title: ['[Dest Room]'], id: 99))
    end

    it 'leaves alt_string untouched when there are no entries' do
      expect(formatter.prepend_room_lines(+'PROMPT', [], [])).to eq('PROMPT')
    end

    it 'prepends exits above stringprocs, both above the original string' do
      Lich.display_room_mono = false

      result = formatter.prepend_room_lines(+'PROMPT', ['Dest Room'], ['go door'])
      expect(result).to eq("Room Exits: go door\r\nStringProcs: Dest Room\r\nPROMPT")
    end

    it 'keeps live <d> links inside a mono-wrapped line (toggles are independent)' do
      Lich.display_room_mono = true
      allow(Frontend).to receive(:supports_mono?).and_return(true)

      result = formatter.prepend_room_lines(+'PROMPT', [], ["<d cmd='go door'>go door</d>"])
      expect(result).to include('<output class="mono"/>Room Exits: ')
      expect(result).to include("<d cmd='go door'>go door</d>")
    end
  end
end

# GS/DR parity: the shared exit/StringProc rendering must be byte-identical
# across games; only the game-specific tails (GS room-window echo, DR room
# number) differ.
RSpec.describe 'process_room_display GS/DR parity' do
  let(:gs) { Lich::Gemstone::GameInstance.new }
  let(:dr) { Lich::DragonRealms::GameInstance.new }
  let(:stringproc) { StringProc.new('nil') }

  before do
    XMLData.reset
    XMLData.room_id = 789
    XMLData.room_title = '[Test Room]'
    Lich.display_lichid = false # no DR room-number line
    Lich.display_uid = false
    Lich.display_exits = true
    Lich.display_stringprocs = true
    Lich.display_room_links = true
    Lich.display_room_mono = false
    allow(Frontend).to receive(:supports_mono?).and_return(false)
    allow(Frontend).to receive(:client).and_return('profanity') # not a room-window frontend
    allow(Map).to receive(:current).and_return(double('map', wayto: { 2 => 'go door', 42 => stringproc }, timeto: { 42 => 5 }, id: 100))
    allow(Map).to receive(:[]).with(42).and_return(double('dest', title: ['[Dest Room]'], id: 99))
  end

  # Reset the shared mock accessors so per-example toggles do not leak into other
  # describe blocks (the suite runs in random order).
  after do
    Lich.display_lichid = nil
    Lich.display_uid = nil
    Lich.display_exits = nil
    Lich.display_stringprocs = nil
    Lich.display_room_links = nil
    Lich.display_room_mono = nil
  end

  it 'renders a byte-identical shared exit/StringProc block in both games even when the game tails differ' do
    Lich.display_lichid = true # DR now appends a "Room Number:" tail; GS still has none

    # lichid=true also appends the dest id to the StringProc label - identically
    # in both games, since both build it through the shared mixin.
    shared = "Room Exits: <d cmd='go door'>go door</d>\r\n" \
             "StringProcs: <d cmd=';go2 42'>Dest Room(99)</d>\r\n"
    gs_out = gs.process_room_display(+'PROMPT')
    dr_out = dr.process_room_display(+'PROMPT')

    expect(gs_out).to include(shared)
    expect(dr_out).to include(shared)
    # The tails genuinely diverge (DR carries the room-number line), so matching
    # the shared block is a real invariant - not the tautology of comparing two
    # outputs whose game-specific tails have both been suppressed.
    expect(gs_out).not_to eq(dr_out)
  end

  it 'DR adds a Room Number line but GS does not' do
    Lich.display_lichid = true

    expect(dr.process_room_display(+'PROMPT')).to include('Room Number:')
    expect(gs.process_room_display(+'PROMPT')).not_to include('Room Number:')
  end

  it 'GS mirrors exits into the room window on a room-window frontend, DR does not' do
    allow(Frontend).to receive(:client).and_return('stormfront')

    expect(gs.process_room_display(+'PROMPT')).to include("<pushStream id='room'")
    expect(dr.process_room_display(+'PROMPT')).not_to include("<pushStream id='room'")
  end

  it 'GS does not mirror exits on a non-room-window frontend' do
    allow(Frontend).to receive(:client).and_return('profanity')

    expect(gs.process_room_display(+'PROMPT')).not_to include("<pushStream id='room'")
  end
end

RSpec.describe Lich::GameBase::GameInstanceFactory do
  it 'creates a game type GS' do
    discovered_game = Lich::GameBase::GameInstanceFactory.create('GS')
    expect(discovered_game).to be_a(Lich::Gemstone::GameInstance)
  end

  it 'creates a game type DR' do
    discovered_game = Lich::GameBase::GameInstanceFactory.create('DR')
    expect(discovered_game).to be_a(Lich::DragonRealms::GameInstance)
  end

  it 'creates a base game type Unknown' do
    discovered_game = Lich::GameBase::GameInstanceFactory.create('Unknown')
    expect(discovered_game).to be_a(Lich::GameBase::GameInstance::Base)
  end
end

RSpec.describe Lich::Gemstone::Game do
  it 'initializes with Gemstone' do
    discovered_game = Lich::Gemstone::Game.new
    expect(discovered_game).to be_a(Lich::GameBase::Game)
  end
end

RSpec.describe Lich::DragonRealms::Game do
  it 'initializes with DragonRealms' do
    discovered_game = Lich::DragonRealms::Game.new
    expect(discovered_game).to be_a(Lich::GameBase::Game)
  end
end

RSpec.describe Lich::Gemstone::Wounds do
  # Use shared injury context from spec_helper (DRY)
  include_context 'Gemstone injury data'

  before do
    XMLData.reset
    # Set specific injury values for wound tests
    set_injuries(
      'leftEye'  => { 'wound' => 0, 'scar' => 1 },
      'rightEye' => { 'wound' => 2, 'scar' => 3 }
    )
  end

  it 'returns correct wound values' do
    expect(Lich::Gemstone::Wounds.leftEye).to eq(0)
    expect(Lich::Gemstone::Wounds.rightEye).to eq(2)
  end

  it 'returns maximum wound value for arms' do
    expect(Lich::Gemstone::Wounds.arms).to eq(0)
  end

  it 'returns maximum wound value for limbs' do
    expect(Lich::Gemstone::Wounds.limbs).to eq(0)
  end

  it 'returns maximum wound value for torso' do
    expect(Lich::Gemstone::Wounds.torso).to eq(2)
  end

  it 'handles invalid areas gracefully' do
    expect(Lich::Gemstone::Wounds.invalid_area).to be_nil
  end
end

RSpec.describe Lich::Gemstone::Scars do
  # Use shared injury context from spec_helper (DRY)
  include_context 'Gemstone injury data'

  before do
    XMLData.reset
    # Set specific injury values for scar tests
    set_injuries(
      'leftEye'   => { 'wound' => 0, 'scar' => 1 },
      'rightEye'  => { 'wound' => 2, 'scar' => 3 },
      'rightArm'  => { 'wound' => 0, 'scar' => 1 },
      'rightHand' => { 'wound' => 0, 'scar' => 1 },
      'rightLeg'  => { 'wound' => 0, 'scar' => 2 }
    )
  end

  it 'returns correct scar values' do
    expect(Lich::Gemstone::Scars.leftEye).to eq(1)
    expect(Lich::Gemstone::Scars.rightEye).to eq(3)
  end

  it 'returns maximum scar value for arms' do
    expect(Lich::Gemstone::Scars.arms).to eq(1)
  end

  it 'returns maximum scar value for limbs' do
    expect(Lich::Gemstone::Scars.limbs).to eq(2)
  end

  it 'returns maximum scar value for torso' do
    expect(Lich::Gemstone::Scars.torso).to eq(3)
  end

  it 'handles invalid areas gracefully' do
    expect(Lich::Gemstone::Scars.invalid).to be_nil
  end
end

RSpec.describe Lich::Gemstone::Gift do
  before do
    Lich::Gemstone::Gift.started
  end

  it 'initializes with default values' do
    expect(Lich::Gemstone::Gift.pulse_count).to eq(0)
    expect(Lich::Gemstone::Gift.gift_start).to be_a(Time)
  end

  it 'increments pulse count correctly' do
    Lich::Gemstone::Gift.pulse
    expect(Lich::Gemstone::Gift.pulse_count).to eq(1)
  end

  it 'calculates remaining time correctly' do
    Lich::Gemstone::Gift.pulse
    expect(Lich::Gemstone::Gift.remaining).to eq(21540.0) # (360-1)*60
  end

  it 'calculates restart time correctly' do
    start_time = Lich::Gemstone::Gift.gift_start
    expect(Lich::Gemstone::Gift.restarts_on).to eq(start_time + 594000)
  end

  it 'serializes data correctly' do
    serialized = Lich::Gemstone::Gift.serialize
    expect(serialized).to be_an(Array)
    expect(serialized.size).to eq(2)
    expect(serialized[0]).to be_a(Time)
    expect(serialized[1]).to eq(0) # From previous test
  end

  it 'loads serialized data correctly' do
    time = Time.now - 3600 # 1 hour ago
    Lich::Gemstone::Gift.load_serialized = [time, 42]
    expect(Lich::Gemstone::Gift.gift_start).to eq(time)
    expect(Lich::Gemstone::Gift.pulse_count).to eq(42)
  end

  it 'ends gift correctly' do
    Lich::Gemstone::Gift.ended
    expect(Lich::Gemstone::Gift.pulse_count).to eq(360)
    expect(Lich::Gemstone::Gift.remaining).to eq(0.0)
  end
end

# Tests for GameBase::Game class variable refactoring (from main)
# NOTE: class_variable_set/get is acceptable in these tests because they are
# specifically verifying the class variable implementation itself - the refactor
# from instance variables (@) to class variables (@@). This is testing the
# implementation detail by design, not testing through public API.
RSpec.describe Lich::GameBase::Game do
  describe '.intentional_shutdown_close_error?' do
    let(:closed_socket) { double('socket', closed?: true) }
    let(:open_socket) { double('socket', closed?: false) }

    before do
      Lich::Common::ShutdownCoordinator.reset!
      described_class.instance_variable_set(:@socket, closed_socket)
    end

    after do
      Lich::Common::ShutdownCoordinator.reset!
      described_class.instance_variable_set(:@socket, nil)
    end

    it 'recognizes reader-thread close errors during orderly user shutdown' do
      Lich::Common::ShutdownCoordinator.request(reason: :user_exit, source: :primary_frontend)

      expect(described_class.intentional_shutdown_close_error?(IOError.new('stream closed in another thread'))).to be_truthy
      expect(described_class.intentional_shutdown_close_error?(Errno::EBADF.new)).to be_truthy
    end

    it 'does not recognize close errors outside orderly user shutdown' do
      Lich::Common::ShutdownCoordinator.request(reason: :game_eof, source: :game_reader)

      expect(described_class.intentional_shutdown_close_error?(IOError.new('stream closed in another thread'))).to be false
      expect(described_class.intentional_shutdown_close_error?(Errno::EBADF.new)).to be false
    end

    it 'does not recognize orderly shutdown errors while the socket is open' do
      Lich::Common::ShutdownCoordinator.request(reason: :user_exit, source: :primary_frontend)
      described_class.instance_variable_set(:@socket, open_socket)

      expect(described_class.intentional_shutdown_close_error?(IOError.new('stream closed in another thread'))).to be false
    end
  end

  describe '.autostarted?' do
    before do
      # Reset the class variable for test isolation
      described_class.class_variable_set(:@@autostarted, false) if described_class.class_variable_defined?(:@@autostarted)
    end

    it 'returns false initially' do
      described_class.class_variable_set(:@@autostarted, false)
      expect(described_class.autostarted?).to be false
    end

    it 'returns true when @@autostarted is set to true' do
      described_class.class_variable_set(:@@autostarted, true)
      expect(described_class.autostarted?).to be true
    end

    it 'reflects the value of the @@autostarted class variable' do
      described_class.class_variable_set(:@@autostarted, false)
      expect(described_class.autostarted?).to be false

      described_class.class_variable_set(:@@autostarted, true)
      expect(described_class.autostarted?).to be true
    end
  end

  describe 'initialization state management' do
    before do
      described_class.class_variable_set(:@@autostarted, false) if described_class.class_variable_defined?(:@@autostarted)
    end

    context 'during startup lifecycle' do
      it 'starts with autostarted as false' do
        # Simulate fresh start
        described_class.send(:initialize_buffers) if described_class.respond_to?(:initialize_buffers)
        expect(described_class.autostarted?).to be false
      end

      it 'becomes true after handle_autostart is called' do
        # Stub dependencies to isolate the state transition
        stub_const('LICH_VERSION', '5.0.0')
        stub_const('RECOMMENDED_RUBY', '3.0.0')
        allow(Lich).to receive(:core_updated_with_lich_version).and_return('5.0.0')
        allow(Script).to receive(:exists?).and_return(false) if defined?(Script)
        # Prevent background sync thread from leaking into other specs.
        # Lich::Util::Update may not be loaded in this spec context, so
        # stub_const ensures the module and method exist for the stub.
        sync_stub = Module.new { def self.sync_all_repos; end }
        stub_const('Lich::Util::Update', sync_stub)
        # stub_const alone doesn't stop the leak: handle_autostart spawns a
        # real Thread, which can still be mid-flight (or not yet scheduled)
        # when this example ends and stub_const reverts the constant. That
        # thread then resolves Lich::Util::Update for real and throws a mock
        # error into whatever unrelated spec happens to be running by then.
        # Run the block inline so no thread survives past this example.
        allow(Thread).to receive(:new) { |&block| block.call; nil }

        described_class.send(:handle_autostart)
        expect(described_class.autostarted?).to be true
      end
    end
  end

  describe '.settings_init_needed?' do
    before do
      described_class.class_variable_set(:@@settings_init_needed, false)
    end

    it 'returns false initially' do
      expect(described_class.settings_init_needed?).to be false
    end

    it 'returns true when @@settings_init_needed is set' do
      described_class.class_variable_set(:@@settings_init_needed, true)
      expect(described_class.settings_init_needed?).to be true
    end
  end

  describe 'class variable vs instance variable' do
    it 'uses a class variable (@@autostarted) not instance variable (@autostarted)' do
      # This test verifies the refactor from @ to @@
      expect(described_class.class_variable_defined?(:@@autostarted)).to be true

      # Set via class variable
      described_class.class_variable_set(:@@autostarted, true)

      # Should be readable via the method
      expect(described_class.autostarted?).to be true
    end
  end

  describe '._puts' do
    let(:mock_socket) { double('socket') }

    before do
      described_class.instance_variable_set(:@socket, mock_socket)
      described_class.instance_variable_set(:@mutex, Mutex.new)
      allow(Lich).to receive(:log)
    end

    it 'writes to the socket' do
      allow(mock_socket).to receive(:puts)
      described_class.send(:_puts, 'test')
      expect(mock_socket).to have_received(:puts).with('test')
    end

    # -- Errno::EPIPE (pre-existing) ----------------------------------------

    context 'when socket raises Errno::EPIPE' do
      before { allow(mock_socket).to receive(:puts).and_raise(Errno::EPIPE) }

      it 'does not propagate the exception' do
        expect { described_class.send(:_puts, 'test') }.not_to raise_error
      end

      it 'returns nil' do
        expect(described_class.send(:_puts, 'test')).to be_nil
      end

      it 'logs the error' do
        described_class.send(:_puts, 'test')
        expect(Lich).to have_received(:log).with(/error: _puts: Broken pipe/)
      end
    end

    # -- IOError (pre-existing) ---------------------------------------------

    context 'when socket raises IOError' do
      before { allow(mock_socket).to receive(:puts).and_raise(IOError, 'closed stream') }

      it 'does not propagate the exception' do
        expect { described_class.send(:_puts, 'test') }.not_to raise_error
      end

      it 'returns nil' do
        expect(described_class.send(:_puts, 'test')).to be_nil
      end

      it 'logs the error' do
        described_class.send(:_puts, 'test')
        expect(Lich).to have_received(:log).with(/error: _puts: closed stream/)
      end
    end

    # -- Errno::ECONNRESET (the bug that caused 9,089 lines of spam) --------

    context 'when socket raises Errno::ECONNRESET' do
      before { allow(mock_socket).to receive(:puts).and_raise(Errno::ECONNRESET) }

      it 'does not propagate the exception' do
        expect { described_class.send(:_puts, 'go north') }.not_to raise_error
      end

      it 'returns nil' do
        expect(described_class.send(:_puts, 'go north')).to be_nil
      end

      it 'logs the error with class name and backtrace' do
        described_class.send(:_puts, 'go north')
        expect(Lich).to have_received(:log).with(/error: _puts:.*(?:Connection reset|forcibly closed)/i)
      end

      it 'absorbs rapid successive ECONNRESET bursts without raising' do
        50.times do
          expect { described_class.send(:_puts, "command_#{_1}") }.not_to raise_error
        end
      end
    end

    # -- Errno::ECONNABORTED ------------------------------------------------

    context 'when socket raises Errno::ECONNABORTED' do
      before { allow(mock_socket).to receive(:puts).and_raise(Errno::ECONNABORTED) }

      it 'does not propagate the exception' do
        expect { described_class.send(:_puts, 'go north') }.not_to raise_error
      end

      it 'returns nil' do
        expect(described_class.send(:_puts, 'go north')).to be_nil
      end

      it 'logs the error' do
        described_class.send(:_puts, 'go north')
        expect(Lich).to have_received(:log).with(/error: _puts:/)
      end
    end

    # -- Non-connection errors must still propagate -------------------------

    context 'when socket raises a non-connection error' do
      it 'raises RuntimeError' do
        allow(mock_socket).to receive(:puts).and_raise(RuntimeError, 'unexpected')
        expect { described_class.send(:_puts, 'go north') }.to raise_error(RuntimeError, 'unexpected')
      end

      it 'raises NoMethodError' do
        allow(mock_socket).to receive(:puts).and_raise(NoMethodError, 'undefined method')
        expect { described_class.send(:_puts, 'go north') }.to raise_error(NoMethodError)
      end

      it 'raises ArgumentError' do
        allow(mock_socket).to receive(:puts).and_raise(ArgumentError, 'bad args')
        expect { described_class.send(:_puts, 'go north') }.to raise_error(ArgumentError)
      end
    end

    # -- Thread safety ------------------------------------------------------

    context 'thread safety under connection failure' do
      it 'serializes concurrent writes through the mutex even when failing' do
        call_order = []
        mutex = Mutex.new

        allow(mock_socket).to receive(:puts) do |str|
          mutex.synchronize { call_order << str }
          raise Errno::ECONNRESET
        end

        threads = 10.times.map do |i|
          Thread.new { described_class.send(:_puts, "cmd_#{i}") }
        end
        threads.each(&:join)

        expect(call_order.size).to eq(10)
      end

      it 'does not deadlock when socket raises inside mutex' do
        allow(mock_socket).to receive(:puts).and_raise(Errno::ECONNRESET)

        result = Timeout.timeout(2) do
          5.times { described_class.send(:_puts, 'test') }
          :completed
        end

        expect(result).to eq(:completed)
      end
    end

    # -- Mixed error sequences ----------------------------------------------

    context 'alternating error types' do
      it 'handles EPIPE then ECONNRESET then IOError in sequence' do
        call_count = 0
        allow(mock_socket).to receive(:puts) do
          call_count += 1
          case call_count
          when 1 then raise Errno::EPIPE
          when 2 then raise Errno::ECONNRESET
          when 3 then raise IOError, 'closed stream'
          end
        end

        3.times do
          expect { described_class.send(:_puts, 'test') }.not_to raise_error
        end

        expect(Lich).to have_received(:log).exactly(3).times
      end
    end
  end

  describe '.send_to_client' do
    def eventually(timeout: 1)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        begin
          return yield
        rescue RSpec::Expectations::ExpectationNotMetError
          raise if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep 0.005
        end
      end
    end

    before do
      allow(Lich).to receive(:log)
    end

    context 'when using detachable clients' do
      let(:raw_socket) { double('raw_detachable_socket', closed?: false) }
      let(:second_raw_socket) { double('second_raw_detachable_socket', closed?: false) }
      let(:mock_detachable) { Lich::Common::SynchronizedSocket.new(raw_socket, role: :detachable) }
      let(:second_detachable) { Lich::Common::SynchronizedSocket.new(second_raw_socket, role: :detachable) }

      before do
        allow(raw_socket).to receive(:close)
        allow(second_raw_socket).to receive(:close)
        $_DETACHABLE_CLIENT_REGISTRY_ = Lich::Common::DetachableClientRegistry.new
        $_DETACHABLE_CLIENT_REGISTRY_.register(mock_detachable)
        $_DETACHABLE_CLIENT_REGISTRY_.register(second_detachable)
        $_DETACHABLE_CLIENT_ = nil
        Lich::Common::ShutdownCoordinator.reset!
      end

      after do
        mock_detachable.close rescue nil
        second_detachable.close rescue nil
        $_DETACHABLE_CLIENT_REGISTRY_ = nil
        $_DETACHABLE_CLIENT_ = nil
        Lich::Common::ShutdownCoordinator.reset!
      end

      it 'fans output out to every detachable client' do
        allow(raw_socket).to receive(:write)
        allow(second_raw_socket).to receive(:write)
        described_class.send(:send_to_client, 'test data')
        eventually { expect(raw_socket).to have_received(:write).with('test data') }
        eventually { expect(second_raw_socket).to have_received(:write).with('test data') }
      end

      it 'continues writing to another client when one write fails' do
        allow(raw_socket).to receive(:write).and_raise(Errno::EPIPE)
        allow(second_raw_socket).to receive(:write)
        expect { described_class.send(:send_to_client, 'test data') }.not_to raise_error
        eventually { expect(mock_detachable.alive?).to be false }
        expect(raw_socket).to have_received(:close)
        eventually { expect(second_raw_socket).to have_received(:write).with('test data') }
        expect(Lich::Common::ShutdownCoordinator.current).to be_nil
      end
    end

    context 'when using non-detachable client' do
      let(:raw_socket) { double('raw_client_socket', closed?: false) }
      let(:mock_client) { Lich::Common::SynchronizedSocket.new(raw_socket) }

      before do
        allow(raw_socket).to receive(:close)
        $_DETACHABLE_CLIENT_REGISTRY_ = nil
        $_DETACHABLE_CLIENT_ = nil
        $_CLIENT_ = mock_client
      end

      after do
        mock_client.close rescue nil
        $_CLIENT_ = nil
      end

      it 'writes to the client' do
        allow(raw_socket).to receive(:write)
        described_class.send(:send_to_client, 'test data')
        eventually { expect(raw_socket).to have_received(:write).with('test data') }
      end

      it 'absorbs Errno::EPIPE without raising' do
        allow(raw_socket).to receive(:write).and_raise(Errno::EPIPE)
        allow(raw_socket).to receive(:close)
        expect { described_class.send(:send_to_client, 'test data') }.not_to raise_error
        eventually { expect(Lich).to have_received(:log).with(/client socket write failed.*EPIPE/) }
      end

      it 'absorbs IOError without raising' do
        allow(raw_socket).to receive(:write).and_raise(IOError, 'closed stream')
        allow(raw_socket).to receive(:close)
        expect { described_class.send(:send_to_client, 'test data') }.not_to raise_error
        eventually { expect(Lich).to have_received(:log).with(/client socket write failed.*closed stream/) }
      end
    end
  end
end

RSpec.describe Lich::GameBase::Game, '.open_with_timeout' do
  it 'returns without error when Game.open succeeds' do
    allow(described_class).to receive(:open).and_return(:socket)
    expect { described_class.open_with_timeout('host', 1, 1) }.not_to raise_error
  end

  it 'raises when the connect does not finish within the timeout' do
    allow(described_class).to receive(:open) { sleep 5 } # hangs past the timeout
    expect { described_class.open_with_timeout('host', 1, 0.3) }
      .to raise_error(/timed out connecting/)
  end

  # Long-standing bug (currently failing; present since the original connect-loop
  # in "Base Lich 5"): a Game.open that raises (e.g. connection refused) must
  # surface so the caller's rescue (retry / clean exit) runs instead of proceeding
  # with a dead socket. The connect thread dies with an exception
  # (Thread#status == nil), which the current code treats the same as a normal
  # finish (status == false).
  it 'raises when Game.open fails to connect' do
    allow(described_class).to receive(:open).and_raise(Errno::ECONNREFUSED)
    expect { described_class.open_with_timeout('unreachable.host', 1, 1) }
      .to raise_error(Errno::ECONNREFUSED)
  end
end

# The stream desync guard: pre-Ox, strict REXML raised on truncated fragments
# and Game.process_xml_data's rescue logged the fragment and reset XMLData --
# parser strictness doubled as stream-desync detection. Ox is permissive: it
# parses truncated fragments without raising (auto-closing elements,
# fabricating empty attribute values) and reports problems only through the
# optional error callback. These specs prove the callback-based guard restores
# the pre-Ox failure mode (GameStreamDesyncError -> log + reset) for
# truncation, while still tolerating the routine almost-XML that Ox was
# adopted to absorb without REXML's clean-and-retry dance.
RSpec.describe 'Lich::GameBase stream desync guard' do
  # Collects Ox parse errors through the real XMLParser error callback while
  # neutering tag handlers (parser state side effects are irrelevant here).
  let(:quiet_parser_class) do
    Class.new(Lich::Common::XMLParser) do
      def tag_start(_name, _attributes); end

      def tag_end(_name); end

      def text(_value); end
    end
  end

  def parse_errors(parser, fragment)
    Ox.sax_parse(parser, fragment, convert_special: false, symbolize: false, skip: :skip_none)
    parser.sax_parse_errors
  end

  def check!(fragment)
    Lich::GameBase::Game.check_stream_desync!(parse_errors(quiet_parser_class.new, fragment))
  end

  describe 'Game.check_stream_desync!' do
    context 'with truncated (desynced) fragments REXML used to raise on' do
      it 'raises when a fragment is cut off inside a quoted attribute value' do
        expect { check!('<a exist="123" noun="swo') }
          .to raise_error(Lich::GameBase::GameStreamDesyncError, /quoted value not terminated/)
      end

      it 'raises when a fragment is cut off after an attribute equals sign' do
        expect { check!('<pushStream id="room"/><compDef id=') }
          .to raise_error(Lich::GameBase::GameStreamDesyncError)
      end

      it 'raises when a fragment is cut off inside an element name' do
        expect { check!('<dialogDa') }
          .to raise_error(Lich::GameBase::GameStreamDesyncError, /document not terminated/)
      end

      it 'raises when a start tag never gets its closing bracket' do
        expect { check!('<dialogData id="minivitals"><progressBar id="health"') }
          .to raise_error(Lich::GameBase::GameStreamDesyncError, /not terminated|not closed/)
      end
    end

    context 'with routine almost-XML the stream sends constantly' do
      it 'tolerates plain prose lines (Ox still reports text not terminated)' do
        errors = parse_errors(quiet_parser_class.new, 'You also see a wooden barrel.')
        expect(errors).not_to be_empty # proves toleration is a choice, not absence of errors
        expect { Lich::GameBase::Game.check_stream_desync!(errors) }.not_to raise_error
      end

      it 'tolerates multiple top-level elements with trailing text' do
        expect { check!('<popBold/><pushStream id="room"/>text after') }.not_to raise_error
      end

      it 'tolerates nested single quotes in attribute values' do
        expect { check!("<d cmd='look Tsetem's pack'>Tsetem's pack</d>") }.not_to raise_error
      end

      it "tolerates elements missing their end tag (Simu's </d> bug)" do
        expect { check!("<d cmd='go gate'>gate<d>more") }.not_to raise_error
      end

      it 'tolerates unescaped ampersands' do
        expect { check!('a large bin labeled "Lost & Found"') }.not_to raise_error
      end

      it 'tolerates the settingsInfo space-not-found server bug' do
        expect { check!("<settingsInfo  crc='612586004' instance='GS4' space not found ItemCmds='1' />") }
          .not_to raise_error
      end

      it 'tolerates a complete unquoted attribute value (not a truncation)' do
        # <a x=y> emits "attribute value not in quotes" but is a complete line;
        # matching it would false-reset a fully-parsed fragment.
        expect { check!('<a x=y>text</a>') }.not_to raise_error
      end
    end
  end

  describe 'Game.process_xml_data with a truncated fragment' do
    it 'logs the desync and resets XMLData' do
      parser = quiet_parser_class.new
      stub_const('XMLData', parser)
      allow(Lich).to receive(:log)
      allow(parser).to receive(:reset).and_call_original
      Lich::GameBase::Game.process_xml_data(+'<a exist="123" noun="swo')
      expect(Lich).to have_received(:log).with(/stream desync/)
      expect(parser).to have_received(:reset)
    end

    it 'does not reset XMLData for a clean fragment' do
      parser = quiet_parser_class.new
      stub_const('XMLData', parser)
      # strip_xml lives outside games.rb and is not loaded here; the assertion
      # under test is only that the parse stage does not trigger recovery.
      # It returns the stripped line as a String; the callsite splits it on CRLF.
      allow(Lich::GameBase::Game).to receive(:strip_xml).and_return('')
      allow(parser).to receive(:reset).and_call_original
      Lich::GameBase::Game.process_xml_data(+"<prompt time=\"1746000000\">&gt;</prompt>\r\n")
      expect(parser).not_to have_received(:reset)
    end

    it 'repairs nested quotes and reparses when Ox flags a valueless attribute' do
      parser = quiet_parser_class.new
      stub_const('XMLData', parser)
      allow(Lich::GameBase::Game).to receive(:strip_xml).and_return('')
      allow(parser).to receive(:reset).and_call_original
      # title='Tsetem's Items' makes Ox emit "no attribute value"; the retry
      # escapes the inner quote, resets the junk first parse, and reparses.
      server_string = +"<openDialog id='quux' title='Tsetem's Items'/>"
      Lich::GameBase::Game.process_xml_data(server_string)
      expect(server_string).to include("title='Tsetem&apos;s Items'")
      expect(parser).to have_received(:reset)
    end

    it 'does not reparse a genuinely valueless attribute (nothing to escape)' do
      parser = quiet_parser_class.new
      stub_const('XMLData', parser)
      allow(Lich::GameBase::Game).to receive(:strip_xml).and_return('')
      allow(parser).to receive(:reset).and_call_original
      # <a foo> also emits "no attribute value", but clean_nested_quotes finds
      # no nested quote to escape, so there is no reset/reparse.
      Lich::GameBase::Game.process_xml_data(+"<a foo>x</a>")
      expect(parser).not_to have_received(:reset)
    end

    it 'repairs a malformed settingsInfo via the retry path and flags an init re-seed' do
      parser = quiet_parser_class.new
      stub_const('XMLData', parser)
      allow(Lich::GameBase::Game).to receive(:strip_xml).and_return('')
      allow(parser).to receive(:reset).and_call_original
      # @@settings_init_needed is a production class variable with no reset! hook.
      Lich::GameBase::Game.class_variable_set(:@@settings_init_needed, false)
      server_string = +"<settingsInfo crc='0' instance='GS4' space not found ItemCmds='1'/>"
      Lich::GameBase::Game.process_xml_data(server_string)
      expect(server_string).to include("client='1.0.1.28'")
      expect(Lich::GameBase::Game.settings_init_needed?).to be true
      expect(parser).to have_received(:reset)
    end
  end

  # Ox tolerates the malformed settingsInfo (see the check_stream_desync! test
  # above), so the repair + @@settings_init_needed flag -- which REXML reached
  # via its raise/rescue -- now has to run in the normal flow instead.
  describe 'Game.fix_invalid_settings_info' do
    before do
      # @@settings_init_needed is a production class variable with no reset! hook;
      # clear it so each example starts from a known state.
      Lich::GameBase::Game.class_variable_set(:@@settings_init_needed, false)
    end

    it 'repairs the space-not-found settingsInfo and flags an init re-seed' do
      server_string = +"<settingsInfo  crc='612586004' instance='GS4' space not found ItemCmds='1' />"
      allow(Lich).to receive(:log)
      Lich::GameBase::Game.fix_invalid_settings_info(server_string)
      expect(server_string).to include("client='1.0.1.28'")
      expect(server_string).not_to include('space not found')
      expect(Lich::GameBase::Game.settings_init_needed?).to be true
    end

    it 'leaves a well-formed settingsInfo untouched and does not flag' do
      server_string = +"<settingsInfo client='1.0.1.28' crc='0' instance='GS4' />"
      Lich::GameBase::Game.fix_invalid_settings_info(server_string)
      expect(server_string).to eq("<settingsInfo client='1.0.1.28' crc='0' instance='GS4' />")
      expect(Lich::GameBase::Game.settings_init_needed?).to be false
    end
  end
end
