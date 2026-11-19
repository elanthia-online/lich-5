# WP7b (G50): trigger-on-input. ClassCommand_SendText runs ParseTriggers(sText) right after
# Game.SendText when triggeroninput is on (Config.cs:19 R default; FormMain.cs:4391-4422 R): the global
# #triggers, then every listed script's TriggerParse(text, bBufferWait=true) -- the sender's own actions
# inline, another script's waitfor/matchwait; a #trigger body's send and a typed command too.
action echo act:$1 when ^peer (\w+)
action echo act-knock when ^knock
put #trigger {^look$} {#echo trig-look}
put #trigger {^ring bell$} {peer bell}
put ._t171_helper
pause 0.2
put look
put peer around
pause 0.2
put knock twice
pause 0.3
put ring bell
pause 0.3
echo done
