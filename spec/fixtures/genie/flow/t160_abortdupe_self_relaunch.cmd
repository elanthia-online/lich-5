# WP7a (G19). Relaunching a running script replaces it (abortdupescript, default True, Config.cs:39 R):
# LoadScript aborts every listed script with the same FileName (FormMain.cs:3401-3426 R), then the new
# copy runs its first rows synchronously (FormMain.cs:4678-4714 R); the old copy's RunScript loop then
# breaks (Script.cs:1726-1730 R), so "old-continues" never echoes. The new copy has its own args.
# (a tester script's `put .<itself> <arg>` / `exit`; hunt.cmd, a wordle script.)
echo run %1 %argcount
if "%1" = "2" then goto second
pause 0.1
put .t160_abortdupe_self_relaunch 2 extra
echo old-continues
pause 0.1
echo old-after-pause
exit
second:
echo new-copy %0
pause 0.2
echo new-done $scriptlist
