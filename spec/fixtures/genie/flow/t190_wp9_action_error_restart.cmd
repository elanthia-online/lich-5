# WP9 G36: an action goto to an unknown label with a scripterror label: RunScriptRow returns 0,
# which ParseAction takes as an action goto to row 0 (Script.cs:2244-2268 R) -- the script
# starts over instead of running the label.
echo top %lastlabel
action goto nowhere when ^boom
waitfor never
echo notreached
scripterror:
echo se %lastscripterror
exit
