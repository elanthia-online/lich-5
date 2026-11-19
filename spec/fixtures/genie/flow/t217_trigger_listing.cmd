# WP10: ListTriggers (Command.cs:3428-3466 R) + three triggers with a " inside {} (a corpus arena-script shape).
put #trigger {^A herald cries, "BEGIN\!"  A wooden gate swings open, revealing the approach of.* (\w+)\!$} {#var arenafoe \$1;#echo >Conversation #000000 *** Bout 1;#echo >Conversation #000000 *** Watching for \\$arenafoe;#script abort all;#queue clear;#var closedin 1;#send .arenawatch;#class backoffwatcher on}
put #trigger {^A herald cries, "Bring out the next contender\!"  A wooden gate swings open, revealing the approach of.* (\w+)\!  The herald adds, "And here comes another\!  Bout (\d+), BEGIN\!"$} {#var arenafoe \$1;#echo >Conversation #000000 *** Bout \$2;#echo >Conversation #000000 *** Watching for \\$arenafoe;#script abort all;#queue clear;#var closedin 1;#class backoffwatcher on;#send .arenawatch}
put #trigger {^A herald cries, "Bring out a veteran\!"  A wooden gate swings open, revealing the approach of.* (\w+)\!  The herald adds, "And here comes another\!  Bout (\d+), BEGIN\!"$} {#var arenafoe \$1;#echo >Conversation #000000 *** Bout \$2;#echo >Conversation #000000 *** Watching for \\$arenafoe;#script abort all;#queue clear;#var closedin 1;#class backoffwatcher on;#send .arenawatch}
put #trigger
put #trigger {^zeta} {#echo zeta}
put #trigger {^Alpha} {#echo alpha} {cls}
put #trigger {/^beta/i} {#echo beta}
put #trigger {e/$x = 1} {#echo ev}
put #trigger
put #trigger eta
put #trigger {(bad} {#echo bad}
put #trigger list
put #action
put #untrigger ^zeta
put #trigger
echo done
