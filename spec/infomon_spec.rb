class Script
  def Script.current
    nil
  end
end

module Lich
  def self.log(msg)
    debug_filename = "debug-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}.log"
    $stderr = File.open(debug_filename, 'w')
    begin
      $stderr.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}: #{msg}"
    end
  end
end

class NilClass
  def method_missing(*)
    nil
  end
end

require 'rexml/document'
require 'rexml/streamlistener'
require 'open-uri'
require "spell"
download = URI.open('https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts/effect-list.xml').read
FileUtils.mkdir_p('/home/runner/work/lich-5/lich-5/data')
File.write('/home/runner/work/lich-5/lich-5/data/effect-list.xml', download)
Games::Gemstone::Spell.load('/home/runner/work/lich-5/lich-5/data/effect-list.xml')

require "infomon/infomon"
require "attributes/stats"
require "infomon/status"
require "experience"
require "psms"
module Infomon
  # cheat definition of `respond` to prevent having to load global_defs with dependenciesw
  def self.respond(msg)
    pp msg
  end
end

module XMLData
  @dialogs = {}
  def self.game
    "rspec"
  end

  def self.name
    "testing"
  end

  def self.indicator
    # shimming together a hash to test 'muckled?' results
    { 'IconSTUNNED' => 'n',
      'IconDEAD'    => 'n',
      'IconWEBBED'  => false }
  end

  def self.save_dialogs(kind, attributes)
    # shimming together response for testing status checks
    @dialogs[kind] ||= {}
    return @dialogs[kind] = attributes
  end

  def self.dialogs
    @dialogs ||= {}
  end
end

