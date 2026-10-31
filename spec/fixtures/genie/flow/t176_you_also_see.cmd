# WP7b (N20): PrintTextWithParse TrimStart()s a text starting "  You also see" (the room look's object
# row, printed after a blank line; Game.cs:2811-2817 R) -- after a roomDesc preset split or on its own
# row; any other leading spaces stay. Each TriggerParse line echoes as L:<text>.
action echo L:[$0] when ^(.*)$
pause 1
