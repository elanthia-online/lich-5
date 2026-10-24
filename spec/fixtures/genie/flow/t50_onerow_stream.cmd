# Remix vs upstream Game.cs: a stream opened and closed on ONE row. Remix flushes the row text to
# the stream that was open (Game.cs:628-660 R); upstream prints it after popStream reset the target
# to Main. Scripts only see text not routed to Room/Inv/Log (Game.cs:3062-3069 R).
put look
matchre ROCK shiny rock
matchre PLAIN plain text
matchwait 3
echo timeout
exit
ROCK:
echo saw-rock
exit
PLAIN:
echo saw-plain
