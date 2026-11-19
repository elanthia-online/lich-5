# WP7b (N19/N20): more of Remix's ParseGameRow routing (Game.cs:567-889, 1341-2643, 2808-3069 R).
# Every printed segment reaches TriggerParse unless its window is Room/Inv/Log; each line echoes as L:<text>.
action echo L:[$0] when ^(.*)$
pause 3
echo done
