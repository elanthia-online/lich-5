# Remix vs upstream: a global #trigger whose action re-sends its own trigger text, with
# triggeroninput on (Genie default, Config.cs:19). Upstream ParseTriggers has a re-entrancy guard
# (FormMain.cs:4148-4171 U) and Command.ParseCommand a depth guard (Command.cs:221-224 U); Remix has
# neither (FormMain.cs:4425 R, Command.cs:219 R): the recursion is unbounded and the real client
# overflows its stack. genieflow reports that as "genie-crash" and halts.
put #trigger {^ping$} {ping}
put ping
echo after
