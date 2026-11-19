# WP7a (G42). A corpus stop label: `put #script abort all` then `put .<cleanup script>`. Once the script is
# listed, the abort stops it before the next row (AbortScript, Script.cs:1137-1165 R; RunScript's loop,
# Script.cs:1726-1730 R): no launch, no send. Also from an action body (ParseAction's put -> the same
# Command_ScriptAbort, FormMain.cs:5783-5830 R).
put ._t164_other
pause 0.1
put #script abort all
put ._t164_other
echo after-abort-all
