var n 0
if (%n = 0) then
{
  echo zero
  if (1 = 2) then
  {
    echo nope
  }
  else
  {
    echo inner-else
  }
}
else echo outer-else
while (%n < 3) do
{
  math n add 1
  echo while %n
}
echo n=%n
if_1 echo has-arg-1
echo end
