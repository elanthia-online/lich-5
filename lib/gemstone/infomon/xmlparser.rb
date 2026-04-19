# frozen_string_literal: true

module Lich
  module Gemstone
    module Infomon
      # this module handles all of the logic for parsing game lines that infomon depends on
      module XMLParser
        module Pattern
          Group_Short = /(?:group|following you|IconJOINED)|^You are leading|(?:'s<\/a>|your) hand(?: tenderly)?\.\r?\n?$/
          Also_Here_Arrival = /^Also here: /
          NpcDeathPrefix = Regexp.union(
            /The fire in the/,
            /With a surprised grunt, the/,
            /A sudden blue fire bursts over the hair of a/,
            /You hear a sound like a (?:weeping child|child weeping) as a white glow separates itself from the/,
            /A low gurgling sound comes from deep within the chest of the/,
            /(?:The|An?)/,
            /One last prolonged bovine moan escapes from the/,
            /The spectral form of the/,
            /All that remains of the/,
            /The lights? in(?: (?:an?|the))?/,
            /With a final squeal the/,
            /The head in/,
            /The skeletal structure of(?: the)?/,
            /The glimmer of (?:an? |some )?<a exist="[^"]+" noun="[^"]+">[^<]+<\/a> catches your eye as the/,
            /A heavy mist pours from the/,
            /The fire leaves the/,
            /As the fire leaves (?:<pushBold\/><a exist="[^"]+" noun="[^"]+">)?(?:hi[ms]|her|s?he|its?)(?:<\/a><popBold\/>)? eyes, the/,
            /As the steam dissipates from <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/>, the/,
            /With a loud crash,/,
            /The flames of/,
            /Ash explodes in all directions as/,
            /The internal skeletal structure of/,
            /The mass of hair and bone that was the/,
            /Silence hangs heavy in the air as the/,
            /With an ear-piercing cry of agony, the/,
            /The evil glint leaves the/,
            /As the strength drains out of the/,
            /Disillusioned, the/,
            /A ragged gasp fills/,
            /With a white-hot corruscation of sparks,/,
            /The deep blue glow emanating from the/,
            /Torn and strained stitches pop all over/,
            /A death spasm shakes/,
            /An instant of clarity dawns in/,
            /Grim realization flashes across/,
            /The nearby shadows resound with the impact as/,
            /A bloodcurdling screech tears from the throat of/,
            /Spines litter the ground as the/,
            /Reduced to a bloody tangle of beak and feathers, the lifeless/,
            /A nebulous haze shimmers into view around/,
          )
          NpcDeathPostfix = Regexp.union(
            /body as it rises, disappearing into the heavens/,
            /falls to the ground and dies(?:, its feelers twitching)?/,
            /falls back into a heap and dies/,
            /body goes rigid and collapses to the (?:floor|ground), dead/,
            /slowly settles to the ground and begins to dissipate/,
            /falls to the (?:floor|ground) motionless/,
            /body goes rigid and <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> eyes roll back into <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> head as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> dies/,
            /growls one last time, and crumples to the ground in a heap/,
            /spins backwards and collapses dead/,
            /falls to the ground as the stillness of death overtakes <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/>/,
            /crumples to the ground motionless/,
            /howls in agony one last time and dies/,
            /howls in agony while falling to the ground motionless/,
            /moans pitifully as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> is released/,
            /careens to the ground and crumples in a heap/,
            /hisses one last time and dies/,
            /flutters its wings one last time and dies/,
            /slumps to the ground with a final snarl/,
            /horn dims as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> lifeforce fades away/,
            /blinks in astonishment, then collapses in a motionless heap/,
            /collapses in a heap, its huge girth shaking the floor around it/,
            /goes limp and <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> falls over as the fire slowly fades from <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> eyes/,
            /eyes slowly fades/,
            /sputters violently, cascading flames all around as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> collapses in a final fiery display/,
            /falls to the ground in a clattering, motionless heap/,
            /collapses to the ground and shudders once before finally going still/,
            /(?:crumbles|collapses) into a pile of rubble/,
            /shudders once before <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> finally goes still/,
            /totters for a moment and then falls to the ground like a pillar, breaking into pieces that fly out in every direction/,
            /twists and coils violently in its death throes, finally going still/,
            /twitches one final time before falling still upon the floor/,
            /, consuming .*? form in the space of a breath/,
            /screams one last time and dies/,
            /breathes <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> last gasp and dies/,
            /rolls over and dies/,
            /as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> falls (?:slack|still) against the (?:floor|ground)/,
            /collapses to the ground, emits a final (?:squeal|sigh|bleat|snarl), and dies/,
            /cries out in pain one last time and dies/,
            /crumples to a heap on the ground and dies/,
            /crumples to the ground and dies/,
            /lets out a final caterwaul and dies/,
            /screams evilly one last time and goes still/,
            /gurgles eerily and collapses into a puddle of water/,
            /shudders, then topples to the ground/,
            /shudders one last time before lying still/,
            /grumbles in pain one last time before lying still/,
            /rumbles in agony and goes still/,
            /falls to the ground dead/,
            /topples to the ground motionless/,
            /shudders violently for a moment, then goes still/,
            /sinks to the ground, the fell light in <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> eyes guttering before going out entirely/,
            /is sliced neatly in two/,
            /falls back and dies/,
            /bellows in rage one last time and dies/,
            /looks up with hatred as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> lets out <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> final breath/,
            /falls on its side and lets out one last whimpering sigh of (?:frosty mist|sparks and blue mist|chartreuse vapors|water droplets)/,
            /lets out one last whimpering sigh of (?:frosty mist|sparks and blue mist|chartreuse vapors|water droplets) and dies/,
            /coughs up some blood and dies/,
            /lets out a final, shrill shriek and dies/,
            /crashes to the ground, (?:dead|motionless)/,
            /falls to the ground, cursing, and dies/,
            /falls to the ground in a crumpled heap/,
            /clicks one last time and dies/,
            /falls over with a curse, then dies/,
            /crumples to the ground, spits out a curse, and dies/,
            /screams silently one last time and dies/,
            /eyes dim and finally go out/,
            /vainly struggles to rise, then goes still/,
            /dies; vitreous fluids escape its body/,
            /drops to the ground and shudders a final time/,
            /dies in a squirming, quivering heap/,
            /shudders a final time and goes still/,
            /collapses heavily into a heap on the ground and dies/,
            /lets out a blood-curdling roar and dies/,
            /stumbles and falls to the ground, twitches and dies/,
            /gives a last angry stare and falls to the ground dead/,
            /shudders violently as it dies/,
            /is a charred ashen figure of its former self lying upon the (?:floor|ground)/,
            /rears up its head, then (?:falls to the (?:floor|ground) and )?curls up into a ball, dead/,
            /rolls over on its back, emits a final screech and dies/,
            /arches its back in a tortured spasm and dies/,
            /shudders violently before scattering into a disorganized pile/,
            /shudders violently, before falling to the ground in a disorganized pile/,
            /gurgles eerily and collapses into the water/,
            /crumples to the ground, dead/,
            /collapses and <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> eyes roll up as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> dies/,
            /eyes roll up as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> dies/,
            /writhes in agony, <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> wings flapping fruitlessly as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> dies/,
            /curses through <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> teeth as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> dies/,
            /screams wickedly with both mouths as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> falls and dies/,
            /spasms uncontrollably as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> goes into shock and dies/,
            /sinks to <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> knees as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> chokes on <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> own blood and dies/,
            /curses the day <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> was created and dies/,
            /lets out a final curse as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> dies/,
            /chest spits out blood just before <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> dies/,
            /collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> face before expiring/,
            /gurgles once and goes still, a wrathful look on <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> face/,
            /gives a plaintive wail before <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> slumps to <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> side and dies/,
            /tenses in agony as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> begins to dissolve from the bottom up/,
            /collapses, gurgling once with a wrathful look on <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> face before expiring/,
            /clutches at <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> wounds as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> falls, the life fading from <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> eyes/,
            /chokes on <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> blood, gurgling noisily before finally dying/,
            /attempts to get up but the effort drains the last of <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> life and <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> collapses dead/,
            /eyes goes out and <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> ceases to move/,
            /emits a hollow scream as ribbons of essence begin to wend away from <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> and into nothingness/,
            /screams with rage as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> falls to the ground and dies/,
            /lets out a final agonized squeal and dies/,
            /falls to the ground, a lifeless lump of flesh/,
            /wails in terrifying pain one last time and lies still/,
            /wails horribly as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> begins to fade away/,
            /shudders slightly then ceases <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> so called life/,
            /collapses to the ground, <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> spirit released/,
            /as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> slumps to the ground/,
            /slumps silently to the ground and begins to rapidly dissipate/,
            /tail trembles then falls to the ground as the rest of <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> body goes limp/,
            /shudders in spectral agony, then begins to rapidly dissipate/,
            /twitches one last time and dies/,
            /falls prone to the ground, twitches one last time and dies/,
            /(?:slumps over|falls to the (?:floor|ground)) dead, (?:his|her|its) (?:husk|skin)? still pulsating with a blinding white hue/,
            /eyes goes out as (?:s?he|it) collapses and finally dies/,
            /eyes goes out and (?:s?he|it) finally dies/,
            /snarls <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> defiance before collapsing and going still/,
            /snarls <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> defiance one last time before going still/,
            /body convulses one last time before the stillness of death overtakes <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/>/,
            /falls to the ground and lies twitching for a moment before going still/,
            /rears up its head, then falls to the floor and curls up into a ball, dead/,
            /kicks a leg one last time and lies still/,
            /falls to the floor as the stillness of death overtakes <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/>/,
            /cries out in pain one last time and expires/,
            /falls to the ground, (<pushBold\/><a exist="[^"]+" noun="[^"]+">)?(?:hi[ms]|her|s?he|its?)(<\/a><popBold\/>)? living fire extinguished/,
            /(?:emits|releases) a (?:roar|shriek) as (?:hi[ms]|her|s?he|its?) (?:falls to the ground and )?goes still/,
            /collapses upon the (?:floor|ground) and the life fades from (?:hi[ms]|her|s?he|its?) eyes/,
            /falls to the ground and lies still/,
            /vibrates violently one final time and then lies still/,
            /topples to the ground as the fire slowly leaves (?:<pushBold\/><a exist="[^"]+" noun="[^"]+">)?(?:hi[ms]|her|s?he|its?)(?:<\/a><popBold\/>)?/,
            /collapses to the (?:floor|ground) with a splash, gurgling once with a wrathful look on <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> face before expiring/,
            /writhes in fiery agony and dies/,
            /falls to the ground, leaking steam profusely/,
            /releases a groan of mingled ecstasy and relief as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> fades away/,
            /falls on (?:hi[ms]|her|s?he|its?) side and lets out one last whimpering sigh of dark and shadowy whirlwinds/,
            /lets out one last whimpering sigh of dark and shadowy whirlwinds and dies/,
            /ceases all attempts at movement/,
            /eyes as (?:<pushBold\/><a exist="[^"]+" noun="[^"]+">)?(?:hi[ms]|her|s?he|its?)(?:<\/a><popBold\/>)? falls still/,
            /eyes dim, and <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> falls to the ground with a dry crackling sound/,
            /drops lifelessly to the ground/,
            /eyes grow dim as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> lifeforce fades away/,
            /lets out a final agonized sigh and dies/,
            /gazes upward one last time and dies/,
            /gives a last shudder and dies/,
            /lets out a final agonized bellow and dies/,
            /screams <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> defiance skyward one last time and dies/,
            /twitches and dies/,
            /collapses in a red mess and dies/,
            /lets out a final agonized cry and dies/,
            /collapses to the ground, emits a final snarl, and dies/,
            /gurgles and collapses into the <a exist="[^"]+" noun="[^"]+">(?:large|small) puddle<\/a> on the (?:floor|ground)/,
            /form sags to the floor, <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> reptilian head finally freed from <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> monstrous glaes form/,
            /slumps to the floor, exhales a sigh of relief, and begins to quickly decay away/,
            /exhales a sigh of relief and begins to quickly decay away/,
            /disappear into the air as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> body crashes to the ground in a ball of feathers/,
            /crashes to the ground, sending searing flames in all directions/,
            /succumbs to <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> final blow/,
            /implodes inward upon itself, leaving behind no support for (?:hi[ms]|her|s?he|its?) body or life.  The <pushBold\/>(?:(?:an?|some|the) )?<a.*?exist=["'](?:<npc_id>\-?[0-9]+)["'].*?>.*?<\/a><popBold\/>(?:'s)? falls to the (?:floor|ground) in a lifeless mass of flesh and fractured bones/,
            /flails wildly for a moment before (?:collapsing|going still), <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> appendages dropping lifelessly to the ground/,
            /collapses to the ground and with a last ripple, dies/,
            /opens <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> mouth wide and lets out a choked, shrill scream and <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> eyes cloud over to a solid milky white as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> (?:collapses and )?dies/,
            /arms, legs and head separate from (?:hi[ms]|her|s?he|its?) torso as the dissimilar parts (?:collapse in a heap|finally fall still)/,
            /(?:flips|rolls over) onto its back, kicks several times and dies/,
            /releases a low rumble before becoming completely still/,
            /quivers violently and collapses, its conical form flattening into a wide pancake/,
            /lets out a final agonized snuffle and dies/,
            /twitches and gives one last rattle before falling silent/,
            /collapses to the ground, emits a final (?:snuffle|cry|bray), and dies/,
            /rolls over, <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> head dropping heavily to the ground as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> goes still/,
            /collapses, <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> head dropping heavily to the ground as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> goes still/,
            /lets out a final agonized bray and dies/,
            /collapses into a pile of hair and bones and goes still/,
            /finally goes still/,
            /dies, falling down like a rag doll/,
            /spasms one last time and then dies/,
            /dies/,
            /exhales (?:hi[ms]|her|s?he|its?) final breath, collapsing lifelessly to the ground/,
            /drops to the floor, quite dead/,
            /thrashes violently and then dies/,
            /rasps a final scream and dies/,
            /(?:rolls over on its back, )?emits a final hiss and dies/,
            /coughs, causing a greenish fluid to dribble down <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> lips as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> falls/,
            /cries out in cold agony one last time and dies/,
            /collapses, <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> eyes fading to a lifeless gaze and stone shell cracking into a barely discernible form/,
            /slumps silently to the ground, <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> brilliant eyes fading to grey/,
            /calls out an oath as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> brilliant eyes fade to grey/,
            /tail twitches feebly as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> dies/,
            /jerks one last time and expires/,
            /chest heaves one last time then (?:hi[ms]|her|s?he|its?) dies/,
            /face turns upward in a tortured rictus then (?:hi[ms]|her|s?he|its?) body goes slack/,
            /mutters belaboring (?:hi[ms]|her|s?he|its?) fate and then dies/,
            /slumps to the ground as the light departs (?:hi[ms]|her|s?he|its?) eyes/,
            /crumples to a heap on the ground/,
            /collapses to the ground in a motionless heap, sending a plume of dust up from (?:hi[ms]|her|s?he|its?) unwashed body/,
            /face twists into a final silent screech and then (?:hi[ms]|her|s?he|its?) lies motionless/,
            /wails one final time as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> collapses/,
            /lets loose a final wail as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> is released/,
            /(?:falls|slumps) to the ground, lying completely motionless.  A last minute twitch causes the <pushBold\/><a exist=["'](?<npc_id>\-?[0-9]+)["'].*?>.*?<\/a><popBold\/>(?:'s)? arm to spasm up into the air before falling limply back to <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> side/,
            /tears off a piece of <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> flesh, gnawing upon the decayed meat in a vain attempt to nourish <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> continued tormented existence.  With the attempt failing, the <pushBold\/><a exist=["'](?<npc_id>\-?[0-9]+)["'].*?>.*?<\/a><popBold\/> (?:topples|slumps) to the ground motionless/,
            /flaps its wings in a last ditch effort to ascend from the ground, but fails and finally lies still/,
            /wings, it falls to the ground in a motionless heap/,
            /collapses into a lifeless heap upon the ground/,
            /twitches a few times before finally dying/,
            /falls to the ground with an echoing clatter, dead/,
            /lets loose a long sigh, as the air around <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> calms and <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> begins to fade/,
            /surrenders, and the azure sparks in <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> eyes fade to black/,
            /stretches a hand skyward, fumbling for something unseen as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> surrenders to death/,
            /lungs with a last breath that wooshes out as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> dies/,
            /collapses into a buzzing tangle of glowing filaments/,
            /gives a last gasp and dies/,
            /writhes in its death throes, its violent writhing causing it to fall from its perch/,
            /freezes completely before falling to (?:the floor in )?pieces/,
            /lets out a final agonized bleat and dies/,
            /shudders briefly before discontinuing its assault/,
            /collapses to the ground, (?:shakes|twitches) one last time and dies/,
            /twists unnaturally as it decomposes into itself/,
            /curls up in the snow and dies/,
            /goes dark suddenly/,
            /howls in pain one last time and dies/,
            /falls to the ground, rotting flesh falling from <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> bones/,
            /lets out a sigh and dies/,
            /mutters, "...the Eye, the Eye..." and lies still/,
            /screams, "Nooooo!" as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> clatters to the ground into a lump of ancient bones and rotting robes/,
            /writhes in cold agony and dies/,  
            /tumbles to the ground motionless/,    
            /body as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> surrenders to death, allowing necrotic organs and ichor to spill free/,
            /body as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> muscles and flesh rapidly reconfigure, leaving behind a still humanoid corpse/,
            /empty black eyes widen with something akin to surprise.  Animation leaves <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> body in a sudden rush, leaving <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> lifeless and still/,
            /eyes as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> succumbs to <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> injuries.  Peace blossoms on <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> face as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> dies/,
            /visage as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> collapses, <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> mouth and eyes trailing threads of crimson smoke/,
            /rapidly begins dwindling away, flickering like a dying candleflame/,
            /falls to the ground/,
            /begins to mouth a desperate prayer, but death stifles <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/>/,
            /as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> slumps to the ground/,
            /twitches its tail one last time and dies/,
            /lets out a final scream and goes still/,
            /collapses to the ground and dies/,
            /clacks its pincers a final agonizing time and dies/,
            /collapses to the ground, clacks its pincers and dies/,
            /screeches one last time and dies/,
            /vainly tries to (?:sound|shout) a warning, then (?:collapses|goes still)/,
            /body jerks one last time and dies/,
            /slumps to the ground, its glowing form now motionless and dull/,
            /growls one last time in defiance, then (?:goes still|slumps to the ground)/,
            /crumbles into a pile of splinters and skin/,
            /cries out one last time and lies still/,
            /falls to the ground, <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> wings collapsing around <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/>/,
            /wings splay out as he goes still/,
            /howls out one last time and dies/,
            /spasms violently and suddenly goes still, its body turning to stone/,
            /, plunging inward in a dizzying spiral to envelop <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> completely!  Silhouetted within the shifting spiritual miasma, the <pushBold\/><a exist="[^"]+" noun="[^"]+">.+<\/a><popBold\/> form withers, wasting away to an attenuated mockery of <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:him|her|it)self<\/a><popBold\/>.  Even this pale shadow disintegrates, dissolving on the air as the last cloudy tendrils vanish/,
            /staggers, feebly trying to catch <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:him|her|it)self<\/a><popBold\/>, then collapses with a wheeze/,
            /sneers, "Urok vas derop tal kalissar kamath," then collapses/,
            /spits an unintelligible oath as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> collapses/,
            /slumps to the ground, exhales a sigh of relief, and begins to quickly decay away/,
            /asks incredulously, "Hor\?  Kla val ptath...\?" then falls, <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> pupil-less green eyes frozen in a dead stare/,
            /whispers, "Ra dro, Te lothre on ka nuko," then collapses/,
            /chuckles wryly as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> falls, "Letta, Leth, Latoth.../,
            /wheezes, an incredulous look on <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> face as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> falls/,
            /screams as <pushBold\/><a exist="[^"]+" noun="[^"]+">(?:hi[ms]|her|s?he|its?)<\/a><popBold\/> collapses, "Granoth!  Tal issar leti!/,
            /body and rises into the heavens/,
          )
          NpcDeathMessage = /^(?:<pushBold\/>)?#{NpcDeathPrefix} (?:<pushBold\/>)?(?:(?:an?|some|the) )?<a exist="(?<npc_id>[^"]+)" noun="[^"]+">[^<]+<\/a>(?:<popBold\/>)?(?:'s)? #{NpcDeathPostfix}[\.!"]\r?\n?$/

          # the following are for parsing STOW LIST and setting of STOW containers
          StowListOutputStart = /^You have the following containers set as stow targets:\r?\n?$/
          StowListContainer = /^  (?:(?:an?|some) )?(?<before>[^<]+)?<a exist="(?<id>\d+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^\(]+)? \((?<type>box|gem|herb|skin|wand|scroll|potion|trinket|reagent|lockpick|treasure|forageable|collectible|default)\)\r?\n?$/
          StowSetContainer1 = /^Set "(?:(?:an?|some) )?(?<before>[^<]+)?<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^"]+)?" to be your STOW (?<type>BOX|GEM|HERB|SKIN|WAND|SCROLL|POTION|TRINKET|REAGENT|LOCKPICK|TREASURE|FORAGEABLE|COLLECTIBLE) container\.\r?\n?$/
          StowSetContainer2 = /Set "(?:(?:an?|some) )?(?<before>[^<]+)?<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^"]+)?" to be your (?<type>default) STOW container\.\r?\n?$/

          # the following are for parsing READY LIST and setting of READY items
          ReadyListOutputStart = /^Your current settings are:\r?\n?$/
          ReadyListNormal = /^  (?<type>shield|(?:secondary |ranged )?weapon|ammo bundle|wand): \(?<d cmd=['"](?:store|ready) (?:SHIELD|2?WEAPON|RANGED|AMMO|WAND)(?: clear)?['"]>(?:(?:(?:an?|some) )?(?<before>[^<]+)?<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^<]+)?|none)<\/d>\)? \(<d cmd='store set'>(?<store>worn if possible, stowed otherwise|stowed|put in (?:secondary )?sheath)<\/d>\)\r?\n?$/
          ReadyListAmmo2 = /^  (?<type>ammo2 bundle): <d cmd="store AMMO2 clear">(?:(?:an?|some) )?(?<before>[^<]+)?<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^<]+)?<\/d>\r?\n?$/
          ReadyListSheathsSet = /^  (?<type>(?:secondary )?sheath): <d cmd="store 2?SHEATH clear">(?:(?:an?|some) )?(?<before>[^<]+)?<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^<]+)?<\/d>\r?\n?$/
          ReadyListFinished = /To change your default item for a category that is already set, clear the category first by clicking on the item in the list above.  Click <d cmd="ready list">here<\/d> to update the list\.\r?\n?$/
          ReadyItemClear = /^Cleared your default (?<type>shield|(?:secondary |ranged )?weapon|ammo2? bundle|(?:secondary )?sheath|wand)\.\r?\n?$/
          ReadyItemSet = /^Setting (?:(?:an?|some) )?(?<before>[^<]+)?<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>(?<after> [^<]+)? to be your default (?<type>shield|(?:secondary |ranged )?weapon|ammo2? bundle|(?:secondary )?sheath|wand)\.\r?\n?$/
          ReadyStoreSet = /^When storing your (?<type>shield|(?:ranged |secondary )?weapon|ammo bundle|wand), it will be (?<store>worn if possible and stowed if not|stowed|stored in your (?:secondary )?sheath)\.\r?\n?$/

          StatusPrompt = /<prompt time="[0-9]+">/

          # Overwatch patterns - simplified reference to the observer patterns
          Overwatch_Short = Overwatch::Observer::Term::ANY

          All = Regexp.union(NpcDeathMessage, Group_Short, Also_Here_Arrival, StowListOutputStart, StowListContainer, StowSetContainer1, StowSetContainer2,
                             ReadyListOutputStart, ReadyListNormal, ReadyListAmmo2, ReadyListSheathsSet, ReadyListFinished, ReadyItemClear, ReadyItemSet,
                             ReadyStoreSet, StatusPrompt, Overwatch_Short)
        end

        def self.parse(line)
          # O(1) vs O(N)
          return :noop unless line =~ Pattern::All

          begin
            case line
            # this detects for death messages in XML that are not matched with appropriate combat attributes above
            when Pattern::NpcDeathMessage
              match = Regexp.last_match
              if (npc = GameObj.npcs.find { |obj| obj.id == match[:npc_id] && obj.status !~ /\b(?:dead|gone)\b/ })
                npc.status = 'dead'
              end
              :ok
            when Pattern::Group_Short
              return :noop unless (match_data = Group::Observer.wants?(line))
              Group::Observer.consume(line.strip, match_data)
              :ok
            when Pattern::Overwatch_Short
              return :noop unless (match_data = Overwatch::Observer.wants?(line))
              Overwatch::Observer.consume(line, match_data)
              :ok
            when Pattern::Also_Here_Arrival
              return :noop unless Lich::Claim::Lock.locked?
              line.scan(%r{<a exist=(?:'|")(?<id>.*?)(?:'|") noun=(?:'|")(?<noun>.*?)(?:'|")>(?<name>.*?)</a>}).each { |player_found| XMLData.arrival_pcs.push(player_found[1]) unless XMLData.arrival_pcs.include?(player_found[1]) }
              :ok
            when Pattern::StowListOutputStart
              StowList.reset
              :ok
            when Pattern::StowListContainer, Pattern::StowSetContainer1, Pattern::StowSetContainer2
              match = Regexp.last_match
              StowList.__send__("#{match[:type].downcase}=", GameObj.index_or_create(match[:id], match[:noun], match[:name], (match[:before].nil? ? nil : match[:before].strip), (match[:after].nil? ? nil : match[:after].strip)))
              StowList.checked = true if line =~ Pattern::StowListContainer
              :ok
            when Pattern::ReadyListOutputStart
              ReadyList.reset
              :ok
            when Pattern::ReadyListNormal, Pattern::ReadyListAmmo2, Pattern::ReadyListSheathsSet, Pattern::ReadyItemSet
              match = Regexp.last_match
              unless match[:id].nil?
                ReadyList.__send__("#{Lich::Util.normalize_name(match[:type].downcase)}=", GameObj.index_or_create(match[:id], match[:noun], match[:name], (match[:before].nil? ? nil : match[:before].strip), (match[:after].nil? ? nil : match[:after].strip)))
              end
              if match.named_captures.include?("store")
                ReadyList.__send__("store_#{Lich::Util.normalize_name(match[:type].downcase)}=", match[:store])
              end
              :ok
            when Pattern::ReadyListFinished
              ReadyList.checked = true
              :ok
            when Pattern::ReadyItemClear
              match = Regexp.last_match
              ReadyList.__send__("#{Lich::Util.normalize_name(match[:type].downcase)}=", nil)
              :ok
            when Pattern::ReadyStoreSet
              match = Regexp.last_match
              ReadyList.__send__("store_#{Lich::Util.normalize_name(match[:type].downcase)}=", match[:store])
              :ok
            when Pattern::StatusPrompt
              Infomon::Parser::State.set(Infomon::Parser::State::Ready) unless Infomon::Parser::State.get.eql?(Infomon::Parser::State::Ready)
              :ok
            else
              :noop
            end
          rescue StandardError
            respond "--- Lich: error: Infomon::XMLParser.parse: #{$!}"
            respond "--- Lich: error: line: #{line}"
            Lich.log "error: Infomon::XMLParser.parse: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            Lich.log "error: line: #{line}\n\t"
          end
        end
      end
    end
  end
end
