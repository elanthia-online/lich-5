var bar BAR
action %w = 5;$gv = 7;eval z len("%bar");evalmath m 1+1;counter add 2;unvar bar;Put SHOULDNOT;frobnicate x;#var hv 1;echo e=%w g=$gv z=%z m=%m c=%c b=%bar when ^go
put look
pause 1
echo after w=%w z=%z m=%m c=%c hv=$hv
