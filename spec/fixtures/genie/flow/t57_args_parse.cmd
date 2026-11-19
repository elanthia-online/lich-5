# WP1 G02/G14/G62: launch args via ParseArgs(text, true) (FormMain.cs:4683 R), %1..%9 seeded,
# %0/%argcount (Script.cs:2064-2082 R), top-level $-args empty / $argcount -1 (Script.cs:2282-2299 R),
# shift rotates the %-locals only (Script.cs:3003-3027 R)
echo argc=%argcount 0=[%0]
echo 1=[%1] 2=[%2] 3=[%3] 4=[%4] 5=[%5] 9=[%9]
echo top d0=[$0] d1=[$1] dargc=$argcount
gosub noargs
gosub withargs u_v "w x"
shift
echo s1 argc=%argcount 0=[%0] 1=[%1] 2=[%2] 3=[%3] 4=[%4]
shift
echo s2 argc=%argcount 0=[%0] 1=[%1] 2=[%2] 3=[%3]
shift
shift
shift
echo s5 argc=%argcount 0=[%0] 1=[%1] d1=[$1] dargc=$argcount
exit
noargs:
echo noargs d0=[$0] d1=[$1] dargc=$argcount
return
withargs:
echo withargs d0=[$0] d1=[$1] d2=[$2] dargc=$argcount
shift
echo withargs-shift d0=[$0] d1=[$1] argc=%argcount 1=[%1]
return
