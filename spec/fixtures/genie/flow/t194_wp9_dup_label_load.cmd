# WP9 G37: a duplicate label is a load warning (default ignorescriptwarnings False) and its text
# stays in %lastscripterror (Script.cs:4322-4336, 4342 R); the last label wins.
echo a
x:
echo b
x:
echo %lastscripterror
