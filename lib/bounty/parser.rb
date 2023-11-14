class Bounty
  class Parser
    HMM_REGEX = /(?:Hmm, I've got a task here from .*?(?<town>[A-Z].*?)\..*?)?/
    LOCATION_REGEX = /(?:on|in|near) (?:the\s+)?(?<area>[^.]+?)(?:\s+(?:near|between) (?<town>[^.]+))?/
    GUARD_REGEX = Regexp.union(
      /one of the guardsmen just inside the (?<town>Ta'Illistim) City Gate/,
      /one of the guardsmen just inside the Sapphire Gate/,
      /one of the guardsmen just inside the gate/,
      /one of the (?<town>.*) (?:gate|tunnel) guards/,
      /one of the (?<town>Icemule Trace) gate guards or the halfing Belle at the Pinefar Trading Post/,
      /Quin Telaren of (?<town>Wehnimer's Landing)/,
      /the dwarven militia sergeant near the (?<town>Kharam-Dzu) town gates/,
      /the sentry just outside town/,
      /the sentry just outside (?<town>Kraken's Fall)/,
      /the purser of (?<town>River's Rest)/,
      /the tavernkeeper at Rawknuckle's Common House/,
    )

    TASK_MATCHERS = {
      :none                => /^You are not currently assigned a task/,
      :bandit_assignment   => /#{HMM_REGEX}It appears they have a bandit problem they'd like you to solve/,
      :creature_assignment => /#{HMM_REGEX}It appears they have a creature problem they'd like you to solve/,
      :gem_assignment      => /#{HMM_REGEX}The local gem dealer, (?<npc_name>[^,]+), has an order to fill and wants our help/,
      :heirloom_assignment => /#{HMM_REGEX}It appears they need your help in tracking down some kind of lost heirloom/,
      :herb_assignment     => /#{HMM_REGEX}The local [^,]+?, (?<npc_name>[^,]+), has asked for our aid.  Head over there and see what you can do.  Be sure to ASK about BOUNTIES./,
      :rescue_assignment   => /#{HMM_REGEX}It appears that a local resident urgently needs our help in some matter/,
      :skin_assignment     => /#{HMM_REGEX}The local furrier (?<npc_name>.+) has an order to fill and wants our help/,
      :taskmaster          => /^You have succeeded in your task and can return to the Adventurer's Guild/,
      :heirloom_found      => /^You have located (?:an?|some) (?<item>.+) and should bring it back to #{GUARD_REGEX}\.$/,
      :guard               => /^You succeeded in your task and should report back to #{GUARD_REGEX}\.$/,
      :dangerous_spawned   => /^You have been tasked to hunt down and kill a particularly dangerous (?<creature>[^.]+) that has established a territory #{LOCATION_REGEX}\.  You have provoked (?:his|her|its) attention and now you must(?: return to where you left (?:him|her|it) and)? kill (?:him|her|it)!$/,
      :rescue_spawned      => /^You have made contact with the child you are to rescue and you must get (?:him|her) back alive to #{GUARD_REGEX}\.$/,
      :bandit              => /^You have been tasked to(?: help (?<assist>\w+))? suppress (?<creature>bandit) activity #{LOCATION_REGEX}\.  You need to kill (?<number>\d+) (?:more\s+)?of them to complete your task\.$/,
      :dangerous           => /^You have been tasked to hunt down and kill a (?:particularly )?dangerous (?<creature>[^.]+) that has established a territory #{LOCATION_REGEX}\.  You can get its attention by killing other creatures of the same type in its territory\.$/,
      :escort              => /^(?:The taskmaster told you:  ")?I've got a special mission for you\.  A certain client has hired us to provide a protective escort on (?:his|her) upcoming journey\.  Go to (?<start>[^.]+) and WAIT for (?:him|her) to meet you there\.  You must guarantee (?:his|her) safety to (?<destination>[^.]+) as soon as you can, being ready for any dangers that the two of you may face\.  Good luck!"?$/,
      :gem                 => /^The gem dealer in (?<town>[^,]+), (?<npc_name>[^,]+), has received orders from multiple customers requesting (?:an?|some) (?<gem>[^.]+)\.  You have been tasked to retrieve (?<number>\d+) (?:more\s+)?of them\.  You can SELL them to the gem dealer as you find them\.$/,
      :heirloom            => /^You have been tasked to recover (?:an?|some) (?<item>[^.]+) that an unfortunate citizen lost after being attacked by an? (?<creature>[^.]+?) #{LOCATION_REGEX}\.  The heirloom can be identified by the initials \w+ engraved upon it\.  [^.]*?(?<action>LOOT|SEARCH)[^.]+\.$/,
      :herb                => /^The .+? in (?<town>[^,]+?), (?<npc_name>[^,]+), is working on a concoction that requires (?:an?|some) (?<herb>[^.]+?) found [oi]n (?:the\s+)?(?<area>[^.]+?)(?:\s+(?:near|under|between) [^.]+)?\.  These samples must be in pristine condition\.  You have been tasked to retrieve (?<number>\d+) (?:more\s+)?samples?\.$/,
      :rescue              => /^You have been tasked to rescue the young (?:runaway|kidnapped) (?:son|daughter) of a local citizen\.  A local divinist has had visions of the child fleeing from an? (?<creature>[^.]+?) #{LOCATION_REGEX}\.  Find the area where the child was last seen and clear out the creatures that have been tormenting (?:him|her) in order to bring (?:him|her) out of hiding\.$/,
      :skin                => /^You have been tasked to retrieve (?<number>\d+) (?<skin>[^.]+?)s? of at least (?<quality>[^.]+) quality for (?<npc_name>.+) in (?<town>[^.]+?)\.  You can SKIN them off the corpse of an? (?<creature>[^.]+) or purchase them from another adventurer\.  You can SELL the skins to the furrier as you collect them\."$/,
      :cull                => Regexp.union(
        /^You have been tasked to(?: help (?<assist>\w+))? suppress (?<creature>[^.]+) activity #{LOCATION_REGEX}\.  You need to kill (?<number>\d+) (?:more\s+)?of them to complete your task\.$/,
        /^You have been tasked to help (?<assist>\w+) rescue a missing child by suppressing (?<creature>[^.]+) activity #{LOCATION_REGEX} during the rescue attempt\.  You need to kill (?<number>\d+) (?:more\s+)?of them to complete your task\.$/,
        /^You have been tasked to help (?<assist>\w+) retrieve an heirloom by suppressing (?<creature>[^.]+) activity #{LOCATION_REGEX} during the retrieval effort\.  You need to kill (?<number>\d+) (?:more\s+)?of them to complete your task\.$/,
        /^You have been tasked to help (?<assist>\w+) kill a dangerous creature by suppressing (?<creature>[^.]+) activity #{LOCATION_REGEX} during the hunt\.  You need to kill (?<number>\d+) (?:more\s+)?of them to complete your task\.$/,
      ),
      :failed              => Regexp.union(
        /^You have failed in your task/,
        /^The child you were tasked to rescue is gone and your task is failed.  Report this failure to the Adventurer's Guild./,
      ),
    }

    def initialize(description)
      @description = description
    end

    attr_reader :description

    def parse
      TASK_MATCHERS.each do |(task_type, regex)|
        if (md = regex.match(description))
          return (
            {
              type: task_type,
            }.merge(
              task_details_from(md.named_captures)
            ).compact
          )
        end
      end
    end

    def task_details_from(captures)
      {
        requirements: {}
      }.tap do |task_details|
        if (town = determine_town(captures["town"]))
          task_details[:town] = town
          task_details[:requirements][:town] = town
        end

        captures.each do |(key, value)|
          task_details[:requirements][key.to_sym] =
            case key
            when "town"
              town
            when "number"
              value.to_i
            when "action"
              value.downcase
            when "creature"
              normalized_creature_name(value)
            else
              value
            end
        end
      end
    end

    def normalized_creature_name(raw_creature_name)
      case raw_creature_name
      when /^\w+ being$/
        'being'
      when /^\w+ magna vereri$/
        'magna vereri'
      else
        raw_creature_name
      end
    end

    def determine_town(captured_town)
      if description =~ /^You succeeded in your task and should report back to the sentry just outside town\.$/
        "Kraken's Fall"
      else
        captured_town
      end
    end

    def self.parse(desc = checkbounty)
      if desc&.empty?
        return
      else
        self.new(desc).parse
      end
    end
  end
end
