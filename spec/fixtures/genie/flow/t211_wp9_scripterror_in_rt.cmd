# WP9 G36: the scripterror arm runs before TickScript's roundtime gate (Script.cs:1498-1511 R).
action matchre x [ when ^boom
waitfor never
scripterror:
echo caught
