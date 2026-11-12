# WP12-r1 N6: a one-line JavaScript block. A line starting with <% and ending with %> does NOT
# close the block (Script.cs:3737-3745 R): the rows up to the next line ending with %> join it, and
# Jint stops at the %> left in the code (Unexpected token at the >); AbortOnScriptError then goes
# to the scripterror label.
var a 1
<% setVar("a", "2") %>
echo inside-block [%a]
setVar("a", "3") %>
echo after-block [%a]
exit
scripterror:
echo handler [%a]
