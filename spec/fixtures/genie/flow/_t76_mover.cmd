Crate:
	action var crate 0 when ^You climb quietly into an old crate.
	action var crate 1 when ^You can't do that.

	send go crate
	waitforre You can't|You climb
	if "%crate" == "1" then send go other crate
	pause
	send #parse MOVE SUCCESSFUL