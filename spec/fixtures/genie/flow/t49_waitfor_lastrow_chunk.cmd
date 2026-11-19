# Trigger-delivery race (Remix FormMain.cs:6596 R channel). Matching text is the LAST row of its
# socket chunk; the next chunk arrives 5 s later. This test runs with the default delivery.
# t49 runs the same script with --trigger-delivery chunk (consumer loses the race).
put look
waitfor You see
echo resumed
