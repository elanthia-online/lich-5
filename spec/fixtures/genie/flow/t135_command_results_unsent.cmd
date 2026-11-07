put #trigger {^Calc now} {#evalmath 2+2;#eval 1;#if {1} {trigger-if}}
put #evalmath 1+1
put #eval 3 > 2
put #if {1} {look}
put #if {0} {look} {flee}
put #if {1} {#send ifsend}
put #if {1} {#evalmath 5+5}
put #echo shown
waitfor ZZZ-NO-SUCH-LINE
