# WP10 G70: #triggers fire in SortedList order with IsActive read per pass (FormMain.cs:4431-4457 R).
put #trigger {^go} {#echo z-fired;#class c1 off} {c0}
put #trigger {^g} {#echo b-fired;#class c2 on} {c0}
put #trigger {go\$} {#echo c1-fired} {c1}
put #trigger {o\$} {#echo c2-fired} {c2}
put #trigger {^(g)(o)} {#echo A-fired \$1 \$2 \$0} {}
put #class c2 off
put #parse go
put #parse go
put #trigger {"(\w+)" (says)} {#echo q=\$1 z=\$0 t=\$2}
put #parse "hi" says
echo done
