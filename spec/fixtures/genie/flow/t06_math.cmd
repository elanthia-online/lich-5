counter set 5
counter add 2
echo c=%c
var x 10
math x multiply 3
echo x=%x
evalmath y (2 + 3) * 4
echo y=%y
eval z replace("a-b-c", "-", "+")
echo z=%z
if %x > 20 then echo big
else echo small
if %y = 20 then
{
  echo y-is-20
}
else
{
  echo y-not-20
}
put say %x and %y
setvariable name Bob Smith
echo name=%name
