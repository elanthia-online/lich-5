require 'rspec'

LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib')

require File.join(LIB_DIR, "common", "sharedbuffer.rb")
require File.join(LIB_DIR, "games.rb")
require File.join(LIB_DIR, "gemstone", "wounds.rb")
require File.join(LIB_DIR, "gemstone", "scars.rb")
require File.join(LIB_DIR, "gemstone", "gift.rb")

# Mock classes and modules needed for testing
module XMLData
  class << self
    attr_accessor :game, :injuries, :name, :dialogs, :room_id, :room_title, :injury_mode

    def reset
      @game = nil
      @injuries = {}
      @name = nil
      @dialogs = {}
      @room_id = 0
      @room_title = nil
      @injury_mode ||= 2
    end
  end
end

module Lich
  class << self
    attr_accessor :display_lichid, :display_uid, :hide_uid_flag, :display_stringprocs, :display_exits

    def log(msg)
      # Mock implementation for testing - Lich.log(msg) calls respond with success returning nil
    end
  end
  module Messaging
    def self.monsterbold(msg)
      # Mock implementation for testing - Lich::Messaging.monsterbold(msg) calls _respond with success returning nil
    end

    def self.mono(msg)
      # Mock implementation for testing - Lich::Messaging.mono(msg) calls _respond with success returning nil
    end
  end
end

class Script
  class << self
    attr_accessor :current

    def exist?(_name)
      false
    end

    def start(name)
      # Mock implementation
    end

    def new_downstream_xml(data)
      # Mock implementation
    end

    def new_downstream(data)
      # Mock implementation
    end
  end
end

class Room
  class << self
    def current
      self
    end

    def id
      1234
    end

    def [](_key)
      self
    end
  end
end

class Map
  class << self
    def current
      self
    end

    def [](_key)
      self
    end

    def id
      1234
    end

    def wayto
      { 1 => 'north', 2 => 'south', 3 => Proc.new {} }
    end

    def timeto
      { 1 => 10, 2 => 20, 3 => 30 }
    end

    def title
      ['[Test Room]']
    end
  end
end

module DownstreamHook
  def self.run(data)
    data
  end
end

# Global variables needed for testing
$_SERVERBUFFER_ = []
$_CLIENTBUFFER_ = []
$_LASTUPSTREAM_ = nil
$SEND_CHARACTER = '>'
$cmd_prefix = ''
$frontend = 'stormfront'
$_CLIENT_ = Object.new.tap do |obj|
  def obj.write(data); end
  def obj.closed?; false; end
end
$_DETACHABLE_CLIENT_ = nil

RSpec.describe Lich::GameBase do
  describe Lich::GameBase::XMLCleaner do
    it 'cleans nested single quotes' do
      input = "<link id='2' value='Ever wondered about the time you've spent in Elanthia?  Check the PLAYED verb!' cmd='played' echo='played' />"
      output = Lich::GameBase::XMLCleaner.clean_nested_quotes(input)
      expect(output).to include("&apos;ve")
    end

    it 'cleans nested double quotes' do
      input = '<subtitle=" - [Avlea\'s Bows, "The Straight and Arrow"]">'
      output = Lich::GameBase::XMLCleaner.clean_nested_quotes(input)
      expect(output).to include('&quot;The')
    end

    it 'fixes invalid ampersands' do
      input = 'You also see a large bin labeled "Lost & Found"'
      output = Lich::GameBase::XMLCleaner.fix_invalid_characters(input)
      expect(output).to include('&amp;')
    end

    it 'removes bell characters' do
      input = "\aYOU HAVE BEEN IDLE TOO LONG. PLEASE RESPOND.\a\n"
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
      input = "<component id='room objs'>  You also see a granite altar with several candles and a water jug on it, and a granite font.\r\n"
      output = Lich::GameBase::XMLCleaner.fix_xml_tags(input)
      expect(output).to include("</component>")
    end

    it 'removes dangling closing tags' do
      input = "</component>\r\n"
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
      input = "Some room description  <compDef id='room text'></compDef>"
      output = game_instance.clean_serverstring(input)
      expect(output).to include("<compDef id='room desc'>Some room description</compDef>")
    end

    it 'returns the string unchanged if no issues' do
      input = "Normal string with no issues"
      output = game_instance.clean_serverstring(input)
      expect(output).to eq(input)
    end
  end

  describe '#handle_combat_tags' do
    it 'tracks combat count correctly' do
      # Increase combat count
      input1 = "Combat text<pushStream id=\"combat\" />more combat"
      game_instance.handle_combat_tags(input1)
      expect(game_instance.combat_count).to eq(1)

      # Check if combat tags are handled correctly
      input2 = "End combat<prompt>prompt</prompt>"
      output2 = game_instance.handle_combat_tags(input2)
      expect(output2).to include("<popStream id=\"combat\" />")
      expect(game_instance.combat_count).to eq(0)
    end
  end

  describe '#handle_atmospherics' do
    it 'handles atmospherics correctly' do
      # Set atmospherics to true
      input1 = "Some text<pushStream id=\"atmospherics\" />atmospheric text"
      # output1 = @game_instance.handle_atmospherics(input1)
      game_instance.handle_atmospherics(input1)
      expect(game_instance.atmospherics).to be true

      # Check if the next string gets the popStream
      input2 = "More text without popStream"
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

      alt_string = "[Test Room] (123)"
      # lichid_from_uid_string = 456 cannot be tested, modify_room_display takes alt_string only and generates uid / lichid

      result = game_instance.modify_room_display(alt_string) # , uid_from_string, lichid_from_uid_string)
      expect(result).to include(" - 1234]") # why 1234?
    end
  end
