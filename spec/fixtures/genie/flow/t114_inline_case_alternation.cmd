put #var pvptarget Bob
put #var prioritytarget Zed
action echo HIT $0 when ^Your lucky charm dims slightly under the strain\.|^Your lucky charm goes dark under the strain\.|^The air around you hardens into a pale blue glow|^You notice.*?quietly closes to melee range on you\.|^You spot a flicker at the edge of your vision\.|^From somewhere nearby, a low hum begins|^You feel a heavy drowsiness settle over you|^A bright green flash glints off of.*?narrowed.*?aims at you with|^You notice (?i)\b$pvptarget\w*(?-i) attempting to hide|(?i)\b$pvptarget\w*(?-i) just arrived\.$|(?i)\b$prioritytarget\w*(?-i) reveals (himself|herself|itself)\.$|(?i)\b$pvptarget\w*(?-i) fades into view\.$|^You catch sight of (?i)\b$pvptarget\w*(?-i)|(?i)\b$pvptarget\w*(?-i) is revealed\!$|turns a cold stare upon you\.$|^You get a sudden chill, as some instinct barely warns you|^You notice.*?attempting to quietly creep|trying to slip quietly past you\.$
put look
pause 1
echo end
