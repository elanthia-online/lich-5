# G73: the prompt text ("> ", "R> " in roundtime with promptforce) is printed with parse and offered to
# #triggers and scripts like a game line (Game.cs:2397-2405, 3062-3069 R; Config.cs:25, 66 R).
action echo k152 when ^(.*).$|^probe$
action echo plain when ^(.*).$
action echo other when ^probe
action echo rt-prompt when ^R>
put #trigger {^R> $} {#echo trig-rprompt}
put look
waitforre ^R>
echo saw-rprompt
