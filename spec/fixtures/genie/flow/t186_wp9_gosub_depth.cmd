# WP9 G36: gosub depth past maxgosubdepth (50) prints the trace and aborts (Script.cs:2497-2502 R).
var n 0
rec:
math n add 1
gosub rec %n