end

RSpec.describe Lich::DragonRealms::GameInstance do
  before do
    XMLData.reset
    XMLData.game = 'DR'
    XMLData.room_title = "[Test DR Room]"
  end

  let(:game_instance) { Lich::DragonRealms::GameInstance.new }

  describe '#clean_serverstring' do
    it 'removes superfluous tags' do
      input = "Some text<pushStream id=\"combat\" /><popStream id=\"combat\" />more text"
      output = game_instance.clean_serverstring(input)
      expect(output).to eq("Some textmore text")
    end

    it 'fixes combat wrapping components' do
      input = "Some text<pushStream id=\"combat\" /><component id='test'>content</component>"
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

      alt_string = "Room [Test Room] (**)"
      # uid_from_string = nil
      # lichid_from_uid_string = 456

      result = game_instance.modify_room_display(alt_string) # , uid_from_string, lichid_from_uid_string)
      expect(result).not_to include("(**)")
    end
  end

  describe '#process_room_display' do
    it 'adds DR-specific room number information' do
      Lich.display_lichid = true
      Lich.display_uid = true
      XMLData.room_id = 789

      alt_string = "Room prompt"
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
  before do
    XMLData.reset
    XMLData.injuries = {
      'leftEye'   => { 'wound' => 0, 'scar' => 1 },
      'rightEye'  => { 'wound' => 2, 'scar' => 3 },
      'head'      => { 'wound' => 0, 'scar' => 0 },
      'neck'      => { 'wound' => 0, 'scar' => 0 },
      'back'      => { 'wound' => 0, 'scar' => 0 },
      'chest'     => { 'wound' => 0, 'scar' => 0 },
      'abdomen'   => { 'wound' => 0, 'scar' => 0 },
      'leftArm'   => { 'wound' => 0, 'scar' => 0 },
      'rightArm'  => { 'wound' => 0, 'scar' => 0 },
      'leftHand'  => { 'wound' => 0, 'scar' => 0 },
      'rightHand' => { 'wound' => 0, 'scar' => 0 },
      'leftLeg'   => { 'wound' => 0, 'scar' => 0 },
      'rightLeg'  => { 'wound' => 0, 'scar' => 0 },
      'leftFoot'  => { 'wound' => 0, 'scar' => 0 },
      'rightFoot' => { 'wound' => 0, 'scar' => 0 },
      'nsys'      => { 'wound' => 0, 'scar' => 0 }
    }
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
  before do
    XMLData.reset
    XMLData.injuries = {
      'leftEye'   => { 'wound' => 0, 'scar' => 1 },
      'rightEye'  => { 'wound' => 2, 'scar' => 3 },
      'head'      => { 'wound' => 0, 'scar' => 0 },
      'neck'      => { 'wound' => 0, 'scar' => 0 },
      'back'      => { 'wound' => 0, 'scar' => 0 },
      'chest'     => { 'wound' => 0, 'scar' => 0 },
      'abdomen'   => { 'wound' => 0, 'scar' => 0 },
      'leftArm'   => { 'wound' => 0, 'scar' => 0 },
      'rightArm'  => { 'wound' => 0, 'scar' => 1 },
      'leftHand'  => { 'wound' => 0, 'scar' => 0 },
      'rightHand' => { 'wound' => 0, 'scar' => 1 },
      'leftLeg'   => { 'wound' => 0, 'scar' => 0 },
      'rightLeg'  => { 'wound' => 0, 'scar' => 2 },
      'leftFoot'  => { 'wound' => 0, 'scar' => 0 },
      'rightFoot' => { 'wound' => 0, 'scar' => 0 },
      'nsys'      => { 'wound' => 0, 'scar' => 0 }
    }
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
