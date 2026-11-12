# WP9 G36: an error with a scripterror label (AbortOnScriptError, Script.cs:1109-1125 R) resumes
# there on the next tick; PrintError sets %lastscripterror (Script.cs:4342 R).
echo start %lastscripterror
goto nowhere
echo notreached
scripterror:
echo caught %lastscripterror
