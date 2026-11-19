put #trigger {^Fire send} {#send rtsend}
put #trigger {^Fire queue} {#queue 0 qfree}
put #trigger {^Fire both} {#send hol1;#queue 0 hol2}
put swing
waitfor ZZZ-NO-SUCH-LINE
