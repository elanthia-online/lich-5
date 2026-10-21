# Remix vs upstream $unixtime: upstream keeps the reserved value "@unixtime@", expanded live on
# every read (Globals.cs:230,895 U). Remix overwrites it with a literal on every prompt
# (Game.cs:2366-2369 R), so after the first prompt it only advances when a prompt arrives.
echo u1=$unixtime
pause 3
echo u2=$unixtime
pause 3
echo u3=$unixtime
