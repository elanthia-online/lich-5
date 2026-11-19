# WP12: <% %> blocks run when the next ordinary row comes (Script.cs:1777-1815 R).
echo start
<% setVar("x", "1");
setVar("y", "2") %>
echo x=%x y=%y
if 0 then
{
<%
setVar("z", "3");
%>
}
echo z=%z
<%
// a comment
setVar("m", "multi")
setVar("m2", 'two')
put("from-block")
%>
echo m=%m m2=%m2
<%
nosuch();
%>
echo not-here
scripterror:
echo at-scripterror
js setVar("w", "9")
echo w=%w
