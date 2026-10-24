# WPF (Q8 correction): a #class toggle inside a #trigger body is no list mutation -- Remix reads each
# trigger's IsActive as ParseTriggers walks the SortedList (FormMain.cs:4431-4455 R), so a class turned
# off by an earlier trigger stops a later trigger on the SAME line and one turned on fires it (114 corpus
# trigger bodies toggle #class).
pause 1
echo end
