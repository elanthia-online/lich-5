require "infomon/infomon"
require "attributes/stats"
require "experience"

module Char
  def self.name
    "testing"
  end
end

module XMLData
  def self.game
    "rspec"
  end
  def self.name
    "testing"
  end
end

describe Infomon, ".setup!" do
  context "can set itself up" do
    it "creates a db" do
      Infomon.setup!
      File.exist?(Infomon.file) or fail("infomon sqlite db was not created")
    end
  end

  context "can manipulate data" do
    it "upserts a new key/value pair" do
      k = "stat.influence"
      # handles when value doesn't exist
      Infomon.queue.push(:type => 'set', :value => [k, 30])
      expect(Infomon.get(k)).to eq(30)
      Infomon.queue.push(:type => 'set', :value => [k, 40])
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
      pp Infomon::Parser.parse %[You currently have full citizenship in Wehnimer's Landing.]
      expect(Infomon.get("citizenship")).to eq(%[Wehnimer's Landing])
    end

    it "handles no citizenship" do
      pp Infomon::Parser.parse %[You don't seem to have citizenship.]
      expect(Infomon.get("citizenship")).to eq("None")
    end
  end

  context "stats" do
    it "handles stats" do
      test_stats = <<-Stuffed
Name: testing Race: Half-Krolvin  Profession: Monk (not shown)
Gender: Male    Age: 0    Expr: 167,500    Level:  12
              Strength (STR):   110 (30)    ...  110 (30)
          Constitution (CON):   104 (22)    ...  104 (22)
             Dexterity (DEX):   100 (35)    ...  100 (35)
               Agility (AGI):   100 (30)    ...  100 (30)
            Discipline (DIS):   110 (20)    ...  110 (20)
                  Aura (AUR):   100 (-35)   ...  100 (35)
                 Logic (LOG):   108 (29)    ...  118 (34)
             Intuition (INT):    99 (29)    ...   99 (29)
                Wisdom (WIS):    84 (22)    ...   84 (22)
             Influence (INF):   100 (20)    ...  108 (24)
Mana:  415   Silver: 0
Stuffed
      test_stats.split("\n").each { |line| pp Infomon::Parser.parse(line) }

      expect(Infomon.get("stat.aura")).to eq(100)
      expect(Infomon.get("stat.aura_bonus")).to eq(-35)
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
      levelup.split("\n").each { |line| pp Infomon::Parser.parse(line) }

      expect(Infomon.get("stat.dexterity")).to eq(37)
      expect(Infomon.get("stat.dexterity_bonus")).to eq(4)
      expect(Infomon.get("stat.strength_bonus")).to eq(7)
    end

    it "handles experience info" do
      output = <<-Experience
                  Level: 100                         Fame: 4,804,958
             Experience: 37,136,999             Field Exp: 1,350/1,010
          Ascension Exp: 4,170,132          Recent Deaths: 0
              Total Exp: 41,307,131         Death's Sting: None
          Long-Term Exp: 26,266                     Deeds: 20
          Exp until lvl: 30,000
      Experience

      output.split("\n").map { |line| pp Infomon::Parser.parse(line) }

      expect(Infomon.get("experience.fame")).to eq(4_804_958)
      expect(Infomon.get("experience.fxp_current")).to eq(1_350)
      expect(Infomon.get("experience.fxp_max")).to eq(1_010)
      expect(Infomon.get("experience.ascension_experience")).to eq(4_170_132)
      expect(Infomon.get("experience.total_experience")).to eq(41_307_131)
      expect(Infomon.get("experience.long_term_experience")).to eq(26_266)
      expect(Infomon.get("experience.deeds")).to eq(20)

      expect(Experience.fame).to eq(4_804_958)
      expect(Experience.fxp_current).to eq(1_350)
      expect(Experience.fxp_max).to eq(1_010)
      expect(Experience.axp).to eq(4_170_132)
      expect(Experience.txp).to eq(41_307_131)
      expect(Experience.lte).to eq(26_266)
      expect(Experience.deeds).to eq(20)
    end
  end

  context "psm" do
    it "handles shield info" do
      output = <<-Shield
testing, the following Shield Specializations are available:

          Skill                Mnemonic        Ranks Type           Category        Subcategory
          -------------------------------------------------------------------------------------
          Deflect the Elements deflectelements 1/3   Passive
          Shield Bash          bash            4/5   Setup
          Shield Forward       forward         3/3   Passive
          Shield Spike Mastery spikemastery    2/2   Passive
          Shield Swiftness     swiftness       3/3   Passive
          Shield Throw         throw           5/5   Area of Effect
          Small Shield Focus   sfocus          5/5   Passive
        The output listed above was generated based on the following filters:
          Availability: profession
                  Type: all
              Category: all
   Subcategory: all
Shield
      output.split("\n").map { |line| pp Infomon::Parser.parse(line) }

      expect(Infomon.get("psm.bash")).to eq(4)
      expect(Infomon.get("psm.throw")).to eq(5)
    end

    it "handles cman info" do
      output = <<-Cman
testing, the following Combat Maneuvers are available:

                  Skill                Mnemonic        Ranks Type           Category        Subcategory
                  -------------------------------------------------------------------------------------
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

                The output listed above was generated based on the following filters:
                  Availability: profession
                          Type: all
                      Category: all
   Subcategory: all
Cman

      output.split("\n").map { |line| pp Infomon::Parser.parse(line) }

      expect(Infomon.get("psm.toughness")).to eq(3)
      expect(Infomon.get("psm.subdue")).to eq(6)
    end

    it "handles armor info" do
      output = <<-Armor
testing, the following Armor Specializations are available:

        Skill                Mnemonic        Ranks Type           Category        Subcategory
        -------------------------------------------------------------------------------------
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
      The output listed above was generated based on the following filters:
        Availability: profession
                Type: all
            Category: all
   Subcategory: all
Armor

      output.split("\n").map { |line| pp Infomon::Parser.parse(line) }

      expect(Infomon.get("psm.support")).to eq(3)
      expect(Infomon.get("psm.crush")).to eq(2)
    end

    it "handles weapon info" do
      output = <<-Weapon
testing, the following Weapon Techniques are available:

      Skill                Mnemonic        Ranks Type           Category        Subcategory
      -------------------------------------------------------------------------------------
        Cripple              cripple         5/5   Setup          Edged Weapons
        Flurry               flurry          5/5   Assault        Edged Weapons
        Riposte              riposte         5/5   Reaction       Edged Weapons
        Whirling Blade       wblade          5/5   Area of Effect Edged Weapons
      The output listed above was generated based on the following filters:
       Availability: profession
                Type: all
            Category: all
   Subcategory: all
Weapon

      output.split("\n").map { |line| pp Infomon::Parser.parse(line) }

      expect(Infomon.get("psm.flurry")).to eq(5)
      expect(Infomon.get("psm.riposte")).to eq(5)
    end

    it "handles feat info" do
      output = <<-Feat
testing, the following Feats are available:

        Skill                Mnemonic        Ranks Type           Category        Subcategory
        -------------------------------------------------------------------------------------
        Light Armor Proficie lightarmor      1/1   Passive
        Martial Mastery      martialmastery  1/1   Passive
        Scale Armor Proficie scalearmor      1/1   Passive
        Shadow Dance         shadowdance     1/1   Buff
        Silent Strike        silentstrike    5/5   Attack
        Vanish               vanish          1/1   Buff
      The output listed above was generated based on the following filters:
        Availability: profession
                Type: all
            Category: all
   Subcategory: all
Feat

      output.split("\n").map { |line| pp Infomon::Parser.parse(line) }

      expect(Infomon.get("psm.martialmastery")).to eq(1)
      expect(Infomon.get("psm.silentstrike")).to eq(5)
    end
  end

  context "booleans" do
    it "handles sleeping? boolean true" do
      output = <<~TestInput
        Your mind goes completely blank.
        You close your eyes and slowly drift off to sleep.
        You slump to the ground and immediately fall asleep.  You must have been exhausted!
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
    end

    it "handles sleeping? boolean false" do
      output = <<~TestInput
        Your thoughts slowly come back to you as you find yourself lying on the ground.  You must have been sleeping.
        You wake up from your slumber.
        You are awoken by a sloth bear!
        You awake
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
    end

    it "handles bound? boolean true" do
      output = <<~TestInput
        An unseen force envelops you, restricting all movement.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
    end

    it "handles bound? boolean false" do
      output = <<~TestInput
        The restricting force that envelops you dissolves away.
        You shake off the immobilization that was restricting your movements!
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
    end

    it "handles silenced? boolean true" do
      output = <<~TestInput
        A pall of silence settles over you.
        The pall of silence settles more heavily over you.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
    end

    it "handles silenced? boolean false" do
      output = <<~TestInput
        The pall of silence leaves you.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
    end

    it "handles calmed? boolean true" do
      output = <<~TestInput
        A calm washes over you.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
    end

    it "handles calmed? boolean false" do
      output = <<~TestInput
        You are enraged by Ferenghi Warlord's attack!
        The feeling of calm leaves you.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
    end

    it "handles cutthroat? boolean true" do
      output = <<~TestInput
        The Ferenghi Warlord slices deep into your vocal cords!
        All you manage to do is cough up some blood.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
    end

    it "handles cutthroat? boolean false" do
      output = <<~TestInput
        The horrible pain in your vocal cords subsides as you spit out the last of the blood clogging your throat.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
    end
  end
end
