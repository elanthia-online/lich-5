#
#  Creating critical table hashes by extending module CritRanks
#  2024/06/25
#

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
#      :regex: !ruby/regexp /The .*? is stunned!/       <<-- the regex that denotes the crit text for capture

module CritRanks
  CritRanks.table[:GENERIC] =
    { "UNSPECIFIED" =>
                       { 0 =>
                              { :type            => "GENERIC",
                                :location        => "UNSPECIFIED",
                                :rank            => 0,
                                :damage          => 0,
                                :position        => nil,
                                :fatal           => false,
                                :stunned         => 999,
                                :amputated       => false,
                                :crippled        => false,
                                :sleeping        => false,
                                :wound_rank      => 0,
                                :secondary_wound => nil,
                                :regex           => /The .*? is stunned./ } } }
end
