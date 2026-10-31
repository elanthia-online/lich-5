# WP10: arm echoes: #lc, #connect, #img, #preset, #window position, #highlight regexp, list words.
put #lc BellulaDR
put #lc {Two Words}
put #connect
put #connect a b c
put #connect a b c d e f
put #img
put #img w:x h:5 >win
put #image #1 width:12 height:zz pic.png
put #preset foo bar
put #preset roomname #00ff00
put #window position
put #window position main
put #window position main 100
put #window position main x 5
put #window position main 10 20 30 40 50
put #window position {a b} 10 20 30 40 50
put #highlight regexp red (bad
put #highlight regex red {(also} more words
put #highlight line red ok
put #macro clear
put #macros save
put #name load
put #names clear
put #highlight load
put #highlight clear
put #gag load
put #gag save
put #sub save
put #subs load
put #class save
put #alias save
put #alias load
echo done
