# frozen_string_literal: true

require_relative '../spec_helper'

# Load production code
require "common/sharedbuffer"
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

    it 'fixes invalid ampersands' do
      # Use +@ to unfreeze string for in-place modification
      input = +'You also see a large bin labeled "Lost & Found"'
      output = Lich::GameBase::XMLCleaner.fix_invalid_characters(input)
      expect(output).to include('&amp;')
    end

    it 'removes bell characters' do
      # Use +@ to unfreeze string for in-place modification
      input = +"\aYOU HAVE BEEN IDLE TOO LONG. PLEASE RESPOND.\a\n"
      output = Lich::GameBase::XMLCleaner.fix_invalid_characters(input)
      expect(output).not_to include("\a")
    end

    # Need to figure out how to send this bad character string - FIXME
    # it 'fixes poorly encoded apostrophes' do
    #  input = "Membrach\x92s Greed"
    #  output = Lich::GameBase::XMLCleaner.fix_invalid_characters(input)
    #  expect(output).to eq("Membrach's Greed")
    # end

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

    it 'rescues Errno::EPIPE and logs the error' do
      allow(mock_socket).to receive(:puts).and_raise(Errno::EPIPE)
      expect { described_class.send(:_puts, 'test') }.not_to raise_error
      expect(Lich).to have_received(:log).with(/error: _puts: Broken pipe/)
    end

    it 'rescues IOError and logs the error' do
      allow(mock_socket).to receive(:puts).and_raise(IOError, 'closed stream')
      expect { described_class.send(:_puts, 'test') }.not_to raise_error
      expect(Lich).to have_received(:log).with(/error: _puts: closed stream/)
    end

    it 'returns nil on broken pipe' do
      allow(mock_socket).to receive(:puts).and_raise(Errno::EPIPE)
      expect(described_class.send(:_puts, 'test')).to be_nil
    end
  end

  describe '.send_to_client' do
    before do
      allow(Lich).to receive(:log)
    end

    context 'when using detachable client' do
      let(:mock_detachable) { double('detachable_client') }

      before do
        $_DETACHABLE_CLIENT_ = mock_detachable
      end

      after do
        $_DETACHABLE_CLIENT_ = nil
      end

      it 'writes to the detachable client' do
        allow(mock_detachable).to receive(:write)
        described_class.send(:send_to_client, 'test data')
        expect(mock_detachable).to have_received(:write).with('test data')
      end

      it 'rescues errors and cleans up detachable client' do
        allow(mock_detachable).to receive(:write).and_raise(Errno::EPIPE)
        allow(mock_detachable).to receive(:close)
        expect { described_class.send(:send_to_client, 'test data') }.not_to raise_error
        expect($_DETACHABLE_CLIENT_).to be_nil
      end
    end

    context 'when using non-detachable client' do
      let(:mock_client) { double('client') }

      before do
        $_DETACHABLE_CLIENT_ = nil
        $_CLIENT_ = mock_client
      end

      it 'writes to the client' do
        allow(mock_client).to receive(:write)
        described_class.send(:send_to_client, 'test data')
        expect(mock_client).to have_received(:write).with('test data')
      end

      it 'rescues Errno::EPIPE without raising' do
        allow(mock_client).to receive(:write).and_raise(Errno::EPIPE)
        expect { described_class.send(:send_to_client, 'test data') }.not_to raise_error
        expect(Lich).to have_received(:log).with(/error: client_thread: Broken pipe/)
      end

      it 'rescues IOError without raising' do
        allow(mock_client).to receive(:write).and_raise(IOError, 'closed stream')
        expect { described_class.send(:send_to_client, 'test data') }.not_to raise_error
        expect(Lich).to have_received(:log).with(/error: client_thread: closed stream/)
      end
    end
  end
end
