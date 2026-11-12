# WP7b (N18/N19/N20): ParseGameRow details -- an element left open at a row end is processed with the
# next row's end as its remainder, appended after that row's text and CRLF with no roomDesc split
# (Game.cs:833-850 R); the familiar stream's row-end fix-up (Game.cs:867-883 R); entities
# (Utility.TranslateHTMLChar, Game.cs:756-815 R). Each TriggerParse line echoes as L:<text>.
action echo L:[$0] when ^(.*)$
pause 1
