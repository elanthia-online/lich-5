# WP12: jsblock / jsblockend rows at debug 15 and 10 (Script.cs:1772-1776, 2438-2441 R).
debug 15
include _t235_tiny.js
echo t=%t
debug 10
<%
setVar("u", "2")
%>
echo u=%u
jscall r getVar("u")
