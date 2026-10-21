# WP10 G48: #echo drops a colour NAME (ColorCode.IsColorString, ColorCode.cs:132-153 R), any case,
# also as the fg of fg,bg; RebeccaPurple/Transparent/system colours/@names stay text (Command.cs:295-313 R).
put #echo red text1
put #echo Crimson text2
put #echo YELLOWGREEN text3
put #echo RebeccaPurple text4
put #echo Transparent text5
put #echo ControlText text6
put #echo grey text7
put #echo RED,blue text8
put #echo red, text9
put #echo red,zzz text10
put #echo zzz,red text11
put #echo >Log yellow text12
put #echo yellow >Log text13
put #echo @red text14
put #echo red
put #echo >w red
put #echo Lime *** Climbed Xing walls 0 times ***
put #echo Crimson *** MISSING MATCH IN PUT! ***
echo done
