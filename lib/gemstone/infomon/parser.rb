# frozen_string_literal: true

module Lich
  module Gemstone
    module Infomon
      # this module handles all of the logic for parsing game lines that infomon depends on
      module Parser
        module Pattern
          # Regex patterns grouped for Info, Exp, Skill and PSM parsing - calls upsert_batch to reduce db impact
          CharRaceProf = /^Name:\s+(?<name>[A-z\s'-]+)\s+Race:\s+(?<race>[A-z]+|[A-z]+(?: |-)[A-z]+)\s+Profession:\s+(?<profession>[-A-z]+)/.freeze
          CharGenderAgeExpLevel = /^Gender:\s+(?<gender>[A-z]+)\s+Age:\s+(?<age>[,0-9]+)\s+Expr:\s+(?<experience>[0-9,]+)\s+Level:\s+(?<level>[0-9]+)/.freeze
          Stat = /^\s*(?<stat>[A-z]+)\s\((?:STR|CON|DEX|AGI|DIS|AUR|LOG|INT|WIS|INF)\):\s+(?<value>[0-9]+)\s\((?<bonus>-?[0-9]+)\)\s+[.]{3}\s+(?<enhanced_value>\d+)\s+\((?<enhanced_bonus>-?\d+)\)/.freeze
          StatEnd = /^Mana:\s+-?\d+\s+Silver:\s(?<silver>-?[\d,]+)$/.freeze
          Fame = /^\s+Level: \d+\s+Fame: (?<fame>-?[\d,]+)$/.freeze # serves as ExprStart
          RealExp = %r{^\s+Experience: [\d,]+\s+Field Exp: (?<fxp_current>[\d,]+)/(?<fxp_max>[\d,]+)$}.freeze
          AscExp = /^\s+Ascension Exp: (?<ascension_experience>[\d,]+)\s+Recent Deaths: [\d,]+$/.freeze
          TotalExp = /^\s+Total Exp: (?<total_experience>[\d,]+)\s+Death's Sting: (?<deaths_sting>None|Light|Moderate|Sharp|Harsh|Piercing|Crushing)$/.freeze
          LTE = /^\s+Long-Term Exp: (?<long_term_experience>[\d,]+)\s+Deeds: (?<deeds>\d+)$/.freeze
          ExprEnd = /^\s+Exp (?:until lvl|to next TP): -?[\d,]+/.freeze
          SkillStart = /^\s\w+\s\(at level \d+\), your current skill bonuses and ranks/.freeze
          Skill = /^\s+(?<name>[[a-zA-Z]\s\-']+)\.+\|\s+(?<bonus>\d+)\s+(?<ranks>\d+)/.freeze
          SpellRanks = /^\s+(?<name>[\w\s\-']+)\.+\|\s+(?<rank>\d+).*$/.freeze
          SkillEnd = /^Training Points: \d+ Phy \d+ Mnt/.freeze
          GoalsDetected = /^Skill goals updated!$/.freeze
          GoalsEnded = /^Further information can be found in the FAQs\.$/.freeze
          PSMStart = /^\w+, the following (?<cat>Ascension Abilities|Armor Specializations|Combat Maneuvers|Feats|Shield Specializations|Weapon Techniques) are available:$/.freeze
          PSM = /^\s+(?<name>[A-z\s\-':]+)\s+(?<command>[a-z]+)\s+(?<ranks>\d+)\/(?<max>\d+).*$/.freeze
          PSMEnd = /^   Subcategory: all$/.freeze

          # Single / low impact - single db write
          Levelup = /^\s+(?<stat>\w+)\s+\(\w{3}\)\s+:\s+(?<value>\d+)\s+(?:\+1)\s+\.\.\.\s+(?<bonus>\d+)(?:\s+\+1)?$/.freeze
          SpellsSolo = /^(?<name>Bard|Cleric|Empath|Minor (?:Elemental|Mental|Spiritual)|Major (?:Elemental|Mental|Spiritual)|Paladin|Ranger|Savant|Sorcerer|Wizard)(?: Base)?\.+(?<rank>\d+).*$/.freeze # from SPELL command
          Citizenship = /^You currently have .*? citizenship in (?<town>.*)\.$/.freeze
          NoCitizenship = /^You don't seem to have citizenship\./.freeze
          Society = /^\s+You are a (?<standing>Master|member) (?:in|of) the (?<society>Order of Voln|Council of Light|Guardians of Sunfist)(?: at (?:rank|step) (?<rank>[0-9]+))?\.$/.freeze
          NoSociety = /^\s+You are not a member of any society at this time./.freeze
          SocietyStep = /^(?:Zarak|Faylanna|Draelox|Marl|Vindar|Taryn|Meaha|Oxanna|Cyndelle) traces the outline of a sigil into the air before you and says|^The High Taskmaster looks at you, consults (?:her|his) notes, and then announces in a loud voice|^The monk concludes ceremoniously,/.freeze
          SocietyJoin = /^The Grandmaster says, "Welcome to the Order|^The Grandmaster says, "You are now a member of the Guardians of Sunfist|^The Grand Poohbah smiles broadly.  "Welcome to the Lodge," he cries/.freeze
          SocietyResign = /^The Grandmaster says, "I'm sorry to hear that.  You are no longer in our service.|^The Poohbah looks at you sternly.  "I had high hopes for you," he says, "but if this be your decision, so be it\.  I hereby strip you of membership|^The Grandmaster says, "I'm sorry to hear that,.+I wish you well with any of your future endeavors./.freeze
          Warcries = /^\s+(?<name>(?:Bertrandt's Bellow|Yertie's Yowlp|Gerrelle's Growl|Seanette's Shout|Carn's Cry|Horland's Holler))$/.freeze
          NoWarcries = /^You must be an active member of the Warrior Guild to use this skill\.$/.freeze
          LearnPSM = /^You have now achieved rank (?<rank>\d+) of (?<psm>[A-z\s]+), costing \d+ (?<cat>[A-z]+) .*?points\.$/
          # Technique covers Specialization (Armor and Shield), Technique (Weapon), and Feat
          LearnTechnique = /^\[You have (?:gained|increased to) rank (?<rank>\d+) of (?<cat>[A-z]+).*: (?<psm>[A-z\s\-':]+)\.\]$/.freeze
          UnlearnPSM = /^You decide to unlearn rank (?<rank>\d+) of (?<psm>[A-z\s\-':]+), regaining \d+ (?<cat>[A-z]+) .*?points\.$/
          UnlearnTechnique = /^\[You have decreased to rank (?<rank>\d+) of (?<cat>[A-z]+).*: (?<psm>[A-z\s\-':]+)\.\]$/.freeze
          LostTechnique = /^\[You are no longer trained in (?<cat>[A-z]+) .*: (?<psm>[A-z\s\-':]+)\.\]$/.freeze
          Resource = /^(?:Essence|Necrotic Energy|Lore Knowledge|Motes of Tranquility|Devotion|Nature's Grace|Grit|Luck Inspiration|Guile|Vitality): (?<weekly>[0-9,]+)\/50,000 \(Weekly\)\s+(?<total>[0-9,]+)\/200,000 \(Total\)$/.freeze
          Suffused = /^Suffused (?<type>(?:Essence|Necrotic Energy|Lore Knowledge|Motes of Tranquility|Devotion|Nature's Grace|Grit|Luck Inspiration|Guile|Vitality)): (?<suffused>[0-9,]+)$/.freeze
          VolnFavor = /^Voln Favor: (?<favor>[-\d,]+)$/.freeze
          CovertArtsCharges = /^Covert Arts Charges: (?<charges>[-\d,]+)\/200$/.freeze
          GigasArtifactFragments = /^You are carrying (?<gigas_artifact_fragments>[\d,]+) gigas artifact fragments\.$/.freeze
          RedsteelMarks = /^(?:\s* Redsteel Marks:           |You are carrying) (?<redsteel_marks>[\d,]+)(?: redsteel marks\.)?$/.freeze
          GemstoneDust = /^You are carrying (?<gemstone_dust>[\d,]+) Dust in your reserves\.$/.freeze
          TicketGeneral = /^\s*General - (?<tickets>[\d,]+) tickets\.$/.freeze
          TicketBlackscrip = /^\s*Troubled Waters - (?<blackscrip>[\d,]+) blackscrip\.$/.freeze
          TicketBloodscrip = /^\s*Duskruin Arena - (?<bloodscrip>[\d,]+) bloodscrip\.$/.freeze
          TicketEtherealScrip = /^\s*Reim - (?<ethereal_scrip>[\d,]+) ethereal scrip\.$/.freeze
          TicketSoulShards = /^\s*Ebon Gate - (?<soul_shards>[\d,]+) soul shards\.$/.freeze
          TicketRaikhen = /^\s*Rumor Woods - (?<raikhen>[\d,]+) raikhen\.$/.freeze
          WealthSilver = /^You have (?<silver>no|[,\d]+|but one) silver with you\./.freeze
          WealthSilverContainer = /^You are carrying (?<silver>[\d,]+) silver stored within your /.freeze
          AccountName = /^Account Name:     (?<name>[\w\d\-\_]+)$/.freeze
          AccountSubscription = /^Account Type:     (?<subscription>F2P|Standard|Premium|Platinum)(?: with Shattered)?(?: \(Promo\))?$/.freeze
          ProfileStart = /^PERSONAL INFORMATION$/.freeze
          ProfileName = /^Name: (?<name>[\w\s]+)$/.freeze
          ProfileHouseCHE = /^[A-Za-z\- ]+? (?:of House of the |of House of |of House |of )(?<house>Argent Aspis|Rising Phoenix|Paupers|Arcane Masters|Brigatta|Twilight Hall|Silvergate Inn|Sovyn|Sylvanfair|Helden Hall|White Haven|Beacon Hall|Rone Academy|Willow Hall|Moonstone Abbey|Obsidian Tower|Cairnfang Manor)(?: Archive)?$|^(?<none>No House affiliation)$/.freeze
          ResignCHE = /^(?:Once you have resigned from your House, you will be unable to rejoin without being inducted again by the |If you wish to renounce your membership in the |Before you can resign from the )(?<house>Argent Aspis|Rising Phoenix|Paupers|Arcane Masters|Brigatta|Twilight Hall|Silvergate Inn|Sovyn|Sylvanfair|Helden Hall|White Haven|Beacon Hall|Rone Academy|Willow Hall|Moonstone Abbey|Obsidian Tower|Cairnfang Manor)(?: Archive)?|^(?<none>The RESIGN command is for resigning your membership in a House, but you don't currently belong to any of the Cooperative Houses of Elanthia)\.$/.freeze

          # TODO: refactor / streamline?
          SleepActive = /^Your mind goes completely blank\.$|^You close your eyes and slowly drift off to sleep\.$|^You slump to the ground and immediately fall asleep\.  You must have been exhausted!$|^That is impossible to do while unconscious$/.freeze
          SleepNoActive = /^Your thoughts slowly come back to you as you find yourself lying on the ground\.  You must have been sleeping\.$|^You wake up from your slumber\.$|^You are awoken|^You awake|^You slowly come back to alertness and realize you must have been sleeping\.$/.freeze
          BindActive = /^An unseen force (?:envelops|entangles) you, restricting (?:all|your) movement|^You are caught fast, the light of (?:Liabo|Lornon|Tilaok|Makiri|the moon) arresting your movements/.freeze
          BindNoActive = /^The restricting force that envelops you dissolves away\.|^You shake off the immobilization that was restricting your movements!|^The restricting force enveloping you fades away\./.freeze
          SilenceActive = /^A pall of silence settles over you\.|^The pall of silence settles more heavily over you\./.freeze
          SilenceNoActive = /^The pall of silence leaves you\./.freeze
          CalmActive = /^A calm washes over you\./.freeze
          CalmNoActive = /^You are enraged by .*? attack!|^The feeling of calm leaves you\./.freeze
          CutthroatActive = /slices deep into your vocal cords!$|^All you manage to do is cough up some blood\.$/.freeze
          CutthroatNoActive = /^\s*The horrible pain in your vocal cords subsides as you spit out the last of the blood clogging your throat\.$|^That tingles, but there are no head injuries to repair\.$/.freeze
          ThornPoisonStart = /^One of the vines surrounding .*? lashes out at you, driving a thorn into your skin!  You feel poison coursing through your veins\.$/.freeze
          ThornPoisonProgression = /^You begin to feel a strange fatigue, spreading throughout your body\.$|^The strange lassitude is growing worse, making it difficult to keep up with any strenuous activities\.$|^You find yourself gradually slowing down, your muscles trembling with fatigue\.$|^It\'s getting increasingly difficult to move. It feels almost as if the air itself is growing thick as molasses\.$|^No longer able to fight this odd paralysis, you collapse to the ground, as limp as an old washrag\.$/.freeze
          ThornPoisonDeprogression = /^With a shaky gasp and trembling muscles, you regain at least some small ability to move, however slowly\.$|Although you can\'t seem to move as quickly as you usually can, you\'re feeling better than you were just moments ago\.$|^Fine coordination is difficult, but at least you can move at something close to your normal speed again\.$|^While you\'re still a bit shaky, your muscles are responding better than they were\.$/.freeze
          ThornPoisonEnd = /^Your body begins to respond normally again\.$|^Your skin takes on a more pinkish tint\.$/.freeze

          # Adding spell regexes.  Does not save to infomon.db.  Used by Spell and by ActiveSpells
          SpellUpMsgs = /^#{Lich::Common::Spell.upmsgs.join('$|^')}$/o.freeze
          SpellDnMsgs = /^#{Lich::Common::Spell.dnmsgs.join('$|^')}$/o.freeze
          SpellsongRenewed = /^Your songs? renews?/.freeze

          All = Regexp.union(CharRaceProf, CharGenderAgeExpLevel, Stat, StatEnd, Fame, RealExp, AscExp, TotalExp, LTE,
                             ExprEnd, SkillStart, Skill, SpellRanks, SkillEnd, PSMStart, PSM, PSMEnd, Levelup, SpellsSolo,
                             Citizenship, NoCitizenship, Society, NoSociety, SleepActive, SleepNoActive, BindActive,
                             BindNoActive, SilenceActive, SilenceNoActive, CalmActive, CalmNoActive, CutthroatActive,
                             CutthroatNoActive, SpellUpMsgs, SpellDnMsgs, Warcries, NoWarcries, SocietyJoin, SocietyStep,
                             SocietyResign, LearnPSM, UnlearnPSM, LostTechnique, LearnTechnique, UnlearnTechnique,
                             Resource, Suffused, VolnFavor, GigasArtifactFragments, RedsteelMarks, TicketGeneral,
                             TicketBlackscrip, TicketBloodscrip, TicketEtherealScrip, TicketSoulShards, TicketRaikhen,
                             WealthSilver, WealthSilverContainer, GoalsDetected, GoalsEnded, SpellsongRenewed,
                             ThornPoisonStart, ThornPoisonProgression, ThornPoisonDeprogression, ThornPoisonEnd, CovertArtsCharges,
                             AccountName, AccountSubscription, ProfileStart, ProfileName, ProfileHouseCHE, ResignCHE, GemstoneDust)
        end

        module State
          @state = :ready
          Goals = :goals
          Profile = :profile
          Ready = :ready

          def self.set(state)
            case state
            when Goals, Profile
              unless @state.eql?(Ready)
                Lich.log "error: Infomon::Parser::State is in invalid state(#{@state}) - caller: #{caller[0]}"
                fail "--- Lich: error: Infomon::Parser::State is in invalid state(#{@state}) - caller: #{caller[0]}"
              end
            end
            @state = state
          end

          def self.get
            @state
          end
        end

        def self.find_cat(category)
          case category
          when /Armor/
            'Armor'
          when /Ascension/
            'Ascension'
          when /Combat/
            'CMan'
          when /Feat/
            'Feat'
          when /Shield/
            'Shield'
          when /Weapon/
            'Weapon'
          end
        end

        def self.parse(line)
          # O(1) vs O(N)
          return :noop unless line =~ Pattern::All

          begin
            case line
            # blob saves
            when Pattern::CharRaceProf
              # name captured here, but do not rely on it - use XML instead
              @stat_hold = []
              Infomon.mutex_lock
              match = Regexp.last_match
              @stat_hold.push(['stat.race', match[:race].to_s],
                              ['stat.profession', match[:profession].to_s]) unless Effects::Spells.active?(1212)
              :ok
            when Pattern::CharGenderAgeExpLevel
              # level captured here, but do not rely on it - use XML instead
              match = Regexp.last_match
              @stat_hold.push(['stat.gender', match[:gender].to_s],
                              ['stat.age', match[:age].delete(',').to_i]) unless Effects::Spells.active?(1212)
              @stat_hold.push(['stat.experience', match[:experience].delete(',').to_i])
              :ok
            when Pattern::Stat
              match = Regexp.last_match
              @stat_hold.push(['stat.%s' % match[:stat], match[:value].to_i],
                              ['stat.%s_bonus' % match[:stat], match[:bonus].to_i],
                              ['stat.%s.enhanced' % match[:stat], match[:enhanced_value].to_i],
                              ['stat.%s.enhanced_bonus' % match[:stat], match[:enhanced_bonus].to_i])
              :ok
            when Pattern::StatEnd
              match = Regexp.last_match
              @stat_hold.push(['currency.silver', match[:silver].delete(',').to_i])
              Infomon.upsert_batch(@stat_hold)
              Infomon.mutex_unlock
              :ok
            when Pattern::Fame # serves as ExprStart
              @expr_hold = []
              Infomon.mutex_lock
              match = Regexp.last_match
              @expr_hold.push(['experience.fame', match[:fame].delete(',').to_i])
              :ok
            when Pattern::RealExp
              match = Regexp.last_match
              @expr_hold.push(['experience.field_experience_current', match[:fxp_current].delete(',').to_i],
                              ['experience.field_experience_max', match[:fxp_max].delete(',').to_i])
              :ok
            when Pattern::AscExp
              match = Regexp.last_match
              @expr_hold.push(['experience.ascension_experience', match[:ascension_experience].delete(',').to_i])
              :ok
            when Pattern::TotalExp
              match = Regexp.last_match
              @expr_hold.push(['experience.total_experience', match[:total_experience].delete(',').to_i],
                              ['experience.deaths_sting', match[:deaths_sting]])
              :ok
            when Pattern::LTE
              match = Regexp.last_match
              @expr_hold.push(['experience.long_term_experience', match[:long_term_experience].delete(',').to_i],
                              ['experience.deeds', match[:deeds].to_i])
              :ok
            when Pattern::ExprEnd
              Infomon.upsert_batch(@expr_hold)
              Infomon.mutex_unlock
              :ok
            when Pattern::SkillStart
              @skills_hold = []
              Infomon.mutex_lock
              :ok
            when Pattern::Skill
              if Infomon.mutex.owned?
                match = Regexp.last_match
                @skills_hold.push(['skill.%s' % match[:name].downcase, match[:ranks].to_i],
                                  ['skill.%s_bonus' % match[:name], match[:bonus].to_i])
                :ok
              else
                :noop
              end
            when Pattern::SpellRanks
              if Infomon.mutex.owned?
                match = Regexp.last_match
                @skills_hold.push(['spell.%s' % match[:name].downcase, match[:rank].to_i])
                :ok
              else
                :noop
              end
            when Pattern::SkillEnd
              if Infomon.mutex.owned?
                Infomon.upsert_batch(@skills_hold)
                Infomon.mutex_unlock
                :ok
              else
                :noop
              end
            when Pattern::GoalsDetected
              State.set(State::Goals)
              :ok
            when Pattern::GoalsEnded
              if State.get.eql?(State::Goals)
                State.set(State::Ready)
                respond
                _respond Lich::Messaging.monsterbold('You just trained your character.  Lich will gather your updated skills.')
                respond
                # temporary inform for users about command
                # fixme: update ExecCommand to consistently perform local API actions from lib files
                respond "[infomon_sync]#{$SEND_CHARACTER}skills"
                Game._puts("#{$cmd_prefix}skills")
                :ok
              else
                :noop
              end
            when Pattern::PSMStart
              match = Regexp.last_match
              @psm_hold = []
              @psm_cat = find_cat(match[:cat])
              Infomon.mutex_lock
              :ok
            when Pattern::PSM
              match = Regexp.last_match
              @psm_hold.push(["#{@psm_cat.downcase}.%s" % match[:command], match[:ranks].to_i])
              :ok
            when Pattern::PSMEnd
              Infomon.upsert_batch(@psm_hold)
              Infomon.mutex_unlock
              :ok
            when Pattern::NoWarcries
              Infomon.upsert_batch([['warcry.bertrandts_bellow', 0],
                                    ['warcry.yerties_yowlp', 0],
                                    ['warcry.gerrelles_growl', 0],
                                    ['warcry.seanettes_shout', 0],
                                    ['warcry.carns_cry', 0],
                                    ['warcry.horlands_holler', 0]])
              :ok
            # end of blob saves
            when Pattern::Warcries
              match = Regexp.last_match
              Infomon.set('warcry.%s' % match[:name].split(' ')[1], 1)
              :ok
            when Pattern::Levelup
              match = Regexp.last_match
              Infomon.upsert_batch([['stat.%s' % match[:stat], match[:value].to_i],
                                    ['stat.%s_bonus' % match[:stat], match[:bonus].to_i]])
              :ok
            when Pattern::SpellsSolo
              match = Regexp.last_match
              Infomon.set('spell.%s' % match[:name].downcase, match[:rank].to_i)
              :ok
            when Pattern::Citizenship
              Infomon.set('citizenship', Regexp.last_match[:town].to_s)
              :ok
            when Pattern::NoCitizenship
              Infomon.set('citizenship', 'None')
              :ok
            when Pattern::Society
              match = Regexp.last_match
              Infomon.set('society.status', match[:society].to_s)
              Infomon.set('society.rank', match[:rank].to_i)
              case match[:standing] # if Master in society the rank match is nil
              when 'Master'
                if /Voln/.match?(match[:society])
                  Infomon.set('society.rank', 26)
                elsif /Council of Light|Guardians of Sunfist/.match?(match[:society])
                  Infomon.set('society.rank', 20)
                end
              end
              :ok
            when Pattern::NoSociety
              Infomon.set('society.status', 'None')
              Infomon.set('society.rank', 0)
              :ok
            when Pattern::SocietyJoin
              match = Regexp.last_match.to_s
              case match[/Order|Council|Guardians/]
              when 'Order'
                Infomon.set('society.status', 'Order of Voln')
                Infomon.set('society.rank', 1)
              when 'Guardians'
                Infomon.set('society.status', "Guardians of Sunfist")
                Infomon.set('society.rank', 0)
              when 'Lodge'
                Infomon.set('society.status', 'Council of Light')
                Infomon.set('society.rank', 1)
              end
              :ok
            when Pattern::SocietyStep
              Infomon.set('society.rank', Infomon.get('society.rank') + 1)
              :ok
            when Pattern::SocietyResign
              Infomon.set('society.status', 'None')
              Infomon.set('society.rank', 0)
              :ok
            when Pattern::LearnPSM, Pattern::LearnTechnique
              match = Regexp.last_match
              @psm_cat = find_cat(match[:cat])
              seek_name = PSMS.name_normal(match[:psm])
              db_name = PSMS.find_name(seek_name, @psm_cat)
              Infomon.set("#{@psm_cat.downcase}.#{db_name[:short_name]}", match[:rank].to_i)
              :ok
            when Pattern::UnlearnPSM, Pattern::UnlearnTechnique
              match = Regexp.last_match
              @psm_cat = find_cat(match[:cat])
              seek_name = PSMS.name_normal(match[:psm])
              no_decrement = (match.string =~ /have decreased to/)
              db_name = PSMS.find_name(seek_name, @psm_cat)
              Infomon.set("#{@psm_cat.downcase}.#{db_name[:short_name]}", (no_decrement ? match[:rank].to_i : match[:rank].to_i - 1))
              :ok
            when Pattern::LostTechnique
              match = Regexp.last_match
              @psm_cat = find_cat(match[:cat])
              seek_name = PSMS.name_normal(match[:psm])
              db_name = PSMS.find_name(seek_name, @psm_cat)
              Infomon.set("#{@psm_cat.downcase}.#{db_name[:short_name]}", 0)
              :ok
            when Pattern::Resource
              match = Regexp.last_match
              Infomon.set('resources.weekly', match[:weekly].delete(',').to_i)
              Infomon.set('resources.total', match[:total].delete(',').to_i)
              :ok
            when Pattern::Suffused
              match = Regexp.last_match
              Infomon.set('resources.type', match[:type].to_s)
              Infomon.set('resources.suffused', match[:suffused].delete(',').to_i)
              :ok
            when Pattern::VolnFavor
              match = Regexp.last_match
              Infomon.set('resources.voln_favor', match[:favor].delete(',').to_i)
              :ok
            when Pattern::CovertArtsCharges
              match = Regexp.last_match
              Infomon.set('resources.covert_arts_charges', match[:charges].delete(',').to_i)
              :ok
            when Pattern::GigasArtifactFragments
              match = Regexp.last_match
              Infomon.set('currency.gigas_artifact_fragments', match[:gigas_artifact_fragments].delete(',').to_i)
              :ok
            when Pattern::RedsteelMarks
              match = Regexp.last_match
              Infomon.set('currency.redsteel_marks', match[:redsteel_marks].delete(',').to_i)
              :ok
            when Pattern::GemstoneDust
              match = Regexp.last_match
              Infomon.set('currency.gemstone_dust', match[:gemstone_dust].delete(',').to_i)
              :ok
            when Pattern::TicketGeneral
              match = Regexp.last_match
              Infomon.set('currency.tickets', match[:tickets].delete(',').to_i)
              :ok
            when Pattern::TicketBlackscrip
              match = Regexp.last_match
              Infomon.set('currency.blackscrip', match[:blackscrip].delete(',').to_i)
              :ok
            when Pattern::TicketBloodscrip
              match = Regexp.last_match
              Infomon.set('currency.bloodscrip', match[:bloodscrip].delete(',').to_i)
              :ok
            when Pattern::TicketEtherealScrip
              match = Regexp.last_match
              Infomon.set('currency.ethereal_scrip', match[:ethereal_scrip].delete(',').to_i)
              :ok
            when Pattern::TicketSoulShards
              match = Regexp.last_match
              Infomon.set('currency.soul_shards', match[:soul_shards].delete(',').to_i)
              :ok
            when Pattern::TicketRaikhen
              match = Regexp.last_match
              Infomon.set('currency.raikhen', match[:raikhen].delete(',').to_i)
              :ok
            when Pattern::WealthSilver
              match = Regexp.last_match
              case match[:silver]
              when 'no'
                Infomon.set('currency.silver', 0)
              when 'but one'
                Infomon.set('currency.silver', 1)
              else
                Infomon.set('currency.silver', match[:silver].delete(',').to_i)
              end
              :ok
            when Pattern::WealthSilverContainer
              match = Regexp.last_match
              Infomon.set('currency.silver_container', match[:silver].delete(',').to_i)
              :ok
            when Pattern::AccountName
              if Account.name.nil?
                match = Regexp.last_match
                Account.name = match[:name].upcase
                :ok
              else
                :noop
              end
            when Pattern::AccountSubscription
              if Account.subscription
                match = Regexp.last_match
                Account.subscription = match[:subscription].gsub('Standard', 'Normal').gsub('F2P', 'Free').gsub('Platinum', 'Premium').upcase
                Infomon.set('account.type', match[:subscription].gsub('Standard', 'Normal').gsub('F2P', 'Free').upcase)
                :ok
              else
                :noop
              end
            when Pattern::ProfileStart
              State.set(State::Profile)
              :ok
            when Pattern::ProfileName
              match = Regexp.last_match
              if State.get.eql?(State::Profile) && !match[:name].split(' ').include?(Char.name)
                State.set(State::Ready)
                :ok
              else
                :noop
              end
            when Pattern::ProfileHouseCHE
              if State.get.eql?(State::Profile)
                match = Regexp.last_match
                Infomon.set('che', (match[:none] ? 'none' : Lich::Util.normalize_name(match[:house])))
                State.set(State::Ready)
                :ok
              else
                :noop
              end
            when Pattern::ResignCHE
              match = Regexp.last_match
              Infomon.set('che', (match[:none] ? 'none' : Lich::Util.normalize_name(match[:house])))
              :ok

            # TODO: refactor / streamline?
            when Pattern::ThornPoisonStart, Pattern::ThornPoisonProgression, Pattern::ThornPoisonDeprogression
              Infomon.set('status.thorned', true)
              :ok
            when Pattern::ThornPoisonEnd
              Infomon.set('status.thorned', false)
              :ok
            when Pattern::SleepActive
              Infomon.set('status.sleeping', true)
              :ok
            when Pattern::SleepNoActive
              Infomon.set('status.sleeping', false)
              :ok
            when Pattern::BindActive
              Infomon.set('status.bound', true)
              :ok
            when Pattern::BindNoActive
              Infomon.set('status.bound', false)
              :ok
            when Pattern::SilenceActive
              Infomon.set('status.silenced', true)
              :ok
            when Pattern::SilenceNoActive
              Infomon.set('status.silenced', false)
              :ok
            when Pattern::CalmActive
              Infomon.set('status.calmed', true)
              :ok
            when Pattern::CalmNoActive
              Infomon.set('status.calmed', false)
              :ok
            when Pattern::CutthroatActive
              Infomon.set('status.cutthroat', true)
              :ok
            when Pattern::CutthroatNoActive
              Infomon.set('status.cutthroat', false)
              :ok
            when Pattern::SpellUpMsgs
              spell = Spell.list.find do |s|
                line =~ /^#{s.msgup}$/
              end
              spell.putup unless spell.active?
              # add various cooldowns back without affecting parse speed
              Spells.require_cooldown(spell)
              :ok
            when Pattern::SpellDnMsgs
              spell = Spell.list.find do |s|
                line =~ /^#{s.msgdn}$/
              end
              spell.putdown if spell.active?
              :ok
            when Pattern::SpellsongRenewed
              Spellsong.renewed
              :ok
            else
              :noop
            end
          rescue StandardError
            respond "--- Lich: error: Infomon::Parser.parse: #{$!}"
            respond "--- Lich: error: line: #{line}"
            Lich.log "error: Infomon::Parser.parse: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Lich.log "error: line: #{line}\n\t"
          end
        end
      end
    end
  end
end
