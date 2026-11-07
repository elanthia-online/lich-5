# WP7b (N20, the unprobed third split): ParseGameRow prints bold text that starts "< ", "> " or "* " on
# its own when a buffer closes while m_bBold is set (Game.cs:705-719 R; a row starting "< "/"> " has
# its "< "/"> " rewritten to entities first, Game.cs:582-591 R). Each line echoes as L:<text>.
action echo L:[$0] when ^(.*)$
pause 2
echo done
