# frozen_string_literal: true

module Lich
  module Gemstone
    module Infomon
      # this module handles all of the logic for parsing game lines that infomon depends on
      module XMLParser
        module Pattern
          Group_Short = /(?:group|following you|IconJOINED)|^You are leading|(?:'s<\/a>|your) hand(?: tenderly)?\.\r?\n?$/
          Also_Here_Arrival = /^Also here: /
          NpcDeathPrefix = Regexp.union(
            /The fire in the/,
            /With a surprised grunt, the/,
            /A sudden blue fire bursts over the hair of a/,
            /You hear a sound like a weeping child as a white glow separates itself from the/,
            /A low gurgling sound comes from deep within the chest of the/,
            /(?:The|An?)/,
            /One last prolonged bovine moan escapes from the/
          )
          NpcDeathPostfix = Regexp.union(
            /body as it rises, disappearing into the heavens/,
            /falls to the ground and dies(?:, its feelers twitching)?/,
            /falls back into a heap and dies/,
            /body goes rigid and collapses to the ground, dead/,
            /body goes rigid and collapses to the floor, dead/,
            /slowly settles to the ground and begins to dissipate/,
            /falls to the ground motionless/,
            /body goes rigid and <pushBold\/><a.*?>\w+<\/a><popBold\/> eyes roll back into <pushBold\/><a.*?>\w+<\/a><popBold\/> head as <pushBold\/><a.*?>\w+<\/a><popBold\/> dies/,
            /growls one last time, and crumples to the ground in a heap/,
            /spins backwards and collapses dead/,
            /falls to the ground as the stillness of death overtakes <pushBold\/><a.*?>(?:him|her|it)<\/a><popBold\/>/,
            /crumples to the ground motionless/,
            /howls in agony one last time and dies/,
            /howls in agony while falling to the ground motionless/,
            /moans pitifully as <pushBold\/><a.*?>(?:he|she|it)<\/a><popBold\/> is released/,
            /careens to the ground and crumples in a heap/,
            /hisses one last time and dies/,
            /flutters its wings one last time and dies/,
            /slumps to the ground with a final snarl/,
            /horn dims as (?:his|her) lifeforce fades away/,
            /blinks in astonishment, then collapses in a motionless heap/,
            /collapses in a heap, its huge girth shaking the floor around it/,
            /goes limp and .*? falls over as the fire slowly fades from .*? eyes/,
            /eyes slowly fades/,
            /sputters violently, cascading flames all around as .*? collapses in a final fiery display/,
            /falls to the ground in a clattering, motionless heap/,
            /goes limp and .*? falls over as the fire slowly fades from .*? eyes/,
            /collapses to the ground and shudders once before finally going still/,
            /crumbles into a pile of rubble/,
            /shudders once before .*? finally goes still/,
            /totters for a moment and then falls to the ground like a pillar, breaking into pieces that fly out in every direction/,
            /collapses into a pile of rubble/,
            /rumbles in agony as .*? teeters for a moment, then falls directly at you/,
            /twists and coils violently in .*? death throes, finally going still/,
            /twitches one final time before falling still upon the floor/,
            /, consuming .*? form in the space of a breath/,
            /screams one last time and dies/,
            /breathes .*? last gasp and dies/,
            /rolls over and dies/,
            /as .*? falls (?:slack|still) against the (?:floor|ground)/,
            /collapses to the ground, emits a final squeal, and dies/,
            /cries out in pain one last time and dies/,
            /crumples to a heap on the ground and dies/,
            /collapses to the ground, emits a final sigh, and dies/,
            /crumples to the ground and dies/,
            /lets out a final caterwaul and dies/,
            /screams evilly one last time and goes still/,
            /gurgles eerily and collapses into a puddle of water/,
            /shudders, then topples to the ground/,
            /shudders one last time before lying still/,
            /violently for a moment, then goes still/,
            /grumbles in pain one last time before lying still/,
            /rumbles in agony and goes still/,
            /falls to the ground dead/,
            /collapses to the ground, emits a final bleat, and dies/,
            /topples to the ground motionless/,
            /shudders violently for a moment, then goes still/,
            /rumbles in agony as .*? teeters for a moment, then tumbles to the ground with a thundering crash/,
            /sinks to the ground, the fell light in (?:his|her) eyes guttering before going out entirely/,
          )
          NpcDeathMessage = /^(?:<pushBold\/>)?#{NpcDeathPrefix} (?:<pushBold\/>)?<a.*?exist=["'](?<npc_id>\-?[0-9]+)["'].*?>.*?<\/a>(?:<popBold\/>)?(?:'s)? #{NpcDeathPostfix}[\.!]\r?\n?$/

          # the following are for parsing STOW LIST and setting of STOW containers
          StowListOutputStart = /^You have the following containers set as stow targets:\r?\n?$/
          StowListContainer = /^  (?:an?|some) <a exist="(?<id>\d+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^\(]+)? \((?<type>box|gem|herb|skin|wand|scroll|potion|trinket|reagent|lockpick|treasure|forageable|collectible|default)\)\r?\n?$/
          StowSetContainer1 = /^Set "a <a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^"]+)?" to be your STOW (?<type>BOX|GEM|HERB|SKIN|WAND|SCROLL|POTION|TRINKET|REAGENT|LOCKPICK|TREASURE|FORAGEABLE|COLLECTIBLE) container\.\r?\n?$/
          StowSetContainer2 = /Set "a <a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^"]+)?" to be your (?<type>default) STOW container\.\r?\n?$/

          # the following are for parsing READY LIST and setting of READY items
          ReadyListOutputStart = /^Your current settings are:\r?\n?$/
          ReadyListNormal = /^  (?<type>shield|(?:secondary |ranged )?weapon|ammo bundle): <d cmd="store (?:SHIELD|2?WEAPON|RANGED|AMMO) clear">(?:an?|some) <a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^<]+)?<\/d> \(<d cmd='store set'>(?:worn if possible, stowed otherwise|stowed|put in (?:secondary )?sheath)<\/d>\)\r?\n?$/
          ReadyListAmmo2 = /^  (?<type>ammo2 bundle): <d cmd="store AMMO2 clear">(?:an?|some) <a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^<]+)?<\/d>\r?\n?$/
          ReadyListSheathsSet = /^  (?<type>(?:secondary )?sheath): <d cmd="store 2?SHEATH clear">(?:an?|some) <a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^<]+)?<\/d>\r?\n?$/
          ReadyListFinished = /To change your default item for a category that is already set, clear the category first by clicking on the item in the list above.  Click <d cmd="ready list">here<\/d> to update the list\.\r?\n?$/
          ReadyItemClear = /^Cleared your default (?<type>shield|(?:secondary |ranged )?weapon|ammo2? bundle|(?:secondary )?sheath)\.\r?\n?$/
          ReadyItemSet = /^Setting (?:an?|some) <a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^<]+)? to be your default (?<type>shield|(?:secondary |ranged )?weapon|ammo2? bundle|(?:secondary )?sheath)\.\r?\n?$/

          StatusPrompt = /<prompt time="[0-9]+">/

          All = Regexp.union(NpcDeathMessage, Group_Short, Also_Here_Arrival, StowListOutputStart, StowListContainer, StowSetContainer1, StowSetContainer2,
                             ReadyListOutputStart, ReadyListNormal, ReadyListAmmo2, ReadyListSheathsSet, ReadyListFinished, ReadyItemClear, ReadyItemSet, StatusPrompt)
        end

        def self.parse(line)
          # O(1) vs O(N)
          return :noop unless line =~ Pattern::All

          begin
            case line
            # this detects for death messages in XML that are not matched with appropriate combat attributes above
            when Pattern::NpcDeathMessage
              match = Regexp.last_match
              if (npc = GameObj.npcs.find { |obj| obj.id == match[:npc_id] && obj.status !~ /\b(?:dead|gone)\b/ })
                npc.status = 'dead'
              end
              :ok
            when Pattern::Group_Short
              return :noop unless (match_data = Group::Observer.wants?(line))
              Group::Observer.consume(line.strip, match_data)
              :ok
            when Pattern::Also_Here_Arrival
              return :noop unless Lich::Claim::Lock.locked?
              line.scan(%r{<a exist=(?:'|")(?<id>.*?)(?:'|") noun=(?:'|")(?<noun>.*?)(?:'|")>(?<name>.*?)</a>}).each { |player_found| XMLData.arrival_pcs.push(player_found[1]) unless XMLData.arrival_pcs.include?(player_found[1]) }
              :ok
            when Pattern::StowListOutputStart
              StowList.reset
              :ok
            when Pattern::StowListContainer, Pattern::StowSetContainer1, Pattern::StowSetContainer2
              match = Regexp.last_match
              if GameObj[match[:id]]
                StowList.__send__("#{match[:type].downcase}=", GameObj[match[:id]])
              else
                StowList.__send__("#{match[:type].downcase}=", GameObj.new(match[:id], match[:noun], match[:name], nil, (match[:after].nil? ? nil : match[:after].strip)))
              end
              StowList.checked = true if line =~ Pattern::StowListContainer
              :ok
            when Pattern::ReadyListOutputStart
              ReadyList.reset
              :ok
            when Pattern::ReadyListNormal, Pattern::ReadyListAmmo2, Pattern::ReadyListSheathsSet, Pattern::ReadyItemSet
              match = Regexp.last_match
              if GameObj[match[:id]]
                ReadyList.__send__("#{Lich::Util.normalize_name(match[:type].downcase)}=", GameObj[match[:id]])
              else
                ReadyList.__send__("#{Lich::Util.normalize_name(match[:type].downcase)}=", GameObj.new(match[:id], match[:noun], match[:name], nil, (match[:after].nil? ? nil : match[:after].strip)))
              end
              :ok
            when Pattern::ReadyListFinished
              ReadyList.checked = true
              :ok
            when Pattern::ReadyItemClear
              match = Regexp.last_match
              ReadyList.__send__("#{Lich::Util.normalize_name(match[:type].downcase)}=", nil)
              :ok
            when Pattern::StatusPrompt
              Infomon::Parser::State.set(Infomon::Parser::State::Ready) unless Infomon::Parser::State.get.eql?(Infomon::Parser::State::Ready)
              :ok
            else
              :noop
            end
          rescue StandardError
            respond "--- Lich: error: Infomon::XMLParser.parse: #{$!}"
            respond "--- Lich: error: line: #{line}"
            Lich.log "error: Infomon::XMLParser.parse: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Lich.log "error: line: #{line}\n\t"
          end
        end
      end
    end
  end
end
