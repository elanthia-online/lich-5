# WP10: the AliasList on the engine path (Command.cs:235-241, 2746-2777 R): put/#send expand aliases.
put #alias {nx} {recall nexus list}
put #alias {sayit} {say $1 and $2 [$0]}
put #alias {k} {kneel}
put nx
put sayit "hi there" bob
put K
put k;nx
put #send sayit a b
put #alias
put #alias n
put #unalias nx
put nx
put #unclass k
put k
put #alias clear
put #aliases
echo done
