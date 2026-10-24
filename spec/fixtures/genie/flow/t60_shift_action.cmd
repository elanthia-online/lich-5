# WP1 G14: shift from an action body rotates the %-locals, never the $-arg list (Script.cs:3003-3027 R)
action shift when ^go now$
echo before argc=%argcount 1=[%1] 0=[%0]
waitfor done
echo after argc=%argcount 1=[%1] 2=[%2] 0=[%0] dargc=$argcount
