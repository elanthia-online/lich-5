# Maps bleed rates from `health` command to severity number.
# A partially tended wound is considered more severe than
# its non-tended counterpart because once the bandages come off
# then the wound is much worse so they should be triaged first.
# https://elanthipedia.play.net/Damage#Bleeding_Levels
#
# Skill to tend based on https://elanthipedia.play.net/First_Aid_skill#Skill_to_Tend
# A 'nil' value means that can't be tended because already is tended or isn't bleeding.
$DRCH_BLEED_RATE_TO_SEVERITY_MAP = {
  'tended'                   => {
    severity: 1,                  # lower numbers are less severe than higher numbers
    bleeding: false,              # is it actively bleeding and causing vitality loss?
    skill_to_tend: nil,           # ranks in First Aid needed to tend this external wound
    skill_to_tend_internal: nil   # ranks in First Aid needed to tend this internal wound
  },
  '(tended)'                 => {
    severity: 1,
    bleeding: false,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'clotted'                  => {
    severity: 2,
    bleeding: false,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'clotted(tended)'          => {
    severity: 3,
    bleeding: false,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'slight'                   => {
    severity: 3,
    bleeding: true,
    skill_to_tend: 30,
    skill_to_tend_internal: 600
  },
  'slight(tended)'           => {
    severity: 4,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'light'                    => {
    severity: 4,
    bleeding: true,
    skill_to_tend: 40,
    skill_to_tend_internal: 600
  },
  'light(tended)'            => {
    severity: 5,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'moderate'                 => {
    severity: 5,
    bleeding: true,
    skill_to_tend: 50,
    skill_to_tend_internal: 600
  },
  'moderate(tended)'         => {
    severity: 6,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'bad'                      => {
    severity: 6,
    bleeding: true,
    skill_to_tend: 60,
    skill_to_tend_internal: 620
  },
  'bad(tended)'              => {
    severity: 7,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'very bad'                 => {
    severity: 7,
    bleeding: true,
    skill_to_tend: 75,
    skill_to_tend_internal: 620
  },
  'very bad(tended)'         => {
    severity: 8,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'heavy'                    => {
    severity: 8,
    bleeding: true,
    skill_to_tend: 90,
    skill_to_tend_internal: 640
  },
  'heavy(tended)'            => {
    severity: 9,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'very heavy'               => {
    severity: 9,
    bleeding: true,
    skill_to_tend: 105,
    skill_to_tend_internal: 640
  },
  'very heavy(tended)'       => {
    severity: 10,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'severe'                   => {
    severity: 10,
    bleeding: true,
    skill_to_tend: 120,
    skill_to_tend_internal: 660
  },
  'severe(tended)'           => {
    severity: 11,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'very severe'              => {
    severity: 11,
    bleeding: true,
    skill_to_tend: 140,
    skill_to_tend_internal: 660
  },
  'very severe(tended)'      => {
    severity: 12,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'extremely severe'         => {
    severity: 12,
    bleeding: true,
    skill_to_tend: 160,
    skill_to_tend_internal: 700
  },
  'extremely severe(tended)' => {
    severity: 13,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'profuse'                  => {
    severity: 13,
    bleeding: true,
    skill_to_tend: 180,
    skill_to_tend_internal: 800
  },
  'profuse(tended)'          => {
    severity: 14,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'very profuse'             => {
    severity: 14,
    bleeding: true,
    skill_to_tend: 205,
    skill_to_tend_internal: 800
  },
  'very profuse(tended)'     => {
    severity: 15,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'massive'                  => {
    severity: 15,
    bleeding: true,
    skill_to_tend: 230,
    skill_to_tend_internal: 850
  },
  'massive(tended)'          => {
    severity: 16,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'gushing'                  => {
    severity: 16,
    bleeding: true,
    skill_to_tend: 255,
    skill_to_tend_internal: 850
  },
  'gushing(tended)'          => {
    severity: 17,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'massive stream'           => {
    severity: 17,
    bleeding: true,
    skill_to_tend: 285,
    skill_to_tend_internal: 1000
  },
  'massive stream(tended)'   => {
    severity: 18,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'gushing fountain'         => {
    severity: 18,
    bleeding: true,
    skill_to_tend: 285,
    skill_to_tend_internal: 1200
  },
  'gushing fountain(tended)' => {
    severity: 19,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'uncontrollable'           => {
    severity: 19,
    bleeding: true,
    skill_to_tend: 400,
    skill_to_tend_internal: 1400
  },
  'uncontrollable(tended)'   => {
    severity: 20,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'unbelievable'             => {
    severity: 20,
    bleeding: true,
    skill_to_tend: 500,
    skill_to_tend_internal: 1600
  },
  'unbelievable(tended)'     => {
    severity: 21,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'beyond measure'           => {
    severity: 21,
    bleeding: true,
    skill_to_tend: 600,
    skill_to_tend_internal: 1750
  },
  'beyond measure(tended)'   => {
    severity: 22,
    bleeding: true,
    skill_to_tend: nil,
    skill_to_tend_internal: nil
  },
  'death awaits'             => {
    severity: 22,
    bleeding: true,
    skill_to_tend: 700,
    skill_to_tend_internal: 1750
  },
}

# https://elanthipedia.play.net/Damage#Lodged_Items
$DRCH_LODGED_TO_SEVERITY_MAP = {
  'loosely hanging' => 1,
  'shallowly'       => 2,
  'firmly'          => 3,
  'deeply'          => 4,
  'savagely'        => 5
}

# https://elanthipedia.play.net/Damage#Wound_Severity_Levels
$DRCH_WOUND_TO_SEVERITY_MAP = {
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
}

# https://elanthipedia.play.net/Damage#Parasites
$DRCH_PARASITES_REGEX_LIST = [
  /(?:small|large) (?:black|red) blood mite/,
  /(?:black|red|albino) (sand|forest) leech/,
  /(?:green|red) blood worm/,
  /retch maggot/
]

# Parses the severity number out of the wound line from 'perceive health self'.
# For example, the 'negligible' in "Fresh External:  light scratches -- negligible"
$DRCH_PERCEIVE_HEALTH_SEVERITY_REGEX = /(?<freshness>Fresh|Scars) (?<location>External|Internal).+--\s+(?<severity>insignificant|negligible|minor|more than minor|harmful|very harmful|damaging|very damaging|severe|very severe|devastating|very devastating|useless)\b/

$DRCH_BODY_PART_REGEX = /(?<part>(?:l\.|r\.|left|right)?\s?(?:\w+))/

# Matches body parts in the `health` line for wounds and bleeders.
$DRCH_WOUND_BODY_PART_REGEX = /(?:inside)?\s?#{$DRCH_BODY_PART_REGEX}/

# Matches body parts in the `health` line for lodged items.
$DRCH_LODGED_BODY_PART_REGEX = /lodged .* into your #{$DRCH_BODY_PART_REGEX}/

# Matches body parts in the `health` line for parasites.
$DRCH_PARASITE_BODY_PART_REGEX = /on your #{$DRCH_BODY_PART_REGEX}/

# https://elanthipedia.play.net/Damage#Wounds
$DRCH_WOUND_SEVERITY_REGEX_MAP = {
  # insignificant
  /minor abrasions to the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                    => {
    severity: 1,
    internal: false,
    scar: false
  },
  /a few nearly invisible scars along the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                    => {
    severity: 1,
    internal: false,
    scar: true
  },
  # negligible
  /some tiny scars (?:across|along) the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                      => {
    severity: 2,
    internal: false,
    scar: true
  },
  /(?:light|tiny) scratches to the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                           => {
    severity: 2,
    internal: false,
    scar: false
  },
  # minor / more than minor
  /a bruised (?<part>head)/                                                                                                  => {
    severity: 3,
    internal: true,
    scar: false
  },
  /(?<skin>a small skin rash)/                                                                                               => {
    severity: 3,
    internal: false,
    scar: false
  },
  /(?<skin>loss of skin tone)/                                                                                               => {
    severity: 3,
    internal: false,
    scar: true
  },
  /(?<skin>some minor twitching)/                                                                                            => {
    severity: 3,
    internal: true,
    scar: false
  },
  /(?<skin>slight difficulty moving your fingers and toes)/                                                                  => {
    severity: 3,
    internal: true,
    scar: true
  },
  /cuts and bruises about the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                => {
    severity: 3,
    internal: false,
    scar: false
  },
  /minor scar\w+ (?:about|along|across) the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                  => {
    severity: 3,
    internal: false,
    scar: true
  },
  /minor swelling and bruising (?:around|in) the #{$DRCH_WOUND_BODY_PART_REGEX}/                                             => {
    severity: 3,
    internal: true,
    scar: false
  },
  /occasional twitch\w* (?:on|in) the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                        => {
    severity: 3,
    internal: true,
    scar: true
  },
  /a black and blue #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                          => {
    severity: 3,
    internal: false,
    scar: false
  },
  # harmful / very harmful
  /a deeply bruised (?<part>head)/                                                                                           => {
    severity: 4,
    internal: true,
    scar: false
  },
  /(?<skin>a large skin rash)/                                                                                               => {
    severity: 4,
    internal: false,
    scar: false
  },
  /(?<skin>minor skin discoloration)/                                                                                        => {
    severity: 4,
    internal: false,
    scar: true
  },
  /(?<skin>some severe twitching)/                                                                                           => {
    severity: 4,
    internal: true,
    scar: false
  },
  /(?<skin>slight numbness in your arms and legs)/                                                                           => {
    severity: 4,
    internal: true,
    scar: true
  },
  /deep cuts (?:about|across) the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                            => {
    severity: 4,
    internal: false,
    scar: false
  },
  /severe scarring (?:across|along|about) the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                => {
    severity: 4,
    internal: false,
    scar: true
  },
  /a severely swollen and\s?(?:deeply)? bruised #{$DRCH_WOUND_BODY_PART_REGEX}/                                              => {
    severity: 4,
    internal: true,
    scar: false
  },
  /(?:occasional|constant) twitch\w* (?:on|in) the #{$DRCH_WOUND_BODY_PART_REGEX}/                                           => {
    severity: 4,
    internal: true,
    scar: true
  },
  /a bruised and swollen (?<part>(?:right|left) (?:eye))/                                                                    => {
    severity: 4,
    internal: false,
    scar: false
  },
  # damaging / very damaging
  /some deep slashes and cuts about the (?<part>head)/                                                                       => {
    severity: 5,
    internal: false,
    scar: false
  },
  /severe scarring and ugly gashes about the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                 => {
    severity: 5,
    internal: false,
    scar: true
  },
  /major swelling and bruising around the (?<part>head)/                                                                     => {
    severity: 5,
    internal: true,
    scar: false
  },
  /an occasional twitch on the fore(?<part>head)/                                                                            => {
    severity: 5,
    internal: true,
    scar: true
  },
  /a bruised,* swollen and bleeding #{$DRCH_WOUND_BODY_PART_REGEX}/                                                          => {
    severity: 5,
    internal: false,
    scar: false
  },
  /deeply scarred gashes across the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                          => {
    severity: 5,
    internal: false,
    scar: true
  },
  /a severely swollen, bruised and crossed #{$DRCH_WOUND_BODY_PART_REGEX}/                                                   => {
    severity: 5,
    internal: true,
    scar: false
  },
  /a constant twitching in the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                               => {
    severity: 5,
    internal: true,
    scar: true
  },
  /deep slashes across the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                   => {
    severity: 5,
    internal: false,
    scar: false
  },
  /a severely swollen and deeply bruised #{$DRCH_WOUND_BODY_PART_REGEX}/                                                     => {
    severity: 5,
    internal: true,
    scar: false
  },
  /severely swollen and bruised #{$DRCH_WOUND_BODY_PART_REGEX}/                                                              => {
    severity: 5,
    internal: true,
    scar: false
  },
  /a constant twitching in the (?<part>chest) area and difficulty breathing/                                                 => {
    severity: 5,
    internal: true,
    scar: true
  },
  /(?<abdomen>a somewhat emaciated look)/                                                                                    => {
    severity: 5,
    internal: true,
    scar: true
  },
  /a constant twitching in the #{$DRCH_WOUND_BODY_PART_REGEX} and difficulty moving in general/                              => {
    severity: 5,
    internal: true,
    scar: true
  },
  /(?<skin>a body rash)/                                                                                                     => {
    severity: 5,
    internal: false,
    scar: false
  },
  /severe (?<part>skin) discoloration/                                                                                       => {
    severity: 5,
    internal: false,
    scar: true
  },
  /(?<skin>difficulty controlling actions)/                                                                                  => {
    severity: 5,
    internal: true,
    scar: false
  },
  /(?<skin>numbness in your fingers and toes)/                                                                               => {
    severity: 5,
    internal: true,
    scar: true
  },
  # severe / very severe
  /(?<head>a cracked skull with deep slashes)/                                                                               => {
    severity: 6,
    internal: false,
    scar: false
  },
  /missing chunks out of the (?<part>head)/                                                                                  => {
    severity: 6,
    internal: false,
    scar: true
  },
  /a bruised, swollen and slashed #{$DRCH_WOUND_BODY_PART_REGEX}/                                                            => {
    severity: 6,
    internal: false,
    scar: false
  },
  /a punctured and shriveled #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                 => {
    severity: 6,
    internal: false,
    scar: true
  },
  /a severely swollen,* bruised and cloudy #{$DRCH_WOUND_BODY_PART_REGEX}/                                                   => {
    severity: 6,
    internal: true,
    scar: false
  },
  /a clouded #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                                 => {
    severity: 6,
    internal: true,
    scar: true
  },
  /gaping holes in the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                       => {
    severity: 6,
    internal: false,
    scar: false
  },
  /a broken #{$DRCH_WOUND_BODY_PART_REGEX} with gaping holes/                                                                => {
    severity: 6,
    internal: false,
    scar: false
  },
  /severe scarring and ugly gashes about the #{$DRCH_WOUND_BODY_PART_REGEX}/                                                 => {
    severity: 6,
    internal: false,
    scar: true
  },
  /severe scarring and chunks of flesh missing from the #{$DRCH_WOUND_BODY_PART_REGEX}/                                      => {
    severity: 6,
    internal: false,
    scar: true
  },
  /a severely swollen and deeply bruised #{$DRCH_WOUND_BODY_PART_REGEX} with odd protrusions under the skin/                 => {
    severity: 6,
    internal: true,
    scar: false
  },
  /a severely swollen and deeply bruised (?<part>chest) area with odd protrusions under the skin/                            => {
    severity: 6,
    internal: true,
    scar: false
  },
  /a partially paralyzed #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                     => {
    severity: 6,
    internal: true,
    scar: true
  },
  /a painful #{$DRCH_WOUND_BODY_PART_REGEX} and difficulty moving without pain/                                              => {
    severity: 6,
    internal: true,
    scar: true
  },
  /a painful (?<part>chest) area and difficulty getting a breath without pain/                                               => {
    severity: 6,
    internal: true,
    scar: true
  },
  /a severely bloated and discolored #{$DRCH_WOUND_BODY_PART_REGEX} with strange round lumps under the skin/                 => {
    severity: 6,
    internal: true,
    scar: false
  },
  /(?<abdomen>a definite greenish pallor and emaciated look)/                                                                => {
    severity: 6,
    internal: true,
    scar: true
  },
  /(?<skin>a painful,* inflamed body rash)/                                                                                  => {
    severity: 6,
    internal: false,
    scar: false
  },
  /(?<skin>a painful,* enflamed body rash)/                                                                                  => {
    severity: 6,
    internal: false,
    scar: false
  },
  /some shriveled and oddly folded (?<part>skin)/                                                                            => {
    severity: 6,
    internal: false,
    scar: true
  },
  /(?<skin>partial paralysis of the entire body)/                                                                            => {
    severity: 6,
    internal: true,
    scar: false
  },
  /(?<skin>numbness in your arms and legs)/                                                                                  => {
    severity: 6,
    internal: true,
    scar: true
  },
  # devastating / very devastating
  /(?<head>a crushed skull with horrendous wounds)/                                                                          => {
    severity: 7,
    internal: false,
    scar: false
  },
  /a mangled and malformed (?<part>head)/                                                                                    => {
    severity: 7,
    internal: false,
    scar: true
  },
  /a ghastly bloated (?<part>head) with bleeding from the ears/                                                              => {
    severity: 7,
    internal: true,
    scar: false
  },
  /a confused look with sporadic twitching of the fore(?<part>head)/                                                         => {
    severity: 7,
    internal: true,
    scar: true
  },
  /a bruised,* swollen and shattered #{$DRCH_WOUND_BODY_PART_REGEX}/                                                         => {
    severity: 7,
    internal: false,
    scar: false
  },
  /a painfully mangled and malformed #{$DRCH_WOUND_BODY_PART_REGEX} in a shattered eye socket/                               => {
    severity: 7,
    internal: false,
    scar: true
  },
  /a severely swollen,* bruised and blind #{$DRCH_WOUND_BODY_PART_REGEX}/                                                    => {
    severity: 7,
    internal: true,
    scar: false
  },
  /severely scarred,* mangled and malformed #{$DRCH_WOUND_BODY_PART_REGEX}/                                                  => {
    severity: 7,
    internal: false,
    scar: true
  },
  /a completely clouded #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                      => {
    severity: 7,
    internal: true,
    scar: true
  },
  /a shattered #{$DRCH_WOUND_BODY_PART_REGEX} with gaping wounds/                                                            => {
    severity: 7,
    internal: false,
    scar: false
  },
  /shattered (?<part>chest) area with gaping wounds/                                                                         => {
    severity: 7,
    internal: false,
    scar: false
  },
  /a severely swollen and deeply bruised #{$DRCH_WOUND_BODY_PART_REGEX} with bones protruding out from the skin/             => {
    severity: 7,
    internal: true,
    scar: false
  },
  /a severely swollen and deeply bruised #{$DRCH_WOUND_BODY_PART_REGEX} with ribs or vertebrae protruding out from the skin/ => {
    severity: 7,
    internal: true,
    scar: false
  },
  /a severely paralyzed #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                      => {
    severity: 7,
    internal: true,
    scar: true
  },
  /a severely painful #{$DRCH_WOUND_BODY_PART_REGEX} with significant problems moving/                                       => {
    severity: 7,
    internal: true,
    scar: true
  },
  /a severely painful (?<part>chest) area with significant problems breathing/                                               => {
    severity: 7,
    internal: true,
    scar: true
  },
  /#{$DRCH_WOUND_BODY_PART_REGEX} deeply gouged with gaping wounds/                                                          => {
    severity: 7,
    internal: false,
    scar: false
  },
  /a severely bloated and discolored #{$DRCH_WOUND_BODY_PART_REGEX} with strange round lumps under the skin/                 => {
    severity: 7,
    internal: true,
    scar: false
  },
  /(?<abdomen>a severely yellow pallor and a look of starvation)/                                                            => {
    severity: 7,
    internal: true,
    scar: true
  },
  /a shattered #{$DRCH_WOUND_BODY_PART_REGEX} with gaping wounds/                                                            => {
    severity: 7,
    internal: false,
    scar: false
  },
  /boils and sores around the (?<part>skin)/                                                                                 => {
    severity: 7,
    internal: false,
    scar: false
  },
  /severely stiff and shriveled (?<part>skin) that seems to be peeling off the body/                                         => {
    severity: 7,
    internal: false,
    scar: true
  },
  /(?<skin>severe paralysis of the entire body)/                                                                             => {
    severity: 7,
    internal: true,
    scar: false
  },
  /(?<skin>general numbness all over)/                                                                                       => {
    severity: 7,
    internal: true,
    scar: true
  },
  # useless
  /pulpy stump for a (?<part>head)/                                                                                          => {
    severity: 8,
    internal: false,
    scar: false
  },
  /a stump for a (?<part>head)/                                                                                              => {
    severity: 8,
    internal: false,
    scar: true
  },
  /an ugly stump for a #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                       => {
    severity: 8,
    internal: false,
    scar: false
  },
  /a grotesquely bloated (?<part>head) with bleeding from the eyes and ears/                                                 => {
    severity: 8,
    internal: true,
    scar: false
  },
  /(?<head>a blank stare)/                                                                                                   => {
    severity: 8,
    internal: true,
    scar: true
  },
  /a pulpy cavity for a #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                      => {
    severity: 8,
    internal: false,
    scar: false
  },
  /an empty #{$DRCH_WOUND_BODY_PART_REGEX} socket overgrown with bits of odd shaped flesh/                                   => {
    severity: 8,
    internal: false,
    scar: true
  },
  /a severely swollen,* bruised and blind #{$DRCH_WOUND_BODY_PART_REGEX}/                                                    => {
    severity: 8,
    internal: true,
    scar: false
  },
  /a blind #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                                   => {
    severity: 8,
    internal: true,
    scar: true
  },
  /a completely useless #{$DRCH_WOUND_BODY_PART_REGEX} with nearly all flesh and bone torn away/                             => {
    severity: 8,
    internal: false,
    scar: false
  },
  /a completely destroyed #{$DRCH_WOUND_BODY_PART_REGEX} with nearly all flesh and bone torn away revealing a gaping hole/   => {
    severity: 8,
    internal: false,
    scar: false
  },
  /an ugly flesh stump for a #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                 => {
    severity: 8,
    internal: false,
    scar: true
  },
  /an ugly flesh stump for a #{$DRCH_WOUND_BODY_PART_REGEX} with little left to support the head/                            => {
    severity: 8,
    internal: false,
    scar: true
  },
  /a severely swollen and shattered #{$DRCH_WOUND_BODY_PART_REGEX} which appears completely useless/                         => {
    severity: 8,
    internal: true,
    scar: false
  },
  /a severely swollen and shattered #{$DRCH_WOUND_BODY_PART_REGEX} which appears useless to hold up the head/                => {
    severity: 8,
    internal: true,
    scar: false
  },
  /a completely paralyzed #{$DRCH_WOUND_BODY_PART_REGEX}/                                                                    => {
    severity: 8,
    internal: true,
    scar: true
  },
  /a mostly non-existent #{$DRCH_WOUND_BODY_PART_REGEX} filled with ugly chunks of scarred flesh/                            => {
    severity: 8,
    internal: false,
    scar: true
  },
  /a severely swollen (?<part>chest) area with a shattered rib cage/                                                         => {
    severity: 8,
    internal: true,
    scar: false
  },
  /an extremely painful #{$DRCH_WOUND_BODY_PART_REGEX} while gasping for breath in short shallow bursts/                     => {
    severity: 8,
    internal: true,
    scar: true
  },
  /a severely bloated and discolored #{$DRCH_WOUND_BODY_PART_REGEX} which appears oddly rearranged/                          => {
    severity: 8,
    internal: true,
    scar: false
  },
  /(?<abdomen>a death pallor and extreme loss of weight)/                                                                    => {
    severity: 8,
    internal: true,
    scar: true
  },
  /a severely swollen #{$DRCH_WOUND_BODY_PART_REGEX} with a shattered spinal cord/                                           => {
    severity: 8,
    internal: true,
    scar: false
  },
  /an extremely painful and bizarrely twisted #{$DRCH_WOUND_BODY_PART_REGEX} making it nearly impossible to move/            => {
    severity: 8,
    internal: true,
    scar: true
  },
  /open and bleeding sores all over the (?<part>skin)/                                                                       => {
    severity: 8,
    internal: false,
    scar: false
  },
  /severe (?<part>skin) loss exposing bone and internal organs/                                                              => {
    severity: 8,
    internal: false,
    scar: true
  },
  /(?<skin>complete paralysis of the entire body)/                                                                           => {
    severity: 8,
    internal: true,
    scar: false
  },
  /(?<skin>general numbness all over and have difficulty thinking)/                                                          => {
    severity: 8,
    internal: true,
    scar: true
  }
}

# https://elanthipedia.play.net/Damage#Wounds
$DRCH_WOUND_COMMA_SEPARATOR = /(?<=swollen|bruised|scarred|painful),(?=\s(?:swollen|bruised|mangled|inflamed))/
