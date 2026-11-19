# WP9 G37: settings.cfg ignorescriptwarnings True drops an unknown command and keeps a duplicate
# label silent (Script.cs:4070-4078, 4322-4336 R); maxgosubdepth 3 (Config.cs:905-912 R).
echo a
blarg zz
x:
x:
echo err=%lastscripterror
gosub a1
echo back
exit
a1:
gosub a2
return
a2:
gosub a3
return
a3:
echo deep
return
