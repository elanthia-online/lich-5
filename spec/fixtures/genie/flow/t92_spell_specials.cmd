# WP5 (G22): $spelltime/$spellpreptime/$casttimeremaining are the reserved specials
# @spelltime@ etc. (Globals.cs:903-907 R), expanded by ParseSpecialVariables (Globals.cs:
# 206-222 R) from the spell timer FormMain starts on a non-None <spell> (FormMain.cs:
# 6697-6707 R): elapsed seconds (fractional, .NET double text), castTime - spellstarttime,
# and the remainder floored at 0. With no spell: "0", "0", and @spellpreptime@ stays literal.
# Only pauses (no waitfor) so both engines read at the same virtual time.
echo 0 st=[$spelltime] pt=[$spellpreptime] ctr=[$casttimeremaining] sst=[$spellstarttime]
pause 4
echo 1 st=[$spelltime] pt=[$spellpreptime] ctr=[$casttimeremaining] sst=[$spellstarttime] ps=[$preparedspell]
pause 4
echo 2 st=[@spelltime@] pt=[@spellpreptime@] ctr=[@casttimeremaining@]
pause 2
echo 3 st=[$spelltime] pt=[$spellpreptime] ctr=[$casttimeremaining] sst=[$spellstarttime]
