# WP12: a JavaScript syntax error in a block: "[Javascript error ...]" naming the block's first row,
# the position inside the block, no scripterror label -> the script aborts.
echo start
<%
setVar("a", "1");
setVar("b",
%>
echo not-here
