# G07 (WP4 stop-gap residue s6): a script launched during roundtime was not in the script list when the
# prompt set the roundtime (FormMain.SetRoundTime loops m_oScriptList, FormMain.cs:6927-6954 R), so its rows
# run at once: `send` queues (released when the roundtime ends) and `put` goes out immediately.
waitfor NEVER
