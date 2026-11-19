echo ================================================================
echo   GENIE ENGINE ON LICH -- full showcase (%scriptname) @time@
echo ================================================================
timer start
echo
echo == VARIABLE TYPES ==
setvariable localvar hello
echo   local var        : %localvar
put #var globalvar world
echo   $global (#var)   : $globalvar
put #tvar tempvar session-only
echo   $temp  (#tvar)   : $tempvar
setvariable colors red|green|blue|violet
echo   array + .length  : %colors(2) is item 3 of %colors.length
gosub showargs alpha bravo charlie
echo   reserved (live game state):
echo     $health/$mana/$spirit = $health / $mana / $spirit
echo     room  = $roomname   exits: $roomexits   north? $north
echo     hands = L:$lefthand  R:$righthand
echo     position: standing=$standing kneeling=$kneeling sitting=$sitting prone=$prone
echo     condition: bleeding=$bleeding dead=$dead hidden=$hidden stunned=$stunned
echo     creatures = $monstercount ($monsterlist)
echo     spell timer: Ease Burden active=$SpellTimer.EaseBurden.active dur=$SpellTimer.EaseBurden.duration
echo     specials: unixtime=$unixtime  time=@time24@
echo
echo == STRING METHODS (eval) ==
setvariable phrase The quick brown fox
echo   phrase = "%phrase"
eval r contains("%phrase", "fox")
echo   contains fox?      %r
eval r indexof("%phrase", "brown")
echo   indexof brown      %r
eval r lastindexof("%phrase", " ")
echo   lastindexof space  %r
eval r startswith("%phrase", "The")
echo   startswith The     %r
eval r endswith("%phrase", "fox")
echo   endswith fox       %r
eval r len("%phrase")
echo   len                %r
eval r toupper("%phrase")
echo   toupper            %r
eval r tolower("%phrase")
echo   tolower            %r
eval r trim("   padded   ")
echo   trim               "%r"
eval r substr("%phrase", 4, 5)
echo   substr(4,5)        %r
eval r replace("%phrase", "quick", "slow")
echo   replace            %r
eval r replacere("%phrase", "o", "0")
echo   replacere o->0     %r
eval r count("%phrase", "o")
echo   count o            %r
eval r element("a|b|c|d", 2)
echo   element(2)         %r
eval r matchre("%phrase", "(\w+) fox")
echo   matchre (\w+) fox  %r  (captured $1)
eval r def("globalvar")
echo   def globalvar?     %r
echo
echo == ARITHMETIC (evalmath) ==
evalmath r sqrt(144)
echo   sqrt(144)          %r
evalmath r abs(0 - 7)
echo   abs(-7)            %r
evalmath r floor(3.9)
echo   floor(3.9)         %r
evalmath r ceiling(3.1)
echo   ceiling(3.1)       %r
evalmath r round(pi, 2)
echo   round(pi,2)        %r
evalmath r max(3, 9, 5)
echo   max(3,9,5)         %r
evalmath r min(3, 9, 5)
echo   min(3,9,5)         %r
evalmath r 2 ^ 3 ^ 2
echo   2^3^2 (left-assoc) %r
evalmath r 17 % 5
echo   17 mod 5           %r
evalmath r 17 \ 5
echo   17 \ 5 (int div)   %r
evalmath r log(1000)
echo   log(1000) base-10  %r
evalmath r round(pi, 4)
echo   pi to 4 places     %r
echo
echo == MATH VERB (add/sub/mul/div/mod/set) ==
var n 20
math n add 5
math n subtract 3
math n multiply 2
math n divide 4
math n mod 3
echo   ((20+5-3)*2/4) mod 3 = %n
echo
echo == CONTROL FLOW ==
random 1 6
echo   rolled %r on a d6
if %r = 6 then echo     if/elseif/else: a perfect six!
elseif %r >= 4 then echo     if/elseif/else: decent (4-5)
else echo     if/elseif/else: low (1-3)
counter set 0
countup:
counter add 1
if %c < 3 then goto countup
echo   goto loop counted to %c
echo
echo == ASYNC ACTION (register + remove) ==
action var sensed 1 when you feel a strange sensation
action remove you feel a strange sensation
echo   action registered then removed
echo
echo == LIVE ROUND-TRIP (put + match/matchre + matchwait) ==
put look
match roomseen Obvious
matchre roomseen2 (?i)obvious
matchwait 3
echo   (no room line within 3s -- fine for this demo)
goto donelook
roomseen:
echo   matched room via match!
goto donelook
roomseen2:
echo   matched room via matchre!
donelook:
echo
echo == INCLUDE (helper .cmd loaded at compile time) ==
gosub libgreet Traveler
echo   libloaded flag = %libloaded
echo
echo == TIMING ==
pause 1
echo   1s pause done; script timer = @timer@ s
echo ================================================================
echo   showcase complete -- every variable type and method, live in Lich
echo ================================================================
exit

showargs:
echo   $args: $0  ->  1:$1 2:$2 3:$3
return

greet:
echo   Hello, $1!
return
include genie-showcase-lib.cmd
