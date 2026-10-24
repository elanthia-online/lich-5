# G07: an action goto during roundtime resumes at the end of the roundtime (actionwait is gated);
# `action instant` resumes at once (actioninstant is exempt, Script.cs:1505-1511, 2247-2260 R).
action instant goto inst when ^Instant
action goto norm when ^Normal
put swing
waitfor NEVER
inst:
echo inst
waitfor NEVER2
norm:
echo norm
