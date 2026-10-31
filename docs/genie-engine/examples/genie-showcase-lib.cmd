# Helper library included by genie-showcase.cmd via `include genie-showcase-lib.cmd`.
# Copy this into your Lich scripts dir alongside genie-showcase.cmd.
libgreet:
echo   [included lib] Greetings, $1, from a separate .cmd file!
setvariable libloaded 1
return
