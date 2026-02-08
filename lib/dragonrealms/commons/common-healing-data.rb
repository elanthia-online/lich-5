# frozen_string_literal: true

module Lich
  module DragonRealms
    module DRCH
      # Maps bleed rates from `health` command to severity number.
      # A partially tended wound is considered more severe than
      # its non-tended counterpart because once the bandages come off
      # then the wound is much worse so they should be triaged first.
      # https://elanthipedia.play.net/Damage#Bleeding_Levels
      #
      # Skill to tend based on https://elanthipedia.play.net/First_Aid_skill#Skill_to_Tend
      # A 'nil' value means that can't be tended because already is tended or isn't bleeding.
      BLEED_RATE_TO_SEVERITY = {
        'tended'                   => { severity: 1, bleeding: false, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        '(tended)'                 => { severity: 1, bleeding: false, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'clotted'                  => { severity: 2, bleeding: false, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'clotted(tended)'          => { severity: 3, bleeding: false, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'slight'                   => { severity: 3, bleeding: true, skill_to_tend: 30, skill_to_tend_internal: 600 }.freeze,
        'slight(tended)'           => { severity: 4, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'light'                    => { severity: 4, bleeding: true, skill_to_tend: 40, skill_to_tend_internal: 600 }.freeze,
        'light(tended)'            => { severity: 5, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'moderate'                 => { severity: 5, bleeding: true, skill_to_tend: 50, skill_to_tend_internal: 600 }.freeze,
        'moderate(tended)'         => { severity: 6, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'bad'                      => { severity: 6, bleeding: true, skill_to_tend: 60, skill_to_tend_internal: 620 }.freeze,
        'bad(tended)'              => { severity: 7, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'very bad'                 => { severity: 7, bleeding: true, skill_to_tend: 75, skill_to_tend_internal: 620 }.freeze,
        'very bad(tended)'         => { severity: 8, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'heavy'                    => { severity: 8, bleeding: true, skill_to_tend: 90, skill_to_tend_internal: 640 }.freeze,
        'heavy(tended)'            => { severity: 9, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'very heavy'               => { severity: 9, bleeding: true, skill_to_tend: 105, skill_to_tend_internal: 640 }.freeze,
        'very heavy(tended)'       => { severity: 10, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'severe'                   => { severity: 10, bleeding: true, skill_to_tend: 120, skill_to_tend_internal: 660 }.freeze,
        'severe(tended)'           => { severity: 11, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'very severe'              => { severity: 11, bleeding: true, skill_to_tend: 140, skill_to_tend_internal: 660 }.freeze,
        'very severe(tended)'      => { severity: 12, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'extremely severe'         => { severity: 12, bleeding: true, skill_to_tend: 160, skill_to_tend_internal: 700 }.freeze,
        'extremely severe(tended)' => { severity: 13, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'profuse'                  => { severity: 13, bleeding: true, skill_to_tend: 180, skill_to_tend_internal: 800 }.freeze,
        'profuse(tended)'          => { severity: 14, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'very profuse'             => { severity: 14, bleeding: true, skill_to_tend: 205, skill_to_tend_internal: 800 }.freeze,
        'very profuse(tended)'     => { severity: 15, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'massive'                  => { severity: 15, bleeding: true, skill_to_tend: 230, skill_to_tend_internal: 850 }.freeze,
        'massive(tended)'          => { severity: 16, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'gushing'                  => { severity: 16, bleeding: true, skill_to_tend: 255, skill_to_tend_internal: 850 }.freeze,
        'gushing(tended)'          => { severity: 17, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'massive stream'           => { severity: 17, bleeding: true, skill_to_tend: 285, skill_to_tend_internal: 1000 }.freeze,
        'massive stream(tended)'   => { severity: 18, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'gushing fountain'         => { severity: 18, bleeding: true, skill_to_tend: 285, skill_to_tend_internal: 1200 }.freeze,
        'gushing fountain(tended)' => { severity: 19, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'uncontrollable'           => { severity: 19, bleeding: true, skill_to_tend: 400, skill_to_tend_internal: 1400 }.freeze,
        'uncontrollable(tended)'   => { severity: 20, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'unbelievable'             => { severity: 20, bleeding: true, skill_to_tend: 500, skill_to_tend_internal: 1600 }.freeze,
        'unbelievable(tended)'     => { severity: 21, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'beyond measure'           => { severity: 21, bleeding: true, skill_to_tend: 600, skill_to_tend_internal: 1750 }.freeze,
        'beyond measure(tended)'   => { severity: 22, bleeding: true, skill_to_tend: nil, skill_to_tend_internal: nil }.freeze,
        'death awaits'             => { severity: 22, bleeding: true, skill_to_tend: 700, skill_to_tend_internal: 1750 }.freeze,
      }.freeze

      # https://elanthipedia.play.net/Damage#Lodged_Items
      LODGED_SEVERITY = {
        'loosely hanging' => 1,
        'shallowly'       => 2,
        'firmly'          => 3,
        'deeply'          => 4,
        'savagely'        => 5
      }.freeze

      # https://elanthipedia.play.net/Damage#Wound_Severity_Levels
      WOUND_SEVERITY = {
        'insignificant'    => 1,
        'negligible'       => 2,
        'minor'            => 3,
        'more than minor'  => 4,
        'harmful'          => 5,
        'very harmful'     => 6,
        'damaging'         => 7,
        'very damaging'    => 8,
        'severe'           => 9,
        'very severe'      => 10,
        'devastating'      => 11,
        'very devastating' => 12,
        'useless'          => 13
      }.freeze

      # https://elanthipedia.play.net/Damage#Parasites
      PARASITES_REGEX = [
        /(?:small|large) (?:black|red) blood mite/,
        /(?:black|red|albino) (sand|forest) leech/,
        /(?:green|red) blood worm/,
        /retch maggot/
      ].freeze

      # Parses the severity number out of the wound line from 'perceive health self'.
      # For example, the 'negligible' in "Fresh External:  light scratches -- negligible"
      PERCEIVE_HEALTH_SEVERITY_REGEX = /(?<freshness>Fresh|Scars) (?<location>External|Internal).+--\s+(?<severity>insignificant|negligible|minor|more than minor|harmful|very harmful|damaging|very damaging|severe|very severe|devastating|very devastating|useless)\b/

      BODY_PART_REGEX = /(?<part>(?:l\.|r\.|left|right)?\s?(?:\w+))/

      # Matches body parts in the `health` line for wounds and bleeders.
      WOUND_BODY_PART_REGEX = /(?:inside)?\s?#{BODY_PART_REGEX}/

      # Matches body parts in the `health` line for lodged items.
      LODGED_BODY_PART_REGEX = /lodged .* into your #{BODY_PART_REGEX}/

      # Matches body parts in the `health` line for parasites.
      PARASITE_BODY_PART_REGEX = /on your #{BODY_PART_REGEX}/

      # Matches body parts in the `health` line for bleeders.
      BLEEDER_LINE_REGEX = /^\b(inside\s+)?((l\.|r\.|left|right)\s+)?(head|eye|neck|chest|abdomen|back|arm|hand|leg|tail|skin)\b/

      # https://elanthipedia.play.net/Damage#Wounds
      WOUND_SEVERITY_REGEX_MAP = {
        # insignificant
        /minor abrasions to the #{WOUND_BODY_PART_REGEX}/                                                                    => { severity: 1, internal: false, scar: false }.freeze,
        /a few nearly invisible scars along the #{WOUND_BODY_PART_REGEX}/                                                    => { severity: 1, internal: false, scar: true }.freeze,
        # negligible
        /some tiny scars (?:across|along) the #{WOUND_BODY_PART_REGEX}/                                                      => { severity: 2, internal: false, scar: true }.freeze,
        /(?:light|tiny) scratches to the #{WOUND_BODY_PART_REGEX}/                                                           => { severity: 2, internal: false, scar: false }.freeze,
        # minor / more than minor
        /a bruised (?<part>head)/                                                                                            => { severity: 3, internal: true, scar: false }.freeze,
        /(?<skin>a small skin rash)/                                                                                         => { severity: 3, internal: false, scar: false }.freeze,
        /(?<skin>loss of skin tone)/                                                                                         => { severity: 3, internal: false, scar: true }.freeze,
        /(?<skin>some minor twitching)/                                                                                      => { severity: 3, internal: true, scar: false }.freeze,
        /(?<skin>slight difficulty moving your fingers and toes)/                                                            => { severity: 3, internal: true, scar: true }.freeze,
        /cuts and bruises about the #{WOUND_BODY_PART_REGEX}/                                                                => { severity: 3, internal: false, scar: false }.freeze,
        /minor scar\w+ (?:about|along|across) the #{WOUND_BODY_PART_REGEX}/                                                  => { severity: 3, internal: false, scar: true }.freeze,
        /minor swelling and bruising (?:around|in) the #{WOUND_BODY_PART_REGEX}/                                             => { severity: 3, internal: true, scar: false }.freeze,
        /occasional twitch\w* (?:on|in) the #{WOUND_BODY_PART_REGEX}/                                                        => { severity: 3, internal: true, scar: true }.freeze,
        /a black and blue #{WOUND_BODY_PART_REGEX}/                                                                          => { severity: 3, internal: false, scar: false }.freeze,
        # harmful / very harmful
        /a deeply bruised (?<part>head)/                                                                                     => { severity: 4, internal: true, scar: false }.freeze,
        /(?<skin>a large skin rash)/                                                                                         => { severity: 4, internal: false, scar: false }.freeze,
        /(?<skin>minor skin discoloration)/                                                                                  => { severity: 4, internal: false, scar: true }.freeze,
        /(?<skin>some severe twitching)/                                                                                     => { severity: 4, internal: true, scar: false }.freeze,
        /(?<skin>slight numbness in your arms and legs)/                                                                     => { severity: 4, internal: true, scar: true }.freeze,
        /deep cuts (?:about|across) the #{WOUND_BODY_PART_REGEX}/                                                            => { severity: 4, internal: false, scar: false }.freeze,
        /severe scarring (?:across|along|about) the #{WOUND_BODY_PART_REGEX}/                                                => { severity: 4, internal: false, scar: true }.freeze,
        /a severely swollen and\s?(?:deeply)? bruised #{WOUND_BODY_PART_REGEX}/                                              => { severity: 4, internal: true, scar: false }.freeze,
        /(?:occasional|constant) twitch\w* (?:on|in) the #{WOUND_BODY_PART_REGEX}/                                           => { severity: 4, internal: true, scar: true }.freeze,
        /a bruised and swollen (?<part>(?:right|left) (?:eye))/                                                              => { severity: 4, internal: false, scar: false }.freeze,
        # damaging / very damaging
        /some deep slashes and cuts about the (?<part>head)/                                                                 => { severity: 5, internal: false, scar: false }.freeze,
        /severe scarring and ugly gashes about the #{WOUND_BODY_PART_REGEX}/                                                 => { severity: 5, internal: false, scar: true }.freeze,
        /major swelling and bruising around the (?<part>head)/                                                               => { severity: 5, internal: true, scar: false }.freeze,
        /an occasional twitch on the fore(?<part>head)/                                                                      => { severity: 5, internal: true, scar: true }.freeze,
        /a bruised,* swollen and bleeding #{WOUND_BODY_PART_REGEX}/                                                          => { severity: 5, internal: false, scar: false }.freeze,
        /deeply scarred gashes across the #{WOUND_BODY_PART_REGEX}/                                                          => { severity: 5, internal: false, scar: true }.freeze,
        /a severely swollen, bruised and crossed #{WOUND_BODY_PART_REGEX}/                                                   => { severity: 5, internal: true, scar: false }.freeze,
        /a constant twitching in the #{WOUND_BODY_PART_REGEX}/                                                               => { severity: 5, internal: true, scar: true }.freeze,
        /deep slashes across the #{WOUND_BODY_PART_REGEX}/                                                                   => { severity: 5, internal: false, scar: false }.freeze,
        /a severely swollen and deeply bruised #{WOUND_BODY_PART_REGEX}/                                                     => { severity: 5, internal: true, scar: false }.freeze,
        /severely swollen and bruised #{WOUND_BODY_PART_REGEX}/                                                              => { severity: 5, internal: true, scar: false }.freeze,
        /a constant twitching in the (?<part>chest) area and difficulty breathing/                                           => { severity: 5, internal: true, scar: true }.freeze,
        /(?<abdomen>a somewhat emaciated look)/                                                                              => { severity: 5, internal: true, scar: true }.freeze,
        /a constant twitching in the #{WOUND_BODY_PART_REGEX} and difficulty moving in general/                              => { severity: 5, internal: true, scar: true }.freeze,
        /(?<skin>a body rash)/                                                                                               => { severity: 5, internal: false, scar: false }.freeze,
        /severe (?<part>skin) discoloration/                                                                                 => { severity: 5, internal: false, scar: true }.freeze,
        /(?<skin>difficulty controlling actions)/                                                                            => { severity: 5, internal: true, scar: false }.freeze,
        /(?<skin>numbness in your fingers and toes)/                                                                         => { severity: 5, internal: true, scar: true }.freeze,
        # severe / very severe
        /(?<head>a cracked skull with deep slashes)/                                                                         => { severity: 6, internal: false, scar: false }.freeze,
        /missing chunks out of the (?<part>head)/                                                                            => { severity: 6, internal: false, scar: true }.freeze,
        /a bruised, swollen and slashed #{WOUND_BODY_PART_REGEX}/                                                            => { severity: 6, internal: false, scar: false }.freeze,
        /a punctured and shriveled #{WOUND_BODY_PART_REGEX}/                                                                 => { severity: 6, internal: false, scar: true }.freeze,
        /a severely swollen,* bruised and cloudy #{WOUND_BODY_PART_REGEX}/                                                   => { severity: 6, internal: true, scar: false }.freeze,
        /a clouded #{WOUND_BODY_PART_REGEX}/                                                                                 => { severity: 6, internal: true, scar: true }.freeze,
        /gaping holes in the #{WOUND_BODY_PART_REGEX}/                                                                       => { severity: 6, internal: false, scar: false }.freeze,
        /a broken #{WOUND_BODY_PART_REGEX} with gaping holes/                                                                => { severity: 6, internal: false, scar: false }.freeze,
        /severe scarring and ugly gashes about the #{WOUND_BODY_PART_REGEX}/                                                 => { severity: 6, internal: false, scar: true }.freeze,
        /severe scarring and chunks of flesh missing from the #{WOUND_BODY_PART_REGEX}/                                      => { severity: 6, internal: false, scar: true }.freeze,
        /a severely swollen and deeply bruised #{WOUND_BODY_PART_REGEX} with odd protrusions under the skin/                 => { severity: 6, internal: true, scar: false }.freeze,
        /a severely swollen and deeply bruised (?<part>chest) area with odd protrusions under the skin/                      => { severity: 6, internal: true, scar: false }.freeze,
        /a partially paralyzed #{WOUND_BODY_PART_REGEX}/                                                                     => { severity: 6, internal: true, scar: true }.freeze,
        /a painful #{WOUND_BODY_PART_REGEX} and difficulty moving without pain/                                              => { severity: 6, internal: true, scar: true }.freeze,
        /a painful (?<part>chest) area and difficulty getting a breath without pain/                                         => { severity: 6, internal: true, scar: true }.freeze,
        /a severely bloated and discolored #{WOUND_BODY_PART_REGEX} with strange round lumps under the skin/                 => { severity: 6, internal: true, scar: false }.freeze,
        /(?<abdomen>a definite greenish pallor and emaciated look)/                                                          => { severity: 6, internal: true, scar: true }.freeze,
        /(?<skin>a painful,* inflamed body rash)/                                                                            => { severity: 6, internal: false, scar: false }.freeze,
        /(?<skin>a painful,* enflamed body rash)/                                                                            => { severity: 6, internal: false, scar: false }.freeze,
        /some shriveled and oddly folded (?<part>skin)/                                                                      => { severity: 6, internal: false, scar: true }.freeze,
        /(?<skin>partial paralysis of the entire body)/                                                                      => { severity: 6, internal: true, scar: false }.freeze,
        /(?<skin>numbness in your arms and legs)/                                                                            => { severity: 6, internal: true, scar: true }.freeze,
        # devastating / very devastating
        /(?<head>a crushed skull with horrendous wounds)/                                                                    => { severity: 7, internal: false, scar: false }.freeze,
        /a mangled and malformed (?<part>head)/                                                                              => { severity: 7, internal: false, scar: true }.freeze,
        /a ghastly bloated (?<part>head) with bleeding from the ears/                                                        => { severity: 7, internal: true, scar: false }.freeze,
        /a confused look with sporadic twitching of the fore(?<part>head)/                                                   => { severity: 7, internal: true, scar: true }.freeze,
        /a bruised,* swollen and shattered #{WOUND_BODY_PART_REGEX}/                                                         => { severity: 7, internal: false, scar: false }.freeze,
        /a painfully mangled and malformed #{WOUND_BODY_PART_REGEX} in a shattered eye socket/                               => { severity: 7, internal: false, scar: true }.freeze,
        /a severely swollen,* bruised and blind #{WOUND_BODY_PART_REGEX}/                                                    => { severity: 7, internal: true, scar: false }.freeze,
        /severely scarred,* mangled and malformed #{WOUND_BODY_PART_REGEX}/                                                  => { severity: 7, internal: false, scar: true }.freeze,
        /a completely clouded #{WOUND_BODY_PART_REGEX}/                                                                      => { severity: 7, internal: true, scar: true }.freeze,
        /a shattered #{WOUND_BODY_PART_REGEX} with gaping wounds/                                                            => { severity: 7, internal: false, scar: false }.freeze,
        /shattered (?<part>chest) area with gaping wounds/                                                                   => { severity: 7, internal: false, scar: false }.freeze,
        /a severely swollen and deeply bruised #{WOUND_BODY_PART_REGEX} with bones protruding out from the skin/             => { severity: 7, internal: true, scar: false }.freeze,
        /a severely swollen and deeply bruised #{WOUND_BODY_PART_REGEX} with ribs or vertebrae protruding out from the skin/ => { severity: 7, internal: true, scar: false }.freeze,
        /a severely paralyzed #{WOUND_BODY_PART_REGEX}/                                                                      => { severity: 7, internal: true, scar: true }.freeze,
        /a severely painful #{WOUND_BODY_PART_REGEX} with significant problems moving/                                       => { severity: 7, internal: true, scar: true }.freeze,
        /a severely painful (?<part>chest) area with significant problems breathing/                                         => { severity: 7, internal: true, scar: true }.freeze,
        /#{WOUND_BODY_PART_REGEX} deeply gouged with gaping wounds/                                                          => { severity: 7, internal: false, scar: false }.freeze,
        /a severely bloated and discolored #{WOUND_BODY_PART_REGEX} with strange round lumps under the skin/                 => { severity: 7, internal: true, scar: false }.freeze,
        /(?<abdomen>a severely yellow pallor and a look of starvation)/                                                      => { severity: 7, internal: true, scar: true }.freeze,
        /boils and sores around the (?<part>skin)/                                                                           => { severity: 7, internal: false, scar: false }.freeze,
        /severely stiff and shriveled (?<part>skin) that seems to be peeling off the body/                                   => { severity: 7, internal: false, scar: true }.freeze,
        /(?<skin>severe paralysis of the entire body)/                                                                       => { severity: 7, internal: true, scar: false }.freeze,
        /(?<skin>general numbness all over)/                                                                                 => { severity: 7, internal: true, scar: true }.freeze,
        # useless
        /pulpy stump for a (?<part>head)/                                                                                    => { severity: 8, internal: false, scar: false }.freeze,
        /a stump for a (?<part>head)/                                                                                        => { severity: 8, internal: false, scar: true }.freeze,
        /an ugly stump for a #{WOUND_BODY_PART_REGEX}/                                                                       => { severity: 8, internal: false, scar: false }.freeze,
        /a grotesquely bloated (?<part>head) with bleeding from the eyes and ears/                                           => { severity: 8, internal: true, scar: false }.freeze,
        /(?<head>a blank stare)/                                                                                             => { severity: 8, internal: true, scar: true }.freeze,
        /a pulpy cavity for a #{WOUND_BODY_PART_REGEX}/                                                                      => { severity: 8, internal: false, scar: false }.freeze,
        /an empty #{WOUND_BODY_PART_REGEX} socket overgrown with bits of odd shaped flesh/                                   => { severity: 8, internal: false, scar: true }.freeze,
        /a severely swollen,* bruised and blind #{WOUND_BODY_PART_REGEX}/                                                    => { severity: 8, internal: true, scar: false }.freeze,
        /a blind #{WOUND_BODY_PART_REGEX}/                                                                                   => { severity: 8, internal: true, scar: true }.freeze,
        /a completely useless #{WOUND_BODY_PART_REGEX} with nearly all flesh and bone torn away/                             => { severity: 8, internal: false, scar: false }.freeze,
        /a completely destroyed #{WOUND_BODY_PART_REGEX} with nearly all flesh and bone torn away revealing a gaping hole/   => { severity: 8, internal: false, scar: false }.freeze,
        /an ugly flesh stump for a #{WOUND_BODY_PART_REGEX}/                                                                 => { severity: 8, internal: false, scar: true }.freeze,
        /an ugly flesh stump for a #{WOUND_BODY_PART_REGEX} with little left to support the head/                            => { severity: 8, internal: false, scar: true }.freeze,
        /a severely swollen and shattered #{WOUND_BODY_PART_REGEX} which appears completely useless/                         => { severity: 8, internal: true, scar: false }.freeze,
        /a severely swollen and shattered #{WOUND_BODY_PART_REGEX} which appears useless to hold up the head/                => { severity: 8, internal: true, scar: false }.freeze,
        /a completely paralyzed #{WOUND_BODY_PART_REGEX}/                                                                    => { severity: 8, internal: true, scar: true }.freeze,
        /a mostly non-existent #{WOUND_BODY_PART_REGEX} filled with ugly chunks of scarred flesh/                            => { severity: 8, internal: false, scar: true }.freeze,
        /a severely swollen (?<part>chest) area with a shattered rib cage/                                                   => { severity: 8, internal: true, scar: false }.freeze,
        /an extremely painful #{WOUND_BODY_PART_REGEX} while gasping for breath in short shallow bursts/                     => { severity: 8, internal: true, scar: true }.freeze,
        /a severely bloated and discolored #{WOUND_BODY_PART_REGEX} which appears oddly rearranged/                          => { severity: 8, internal: true, scar: false }.freeze,
        /(?<abdomen>a death pallor and extreme loss of weight)/                                                              => { severity: 8, internal: true, scar: true }.freeze,
        /a severely swollen #{WOUND_BODY_PART_REGEX} with a shattered spinal cord/                                           => { severity: 8, internal: true, scar: false }.freeze,
        /an extremely painful and bizarrely twisted #{WOUND_BODY_PART_REGEX} making it nearly impossible to move/            => { severity: 8, internal: true, scar: true }.freeze,
        /open and bleeding sores all over the (?<part>skin)/                                                                 => { severity: 8, internal: false, scar: false }.freeze,
        /severe (?<part>skin) loss exposing bone and internal organs/                                                        => { severity: 8, internal: false, scar: true }.freeze,
        /(?<skin>complete paralysis of the entire body)/                                                                     => { severity: 8, internal: true, scar: false }.freeze,
        /(?<skin>general numbness all over and have difficulty thinking)/                                                    => { severity: 8, internal: true, scar: true }.freeze,
      }.freeze

      # https://elanthipedia.play.net/Damage#Wounds
      WOUND_COMMA_SEPARATOR = /(?<=swollen|bruised|scarred|painful),(?=\s(?:swollen|bruised|mangled|inflamed))/

      # Tend action response patterns
      TEND_SUCCESS_PATTERNS = [
        /You work carefully at tending/,
        /You work carefully at binding/,
        /That area has already been tended to/,
        /That area is not bleeding/
      ].freeze

      TEND_FAILURE_PATTERNS = [
        /You fumble/,
        /too injured for you to do that/,
        /TEND allows for the tending of wounds/,
        /^You must have a hand free/
      ].freeze

      TEND_DISLODGE_PATTERNS = [
        /^You \w+ remove (a|the|some) (.*) from/,
        /^As you reach for the clay fragment/
      ].freeze
    end

    # Backward compatibility — global variable aliases for third-party scripts
    $DRCH_BLEED_RATE_TO_SEVERITY_MAP = DRCH::BLEED_RATE_TO_SEVERITY
    $DRCH_LODGED_TO_SEVERITY_MAP = DRCH::LODGED_SEVERITY
    $DRCH_WOUND_TO_SEVERITY_MAP = DRCH::WOUND_SEVERITY
    $DRCH_PARASITES_REGEX_LIST = DRCH::PARASITES_REGEX
    $DRCH_PERCEIVE_HEALTH_SEVERITY_REGEX = DRCH::PERCEIVE_HEALTH_SEVERITY_REGEX
    $DRCH_BODY_PART_REGEX = DRCH::BODY_PART_REGEX
    $DRCH_WOUND_BODY_PART_REGEX = DRCH::WOUND_BODY_PART_REGEX
    $DRCH_LODGED_BODY_PART_REGEX = DRCH::LODGED_BODY_PART_REGEX
    $DRCH_PARASITE_BODY_PART_REGEX = DRCH::PARASITE_BODY_PART_REGEX
    $DRCH_WOUND_SEVERITY_REGEX_MAP = DRCH::WOUND_SEVERITY_REGEX_MAP
    $DRCH_WOUND_COMMA_SEPARATOR = DRCH::WOUND_COMMA_SEPARATOR
  end
end
