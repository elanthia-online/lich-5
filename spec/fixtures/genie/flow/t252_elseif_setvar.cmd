# WPF coverage: elseif after a single-line if and after a block (corpus: 11 lines), the setvar /
# setvariable / unsetvar / unsetvariable / variable / unvariable synonyms (corpus: 13 lines;
# Script.cs:4132-4180 R keyword table).
var x 2
if %x = 1 then echo one
elseif %x = 2 then echo two
else echo other
if %x = 1 then {
  echo b1
}
elseif (%x > 1) then {
  echo b2
}
else {
  echo b3
}
var x 5
if %x = 1 then echo one
elseif %x = 2 then echo two
else echo other
if %x = 5 then echo five
elseif %x = 5 then echo never
setvar y 5
echo y=%y
setvariable y2 6
echo y2=%y2
unsetvar y
echo y=%y
unsetvariable y2
echo y2=%y2
variable z 7
echo z=%z
unvariable z
echo z=%z
