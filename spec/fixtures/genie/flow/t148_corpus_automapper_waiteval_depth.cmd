# automapper.cmd:736-737 (+806/853/932/1005/1080/1501/2330) (verbatim row)
var waitevalTimeOut 300
var depth 3
action math depth subtract 1 when ^Obvious paths
waitfor GO
echo before %depth
evalmath depthtimeout $unixtime + %waitevalTimeOut
  if (%depth > 1) then waiteval ((1 <= %depth) || ($gametime >= %depthtimeout))
echo after %depth
