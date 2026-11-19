# Remix vs upstream ordering of a game-variable change vs game text in ONE socket chunk.
# Upstream: text actions run inline (FormMain.cs:6284 U) while the variable change is queued to the
# next tick (FormMain.cs:4815-4819, 2885 U). Remix: the variable change runs synchronously on the
# socket thread (FormMain.cs:5049 R) while text goes through the trigger Channel (FormMain.cs:6596 R).
action echo TEXT-ACTION when ^Ouch
action echo VAR-ACTION $health when eval $health < 60
put look
pause 2
echo done
