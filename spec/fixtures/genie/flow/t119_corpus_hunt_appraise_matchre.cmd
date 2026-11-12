# GenieHunter hunt.cmd:256-291 var block verbatim + its appraise matchre() lines 4071-4073 and 4253
# (WP3-r2 engineering NB4): eval matchre() over the variable-length lookbehind of %critters.
# %ml stands in for $monsterlist (the game-fed reserved variable).
var monsters1 \badder\b|ashu hhinvi|atik'et|banshee|bloodvine|bucca|clay archer|clay mage|clay soldier|clockwork monstrosity|\bcrag\b|creeper|cutthroat
var monsters2 /bdoll\b|dragon fanatic|dragon priest|dryad|dummy|dusk ogre|dyrachis|eviscerator|faenrae assassin|fendryad|fire maiden|folsi immola
var monsters3 footpad|frostweaver|gam chaga|\bgeni\b|gidii|goblin shaman|graverobber|guardian|gypsy marauder|\bhag\b|harbinger|\bimp\b|juggernaut
var monsters4 kelpie|kra'hei|kra'hei hatchling|lipopod|lun'shele hunter|madman|malchata|mountain giant|nipoh oshu|\bnyad\b|orc bandit
var monsters5 orc clan-chief|orc raider|orc reiver|orc scout|pile of rubble|pirate|river sprite|ruffian|sandstone golem|scavenger troll|scout ogre|screamer
var monsters6 sentinel|shadow master|shadoweaver|sky giant|sleazy lout|sprite|swain|swamp troll|telga moradu|\bthug\b|trekhalo
var monsters7 tress|umbramagii|velver|\bvine\b|vykathi builder|vykathi excavator|wood troll|\bwretch\b|young ogre|zealot

var undead1 boggle|emaciated umbramagus|fiend|gargantuan bone golem|olensari mihmanan|plague wraith|resuscitant
var undead2 revivified mutt|shylvic|sinister maelshyvean heirophant|skeletal peon|skeletal sailor|skeleton
var undead3 skeletal kobold headhunter|skeletal kobold savage|snaer hafwa|soul|spectral pirate|spectral sailor
var undead4 spirit|ur hhrki'izh|wind hound|wir dinego|(?<!arisen \S+ )zombie(?!\s)|zombie (head-splitter|mauler|nomad|stomper)

var skinnablemonsters1 angiswaerd hatchling|antelope|arbelog|armadillo|(armored )?warklin( mauler)?|arzumo|asaren celpeze|badger|barghest|basilisk|(?<!red )\bbear\b|beisswurm|bison|black ape
var skinnablemonsters2 blight ogre|blood warrior|\bboa\b|\bboar\b|bobcat|boobrie|brocket deer|burrower|caiman|caracal|carcal|cave troll
var skinnablemonsters3 cinder beast|cougar|\bcrab\b|crayfish|crocodile|\bdeer\b|dobek moruryn|faenrae stalker|firecat|\bfrog\b|gargoyle|giant blight bat
var skinnablemonsters4 goblin|grass eel|\bgrub\b|gryphon|Isundjen conjurer|jackal|kartais|kobold|la'heke|larva|la'tami|leucro
var skinnablemonsters5 marbled angiswaerd|merrows|misty black husk|\bmoda\b|\bmoth\b|mottled westanuryn|musk hog|\bpard\b|peccary|pivuh|poloh'izh|pothanit|prereni|\bram\b
var skinnablemonsters6 \brat\b|retan dolomar|rock troll|scaly seordmaor|serpent|shadow beast|shadow mage|shalswar|silverfish|sinuous elsralael|skunk|S'lai scout
var skinnablemonsters7 sleek hele'la|sluagh|snowbeast|\bsow\b|spider|spirit dancer|steed|storm bull|trollkin|\bunyn\b|viper|vulture|vykathi harvester
var skinnablemonsters8 vykathi soldier|warcat|\bwasp\b|\bwolf\b|\bworm\b|zephyr husk

var skinnableundead1 enraged tusky|fell hog|ghoul|ghoul crow|gremlin|grendel|lach|mastiff|mey|misshapen germish'din
var skinnableundead2 mutant togball|reaver|shadow hound|squirrel|zombie kobold headhunter|zombie kobold savage|skeletal kobold headhunter|skeletal kobold savage

var construct ashu hhinvi|boggle|bone amalgam|clay archer|clay mage|clay soldier|clockwork assistant|clockwork monstrosity|gam chaga|glass construct|granite gargoyle|lachmate|lava drake|marble gargoyle|origami \S+|quartz gargoyle|(alabaster|andesite|breccia|dolomite|marble|obsidian|quartzite|rock) guardian|rough-hewn doll|sandstone golem|Endrus serpent
var skinnableconstruct granite gargoyle|lava drake|marble gargoyle|quartz gargoyle|Endrus serpent

var invasioncritters bone amalgam|bone warrior|Elpalzi (bowyer|deadeye|dissident|fomenter|hunter|incendiary|instigator|malcontent|malcontent|partisan|rebel|sharpshooter|toxophilite)|flea-ridden beast|ogre (berserker|deadshot|enraged|hurler|pelter|shooter|youngling)|putrefying shambler|rebel (gladiator|hunter|novice)|revivified mutt|shambling horror|skeletal peon|starcrasher|transmogrified oaf|zenzic

var skinnablecritters %skinnablemonsters1|%skinnablemonsters2|%skinnablemonsters3|%skinnablemonsters4|%skinnablemonsters5|%skinnablemonsters6|%skinnablemonsters7|%skinnablemonsters8|%skinnableundead1|%skinnableundead2|%skinnableconstruct
var nonskinnablecritters %monsters1|%monsters2|%monsters3|%monsters4|%monsters5|%monsters6|%monsters7|%undead1|%undead2|%undead3|%undead4|construct

var ritualcritters %monsters1|%monsters2|%monsters3|%monsters4|%monsters5|%monsters6|%monsters7|%skinnablemonsters1|%skinnablemonsters2|%skinnablemonsters3|%skinnablemonsters4|%skinnablemonsters5|%skinnablemonsters6|%skinnablemonsters7|%skinnablemonsters8|%skinnableundead1|%skinnableundead2|%undead1|%undead2|%undead3|%undead4

var critters %skinnablecritters|%nonskinnablecritters
var ml an arisen big zombie and a goblin
gosub CHECK
var ml an arisen big zombie
gosub CHECK
var ml an arisen zombie mauler
gosub CHECK
var ml an armored warklin mauler
gosub CHECK
var ml a red bear and a zombie
gosub CHECK
var ml a black ape, a zombie
gosub CHECK
echo end
exit
CHECK:
	if matchre("%ml", "\b(%nonskinnablecritters)\b") then goto APPR_CREEP
	if matchre("%ml", "\b(%skinnablecritters)\b") then goto APPR_CREEP
	if matchre("%ml", "\b(%invasioncritters)\b") then goto APPR_CREEP
	if matchre ("%ml", "%critters") then goto JUGGLE_STOP
	echo NONE %ml
	return
APPR_CREEP:
	echo APPR $1 [$0]
	return
JUGGLE_STOP:
	echo JUGGLE [$0]
	return
