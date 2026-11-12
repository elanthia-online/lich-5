# WP10 G49: gag/sub lists (Globals.cs:1414-1846 R; Command.cs:1661-1884 R); display not compared.
put #gag {^You see}
put #gag {^You see}
put #gag {/^hidden/i} {cls} TRUE
put #gag {(bad} {x}
put #gag {a b} c d
put #sub {^The (\w+) door} {A ${1}x door $$ $& $0 $9 $+ [$_]}
put #sub {(bad} {x}
put #subs {^In the chapter entitled.*(Holy Warrior \[how\]) {\$1 utility/warding} {Paladin}
put #sub {^Gold} {$roundtime gold} {money}
put #gag
put #sub
put #gag list
put #ungag a b
put #ungag ^You see
put #gag
put #unsub ^Gold
put #sub
put #sub clear
put #gag clear
put #gag {^You see}
put #sub {^The (\w+) door} {A ${1}x door $$ $& $0 $9 $+ [$_]}
put #sub {^Gold} {\$roundtime gold}
put #sub {  spaced  } {S}
put #gag {^gagme}
put #sub {^ab+} {}
