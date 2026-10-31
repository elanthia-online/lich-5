# WP7a (G59 + membership). `put .child` runs the child's first rows synchronously inside this row
# (ClassCommand_RunScript -> oScript.RunScript(), FormMain.cs:4678-4714 R), before either script is
# in m_oScriptList: the child's `#script abort all except nobody` aborts nothing, and this script's
# `#script abort _t159_child` misses the child, which joins at the tick end (AddScripts, FormMain.cs:
# 3809-3835 R). The child's `#var` is visible right after the launch row.
put ._t159_child one two
echo parent-after-launch $t159
put #script abort _t159_child
echo parent-still
pause 0.1
echo parent-later $scriptlist
pause 0.5
echo parent-end $scriptlist
