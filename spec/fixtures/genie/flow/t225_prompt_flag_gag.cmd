# WP10 G49/NB4: a gagged line or one substituted to blank leaves m_bLastRowWasPrompt (Game.cs:3075-3103 R).
put #gag {^hide}
put #sub {^blank.*} {}
var cnt 0
action math cnt add 1 when ^>
waitfor shown line
pause 0.5
echo cnt=%cnt
