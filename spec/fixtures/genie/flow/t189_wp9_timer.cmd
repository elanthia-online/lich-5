# WP9 G38: EvalTimer (Script.cs:3034-3105 R) and @timer@ (Script.cs:2350-2361 R).
echo t0=%t
timer
echo bare=%t
timer start
pause 1.5
echo t=%t
timer stop
echo stopped=%t
pause 1
timer start
pause 0.5
echo resumed=%t
timer start
echo twice=%t
timer clear
echo cleared=%t
timer start
pause 2
echo two=@timer@
timer setstart notadate
echo after-setstart
