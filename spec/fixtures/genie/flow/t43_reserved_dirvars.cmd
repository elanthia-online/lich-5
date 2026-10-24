# Remix vs upstream Globals: Remix adds reserved $scriptdir/$mapdir/$plugindir/$logdir/$artdir/
# $sounddir (Globals.cs:859-864 R, expanded at Globals.cs:237-242 R) and drops $gameroomid.
echo sd=$scriptdir
echo ld=$logdir
echo md=$mapdir
echo gr=$gameroomid
