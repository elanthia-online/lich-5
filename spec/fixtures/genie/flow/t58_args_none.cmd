# WP1 G02/G62: zero launch args still seed %1..%9 = "", %0 = "", %argcount = 0 (Script.cs:2064-2082 R)
echo argc=%argcount 0=[%0] 1=[%1] 9=[%9] d1=[$1] dargc=$argcount
if "%1" = "" then echo one-empty
shift
echo after argc=%argcount 0=[%0] 1=[%1]
