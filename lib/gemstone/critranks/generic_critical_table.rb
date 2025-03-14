#
#  2024/06/25 - Creating critical table hashes by extending module CritRanks
#  2025/03/14 - Standardizing regex to /^String and downcase to all type / location
#             - support XML parsing by using consistent .*?
#

#  Generic crits are crits where the specifics of the crit are not defined by the crit table.
#  This means that the crit is not specific to a location or type, and can be applied to any
#  location or type.  An example of this would be a crit that causes the target to be stunned,
#  but does not specify where the stun occurs or what type of crit it is, such as a snake that
#  gets an RIGHT ARM critical that would stun, but has no RIGHT ARM.

# requireds template for a crit
# GENERIC:                                              <<-- the 'crit table name'
#  UNSPECIFIED:                                         <<-- the 'location'
#    0:                                                 <<-- the 'crit rank'
#      :type: GENERIC                                   <<-- this must match the crit table name
#      :location: UNSPECIFIED                           <<-- this must match the location
#      :rank: 0                                         <<-- this must match the crit rank
#      :damage: 0                                       <<-- additional damage per crit table
#      :position:                                       <<-- if the crit causing KNEEL, SITTING or PRONE
#      :fatal: false                                    <<-- if the crit is fatal
#      :stunned: 999                                    <<-- rounds of stun caused by the crit - use 999 for unknown
#      :amputated: false                                <<-- if the crit causes the LOCATION to be severed
#      :crippled: false                                 <<-- if the crit causes the location to be useless
#      :sleeping: false                                 <<-- if the crit causes an unconcious / sleeping state
#      :dazed: false                                    <<-- UAC can caused dazed effect (possible PSMs too?)
#      :limb_favored:                                   <<-- limb favored (true false or location tbd)
#      :roundtime: 0                                    <<-- if the crit causes additional roundtime
#      :silenced: false                                 <<-- if the crit prevents speaking / casting
#      :slowed: false                                   <<-- if the crit causes slower actions
#      :wound_rank: 0                                   <<-- rank of wound caused at LOCATION
#      :secondary_wound:                                <<-- second wound caused at different LOCATIONI
#      :regex: !ruby/regexp /.*? is stunned!/       <<-- the regex that denotes the crit text for capture

module Lich
  module Gemstone
    module CritRanks
      CritRanks.table[:generic] =
        { :unspecified =>
                          { 0 =>
                                 { :type            => "generic",
                                   :location        => "unspecified",
                                   :rank            => 0,
                                   :damage          => 0,
                                   :position        => nil,
                                   :fatal           => false,
                                   :stunned         => 999, # generic crits cannot have legitimate stun values (or any other value)
                                   :amputated       => false,
                                   :crippled        => false,
                                   :sleeping        => false,
                                   :wound_rank      => 0,
                                   :secondary_wound => nil,
                                   :regex           => /.*? is stunned./ } } }
    end
  end
end
