# B1 (WP6-r1): Game.cs prints the prompt text with parse (and rewrites $prompt to "> ") only while the
# last row printed to the MAIN window was not itself a prompt (!m_bLastRowWasPrompt, Game.cs:2397 R).
# FormMain.AddText sets the flag when a prompt is printed to main and clears it on any other main
# text that is not blank: game text, the echo of every send, script echo, #echo with no window
# (FormMain.cs:5100-5122 R). A vitals pulse, a thoughts-stream row or #echo >window clear nothing,
# so the next prompt is neither offered to the actions nor seen by a matchre .* (uber.cmd's
# CLEAR_MATCHTABLE). TriggerPrompt still fires on every prompt (Game.cs:2411 R).
action var seen %seen|$0 when ^R?>
var seen start
waitfor START
pause 1
put step2
pause 1
echo mark
pause 1
put #echo >Familiar named
pause 1
put #echo plain
pause 1
matchre CLR .*
matchwait 3
CLR:
echo matched=[$0]
echo seen=%seen
echo prompt=[$prompt]
