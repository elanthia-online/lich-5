# WP9 G36: a label passed inside a { } block (Script.cs:2541-2552 R) with a scripterror label.
if 1 then
{
inside:
echo in
}
echo out
scripterror:
echo se %lastscripterror
exit
