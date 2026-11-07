# WP3b (G11): eval actions on LOCAL variable changes. Script.TriggerVariableChanged (Script.cs:1358-1433 R)
# runs synchronously from every local set that calls it: setvariable/var (3543, 3554-3558), save (3535),
# put's %lastcommand (3465), eval (3275), evalmath (3244), math/counter (3307), goto's %lastlabel (2466).
# NOT from random (3119), unvar (3551), shift (3005-3025). An action fires when its key CONTAINS the
# variable name and EvalString(ParseVariables(key)) is non-empty and not "0"; a key EQUAL to the name fires
# without evaluating (1377-1384). $0 in the body is the variable NAME (ParseAction(key, [], name), 1388),
# re-expanded by RunScriptRow. Class off/on and action remove apply to eval actions too. Contains, not
# equals: `var a 7` re-evaluates the %ab and %argcount keys (AB 1, SHIFT); the `shift` row itself
# notifies nothing.
action echo LOCAL %x when eval %x = 1
action echo BARE when eval %y
action echo ZERO $0 when eval %z = 2
action echo AB %ab when eval %ab = 1
action echo LBL %lastlabel when eval %lastlabel = here
action echo SAVE when eval %s = hi
action echo CNT %c when eval %c = 3
action echo EM when eval %em = 4
action echo EV when eval %ev = yes
action echo LC when eval contains("%lastcommand", "#echo")
action echo RND when eval %r > 0
action echo UNV when eval %u = 0
action echo SHIFT when eval %argcount < 9
action (cls) echo CLS when eval %q = 1
action echo RMV when eval %w = 1
var x 0
var x 1
math x add 1
var x 1
var y 0
var z 2
var ab 1
var a 7
goto here
here:
save hi
counter set 3
evalmath em 2 + 2
eval ev "yes"
put #echo hello
random 5 9
var u 0
unvar u
shift
action (cls) off
var q 1
action (cls) on
var q 1
action remove eval %w = 1
var w 1
echo end
