action echo full=[$0] g1=[$1] g2=[$2] g3=[$3] when ^(\w+) says, "(.*)"
action echo esc=[\$1] when ^esc
action echo ten=[$10] when ^(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)
action echo opt=[$1][$2] when ^opt(x)?(y)?
put look
pause 1
