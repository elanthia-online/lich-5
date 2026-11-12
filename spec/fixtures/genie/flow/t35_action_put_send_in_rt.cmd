action put react-put $1 when ^Then (\w+) happens
action send react-send $1 when ^Now (\w+) occurs
put swing
waitfor You swing
echo after-rt
