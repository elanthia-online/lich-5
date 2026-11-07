echo argc=%argcount 1=%1 2=%2 3=%3 0=[%0]
shift
echo argc=%argcount 1=%1 2=%2 3=%3 0=[%0]
gosub sub a b c
exit
sub:
echo sub0=[$0] sub1=$1 sub2=$2 argc=$argcount
shift
echo sub0=[$0] sub1=$1 sub2=$2 argc=$argcount
return
