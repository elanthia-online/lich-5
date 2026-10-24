matchre semiA ^You think\W therefore
matchre semiB ^You think therefore
matchwait 2
echo miss-semi
goto amp
semiA:
echo semi-kept $0
goto amp
semiB:
echo semi-dropped $0
amp:
matchre ampA ^Tom & Al$
matchre ampB ^Tom\s*$
matchwait 2
echo miss-amp
goto gt
ampA:
echo amp-kept $0
goto gt
ampB:
echo amp-lost $0
gt:
matchre gtA X &gt. Y
matchre gtB X &gt Y
matchwait 2
echo miss-gt
exit
gtA:
echo gt-semi
exit
gtB:
echo gt-nosemi
