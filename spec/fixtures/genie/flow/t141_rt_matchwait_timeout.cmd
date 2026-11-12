# G07: a matchwait timeout that expires during roundtime resumes only when the roundtime ends
# (TickScript returns before every state arm while DateTime.Now < m_oRoundTimeEnd, Script.cs:1505-1511 R).
put swing
matchre never NEVERMATCH
matchwait 1
echo timeout-after-rt
put done
