# WP12: a skipped block keeps the PREVIOUS block's source (only a running block starts a new one,
# Script.cs:1805-1812 R); still open at the end, that stale source runs again (Script.cs:1736-1750 R).
<%
put("A")
%>
echo mid
if 0 then
{
<%
put("B")
