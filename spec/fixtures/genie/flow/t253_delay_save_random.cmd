# WPF coverage: delay forms (1836 corpus lines; only t20 before) -- EvalDelayScript on
# Utility.EvalDoubleTime (Script.cs:2644, 3375 R), RT-exempt; save sets %s (Script.cs:4132 R);
# a degenerate random range.
delay 0.05
echo d1
delay
echo d2
delay 0.3s
echo d3
delay abc
echo d4
put swing
waitfor You swing
delay 1
echo d5-in-rt
save hello world
echo s=%s
save
echo s=[%s]
random 5 5
echo r=%r
random 0 0
echo r0=%r
