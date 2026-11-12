# WP9 G36: RETURN with no gosub frame prints the trace and aborts (Script.cs:2515-2537 R).
echo one
goto two
two:
gosub three
echo after
return
three:
return
