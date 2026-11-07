action echo scroll $1 when ^@(?:an?|some).* ([\w-']+)
put look
matchre ARMOR (gauntlets|gloves|shield|claw guards|steel mail gloves|parry stick|handwraps|\bhat\b|hand claws|jacket|armwraps|footwraps|aegis|buckler|\bhood\b|\bcowl\b|\bheater|pavise|scutum|shield|sipar|\btarge\b|aventail|backplate|balaclava|barbute|bascinet|breastplate|\bcap\b|coat|cowl|cuirass|fauld|greaves|hauberk|helm|\bhood\b|jerkin|leathers|lorica|mantle|mask|morion|pants|(?<=(field|fluted|full|half) )\bplate\b|handguards|robe|sallet|shirt|sleeves|ticivara|tabard|tasset|thorakes|\blid\b|vambraces|vest|collar|coif|mitt|steel mail)
matchwait 3
echo none
exit
ARMOR:
echo armor [$1]
