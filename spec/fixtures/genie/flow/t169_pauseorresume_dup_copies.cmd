# WP7a-r1 (found verifying parity NB5). Two copies of one script launched in the same run are both
# listed (the dupe check walks only m_oScriptList, FormMain.cs:3401-3426 R). Command_ScriptPauseOr-
# Resume walks the list and toggles each match once (FormMain.cs:5783-6080 R): both copies pause
# and never tick, and `abort all except` ends both.
put ._t169_w
put ._t169_w
pause 0.1
echo list $scriptlist
put #script pauseorresume _t169_w
pause 0.1
echo after $scriptlist
pause 0.5
put #script abort all except t169_pauseorresume_dup_copies
pause 0.1
echo end $scriptlist
