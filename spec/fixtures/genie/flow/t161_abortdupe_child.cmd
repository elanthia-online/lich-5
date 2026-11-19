# WP7a (G19 + membership). A second launch of a listed child aborts the first copy (FormMain.cs:
# 3401-3426 R); two launches in the same run both start (the first copy is still in m_oScriptListNew,
# which the dupe check does not walk), and both keep running.
put ._t161_child a
pause 0.2
put ._t161_child b
pause 1.5
echo phase2 $scriptlist
put ._t161_child c
put ._t161_child d
pause 1.5
echo end $scriptlist