# stub in Effects module for testing - not suitable for testing Effects itself
module Effects
  class Registry
    include Enumerable

    def initialize(dialog)
      @dialog = dialog
    end

    def to_h
      XMLData.dialogs.fetch(@dialog, {})
    end

    def each()
      to_h.each { |k, v| yield(k, v) }
    end
  end

  Debuffs = Registry.new("Debuffs")
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
      expect(Infomon.get("citizenship")).to eq(%[Wehnimer's Landing])
    end

    it "handles no citizenship" do
      Infomon::Parser.parse %[You don't seem to have citizenship.]
      expect(Infomon.get("citizenship")).to eq("None")
    end
  end

  context "stats" do
    it "handles stats" do
      test_stats = <<~Stuffed
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
      test_stats.split("\n").each { |line| Infomon::Parser.parse(line) }

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
      levelup.split("\n").each { |line| Infomon::Parser.parse(line) }

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

      output.split("\n").map { |line| Infomon::Parser.parse(line) }

      expect(Infomon.get("experience.fame")).to eq(4_804_958)
      expect(Infomon.get("experience.field_experience_current")).to eq(1_350)
      expect(Infomon.get("experience.field_experience_max")).to eq(1_010)
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
      output = <<~Shield
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
      output.split("\n").map { |line| Infomon::Parser.parse(line) }

      expect(Infomon.get("psm.bash")).to eq(4)
      expect(Infomon.get("psm.throw")).to eq(5)
    end

    it "handles cman info" do
      output = <<~Cman
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

      output.split("\n").map { |line| Infomon::Parser.parse(line) }

      expect(Infomon.get("psm.toughness")).to eq(3)
      expect(Infomon.get("psm.subdue")).to eq(6)
    end

    it "handles armor info" do
      output = <<~Armor
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
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get("psm.support")).to eq(3)
      expect(Infomon.get("psm.crush")).to eq(2)
    end

    it "handles weapon info" do
      output = <<~Weapon
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
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get("psm.flurry")).to eq(5)
      expect(Infomon.get("psm.riposte")).to eq(5)
    end

    it "handles feat info" do
      output = <<~Feat
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
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get("psm.martialmastery")).to eq(1)
      expect(Infomon.get("psm.silentstrike")).to eq(5)
    end

    it "handles Learning a new PSM" do
      # Check LearnPSM
      Infomon.set('psm.krynch', 1)
      Infomon.set('psm.vaultkick', 0)
      # Check LearnTechnique
      Infomon.set('psm.perfectself', 0)
      Infomon.set('psm.pin', 2)
      output = <<~Learning
        You have now achieved rank 2 of Rolling Krynch Stance, costing 6 Combat Maneuver points.
        You have now achieved rank 1 of Vault Kick, costing 2 Combat Maneuver points.
        [You have gained rank 1 of Feat: Perfect Self.]
        [You have increased to rank 3 of Shield Specialization: Pin.]
      Learning
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get("psm.krynch")).to eq(2)
      expect(Infomon.get("psm.vaultkick")).to eq(1)
      expect(Infomon.get("psm.perfectself")).to eq(1)
      expect(Infomon.get("psm.pin")).to eq(3)
    end

    it "handles Unlearning an existing PSM" do
      # Check UnlearnPSM
      Infomon.set('psm.krynch', 1)
      Infomon.set('psm.vaultkick', 5)
      # Check UnlearnTechnique
      Infomon.set('psm.stealth', 2)
      Infomon.set('psm.pin', 2)
      # Check LostTechnique
      Infomon.set("psm.fury", 1)
      output = <<~Unlearnings
        You decide to unlearn rank 5 of Vault Kick, regaining 20 Combat Maneuver points.
        You decide to unlearn rank 1 of Rolling Krynch Stance, regaining 2 Combat Maneuver points.
        [You have decreased to rank 1 of Armor Specialization: Armored Stealth.]
        [You have decreased to rank 1 of Shield Specialization: Pin.]
        [You are no longer trained in Weapon Technique: Fury.]
      Unlearnings
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get("psm.krynch")).to eq(0)
      expect(Infomon.get('psm.vaultkick')).to eq(4)
      expect(Infomon.get("psm.stealth")).to eq(1)
      expect(Infomon.get("psm.pin")).to eq(1)
      expect(Infomon.get("psm.fury")).to eq(0)
    end
  end

  context "warcry" do
    it "handles warcry info" do
      output = <<~Warcry
        You have learned the following War Cries:
            Bertrandt's Bellow
            Yertie's Yowlp
            Gerrelle's Growl
            Seanette's Shout
            Carn's Cry
            Horland's Holler
        Warcry
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get("psm.cry")).to eq(1)
      expect(Infomon.get("psm.yowlp")).to eq(1)
    end
  end

  context "Society status" do
    it "handles no society" do
      output = <<~SocietyCommand
      Current society status:
         You are not a member of any society at this time.
      SocietyCommand

      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get('society.status')).to eq('None')
    end

    it "handles member of society" do
      output = <<~SocietyStatus
      Current society status:
         You are a member in the Order of Voln at step 13.
      SocietyStatus
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get('society.status')).to eq('Order of Voln')
      expect(Infomon.get('society.rank')).to eq(13)
    end

    it "handles master of society" do
      output = <<~SocietyMaster
      Current society status:
         You are a Master in the Council of Light.
      SocietyMaster
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get('society.status')).to eq('Council of Light')
      expect(Infomon.get('society.rank')).to eq(20)
    end
  end

  context "Society Join or Resign" do
    it "handles joining a society" do
      output = <<~SocietyJoin
      The Grandmaster says, "Welcome to the Order of Voln."
      SocietyJoin
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get('society.status')).to eq('Order of Voln')
      expect(Infomon.get('society.rank')).to eq(1)
    end

    it "handles joining a society (test2)" do
      output = <<~SocietyJoin
      The Grandmaster says, "You are now a member of the Guardians of Sunfist."
      SocietyJoin
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get('society.status')).to eq('Guardians of Sunfist')
      expect(Infomon.get('society.rank')).to eq(0)
    end

    it "handles resigning froim a society" do
      output = <<~SocietyResign
      The Grandmaster says, "I'm sorry to hear that.  You are no longer in our service.
      SocietyResign
      output.split("\n").map { |line| Infomon::Parser.parse(line) }
      expect(Infomon.get('society.status')).to eq('None')
      expect(Infomon.get('society.rank')).to eq(0)
    end
  end

  context "Infomon.show displays 0 values, or not" do
    it "handles Infomon.show(full = true) and (full = false)" do
      Infomon.set('psm.krynch', 1)
      Infomon.set('skill.ambush', 1)
      Infomon.set('skill.swimming', 0)
      Infomon.set('society.status', 'None')
      test_results = Infomon.show(true)
      expect(test_results.any? { |s| s.include?('psm.krynch : 1') }).to be(true)
      expect(test_results.any? { |s| s.include?('skill.swimming : 0') }).to be(true)
      expect(test_results.any? { |s| s.include?('society.status : "None"') }).to be(true)
      test2_results = Infomon.show
      expect(test2_results.any? { |s| s.include?('psm.krynch : 1') }).to be(true)
      expect(test2_results.any? { |s| s.include?('skill.ambush : 1') }).to be(true)
      expect(test2_results.any? { |s| s.include?('skill.swimming : 0') }).to be(false)
    end
  end

  context "db feature method - Infomon.delete!(key)" do
    it "allows for selective deletion of a row in the infomon.db" do
      Infomon.set('skill.edged_weapon', 1)
      Infomon.set('psm.pummel', 5)
      Infomon.set('stat.aura_bonus', 18)
      expect(Infomon.get('skill.edged_weapon')).to eq(1)
      expect(Infomon.get('psm.pummel')).to eq(5)
      expect(Infomon.get('stat.aura_bonus')).to eq(18)
      Infomon.delete!('psm.pummel')
      expect(Infomon.get('skill.edged_weapon')).to eq(1)
      expect(Infomon.get('psm.pummel')).to be(nil)
      expect(Infomon.get('stat.aura_bonus')).to eq(18)
      Infomon.delete!('stat.aura_bonus')
      expect(Infomon.get('skill.edged_weapon')).to eq(1)
      expect(Infomon.get('stat.aura_bonus')).to be(nil)
    end
  end

  # booleen status checks below

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
      XMLData.save_dialogs("Debuffs", { 'Sleep' => true }) # to test if Effects has this key
      expect(Status.sleeping?).to be(true)
      expect(Status.muckled?).to be(true) # discount IconMAP presently - future update
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
      expect(Status.sleeping?).to be(false)
      expect(Status.muckled?).to be(false)
    end

    it "handles bound? boolean true" do
      output = <<~TestInput
        An unseen force envelops you, restricting all movement.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
      XMLData.save_dialogs("Debuffs", { 'Bind' => true }) # to test if Effects has this key
      expect(Status.bound?).to be(true)
      expect(Status.muckled?).to be(true)
    end

    it "handles bound? boolean false" do
      output = <<~TestInput
        The restricting force that envelops you dissolves away.
        You shake off the immobilization that was restricting your movements!
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
      expect(Status.bound?).to be(false)
      expect(Status.muckled?).to be(false)
    end

    it "handles silenced? boolean true" do
      output = <<~TestInput
        A pall of silence settles over you.
        The pall of silence settles more heavily over you.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
      XMLData.save_dialogs("Debuffs", { 'Silenced' => true }) # to test if Effects has this key
      expect(Status.silenced?).to be(true)
      expect(Status.muckled?).to be(false)
    end

    it "handles silenced? boolean false" do
      output = <<~TestInput
        The pall of silence leaves you.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
      expect(Status.silenced?).to be(false)
      expect(Status.muckled?).to be(false)
    end

    it "handles calmed? boolean true" do
      output = <<~TestInput
        A calm washes over you.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
      XMLData.save_dialogs("Debuffs", { 'Calm' => true }) # to test if Effects has this key
      expect(Status.calmed?).to be(true)
      expect(Status.muckled?).to be(false)
    end

    it "handles calmed? boolean false" do
      output = <<~TestInput
        You are enraged by Ferenghi Warlord's attack!
        The feeling of calm leaves you.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
      expect(Status.calmed?).to be(false)
      expect(Status.muckled?).to be(false)
    end

    it "handles cutthroat? boolean true" do
      output = <<~TestInput
        The Ferenghi Warlord slices deep into your vocal cords!
        All you manage to do is cough up some blood.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
      XMLData.save_dialogs("Debuffs", { 'Major Bleed' => true }) # to test if Effects has this key
      expect(Status.cutthroat?).to be(true)
      expect(Status.muckled?).to be(false)
    end

    it "handles cutthroat? boolean false" do
      output = <<~TestInput
        The horrible pain in your vocal cords subsides as you spit out the last of the blood clogging your throat.
      TestInput
      output.split("\n").map { |line|
        Infomon::Parser.parse(line).eql?(:ok) or fail("did not parse:\n%s" % line)
      }
      expect(Status.cutthroat?).to be(false)
      expect(Status.muckled?).to be(false)
    end
  end

  context "db performance" do
    it "has a cache that will lazily load" do
      k = "answer.life"
      # big sample size so we can be sure about some sane access rules
      100.times do
        Infomon.reset!
        Infomon.cache.flush!

        expect(Infomon.get(k)).to be_nil
        Infomon.set(k, 42)
        expect(Infomon.get(k)).to eq(42)
        expect(Infomon.cache.include?(k)).to be(true)
        Infomon.cache.flush!
        # no longer in cache
        expect(Infomon.cache.include?(k)).to be(false)
        # will load from DB
        expect(Infomon.get(k)).to eq(42)
        # is now back in cache
        expect(Infomon.cache.include?(k)).to be(true)
      end
    end

    it "can handle 100 scripts accessing it simultaneously" do
      k = "answer.life"
      # if this ever breaks, we have a problem with the way this interacts with scripts
      scripts = (0..99).to_a.map { |n|
        Thread.new {
          Infomon.set(k, n)
          expect((0..99).include?(n)).to be(true)
          sleep rand
          Infomon.set(k, n)
          expect((0..99).include?(n)).to be(true)
        }
      }
      scripts.map(&:value)
    end
  end
end
