# WP10 G29: ClassList (Classes.cs R) + Command_EventClassChange re-apply (FormMain.cs:7483-7519 R).
put #class
put #class foo on
put #class Bar off
put #class baz yes
put #class qux enable
put #class
put #class ba
put #class +zed -foo +all
put #class
put #class -all
put #class
put #class all on
put #class all whatever
put #class
put #class all off
put #class default off
put #class
put #trigger {^ping$} {#echo pinged} {foo}
put #trigger {^ping$} {#echo pinged2}
put #trigger {^pong$} {#echo ponged} {}
put #parse ping
put #class foo on
put #parse ping
put #parse pong
put #class default on
put #parse pong
put #trigger {^tick$} {#echo ticked} {late}
put #class late off
put #trigger {^tick$} {#echo ticked again} {late}
put #parse tick
put #class nothing on
put #parse tick
put #class clear
put #class
put #class Mixed On
put #class mixed
put #class
put #class save
put #classes load
put #unclass foo
put #class foo
echo done
