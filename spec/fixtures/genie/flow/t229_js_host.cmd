# WP12: the host functions Remix gives Jint (Script.cs:699-776 R) and the expression slice.
action echo changed-v %v when eval %v = 5
js setVar("v", "5")
echo after-setvar
action echo changed-w %w when eval %w = undefined
jscall w nosuch()
echo after-jscall
var 1.5 onefive
var True tru
js setVar("n", 3)
js setVar("n2", 2.5)
js setVar("n3", 1e21)
js setVar("b", true)
js setVar("b2", false)
js setVar("n", undefined)
js setVar(null, "q")
js setVar()
echo vals %n %n2 %n3 %b %b2
js echo("hello")
js echo(1e21)
js echo(-0)
js echo(0.1)
js echo(true)
js echo()
js echo(null)
js echo(1e16, "ignored")
js echo(getVar("n"))
js put("look")
js put()
js put(42)
js setGlobal("jsglob", "gv")
echo glob $jsglob
jscall r getGlobal("jsglob")
echo g1 [%r]
jscall r getGlobal("nosuchglobal")
echo g2 [%r]
jscall r getVar()
echo g3 [%r]
jscall r getVar(1.5)
echo g4 [%r]
jscall r getVar(true)
echo g5 [%r]
jscall r 1e21
echo l1 [%r]
jscall r -0
echo l2 [%r]
jscall r 0.000001
echo l3 [%r]
jscall r 1e-7
echo l4 [%r]
jscall r null
echo l5 [%r]
jscall r undefined
echo l6 [%r]
jscall r true
echo l7 [%r]
jscall r "a"; "b"
echo l8 [%r]
jscall r 017
echo l9 [%r]
jscall r 08
echo l10 [%r]
jscall r 0x1F
echo l11 [%r]
jscall r 1_000
echo l12 [%r]
jscall r .5
echo l13 [%r]
jscall r 'it\'s \x41B\u{43}\101'
echo l14 [%r]
jscall r NaN
echo l15 [%r]
jscall r Infinity
echo l16 [%r]
jscall r
echo l17 [%r]
js
jscall  r2   getVar("n")  ;
echo l18 [%r2]
js // only a comment
js /* c */ setVar("c", "1") // tail
echo c=%c
js ;;
js nosuch("a")
js doPush("arr", "z
js doPush("arr",
js doPush("arr" "b")
js doPush("arr", 1 2)
js doPush("arr", x y)
js )
js setVar("a" ; "b")
js setVar("x", "a\x4")
js setVar("x", "a\u00")
js setVar("x", "a\u{110000}")
js setVar("x", 5abc)
js setVar("x", 0x)
js setVar("x", 1e)
js foo bar
js setVar("x", "y") setVar("z", "w")
js undefinedname
js "trail\
echo done
