# WP7a (membership + G01(b)). ParseTriggers offers a #parse only to the scripts in m_oScriptList
# (FormMain.cs:4425-4512 R): a child launched in the same run is not listed yet (FormMain.cs:4678-4714,
# 3809-3835 R), so the first #parse misses its waitfor; the second, a tick later, reaches it.
put ._t165_child
put #parse HELLO
pause 0.1
put #parse HELLO
pause 0.2
echo end
