put #trigger {^Hit (\S+) (\w+)(x)?} {#echo [\$0] [\$1] [\$2] [\$3] [\$4] [\$probe];say \$1 and \$probe}
put #var probe late
waitfor ZZZ-NO-SUCH-LINE
