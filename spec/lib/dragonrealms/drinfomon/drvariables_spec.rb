# frozen_string_literal: true

require 'rspec'

require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'

RSpec.describe 'Lich::DragonRealms constants' do
  describe 'DR_LEARNING_RATES' do
    let(:rates) { Lich::DragonRealms::DR_LEARNING_RATES }

    it 'is frozen' do
      expect(rates).to be_frozen
    end

    it 'has 35 learning rate levels' do
      expect(rates.length).to eq(35)
    end

    it 'starts with clear' do
      expect(rates.first).to eq('clear')
    end

    it 'ends with mind lock' do
      expect(rates.last).to eq('mind lock')
    end

    it 'includes common mindstates' do
      expect(rates).to include('dabbling')
      expect(rates).to include('learning')
      expect(rates).to include('focused')
      expect(rates).to include('enthralled')
    end
  end

  describe 'DR_LONGEST_LEARNING_RATE_LENGTH' do
    it 'equals the length of the longest rate name' do
      max_len = Lich::DragonRealms::DR_LEARNING_RATES.max_by(&:length).length
      expect(Lich::DragonRealms::DR_LONGEST_LEARNING_RATE_LENGTH).to eq(max_len)
    end

    it 'equals 13 (for "nearly locked")' do
      expect(Lich::DragonRealms::DR_LONGEST_LEARNING_RATE_LENGTH).to eq(13)
    end
  end

  describe 'DR_BALANCE_VALUES' do
    let(:values) { Lich::DragonRealms::DR_BALANCE_VALUES }

    it 'is frozen' do
      expect(values).to be_frozen
    end

    it 'has 12 balance levels' do
      expect(values.length).to eq(12)
    end

    it 'includes balance states' do
      expect(values).to include('completely')
      expect(values).to include('solidly')
      expect(values).to include('incredibly')
    end
  end

  describe 'DR_SKILLS_DATA' do
    let(:data) { Lich::DragonRealms::DR_SKILLS_DATA }

    it 'is frozen' do
      expect(data).to be_frozen
    end

    it 'has skillsets key' do
      expect(data).to have_key(:skillsets)
    end

    it 'has guild_skill_aliases key' do
      expect(data).to have_key(:guild_skill_aliases)
    end

    describe 'skillsets' do
      let(:skillsets) { data[:skillsets] }

      it 'is frozen' do
        expect(skillsets).to be_frozen
      end

      it 'has 5 skillsets' do
        expect(skillsets.keys).to contain_exactly('Armor', 'Lore', 'Weapon', 'Magic', 'Survival')
      end

      it 'has frozen skill arrays' do
        skillsets.each do |name, skills|
          expect(skills).to be_frozen, "#{name} skills should be frozen"
        end
      end

      it 'includes Evasion in Survival' do
        expect(skillsets['Survival']).to include('Evasion')
      end

      it 'includes Primary Magic in Magic' do
        expect(skillsets['Magic']).to include('Primary Magic')
      end
    end

    describe 'guild_skill_aliases' do
      let(:aliases) { data[:guild_skill_aliases] }

      it 'is frozen' do
        expect(aliases).to be_frozen
      end

      it 'has aliases for magic guilds' do
        expect(aliases.keys).to include('Moon Mage', 'Warrior Mage', 'Cleric')
      end

      it 'maps Primary Magic to Lunar Magic for Moon Mage' do
        expect(aliases['Moon Mage']['Primary Magic']).to eq('Lunar Magic')
      end

      it 'maps Primary Magic to Inner Fire for Barbarian' do
        expect(aliases['Barbarian']['Primary Magic']).to eq('Inner Fire')
      end

      it 'has frozen inner hashes' do
        aliases.each do |guild, alias_hash|
          expect(alias_hash).to be_frozen, "#{guild} aliases should be frozen"
        end
      end
    end
  end

  describe 'bank constants' do
    describe 'KRONAR_BANKS' do
      it 'is frozen' do
        expect(Lich::DragonRealms::KRONAR_BANKS).to be_frozen
      end

      it 'includes Crossings' do
        expect(Lich::DragonRealms::KRONAR_BANKS).to include('Crossings')
      end
    end

    describe 'LIRUM_BANKS' do
      it 'is frozen' do
        expect(Lich::DragonRealms::LIRUM_BANKS).to be_frozen
      end

      it 'includes Riverhaven' do
        expect(Lich::DragonRealms::LIRUM_BANKS).to include('Riverhaven')
      end
    end

    describe 'DOKORA_BANKS' do
      it 'is frozen' do
        expect(Lich::DragonRealms::DOKORA_BANKS).to be_frozen
      end

      it 'includes Shard' do
        expect(Lich::DragonRealms::DOKORA_BANKS).to include('Shard')
      end
    end

    describe 'BANK_TITLES' do
      it 'is frozen' do
        expect(Lich::DragonRealms::BANK_TITLES).to be_frozen
      end

      it 'has frozen arrays for each bank' do
        Lich::DragonRealms::BANK_TITLES.each do |name, titles|
          expect(titles).to be_frozen, "#{name} titles should be frozen"
        end
      end
    end

    describe 'VAULT_TITLES' do
      it 'is frozen' do
        expect(Lich::DragonRealms::VAULT_TITLES).to be_frozen
      end

      it 'has frozen arrays for each vault' do
        Lich::DragonRealms::VAULT_TITLES.each do |name, titles|
          expect(titles).to be_frozen, "#{name} titles should be frozen"
        end
      end
    end
  end

  describe 'HOMETOWN_REGEX_MAP' do
    let(:map) { Lich::DragonRealms::HOMETOWN_REGEX_MAP }

    it 'is frozen' do
      expect(map).to be_frozen
    end

    it 'has regex values' do
      map.each do |name, regex|
        expect(regex).to be_a(Regexp), "#{name} should map to a Regexp"
      end
    end

    it 'matches various hometown formats' do
      expect('crossing').to match(map['Crossing'])
      expect('cross').to match(map['Crossing'])
      expect('theren').to match(map['Therenborough'])
      expect('Therenborough').to match(map['Therenborough'])
    end
  end

  describe 'HOMETOWN_LIST' do
    it 'is frozen' do
      expect(Lich::DragonRealms::HOMETOWN_LIST).to be_frozen
    end

    it 'contains canonical hometown names' do
      expect(Lich::DragonRealms::HOMETOWN_LIST).to include('Crossing')
      expect(Lich::DragonRealms::HOMETOWN_LIST).to include('Therenborough')
      expect(Lich::DragonRealms::HOMETOWN_LIST).to include('Shard')
    end
  end

  describe 'HOMETOWN_REGEX' do
    it 'is a Regexp' do
      expect(Lich::DragonRealms::HOMETOWN_REGEX).to be_a(Regexp)
    end

    it 'matches hometown names' do
      expect('crossing').to match(Lich::DragonRealms::HOMETOWN_REGEX)
      expect('Riverhaven').to match(Lich::DragonRealms::HOMETOWN_REGEX)
    end
  end

  describe 'ORDINALS' do
    it 'is frozen' do
      expect(Lich::DragonRealms::ORDINALS).to be_frozen
    end

    it 'has 20 ordinals' do
      expect(Lich::DragonRealms::ORDINALS.length).to eq(20)
    end

    it 'starts with first' do
      expect(Lich::DragonRealms::ORDINALS.first).to eq('first')
    end

    it 'ends with twentieth' do
      expect(Lich::DragonRealms::ORDINALS.last).to eq('twentieth')
    end
  end

  describe 'CURRENCIES' do
    it 'is frozen' do
      expect(Lich::DragonRealms::CURRENCIES).to be_frozen
    end

    it 'contains DR currencies' do
      expect(Lich::DragonRealms::CURRENCIES).to contain_exactly('Kronars', 'Lirums', 'Dokoras')
    end
  end

  describe 'ENC_MAP' do
    it 'is frozen' do
      expect(Lich::DragonRealms::ENC_MAP).to be_frozen
    end

    it 'maps encumbrance strings to numeric values' do
      expect(Lich::DragonRealms::ENC_MAP['None']).to eq(0)
      expect(Lich::DragonRealms::ENC_MAP['Overburdened']).to eq(6)
    end

    it 'has 12 encumbrance levels' do
      expect(Lich::DragonRealms::ENC_MAP.length).to eq(12)
    end
  end

  describe 'NUM_MAP' do
    it 'is frozen' do
      expect(Lich::DragonRealms::NUM_MAP).to be_frozen
    end

    it 'maps number words to integers' do
      expect(Lich::DragonRealms::NUM_MAP['one']).to eq(1)
      expect(Lich::DragonRealms::NUM_MAP['ten']).to eq(10)
      expect(Lich::DragonRealms::NUM_MAP['twenty']).to eq(20)
    end
  end

  describe 'BOX_REGEX' do
    it 'matches box patterns' do
      expect('brass box').to match(Lich::DragonRealms::BOX_REGEX)
      expect('steel strongbox').to match(Lich::DragonRealms::BOX_REGEX)
      expect('mahogany chest').to match(Lich::DragonRealms::BOX_REGEX)
    end

    it 'does not match non-box items' do
      expect('golden ring').not_to match(Lich::DragonRealms::BOX_REGEX)
    end
  end

  describe 'MANA_MAP' do
    it 'is frozen' do
      expect(Lich::DragonRealms::MANA_MAP).to be_frozen
    end

    it 'has frozen arrays' do
      Lich::DragonRealms::MANA_MAP.each do |level, words|
        expect(words).to be_frozen, "#{level} words should be frozen"
      end
    end

    it 'maps perception levels to mana words' do
      expect(Lich::DragonRealms::MANA_MAP['weak']).to include('dim')
      expect(Lich::DragonRealms::MANA_MAP['good']).to include('blazing')
    end
  end

  describe 'sigil patterns' do
    describe 'PRIMARY_SIGILS_PATTERN' do
      it 'matches primary sigils' do
        expect('abolition sigil').to match(Lich::DragonRealms::PRIMARY_SIGILS_PATTERN)
        expect('congruence sigil').to match(Lich::DragonRealms::PRIMARY_SIGILS_PATTERN)
      end
    end

    describe 'SECONDARY_SIGILS_PATTERN' do
      it 'matches secondary sigils' do
        expect('antipode sigil').to match(Lich::DragonRealms::SECONDARY_SIGILS_PATTERN)
        expect('metamorphosis sigil').to match(Lich::DragonRealms::SECONDARY_SIGILS_PATTERN)
      end
    end
  end

  describe 'VOL_MAP' do
    it 'is frozen' do
      expect(Lich::DragonRealms::VOL_MAP).to be_frozen
    end

    it 'maps volume words to multipliers' do
      expect(Lich::DragonRealms::VOL_MAP['tiny']).to eq(1)
      expect(Lich::DragonRealms::VOL_MAP['enormous']).to eq(20)
    end
  end

  describe 'backward compatibility global aliases' do
    it 'defines $HOMETOWN_REGEX_MAP' do
      expect($HOMETOWN_REGEX_MAP).to eq(Lich::DragonRealms::HOMETOWN_REGEX_MAP)
    end

    it 'defines $HOMETOWN_LIST' do
      expect($HOMETOWN_LIST).to eq(Lich::DragonRealms::HOMETOWN_LIST)
    end

    it 'defines $HOMETOWN_REGEX' do
      expect($HOMETOWN_REGEX).to eq(Lich::DragonRealms::HOMETOWN_REGEX)
    end

    it 'defines $ORDINALS' do
      expect($ORDINALS).to eq(Lich::DragonRealms::ORDINALS)
    end

    it 'defines $CURRENCIES' do
      expect($CURRENCIES).to eq(Lich::DragonRealms::CURRENCIES)
    end

    it 'defines $ENC_MAP' do
      expect($ENC_MAP).to eq(Lich::DragonRealms::ENC_MAP)
    end

    it 'defines $NUM_MAP' do
      expect($NUM_MAP).to eq(Lich::DragonRealms::NUM_MAP)
    end

    it 'defines $box_regex' do
      expect($box_regex).to eq(Lich::DragonRealms::BOX_REGEX)
    end

    it 'defines $MANA_MAP' do
      expect($MANA_MAP).to eq(Lich::DragonRealms::MANA_MAP)
    end

    it 'defines $PRIMARY_SIGILS_PATTERN' do
      expect($PRIMARY_SIGILS_PATTERN).to eq(Lich::DragonRealms::PRIMARY_SIGILS_PATTERN)
    end

    it 'defines $SECONDARY_SIGILS_PATTERN' do
      expect($SECONDARY_SIGILS_PATTERN).to eq(Lich::DragonRealms::SECONDARY_SIGILS_PATTERN)
    end

    it 'defines $VOL_MAP' do
      expect($VOL_MAP).to eq(Lich::DragonRealms::VOL_MAP)
    end
  end
end
