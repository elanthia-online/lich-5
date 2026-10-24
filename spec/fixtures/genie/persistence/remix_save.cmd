put #var zeta 1
put #var Alpha 2
put #var alpha 3
put #var _u 4
put #var 0num 5
put #var a-b 6
put #var ab 7
put #var a.b 8
put #var aB 9
put #var {sp ace} {v w}
put #tvar tmp 9
put #svar srv 10
put #var quoted "hi there"
put #var brace {x {y} z}
put #var empty {}
put #var co-op 1
put #var coop 1
put #var gone 1
put #unvar gone
put #var flip 1
put #tvar flip 2
put #tvar flop 1
put #var flop 2
put #math counter add 5
put #trigger {^You charge the widget|^You prime} {#if {(\\$alt = 0)} {#var charges #evalmath (\\$charges + 1)};#if {(\\$alt = 1)} {#var altcharges #evalmath (\\$altcharges + 1)};#class charging off} {charging}
put #trigger {/^Foo bar/i} {#echo x}
put #trigger {e/$nosuchvar = 1/} {#echo y}
put #trigger {^plain} {#var p 1}
put #trigger {^Apple} {#var p 2} {  spaced  }
put #trigger {^The cold mist around you fades} {#var misty 0;#class mist off} {mist}
put #var save
put #trigger save
