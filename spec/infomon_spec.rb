require "infomon/infomon"
require "stats/stats_gs"

module Char
  def self.name
    "testing"
  end
end


describe Infomon, ".setup!" do
  context "can set itself up" do
    it "creates a db" do
      Infomon.setup!
      File.exist?(Infomon.file) or fail "infomon sqlite db was not created"
    end
  end

  context "can manipulate data" do
    it "upserts a new key/value pair" do
      k = "stats.influence"
      # handles when value doesn't exist
      Infomon.set(k, 30)
      expect(Infomon.get(k)).to eq(30)
      Infomon.set(k, 40)
      # handles upsert on already existing values
      expect(Infomon.get(k)).to eq(40)
    end
  end
end

describe Infomon::Parser, ".parse" do
  before(:each) do
    # ensure clean db on every test
    Infomon.reset!
  end

  context "citizenship" do
    it "handles citizenship in a town" do
      Infomon::Parser.parse %[You currently have full citizenship in Wehnimer's Landing.]
      citizenship = Infomon.get("citizenship")
      expect(citizenship).to eq(%[Wehnimer's Landing])
    end

    it "handles no citizenship" do
      Infomon::Parser.parse %[You don't seem to have citizenship.]
      expect(Infomon.get("citizenship")).to eq(nil)
    end
  end

  context "stats" do
    it "handles stats" do
      stats = <<-Stats
            Strength (STR):   110 (30)    ...  110 (30)
      Constitution (CON):   104 (22)    ...  104 (22)
        Dexterity (DEX):   100 (35)    ...  100 (35)
          Agility (AGI):   100 (30)    ...  100 (30)
        Discipline (DIS):   110 (20)    ...  110 (20)
              Aura (AUR):   100 (-35)    ...  100 (35)
            Logic (LOG):   108 (29)    ...  118 (34)
        Intuition (INT):    99 (29)    ...   99 (29)
            Wisdom (WIS):    84 (22)    ...   84 (22)
        Influence (INF):   100 (20)    ...  108 (24)
      Stats
      stats.split("\n").each {|line| Infomon::Parser.parse(line)}

      expect(Infomon.get("stat.aura")).to eq(100)
      expect(Infomon.get("stat.aura.bonus")).to eq(-35)
      expect(Infomon.get("stat.logic.enhanced")).to eq(118)
      expect(Infomon.get("stat.logic.enhanced_bonus")).to eq(34)

      expect(Stats.aura.value).to eq(100)
      expect(Stats.aura.bonus).to eq(-35)
      expect(Stats.logic.enhanced.value).to eq(118)
      expect(Stats.logic.enhanced.bonus).to eq(34)

      expect(Stats.aur).to eq([100, -35])
      expect(Stats.enhanced_log).to eq([118, 34])
    end

    it "handles levelup" do
      levelup = <<-Levelup
            Strength (STR) :  65   +1  ...      7    +1
        Constitution (CON) :  78   +1  ...      9
          Dexterity (DEX) :  37   +1  ...      4
            Agility (AGI) :  66   +1  ...     13
          Discipline (DIS) :  78   +1  ...      4
          Intuition (INT) :  66   +1  ...     13
              Wisdom (WIS) :  66   +1  ...     13
      Levelup
      levelup.split("\n").each {|line| 
        Infomon::Parser.parse(line).eql?(:ok) or fail ("did not parse:\n%s" % line.inspect)
      }
      
      expect(Infomon.get("stat.dexterity")).to eq(37)
      expect(Infomon.get("stat.dexterity.bonus")).to eq(4)
      expect(Infomon.get("stat.strength.bonus")).to eq(7)
    end
  end

  context "psm" do
    it "handles shield info" do
      output = <<-Shield
          Deflect the Elements deflectelements 1/3   Passive                                        
          Shield Bash          bash            4/5   Setup                                          
          Shield Forward       forward         3/3   Passive                                        
          Shield Spike Mastery spikemastery    2/2   Passive                                        
          Shield Swiftness     swiftness       3/3   Passive                                        
          Shield Throw         throw           5/5   Area of Effect                                 
          Small Shield Focus   sfocus          5/5   Passive      
      Shield
      output.split("\n").map {|line|
        Infomon::Parser.parse(line).eql?(:ok) or fail ("did not parse:\n%s" % line)
      }
    end

    it "handles cman info" do
      output = <<-Cman
          Cheapshots           cheapshots      6/6   Setup          Rogue Guild                     
          Combat Mobility      mobility        1/1   Passive                                        
          Combat Toughness     toughness       3/3   Passive                                        
          Cutthroat            cutthroat       3/5   Setup                                          
          Divert               divert          6/6   Setup          Rogue Guild                     
          Duck and Weave       duckandweave    3/3   Martial Stance                                 
          Evade Specialization evadespec       3/3   Passive                                        
          Eviscerate           eviscerate      4/5   Area of Effect                                 
          Eyepoke              eyepoke         6/6   Setup          Rogue Guild                     
          Footstomp            footstomp       6/6   Setup          Rogue Guild                     
          Hamstring            hamstring       3/5   Setup                                          
          Kneebash             kneebash        6/6   Setup          Rogue Guild                     
          Mug                  mug             1/5   Attack                                         
          Nosetweak            nosetweak       6/6   Setup          Rogue Guild                     
          Predator's Eye       predator        3/3   Martial Stance                                 
          Spike Focus          spikefocus      2/2   Passive                                        
          Stun Maneuvers       stunman         6/6   Buff           Rogue Guild                     
          Subdue               subdue          6/6   Setup          Rogue Guild                     
          Sweep                sweep           6/6   Setup          Rogue Guild                     
          Swiftkick            swiftkick       6/6   Setup          Rogue Guild                     
          Templeshot           templeshot      6/6   Setup          Rogue Guild                     
          Throatchop           throatchop      6/6   Setup          Rogue Guild                     
          Weapon Specializatio wspec           5/5   Passive                                        
          Whirling Dervish     dervish         3/3   Martial Stance                              
      Cman

      output.split("\n").map {|line|
        Infomon::Parser.parse(line).eql?(:ok) or fail ("did not parse:\n%s" % line)
      }
    end

    it "handles armor info" do
      output = <<-Armor
        Armor Blessing       blessing        1/5   Buff                                           
        Armor Reinforcement  reinforcement   2/5   Buff                                           
        Armor Spike Mastery  spikemastery    2/2   Passive                                        
        Armor Support        support         3/5   Buff                                           
        Armored Casting      casting         4/5   Buff                                           
        Armored Evasion      evasion         5/5   Buff                                           
        Armored Fluidity     fluidity        4/5   Buff                                           
        Armored Stealth      stealth         3/5   Buff                                           
        Crush Protection     crush           2/5   Passive                                        
        Puncture Protection  puncture        1/5   Passive                                        
        Slash Protection     slash           0/5   Passive                                        
      Armor

      output.split("\n").map {|line|
        Infomon::Parser.parse(line).eql?(:ok) or fail ("did not parse:\n%s" % line)
      }
    end

    it "handles weapon info" do
      output = <<-Weapon
        Cripple              cripple         5/5   Setup          Edged Weapons                   
        Flurry               flurry          5/5   Assault        Edged Weapons                   
        Riposte              riposte         5/5   Reaction       Edged Weapons                   
        Whirling Blade       wblade          5/5   Area of Effect Edged Weapons              
      Weapon

      output.split("\n").map {|line|
        Infomon::Parser.parse(line).eql?(:ok) or fail ("did not parse:\n%s" % line)
      }
    end

    it "handles feat info" do
      output = <<-Feat
        Light Armor Proficie lightarmor      1/1   Passive                                        
        Martial Mastery      martialmastery  1/1   Passive                                        
        Scale Armor Proficie scalearmor      1/1   Passive                                        
        Shadow Dance         shadowdance     1/1   Buff                                           
        Silent Strike        silentstrike    5/5   Attack                                         
        Vanish               vanish          1/1   Buff                                           
      Feat

      output.split("\n").map {|line|
        Infomon::Parser.parse(line).eql?(:ok) or fail ("did not parse:\n%s" % line)
      }
    end
  end
end