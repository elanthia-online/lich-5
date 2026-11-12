# WP12: a block still open at the end runs there; bJSBlock is never reset on that path, so the next
# ordinary row -- the scripterror label -- runs the same block again (Script.cs:1736-1750,
# 1777-1803 R) before the script gets to the label's rows.
echo start
goto skip
scripterror:
echo at-scripterror
exit
skip:
<%
put("tail");
nosuch()
