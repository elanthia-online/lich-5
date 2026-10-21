# helper for t125_var_change_scripts: an eval action on a global, waiting forever.
action echo B-SAW $bar when eval $bar > 0
waitfor NEVER
