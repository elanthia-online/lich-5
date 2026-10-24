put #trigger {^ZAP$} {#parse ZAPPED now}
waitfor ZAPPED
echo got-zapped
put look
