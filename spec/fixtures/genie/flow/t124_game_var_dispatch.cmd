# WP3b (G11, N08): game-variable changes. Game.cs raises VariableChanged while it parses a row
# ($health Game.cs:1856, $standing 2066, $prompt 2410, $roundtime 2389, $roomname 1515, "monsterlist"
# 2716, $righthand 1975 R) and FormMain runs TriggerVariableChanged synchronously (FormMain.cs:5045-5050
# R): global eval #triggers first (4936-4963 R), then every script (4964-4969 R) -- before the row's
# text reaches the text actions through the trigger Channel (6596 R), so ACT-HEALTH precedes ACT-TEXT.
# "compass" returns early (4779-4795 R): NORTH never fires. A key equal to the name fires unevaluated
# (`e/$standing/`, `eval $prompt`). The #triggers are typed (INPUT) so the script's own $-expansion
# does not bake the current values into the patterns.
action echo ACT-PROMPT $prompt when eval $prompt
action echo ACT-RT $roundtime when eval $roundtime > 0
action echo ACT-ML $monsterlist when eval contains("$monsterlist", "goblin")
action echo ACT-HAND $righthand when eval $righthand != Empty
action echo ACT-HEALTH $health when eval $health < 60
action echo ACT-TEXT when ^Ouch
pause 0.1
echo ready
pause 3
echo end
