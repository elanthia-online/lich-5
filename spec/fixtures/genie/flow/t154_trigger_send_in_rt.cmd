# G07: resumes are RT-gated, sends are not: a #trigger body's game text goes out during roundtime at once
# (ParseCommand -> SendTextToGame, FormMain.cs:4615-4657, 4391-4422 R).
put #trigger {^Fire send} {rtsend}
put swing
waitfor ZZZ-NO-SUCH-LINE
