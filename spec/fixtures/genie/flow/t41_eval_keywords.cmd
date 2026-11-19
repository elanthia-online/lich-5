# Remix vs upstream Eval.cs: keyword regex case (Eval.cs:83 U "&" bug vs Eval.cs:92 R "|") and the
# &&/|| group boundary (Eval.cs:530-546 R, #145).
var a 5
if %a > 1 AND %a < 10 then echo upper-and-true
else echo upper-and-false
if %a > 1 and %a < 10 then echo lower-and-true
else echo lower-and-false
if %a > 10 OR %a = 5 then echo upper-or-true
else echo upper-or-false
if contains("abc","b") && %a = 6 then echo c1-true
else echo c1-false
if %a = 6 && contains("abc","b") then echo c2-true
else echo c2-false
if contains("abc","z") || %a = 5 then echo c3-true
else echo c3-false
if contains("abc", "b") and contains("xyz", "q") then echo c4-true
else echo c4-false
if %a = 5 && "abc" = "abd" then echo c5-true
else echo c5-false
if contains("abc","b") && 2 = 1 then echo c6-true
else echo c6-false
if %a && 2 = 5 then echo c7-true
else echo c7-false
if %a || 9 = 5 then echo c8-true
else echo c8-false
if NOT (%a = 5) then echo not-true
else echo not-false
