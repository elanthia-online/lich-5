# WP5 (G25 G41 G76 G80): hands with exist ids, the spell + castTime raw value, the
# per-prompt $roundtime snapshot (it does not decay: still 3 after the RT ran out), $gametime,
# PromptForce status letters and the "> " rewrite, the dead prompt, the status-prompt
# switch and its joined/bleeding fix, bar text, $charactername/$gamename. Every STEP line
# arrives after the roundtime is over (resumes are RT-gated in Remix, G07).
# Game.cs:1835-1909, 1914-1977, 1983-2010, 2014-2167, 2195-2416 R.
waitfor STEP1
echo lh=[$lefthand] lhn=[$lefthandnoun] lhid=[$lefthandid] rh=[$righthand] rhn=[$righthandnoun] rhid=[$righthandid]
echo ps=[$preparedspell] ct=[$casttime] rt=[$roundtime] gt=[$gametime] pr=[$prompt] hid=[$hidden] st=[$standing]
echo hp=[$health] hbt=[$healthBarText] mana=[$mana] mbt=[$manaBarText] enc=[$encumbrance] cn=[$charactername] gn=[$gamename]
waitfor STEP2
echo rt3=[$roundtime] pr=[$prompt] lh=[$lefthand] lhid=[$lefthandid] ps=[$preparedspell]
waitfor STEP3
echo pr=[$prompt] dead=[$dead]
waitfor STEP4
echo pr=[$prompt] joined=[$joined] bleeding=[$bleeding]
waitfor STEP5
echo pr=[$prompt] rt=[$roundtime]
