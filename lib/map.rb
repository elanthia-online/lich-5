#Preliminary fix (4.10.2022) for DR/GS class declare separation
#this area will see significant change / improvement

sleep 0.2 while XMLData.game.nil? or XMLData.game.empty?

if XMLData.game =~ /DR/
  require 'lib/map_dr.rb'
elsif XMLData.game =~ /GS/
  require 'lib/map_gs.rb'
else
  echo "Got me boss, no clue on map class."
end
