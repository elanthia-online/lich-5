# frozen_string_literal: true

# Spec for Lich::Gemstone::Infomon::XMLParser::Pattern::NpcDeathMessage
#
# Self-contained: both corpora are embedded as literal heredocs below, so this
# file needs no external fixture files.
#   * DEATH_CORPUS   -- real NPC death lines that MUST be detected (match).
#                       Migrated from cleaneddeathlog.log.
#   * CONTROL_CORPUS -- item-drop lines that look death-adjacent but must NOT be
#                       detected (no match), so a falling weapon is never mistaken
#                       for a creature dying. Migrated from deathmessagecontrols.log
#                       (the "Control:" annotation lines are intentionally dropped;
#                       only the actual game lines are kept).
#
# Line endings: the corpora use \n only. The regex anchors on [\.!"]\s?\r?\n?$,
# which tolerates a missing \r, so LF-only storage matches identically to the
# original \r\n game stream.

require_relative '../../../spec_helper'
require 'gemstone/infomon/xmlparser.rb'

DEATH_CORPUS = <<'__DEATH_CORPUS__'.freeze
<pushBold/>A <a exist="12345678" noun="being">bent being</a><popBold/> falls over with a curse, then dies.
<pushBold/>A <a exist="12345678" noun="being">stooped being</a><popBold/> screams wickedly with both mouths as <pushBold/><a exist="12345678" noun="being">it</a><popBold/> falls and dies.
<pushBold/>A <a exist="12345678" noun="gremlock">gremlock</a><popBold/> collapses and <pushBold/><a exist="12345678" noun="gremlock">her</a><popBold/> eyes roll up as <pushBold/><a exist="12345678" noun="gremlock">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="taint">festering taint</a><popBold/> lets out a final curse as <pushBold/><a exist="12345678" noun="taint">it</a><popBold/> dies.
<pushBold/>A <a exist="12345678" noun="gremlock">gremlock</a><popBold/>'s eyes roll up as <pushBold/><a exist="12345678" noun="gremlock">she</a><popBold/> dies.
The head in <pushBold/>a <a exist="12345678" noun="being">stooped being's</a><popBold/> chest spits out blood just before <pushBold/><a exist="12345678" noun="being">it</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="taint">festering taint</a><popBold/> chokes on <pushBold/><a exist="12345678" noun="taint">its</a><popBold/> blood, gurgling noisily before finally dying.
The <pushBold/><a exist="12345678" noun="taint">festering taint</a><popBold/> screams with rage as <pushBold/><a exist="12345678" noun="taint">it</a><popBold/> falls to the ground and dies.
<pushBold/>A <a exist="12345678" noun="being">twisted being</a><popBold/> crumples to the ground, dead.
The <pushBold/><a exist="12345678" noun="taint">festering taint</a><popBold/> curses the day <pushBold/><a exist="12345678" noun="taint">it</a><popBold/> was created and dies.
A low gurgling sound comes from deep within the chest of the <pushBold/><a exist="12345678" noun="minotaur">lesser minotaur</a><popBold/> as <pushBold/><a exist="12345678" noun="minotaur">he</a><popBold/> falls slack against the ground.
The <pushBold/><a exist="12345678" noun="dweller">krag dweller</a><popBold/> collapses into a pile of rubble.
The <pushBold/><a exist="12345678" noun="dweller">krag dweller</a><popBold/> crumbles into a pile of rubble.
<pushBold/>A <a exist="12345678" noun="gremlock">gremlock</a><popBold/> collapses and <pushBold/><a exist="12345678" noun="gremlock">his</a><popBold/> eyes roll up as <pushBold/><a exist="12345678" noun="gremlock">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="taint">festering taint</a><popBold/> falls to the ground, cursing, and dies.
All that remains of the <pushBold/><a exist="12345678" noun="being">being</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
<pushBold/>A <a exist="12345678" noun="being">bent being</a><popBold/> curses through <pushBold/><a exist="12345678" noun="being">its</a><popBold/> teeth as <pushBold/><a exist="12345678" noun="being">it</a><popBold/> dies.
<pushBold/>A <a exist="12345678" noun="being">twisted being</a><popBold/> lets out a final, shrill shriek and dies.
<pushBold/>A <a exist="12345678" noun="being">gnarled being</a><popBold/> coughs up some blood and dies.
The <pushBold/><a exist="12345678" noun="yeti">krag yeti</a><popBold/> collapses to the ground and shudders once before finally going still.
The <pushBold/><a exist="12345678" noun="taint">festering taint</a><popBold/> sinks to <pushBold/><a exist="12345678" noun="taint">its</a><popBold/> knees as <pushBold/><a exist="12345678" noun="taint">it</a><popBold/> chokes on <pushBold/><a exist="12345678" noun="taint">its</a><popBold/> own blood and dies.
<pushBold/>A <a exist="12345678" noun="gremlock">gremlock</a><popBold/>'s eyes roll up as <pushBold/><a exist="12345678" noun="gremlock">he</a><popBold/> dies.
All that remains of the <pushBold/><a exist="12345678" noun="gremlock">gremlock</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
The <pushBold/><a exist="12345678" noun="taint">festering taint</a><popBold/> crumples to the ground, spits out a curse, and dies.
The <pushBold/><a exist="12345678" noun="taint">festering taint</a><popBold/> spasms uncontrollably as <pushBold/><a exist="12345678" noun="taint">it</a><popBold/> goes into shock and dies.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="executioner">his</a><popBold/> face.
<pushBold/>The <a exist="12345678" noun="siren">siren</a><popBold/> gives a plaintive wail before <pushBold/><a exist="12345678" noun="siren">she</a><popBold/> slumps to <pushBold/><a exist="12345678" noun="siren">her</a><popBold/> side and dies.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="executioner">her</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="dissembler">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="combatant">his</a><popBold/> face before expiring.
The glimmer of a <a exist="12345678" noun="zircon">yellow zircon</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="peridot">green peridot</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The spectral form of the <pushBold/><a exist="12345678" noun="defender">triton defender</a><popBold/> tenses in agony as <pushBold/><a exist="12345678" noun="defender">she</a><popBold/> begins to dissolve from the bottom up!
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="combatant">her</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="radical">his</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="combatant">her</a><popBold/> face before expiring.
The spectral form of the <pushBold/><a exist="12345678" noun="defender">triton defender</a><popBold/> tenses in agony as <pushBold/><a exist="12345678" noun="defender">he</a><popBold/> begins to dissolve from the bottom up!
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="radical">her</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="radical">her</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="combatant">his</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="combatant">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="executioner">her</a><popBold/> face before expiring.
The glimmer of a <a exist="12345678" noun="tourmaline">clear tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="dissembler">his</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="executioner">his</a><popBold/> face before expiring.
The glimmer of a <a exist="12345678" noun="dreamstone">white dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="executioner">her</a><popBold/> face before expiring.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="spectre">shadowy spectre's</a><popBold/> body and rises into the heavens.
The <pushBold/><a exist="12345678" noun="spectre">shadowy spectre</a><popBold/> falls to the ground motionless.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="wolfshade">wolfshade's</a><popBold/> body and rises into the heavens.
The <pushBold/><a exist="12345678" noun="wolfshade">wolfshade</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="witch">wind witch</a><popBold/> crumples to the ground motionless.
The <pushBold/><a exist="12345678" noun="titan">arctic titan</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="hound">vapor hound</a><popBold/> lets out one last whimpering sigh of chartreuse vapors and dies.
The <pushBold/><a exist="12345678" noun="wolfshade">wolfshade</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="hound">water hound</a><popBold/> lets out one last whimpering sigh of water droplets and dies.
The <pushBold/><a exist="12345678" noun="giant">frost giant</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="witch">wind witch</a><popBold/> howls in agony one last time and dies.
The <pushBold/><a exist="12345678" noun="hound">water hound</a><popBold/> falls on its side and lets out one last whimpering sigh of water droplets.
The <pushBold/><a exist="12345678" noun="titan">arctic titan</a><popBold/> screams evilly one last time and goes still.
The <pushBold/><a exist="12345678" noun="hound">vapor hound</a><popBold/> falls on its side and lets out one last whimpering sigh of chartreuse vapors.
The <pushBold/><a exist="12345678" noun="hound">storm hound</a><popBold/> falls on its side and lets out one last whimpering sigh of sparks and blue mist.
The <pushBold/><a exist="12345678" noun="hound">storm hound</a><popBold/> lets out one last whimpering sigh of sparks and blue mist and dies.
The <pushBold/><a exist="12345678" noun="giant">frost giant</a><popBold/> cries out in cold agony one last time and dies.
<pushBold/>A <a exist="12345678" noun="being">gnarled being</a><popBold/> crashes to the ground, dead.
The glimmer of a <a exist="12345678" noun="moonstone">blue moonstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="dissembler">her</a><popBold/> face.
The glimmer of a <a exist="12345678" noun="dreamstone">yellow dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="deathstone">black deathstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="executioner">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="radical">his</a><popBold/> face before expiring.
The glimmer of a <a exist="12345678" noun="spinel">violet spinel</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="magus">his</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="dissembler">her</a><popBold/> face before expiring.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="radical">triton radical</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="combatant">her</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="sentry">triton sentry</a><popBold/> emits a hollow scream as ribbons of essence begin to wend away from <pushBold/><a exist="12345678" noun="sentry">her</a><popBold/> and into nothingness!
The <pushBold/><a exist="12345678" noun="sentry">triton sentry</a><popBold/> emits a hollow scream as ribbons of essence begin to wend away from <pushBold/><a exist="12345678" noun="sentry">him</a><popBold/> and into nothingness!
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="radical">triton radical</a><popBold/> implodes inward upon itself, leaving behind no support for his body or life.  The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The glimmer of a <a exist="12345678" noun="starstone">green starstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="gem">bright chrysoberyl gem</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
All that remains of the <pushBold/><a exist="12345678" noun="taint">taint</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
The glimmer of an <a exist="12345678" noun="gem">aquamarine gem</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="peridot">pink peridot</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of an <a exist="12345678" noun="ruby">uncut ruby</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="radical">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="crone">snow crone</a><popBold/> falls to the ground motionless.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> implodes inward upon itself, leaving behind no support for his body or life.  The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="radical">her</a><popBold/> face before expiring.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="executioner">triton executioner</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="siren">siren</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="siren">siren</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="magus">triton magus</a><popBold/> implodes inward upon itself, leaving behind no support for his body or life.  The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
The glimmer of a <a exist="12345678" noun="pearl">tiny white pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="dreamstone">black dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="opal">white opal</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="magus">her</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="magus">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="yeti">krag yeti</a><popBold/> shudders once before <pushBold/><a exist="12345678" noun="yeti">it</a><popBold/> finally goes still.
The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="dissembler">her</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="magus">her</a><popBold/> face before expiring.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="executioner">triton executioner</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="combatant">triton combatant</a><popBold/> implodes inward upon itself, leaving behind no support for his body or life.  The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The glimmer of a <a exist="12345678" noun="spinel">red spinel</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> collapses to the ground with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="radical">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> collapses to the ground with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="magus">his</a><popBold/> face before expiring.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="executioner">triton executioner</a><popBold/> implodes inward upon itself, leaving behind no support for his body or life.  The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> falls to the ground in a crumpled heap.
The glimmer of a <a exist="12345678" noun="spinel">pink spinel</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="sapphire">star sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="ogre">plains ogre</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="leopard">black leopard</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="worker">kiramon worker</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="defender">kiramon defender</a><popBold/> clicks one last time and dies.
The <pushBold/><a exist="12345678" noun="defender">kiramon defender</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="worker">kiramon worker</a><popBold/> clicks one last time and dies.
The glimmer of a <a exist="12345678" noun="stone">light pink morganite stone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="defender">triton defender's</a><popBold/> body and rises into the heavens.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="wraith">grave wraith's</a><popBold/> body and rises into the heavens.
The <pushBold/><a exist="12345678" noun="defender">triton defender</a><popBold/> falls to the ground and dies.
The glimmer of a <a exist="12345678" noun="topaz">golden topaz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="dreamstone">green dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="magus">triton magus</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="magus">her</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> collapses to the floor with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="magus">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> vainly struggles to rise, then goes still.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> vainly struggles to rise, then goes still.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> vainly struggles to rise, then goes still.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="herald">his</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="herald">he</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="herald">his</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> vainly struggles to rise, then goes still.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> vainly struggles to rise, then goes still.
The <pushBold/><a exist="12345678" noun="griffin">war griffin</a><popBold/> crashes to the ground, motionless.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> falls to the ground in a crumpled heap.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> vainly struggles to rise, then goes still.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="dirge">death dirge's</a><popBold/> body and rises into the heavens.
The <pushBold/><a exist="12345678" noun="dirge">death dirge</a><popBold/> falls to the ground motionless.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="golem">bone golem's</a><popBold/> body and rises into the heavens.
The skeletal structure of <pushBold/>a <a exist="12345678" noun="golem">bone golem</a><popBold/> shudders violently, before falling to the ground in a disorganized pile.
The skeletal structure of the <pushBold/>a <a exist="12345678" noun="golem">bone golem</a><popBold/> shudders violently before scattering into a disorganized pile.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="janissary">his</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="janissary">he</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="janissary">his</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> falls to the ground in a crumpled heap.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="seer">his</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="seer">he</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="seer">his</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> falls to the ground in a crumpled heap.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="seer">her</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="seer">she</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="seer">her</a><popBold/> eyes.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="wight">arch wight's</a><popBold/> body and rises into the heavens.
The <pushBold/><a exist="12345678" noun="wight">arch wight</a><popBold/> screams evilly one last time and goes still.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> falls to the ground in a crumpled heap.
The <pushBold/><a exist="12345678" noun="wight">arch wight</a><popBold/> falls to the floor motionless.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="master">ghoul master's</a><popBold/> body and rises into the heavens.
The <pushBold/><a exist="12345678" noun="master">ghoul master</a><popBold/> screams evilly one last time and goes still.
The <pushBold/><a exist="12345678" noun="shambler">dark shambler</a><popBold/> screams evilly one last time and goes still.
The <pushBold/><a exist="12345678" noun="shambler">dark shambler</a><popBold/> falls to the ground motionless.
The glimmer of a <a exist="12345678" noun="dreamstone">pink dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> falls to the ground in a crumpled heap.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="scout">her</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="scout">she</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="scout">her</a><popBold/> eyes.
The glimmer of an <a exist="12345678" noun="diamond">uncut diamond</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="emerald">star emerald</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> falls to the ground dead, her skin still pulsating with a blinding white hue.
The glimmer of a <a exist="12345678" noun="pearl">tiny black pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="moonstone">cats-eye moonstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="ogre">plains ogre</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="leopard">black leopard</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="lion">plains lion</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="chieftain">troll chieftain</a><popBold/> bellows in rage one last time and dies.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="adept">his</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="adept">he</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="adept">his</a><popBold/> eyes.
The glimmer of a <a exist="12345678" noun="sapphire">green sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="sapphire">yellow sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="sunstone">yellow sunstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="sentry">triton sentry's</a><popBold/> body and rises into the heavens.
The <pushBold/><a exist="12345678" noun="wraith">grave wraith</a><popBold/> slumps to the floor, exhales a sigh of relief, and begins to quickly decay away.
The glimmer of a <a exist="12345678" noun="quartz">piece of citrine quartz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="tourmaline">black tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of an <a exist="12345678" noun="emerald">uncut emerald</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="pearl">tiny grey pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="pearl">small white pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="tourmaline">pink tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="opal">fire opal</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="initiate">her</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="initiate">she</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="initiate">her</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="griffin">war griffin</a><popBold/> writhes in agony, <pushBold/><a exist="12345678" noun="griffin">its</a><popBold/> wings flapping fruitlessly as <pushBold/><a exist="12345678" noun="griffin">it</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="scout">his</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="scout">he</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="scout">his</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="adept">her</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="adept">she</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="adept">her</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> sneers, "Urok vas derop tal kalissar kamath," then collapses.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> slumps over dead, his skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="herald">her</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="herald">she</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="herald">her</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="troll">ice troll</a><popBold/> falls to the ground motionless.
The glimmer of a <a exist="12345678" noun="starstone">blue starstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> slumps over dead, his skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="scout">herself</a><popBold/>, then collapses with a wheeze.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="seer">her</a><popBold/> lips as <pushBold/><a exist="12345678" noun="seer">she</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="lion">plains lion</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="initiate">himself</a><popBold/>, then collapses with a wheeze.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> sneers, "Urok vas derop tal kalissar kamath," then collapses.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="janissary">herself</a><popBold/>, then collapses with a wheeze.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> sneers, "Urok vas derop tal kalissar kamath," then collapses.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="seer">she</a><popBold/> collapses.
The glimmer of an <a exist="12345678" noun="ruby">uncut ruby</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="peridot">green peridot</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="dreamstone">blue dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="sunstone">white sunstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="sapphire">star sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of <a exist="12345678" noun="quartz">some asterfire quartz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="radical">triton radical</a><popBold/> implodes inward upon itself, leaving behind no support for his body or life.  The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
The <pushBold/><a exist="12345678" noun="chieftain">troll chieftain</a><popBold/> howls in agony while falling to the ground motionless.
The glimmer of a <a exist="12345678" noun="gem">bright chrysoberyl gem</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="topaz">pink topaz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="combatant">triton combatant</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="dissembler">his</a><popBold/> face before expiring.
The glimmer of a <a exist="12345678" noun="sapphire">green sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="executioner">triton executioner</a><popBold/> implodes inward upon itself, leaving behind no support for his body or life.  The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
The glimmer of a <a exist="12345678" noun="moonstone">black moonstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="tourmaline">clear tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="opal">dragonfire opal</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of <a exist="12345678" noun="quartz">some dragonfire quartz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="moonstone">golden moonstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of <a exist="12345678" noun="coral">some polished pink coral</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="pearl">tiny black pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> falls to the ground dead, her skin still pulsating with a blinding white hue.
The glimmer of <a exist="12345678" noun="coral">some polished red coral</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="starstone">red starstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="stone">green malachite stone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="ruby">star ruby</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> sneers, "Urok vas derop tal kalissar kamath," then collapses.
The glimmer of a <a exist="12345678" noun="starstone">green starstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="topaz">smoky topaz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="peridot">blue peridot</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="initiate">his</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="initiate">he</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="initiate">his</a><popBold/> eyes.
The glimmer of a <a exist="12345678" noun="sapphire">yellow sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="starstone">blue starstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="garnet">green garnet</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> collapses to the ground with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="combatant">her</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="defender">triton defender</a><popBold/> rolls over and dies.
The glimmer of a <a exist="12345678" noun="tourmaline">pink tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="moonstone">black moonstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="wasp">mud wasp</a><popBold/> careens to the ground and crumples in a heap.
The <pushBold/><a exist="12345678" noun="lizard">siren lizard</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="devil">sand devil</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="shoot">firethorn shoot</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="beetle">giant fog beetle</a><popBold/> kicks a leg one last time and lies still.
The <pushBold/><a exist="12345678" noun="chieftain">troll chieftain</a><popBold/> snarls <pushBold/><a exist="12345678" noun="chieftain">his</a><popBold/> defiance before collapsing and going still.
The <pushBold/><a exist="12345678" noun="beetle">giant fog beetle</a><popBold/> falls to the ground and lies twitching for a moment before going still.
The <pushBold/><a exist="12345678" noun="chieftain">troll chieftain</a><popBold/> snarls <pushBold/><a exist="12345678" noun="chieftain">her</a><popBold/> defiance one last time before going still.
The <pushBold/><a exist="12345678" noun="troll">jungle troll's</a><popBold/> body convulses one last time before the stillness of death overtakes <pushBold/><a exist="12345678" noun="troll">him</a><popBold/>.
With a final squeal the <pushBold/><a exist="12345678" noun="burgee">scaly burgee</a><popBold/> rears up its head, then curls up into a ball, dead.
With a final squeal the <pushBold/><a exist="12345678" noun="burgee">scaly burgee</a><popBold/> rears up its head, then falls to the ground and curls up into a ball, dead.
With a final squeal the <pushBold/><a exist="12345678" noun="burgee">scaly burgee</a><popBold/> rears up its head, then falls to the floor and curls up into a ball, dead.
The <pushBold/><a exist="12345678" noun="troll">jungle troll's</a><popBold/> body convulses one last time before the stillness of death overtakes <pushBold/><a exist="12345678" noun="troll">her</a><popBold/>.
The <pushBold/><a exist="12345678" noun="hag">ash hag</a><popBold/> falls to the ground, her living fire extinguished.
The <pushBold/><a exist="12345678" noun="ogre">fire ogre</a><popBold/> falls to the ground, <pushBold/><a exist="12345678" noun="ogre">his</a><popBold/> living fire extinguished.
As the fire leaves her eyes, the <pushBold/><a exist="12345678" noun="hag">ash hag</a><popBold/> cries out in pain one last time and expires.
The glimmer of an <a exist="12345678" noun="diamond">uncut diamond</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of <a exist="12345678" noun="lapis lazuli">some blue lapis lazuli</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="stone">green malachite stone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="peridot">blue peridot</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="dreamstone">red dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="opal">white opal</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="marauder">human marauder</a><popBold/> rolls over and dies.
The glimmer of a <a exist="12345678" noun="ruby">star ruby</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="amber">piece of golden amber</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="peridot">pink peridot</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="dreamstone">red dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="combatant">triton combatant</a><popBold/> implodes inward upon itself, leaving behind no support for his body or life.  The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
All that remains of the <pushBold/><a exist="12345678" noun="herald">herald</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
All that remains of the <pushBold/><a exist="12345678" noun="scout">scout</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="janissary">her</a><popBold/> wounds as <pushBold/><a exist="12345678" noun="janissary">she</a><popBold/> falls, the life fading from <pushBold/><a exist="12345678" noun="janissary">her</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> slumps over dead, his skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="siren">siren</a><popBold/> falls to the ground dead, her skin still pulsating with a blinding white hue.
The glimmer of a <a exist="12345678" noun="zircon">yellow zircon</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="opal">fire opal</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> collapses to the ground with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="combatant">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="wraith">grave wraith</a><popBold/> exhales a sigh of relief and begins to quickly decay away.
The glimmer of a <a exist="12345678" noun="stone">pink rhodochrosite stone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="topaz">golden topaz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="pearl">small black pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="amethyst">deep purple amethyst</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="chieftain">troll chieftain</a><popBold/> snarls <pushBold/><a exist="12345678" noun="chieftain">her</a><popBold/> defiance before collapsing and going still.
The <pushBold/><a exist="12345678" noun="ranger">giant ranger</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="troll">jungle troll</a><popBold/> falls to the floor as the stillness of death overtakes <pushBold/><a exist="12345678" noun="troll">him</a><popBold/>.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="siren">siren</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="siren">siren</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="initiate">she</a><popBold/> collapses.
The glimmer of a <a exist="12345678" noun="spinel">blue spinel</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="stone">pink rhodochrosite stone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="moonstone">golden moonstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="amethyst">deep purple amethyst</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> collapses to the ground with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="magus">her</a><popBold/> face before expiring.
The glimmer of a <a exist="12345678" noun="starstone">red starstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of <a exist="12345678" noun="quartz">some dragonfire quartz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="opal">dragonfire opal</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="pearl">large grey pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="stone">turquoise stone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of <a exist="12345678" noun="quartz">some asterfire quartz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> falls to the floor dead, his skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> slumps over dead, his skin still pulsating with a blinding white hue.
The glimmer of a <a exist="12345678" noun="gem">golden beryl gem</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> slumps over dead, her skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="magus">triton magus</a><popBold/> falls to the floor dead, his skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="initiate">he</a><popBold/> collapses.
The glimmer of a <a exist="12345678" noun="dreamstone">blue dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="initiate">her</a><popBold/> lips as <pushBold/><a exist="12345678" noun="initiate">she</a><popBold/> falls.
The glimmer of a <a exist="12345678" noun="dreamstone">green dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="wraith">grave wraith</a><popBold/> slumps to the ground, exhales a sigh of relief, and begins to quickly decay away.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="adept">her</a><popBold/> pupil-less green eyes frozen in a dead stare.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> whispers, "Ra dro, Te lothre on ka nuko," then collapses.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> whispers, "Ra dro, Te lothre on ka nuko," then collapses.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="initiate">he</a><popBold/> falls, "Letta, Leth, Latoth..."
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="janissary">her</a><popBold/> face as <pushBold/><a exist="12345678" noun="janissary">she</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="scout">his</a><popBold/> face as <pushBold/><a exist="12345678" noun="scout">he</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="initiate">her</a><popBold/> face as <pushBold/><a exist="12345678" noun="initiate">she</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> screams as <pushBold/><a exist="12345678" noun="janissary">he</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="adept">her</a><popBold/> lips as <pushBold/><a exist="12345678" noun="adept">she</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> falls to the ground dead, its  still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> falls to the floor dead, its  still pulsating with a blinding white hue.
The glimmer of a <a exist="12345678" noun="sapphire">yellow sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the ground.
The glimmer of a <a exist="12345678" noun="peridot">blue peridot</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">large puddle</a> on the floor.
The glimmer of <a exist="12345678" noun="coral">some polished pink coral</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="moonstone">cats-eye moonstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="sapphire">violet sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="sapphire">blue sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="ghoul">lesser ghoul</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="skeleton">skeleton</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="apparition">dark apparition</a><popBold/> slowly settles to the ground and begins to dissipate.
The <pushBold/><a exist="12345678" noun="boar">brown boar</a><popBold/> collapses to the ground, emits a final squeal, and dies.
<pushBold/>A <a exist="12345678" noun="orc">Neartofar orc</a><popBold/> breathes <pushBold/><a exist="12345678" noun="orc">his</a><popBold/> last gasp and dies.
The <pushBold/><a exist="12345678" noun="moccasin">water moccasin</a><popBold/> is sliced neatly in two.
The <pushBold/><a exist="12345678" noun="spirit">sacristan spirit</a><popBold/> wails horribly as <pushBold/><a exist="12345678" noun="spirit">he</a><popBold/> begins to fade away!
The <pushBold/><a exist="12345678" noun="zombie">crazed zombie</a><popBold/> falls to the ground, a lifeless lump of flesh.
The <pushBold/><a exist="12345678" noun="niirsha">niirsha</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="spirit">tree spirit</a><popBold/> slowly settles to the ground and begins to dissipate.
The <pushBold/><a exist="12345678" noun="monk">frenzied monk</a><popBold/> collapses to the ground, <pushBold/><a exist="12345678" noun="monk">his</a><popBold/> spirit released.
<pushBold/>A <a exist="12345678" noun="snake">necrotic snake's</a><popBold/> tail trembles then falls to the ground as the rest of <pushBold/><a exist="12345678" noun="snake">its</a><popBold/> body goes limp.
A heavy mist pours from the <pushBold/><a exist="12345678" noun="spectre">bog spectre</a><popBold/> as <pushBold/><a exist="12345678" noun="spectre">she</a><popBold/> slumps to the ground.
The <pushBold/><a exist="12345678" noun="wight">bog wight</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="shade">warrior shade</a><popBold/> slumps silently to the ground and begins to rapidly dissipate.
A heavy mist pours from the <pushBold/><a exist="12345678" noun="spectre">bog spectre</a><popBold/> as <pushBold/><a exist="12345678" noun="spectre">he</a><popBold/> slumps to the ground.
The <pushBold/><a exist="12345678" noun="warrior">troll warrior</a><popBold/> gives a last angry stare and falls to the ground dead.
Grim realization flashes across <pushBold/>a <a exist="12345678" noun="occultist">bony Tenthsworn occultist's</a><popBold/> visage as <pushBold/><a exist="12345678" noun="occultist">she</a><popBold/> collapses, <pushBold/><a exist="12345678" noun="occultist">her</a><popBold/> mouth and eyes trailing threads of crimson smoke.
Torn and strained stitches pop all over <pushBold/>a <a exist="12345678" noun="hulk">grisly corpse hulk's</a><popBold/> body as <pushBold/><a exist="12345678" noun="hulk">it</a><popBold/> surrenders to death, allowing necrotic organs and ichor to spill free.
<pushBold/>A <a exist="12345678" noun="strigoi">desiccated half-krolvin strigoi's</a><popBold/> empty black eyes widen with something akin to surprise.  Animation leaves <pushBold/><a exist="12345678" noun="strigoi">his</a><popBold/> body in a sudden rush, leaving <pushBold/><a exist="12345678" noun="strigoi">him</a><popBold/> lifeless and still.
<pushBold/>A <a exist="12345678" noun="strigoi">desiccated half-krolvin strigoi's</a><popBold/> empty black eyes widen with something akin to surprise.  Animation leaves <pushBold/><a exist="12345678" noun="strigoi">her</a><popBold/> body in a sudden rush, leaving <pushBold/><a exist="12345678" noun="strigoi">her</a><popBold/> lifeless and still.
Grim realization flashes across <pushBold/>a <a exist="12345678" noun="occultist">bony Tenthsworn occultist's</a><popBold/> visage as <pushBold/><a exist="12345678" noun="occultist">he</a><popBold/> collapses, <pushBold/><a exist="12345678" noun="occultist">his</a><popBold/> mouth and eyes trailing threads of crimson smoke.
An instant of clarity dawns in <pushBold/>a <a exist="12345678" noun="selkie">gaunt feral selkie's</a><popBold/> eyes as <pushBold/><a exist="12345678" noun="selkie">she</a><popBold/> succumbs to <pushBold/><a exist="12345678" noun="selkie">her</a><popBold/> injuries.  Peace blossoms on <pushBold/><a exist="12345678" noun="selkie">her</a><popBold/> face as <pushBold/><a exist="12345678" noun="selkie">she</a><popBold/> dies.
A death spasm shakes <pushBold/>a <a exist="12345678" noun="selkie">gaunt feral selkie's</a><popBold/> body as <pushBold/><a exist="12345678" noun="selkie">her</a><popBold/> muscles and flesh rapidly reconfigure, leaving behind a still humanoid corpse.
The nearby shadows resound with the impact as <pushBold/>an <a exist="12345678" noun="incubus">athletic dark-eyed incubus</a><popBold/> falls to the ground.
A bloodcurdling screech tears from the throat of <pushBold/>a <a exist="12345678" noun="vereri">horrific magna vereri</a><popBold/> as <pushBold/><a exist="12345678" noun="vereri">she</a><popBold/> slumps to the ground.
<pushBold/>A <a exist="12345678" noun="vision">seething pestilent vision</a><popBold/> rapidly begins dwindling away, flickering like a dying candleflame.
<pushBold/>A <a exist="12345678" noun="inciter">supple Ivasian inciter</a><popBold/> begins to mouth a desperate prayer, but death stifles <pushBold/><a exist="12345678" noun="inciter">her</a><popBold/>.
<pushBold/>A <a exist="12345678" noun="inciter">supple Ivasian inciter</a><popBold/> begins to mouth a desperate prayer, but death stifles <pushBold/><a exist="12345678" noun="inciter">him</a><popBold/>.
<pushBold/>A <a exist="12345678" noun="orc">greater orc</a><popBold/> breathes <pushBold/><a exist="12345678" noun="orc">her</a><popBold/> last gasp and dies.
The <pushBold/><a exist="12345678" noun="ogre">large ogre</a><popBold/> screams one last time and dies.
<pushBold/>A <a exist="12345678" noun="orc">greater orc</a><popBold/> breathes <pushBold/><a exist="12345678" noun="orc">his</a><popBold/> last gasp and dies.
The <pushBold/><a exist="12345678" noun="spinner">brown spinner</a><popBold/> collapses to the ground and dies.
The <pushBold/><a exist="12345678" noun="wraith">mist wraith</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="rolton">zombie rolton</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="rolton">zombie rolton</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="goblin">fanged goblin</a><popBold/> falls to the ground, kicks several times and dies.
The <pushBold/><a exist="12345678" noun="ogre">large ogre</a><popBold/> falls to the floor and dies.
The <pushBold/><a exist="12345678" noun="pirate">krolvin pirate</a><popBold/> spits out one last curse and lies still.
The bright flecks of light in <pushBold/>a <a exist="12345678" noun="golem">night golem</a><popBold/> flare one last time before fading dully into black.
The <pushBold/><a exist="12345678" noun="eagle">blood eagle</a><popBold/> squawks as it falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="warrior">spectral warrior</a><popBold/> wails mournfully as the darkness fades from <pushBold/><a exist="12345678" noun="warrior">her</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="warrior">spectral warrior</a><popBold/> slumps silently to the floor, <pushBold/><a exist="12345678" noun="warrior">his</a><popBold/> dark eyes fading to grey.
The <pushBold/><a exist="12345678" noun="warrior">spectral warrior</a><popBold/> wails mournfully as the darkness fades from <pushBold/><a exist="12345678" noun="warrior">his</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="warrior">spectral warrior</a><popBold/> slumps silently to the floor, <pushBold/><a exist="12345678" noun="warrior">her</a><popBold/> dark eyes fading to grey.
The <pushBold/><a exist="12345678" noun="crocodile">crocodile</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="monkey">monkey</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="kobold">mongrel kobold</a><popBold/> falls to the floor and dies.
The <pushBold/><a exist="12345678" noun="kobold">mongrel kobold</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="firephantom">firephantom</a><popBold/> slowly settles to the ground and begins to dissipate.
The <pushBold/><a exist="12345678" noun="troll">mountain troll</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="bear">cave bear</a><popBold/> lets out a blood-curdling roar and dies.
The <pushBold/><a exist="12345678" noun="troll">mountain troll</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="troll">cave troll</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="troll">cave troll</a><popBold/> screams one last time and dies.
<pushBold/>A <a exist="12345678" noun="guardsman">decaying Citadel guardsman</a><popBold/> collapses sobbing silently before lying motionless on the floor.
<pushBold/>An <a exist="12345678" noun="apprentice">ethereal mage apprentice</a><popBold/> shrieks out in sorrow and collapses to the floor.
<pushBold/>A <a exist="12345678" noun="herald">putrefied Citadel herald</a><popBold/> stumbles to <pushBold/><a exist="12345678" noun="herald">his</a><popBold/> knees, uttering in an incredulous voice, "This cannot be defeat..." before dropping motionless to the floor.
<pushBold/>A <a exist="12345678" noun="herald">putrefied Citadel herald</a><popBold/> stumbles to <pushBold/><a exist="12345678" noun="herald">her</a><popBold/> knees before dropping motionless to the floor.
<pushBold/>A <a exist="12345678" noun="arbalester">rotting Citadel arbalester</a><popBold/> collapses motionless to the floor.
<pushBold/>A <a exist="12345678" noun="guardsman">decaying Citadel guardsman</a><popBold/> falls to <pushBold/><a exist="12345678" noun="guardsman">his</a><popBold/> knees sobbing silently before dropping motionless to the floor.
<pushBold/>A <a exist="12345678" noun="herald">putrefied Citadel herald</a><popBold/> writhes on the ground before lying motionless.
<pushBold/>A <a exist="12345678" noun="arbalester">rotting Citadel arbalester</a><popBold/> collapses motionless to the ground.
<pushBold/>A <a exist="12345678" noun="herald">putrefied Citadel herald</a><popBold/> stumbles to <pushBold/><a exist="12345678" noun="herald">his</a><popBold/> knees before dropping motionless to the ground.
<pushBold/>A <a exist="12345678" noun="herald">putrefied Citadel herald</a><popBold/> stumbles to <pushBold/><a exist="12345678" noun="herald">his</a><popBold/> knees before dropping motionless to the floor.
<pushBold/>A <a exist="12345678" noun="guardsman">decaying Citadel guardsman</a><popBold/> falls to <pushBold/><a exist="12345678" noun="guardsman">her</a><popBold/> knees sobbing silently before dropping motionless to the floor.
Growling lowly, the <pushBold/><a exist="12345678" noun="swordsman">bestial swordsman</a><popBold/> falls to one knee, then collapses to the floor.
<pushBold/>A <a exist="12345678" noun="herald">putrefied Citadel herald</a><popBold/> writhes on the floor before lying motionless.
<pushBold/>A <a exist="12345678" noun="herald">putrefied Citadel herald</a><popBold/> writhes on the floor then spits, "This cannot be defeat..." before lying motionless.
The <pushBold/><a exist="12345678" noun="shaman">hisskra shaman</a><popBold/> collapses in a motionless heap.
The <pushBold/><a exist="12345678" noun="warrior">hisskra warrior</a><popBold/> contorts in a tortured spasm, then goes still.
The <pushBold/><a exist="12345678" noun="chieftain">hisskra chieftain</a><popBold/> contorts in a tortured spasm, then goes still.
The <pushBold/><a exist="12345678" noun="warrior">hisskra warrior</a><popBold/> rolls over on his back and dies.
The <pushBold/><a exist="12345678" noun="warrior">hisskra warrior</a><popBold/> collapses in a motionless heap.
The <pushBold/><a exist="12345678" noun="shaman">hisskra shaman</a><popBold/> rolls over on his back and dies.
The <pushBold/><a exist="12345678" noun="warrior">hisskra warrior</a><popBold/> opens his mouth in an agonized scream, then collapses in an unmoving heap.
The <pushBold/><a exist="12345678" noun="chieftain">hisskra chieftain</a><popBold/> collapses in a motionless heap.
The <pushBold/><a exist="12345678" noun="chieftain">hisskra chieftain</a><popBold/> rolls over on his back and dies.
The <pushBold/><a exist="12345678" noun="hound">moor hound</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="hound">moor hound</a><popBold/> falls to the ground and dies.
<pushBold/>A <a exist="12345678" noun="wight">greater moor wight</a><popBold/> wails one final time as <pushBold/><a exist="12345678" noun="wight">it</a><popBold/> collapses.
The <pushBold/><a exist="12345678" noun="troll">greater bog troll's</a><popBold/> body goes rigid and collapses to the ground, dead.
The <pushBold/><a exist="12345678" noun="warrior">hisskra warrior's</a><popBold/> tail thrashes violently as he collapses.
The <pushBold/><a exist="12345678" noun="eagle">moor eagle</a><popBold/> augers into the ground, <pushBold/><a exist="12345678" noun="eagle">its</a><popBold/> death spiral ending in a **THUD**.
The <pushBold/><a exist="12345678" noun="eagle">moor eagle</a><popBold/> flops about on the ground, <pushBold/><a exist="12345678" noun="eagle">its</a><popBold/> thrashing finally ceasing in death.
The <pushBold/><a exist="12345678" noun="witch">moor witch's</a><popBold/> face takes on a surprised expression and she collapses, motionless.
The <pushBold/><a exist="12345678" noun="troll">bog troll</a><popBold/> drops to the ground in <pushBold/><a exist="12345678" noun="troll">her</a><popBold/> final moments and goes deathly still.
A purple vapor pours from the <pushBold/><a exist="12345678" noun="wraith">bog wraith's</a><popBold/> eyes, as <pushBold/><a exist="12345678" noun="wraith">she</a><popBold/> descends to the ground.
A purple vapor pours from the <pushBold/><a exist="12345678" noun="wraith">bog wraith's</a><popBold/> eyes, as <pushBold/><a exist="12345678" noun="wraith">he</a><popBold/> descends to the ground.
The <pushBold/><a exist="12345678" noun="troll">bog troll</a><popBold/> tries to get back up but finally collapses and goes still.
The <pushBold/><a exist="12345678" noun="troll">greater bog troll's</a><popBold/> body goes rigid and <pushBold/><a exist="12345678" noun="troll">her</a><popBold/> eyes roll back into <pushBold/><a exist="12345678" noun="troll">her</a><popBold/> head as <pushBold/><a exist="12345678" noun="troll">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="troll">greater bog troll's</a><popBold/> body goes rigid and <pushBold/><a exist="12345678" noun="troll">his</a><popBold/> eyes roll back into <pushBold/><a exist="12345678" noun="troll">his</a><popBold/> head as <pushBold/><a exist="12345678" noun="troll">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="hag">swamp hag's</a><popBold/> face muscles slacken, her hard-bitten features disappearing in death.
The <pushBold/><a exist="12345678" noun="hag">swamp hag's</a><popBold/> muscles collapse and she shrinks into a pitiful pile of rags and bones, her hard-bitten features disappearing in death.
The <pushBold/><a exist="12345678" noun="slaver">krolvin slaver's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="slaver">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="slaver">krolvin slaver</a><popBold/> slams to the deck, dead as a salmon bear snack.
The <pushBold/><a exist="12345678" noun="slaver">krolvin slaver</a><popBold/> collapses to the deck, dead as a pickled herring.
The <pushBold/><a exist="12345678" noun="corsair">krolvin corsair</a><popBold/> thuds to the deck in a plume of dust.
The <pushBold/><a exist="12345678" noun="corsair">krolvin corsair</a><popBold/> tries to crawl away on the deck but collapses and goes still.
<pushBold/>A <a exist="12345678" noun="shaman">Grutik shaman</a><popBold/> collapses into a lifeless heap upon the ground.
<pushBold/>A <a exist="12345678" noun="savage">Grutik savage</a><popBold/> collapses into a lifeless heap upon the ground.
<pushBold/>The <a exist="12345678" noun="wormling">wormling</a><popBold/> rolls over and dies.
All that remains of the <pushBold/><a exist="12345678" noun="wormling">wormling</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
All that remains of the <pushBold/><a exist="12345678" noun="savage">savage</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
<pushBold/>A <a exist="12345678" noun="shaman">dreary Grutik shaman</a><popBold/> collapses into a lifeless heap upon the ground.
All that remains of the <pushBold/><a exist="12345678" noun="shaman">shaman</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
A nebulous haze shimmers into view around <pushBold/>a <a exist="12345678" noun="defender">spectral triton defender</a><popBold/>, plunging inward in a dizzying spiral to envelop <pushBold/><a exist="12345678" noun="defender">him</a><popBold/> completely!  Silhouetted within the shifting spiritual miasma, the <pushBold/><a exist="12345678" noun="defender">defender's</a><popBold/> form withers, wasting away to an attenuated mockery of <pushBold/><a exist="12345678" noun="defender">himself</a><popBold/>.  Even this pale shadow disintegrates, dissolving on the air as the last cloudy tendrils vanish.
A nebulous haze shimmers into view around <pushBold/>a <a exist="12345678" noun="defender">spectral triton defender</a><popBold/>, plunging inward in a dizzying spiral to envelop <pushBold/><a exist="12345678" noun="defender">her</a><popBold/> completely!  Silhouetted within the shifting spiritual miasma, the <pushBold/><a exist="12345678" noun="defender">defender's</a><popBold/> form withers, wasting away to an attenuated mockery of <pushBold/><a exist="12345678" noun="defender">herself</a><popBold/>.  Even this pale shadow disintegrates, dissolving on the air as the last cloudy tendrils vanish.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="scout">her</a><popBold/> pupil-less green eyes frozen in a dead stare.
The glimmer of a <a exist="12345678" noun="quartz">piece of rose quartz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> collapses to the ground with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="radical">her</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="troll">bog troll</a><popBold/> drops to the ground in <pushBold/><a exist="12345678" noun="troll">his</a><popBold/> final moments and goes deathly still.
The <pushBold/><a exist="12345678" noun="soldier">skeletal soldier</a><popBold/> clatters to the ground into a heap of jumbled bones.
<pushBold/>A <a exist="12345678" noun="troll">sickly green tomb troll</a><popBold/> blinks in astonishment, then collapses in a motionless heap.
<pushBold/>A <a exist="12345678" noun="golem">flesh golem</a><popBold/> collapses in a heap, <pushBold/><a exist="12345678" noun="golem">its</a><popBold/> huge girth shaking the floor around <pushBold/><a exist="12345678" noun="golem">it</a><popBold/>.
<pushBold/>A <a exist="12345678" noun="troll">tomb troll</a><popBold/> blinks in astonishment, then collapses in a motionless heap.
<pushBold/>A <a exist="12345678" noun="necromancer">tomb troll necromancer</a><popBold/> glares forward, then collapses in a motionless heap.
<pushBold/>A <a exist="12345678" noun="troll">tomb troll</a><popBold/> blinks in astonishment, then falls flat on <pushBold/><a exist="12345678" noun="troll">his</a><popBold/> face with a loud *THUD*.
<pushBold/>A <a exist="12345678" noun="troll">tomb troll</a><popBold/> blinks in astonishment, then falls flat on <pushBold/><a exist="12345678" noun="troll">her</a><popBold/> face with a loud *THUD*.
<pushBold/>A <a exist="12345678" noun="servant">gaunt spectral servant</a><popBold/> groans weakly and drops slowly to the ground.
<pushBold/>A <a exist="12345678" noun="chimera">rotting chimera</a><popBold/> releases a loud, weary sigh and slumps to the ground.
The <pushBold/><a exist="12345678" noun="corpse">rotting corpse</a><popBold/> wails in terrifying pain one last time and lies still.
The <pushBold/><a exist="12345678" noun="corpse">rotting corpse</a><popBold/> falls to the ground, rotting flesh falling from <pushBold/><a exist="12345678" noun="corpse">his</a><popBold/> bones.
The <pushBold/><a exist="12345678" noun="warhorse">skeletal warhorse</a><popBold/> wails in terrifying pain one last time and lies still.
The <pushBold/><a exist="12345678" noun="lord">skeletal lord</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="lord">skeletal lord</a><popBold/> wails in terrifying pain one last time and lies still.
The <pushBold/><a exist="12345678" noun="phantasma">phantasma</a><popBold/> shrieks in terror for an instant, then begins to rapidly dissipate!
<pushBold/>The <a exist="12345678" noun="roa'ter">roa'ter</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="urgh">urgh</a><popBold/> collapses to the ground, emits a final squeal, and dies.
The <pushBold/><a exist="12345678" noun="ogre">large ogre</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="troll">swamp troll</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="troll">swamp troll</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="revenant">revenant</a><popBold/> slowly settles to the ground and begins to dissipate.
<pushBold/>A <a exist="12345678" noun="werebear">werebear</a><popBold/> growls one last time, and crumples to the ground in a heap.
The <pushBold/><a exist="12345678" noun="dobrem">dobrem</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="rolton">Bresnahanini rolton</a><popBold/> collapses to the ground, emits a final bleat, and dies.
The <pushBold/><a exist="12345678" noun="rolton">Bresnahanini rolton</a><popBold/> lets out a final agonized bleat and dies.
The <pushBold/><a exist="12345678" noun="daggerbeak">black-winged daggerbeak</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="coyote">coyote</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="urgh">urgh</a><popBold/> lets out a final agonized squeal and dies.
The <pushBold/><a exist="12345678" noun="kobold">mongrel kobold</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="kobold">kobold</a><popBold/> crumples to a heap on the ground and dies.
The <pushBold/><a exist="12345678" noun="wight">wood wight</a><popBold/> falls to the floor motionless.
The <pushBold/><a exist="12345678" noun="wight">wood wight</a><popBold/> screams evilly one last time and goes still.
The <pushBold/><a exist="12345678" noun="woodsman">rotting woodsman</a><popBold/> shudders slightly then ceases <pushBold/><a exist="12345678" noun="woodsman">her</a><popBold/> so called life.
The <pushBold/><a exist="12345678" noun="woodsman">rotting woodsman</a><popBold/> shudders slightly then ceases <pushBold/><a exist="12345678" noun="woodsman">his</a><popBold/> so called life.
The <pushBold/><a exist="12345678" noun="chieftain">shelfae chieftain</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="panther">panther</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="crocodile">crocodile</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="cyclops">cyclops</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="cyclops">cyclops</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="spectre">spectre</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="spider">greater spider</a><popBold/> collapses to the ground and dies.
The <pushBold/><a exist="12345678" noun="spider">greater spider's</a><popBold/> body jerks one last time and dies.
The <pushBold/><a exist="12345678" noun="thrak">thrak</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="puma">puma</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="boar">great boar</a><popBold/> collapses to the ground, emits a final squeal, and dies.
The <pushBold/><a exist="12345678" noun="manticore">manticore</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="salamander">fire salamander</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="salamander">fire salamander</a><popBold/> is sliced neatly in two.
The <pushBold/><a exist="12345678" noun="nymph">sea nymph</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="cobra">cobra</a><popBold/> is sliced neatly in two.
The <pushBold/><a exist="12345678" noun="fisherman">spectral fisherman</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="ghoul">greater ghoul</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="crab">pale crab</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="whiptail">whiptail</a><popBold/> falls back and dies.
The <pushBold/><a exist="12345678" noun="ogre">forest ogre</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="darkwoode">darkwoode</a><popBold/> slowly settles to the ground and begins to dissipate.
The <pushBold/><a exist="12345678" noun="fenghai">fenghai</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="mezic">mezic</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="shade">spectral shade</a><popBold/> slumps silently to the ground and begins to rapidly dissipate.
The <pushBold/><a exist="12345678" noun="wolverine">wolverine</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="wolverine">wolverine</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="troll">thunder troll</a><popBold/> crumples to the ground motionless.
The <pushBold/><a exist="12345678" noun="troll">mongrel troll</a><popBold/> falls to the ground with a thud.
The <pushBold/><a exist="12345678" noun="troll">forest troll</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="troll">mongrel troll</a><popBold/> whimpers pitifully one last time and dies.
The <pushBold/><a exist="12345678" noun="vesperti">vesperti</a><popBold/> falls to the ground, <pushBold/><a exist="12345678" noun="vesperti">his</a><popBold/> wings collapsing around <pushBold/><a exist="12345678" noun="vesperti">him</a><popBold/>.
The <pushBold/><a exist="12345678" noun="vesperti">vesperti</a><popBold/> falls to the ground, <pushBold/><a exist="12345678" noun="vesperti">her</a><popBold/> wings collapsing around <pushBold/><a exist="12345678" noun="vesperti">her</a><popBold/>.
The <pushBold/><a exist="12345678" noun="vesperti">vesperti's</a><popBold/> wings splay out as <pushBold/><a exist="12345678" noun="vesperti">he</a><popBold/> goes still.
The <pushBold/><a exist="12345678" noun="pra'eda">pra'eda</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="cougar">cougar</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="centaur">black centaur</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="cougar">cougar</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="arachnid">mammoth arachnid</a><popBold/> collapses to the ground and dies.
The <pushBold/><a exist="12345678" noun="cleric">shan cleric</a><popBold/> howls out one last time and dies.
The <pushBold/><a exist="12345678" noun="warrior">shan warrior</a><popBold/> yips in pain as <pushBold/><a exist="12345678" noun="warrior">she</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="ranger">shan ranger</a><popBold/> yips in pain as <pushBold/><a exist="12345678" noun="ranger">she</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="ranger">shan ranger</a><popBold/> yips in pain as <pushBold/><a exist="12345678" noun="ranger">he</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="warrior">shan warrior</a><popBold/> howls out one last time and dies.
The <pushBold/><a exist="12345678" noun="eidolon">eidolon</a><popBold/> slumps silently to the floor and begins to rapidly dissipate.
The <pushBold/><a exist="12345678" noun="dybbuk">dybbuk</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="waern">waern</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="dybbuk">dybbuk</a><popBold/> wails in terrifying pain one last time and lies still.
The <pushBold/><a exist="12345678" noun="empath">shan empath</a><popBold/> howls out one last time and dies.
The <pushBold/><a exist="12345678" noun="empath">shan empath</a><popBold/> yips in pain as <pushBold/><a exist="12345678" noun="empath">he</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="rogue">shan rogue</a><popBold/> howls out one last time and dies.
With a surprised grunt, the <pushBold/><a exist="12345678" noun="warrior">minotaur warrior</a><popBold/> twitches one final time before falling still upon the floor.
A low gurgling sound comes from deep within the chest of the <pushBold/><a exist="12345678" noun="minotaur">lesser minotaur</a><popBold/> as <pushBold/><a exist="12345678" noun="minotaur">he</a><popBold/> falls slack against the floor.
One last prolonged bovine moan escapes from the <pushBold/><a exist="12345678" noun="magus">minotaur magus</a><popBold/> as <pushBold/><a exist="12345678" noun="magus">he</a><popBold/> falls still against the floor.
One last prolonged bovine moan escapes from the <pushBold/><a exist="12345678" noun="magus">minotaur magus</a><popBold/> as <pushBold/><a exist="12345678" noun="magus">she</a><popBold/> falls still against the floor.
<pushBold/>A <a exist="12345678" noun="vereri">nedum vereri</a><popBold/> exhales a sigh of relief and slumps to the ground motionless.
<pushBold/>A <a exist="12345678" noun="vereri">nedum vereri</a><popBold/> exhales a sigh of relief and goes still.
The <pushBold/><a exist="12345678" noun="giant">storm giant</a><popBold/> crumples to the ground motionless.
<pushBold/>A <a exist="12345678" noun="giant">skeletal giant</a><popBold/> falls to the ground in a clattering, motionless heap.
The <pushBold/><a exist="12345678" noun="giant">storm giant</a><popBold/> howls in agony one last time and dies.
<pushBold/>A <a exist="12345678" noun="giant">skeletal giant</a><popBold/> falls still, its bones snapping like twigs.
<pushBold/>A <a exist="12345678" noun="orc">grey orc</a><popBold/> gazes upward one last time and dies.
The <pushBold/><a exist="12345678" noun="ranger">gnoll ranger</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="thief">gnoll thief</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="worker">gnoll worker</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="thief">gnoll thief</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="troll">forest troll</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="cockatrice">cockatrice</a><popBold/> rolls over on its back, emits a final screech and dies.
The <pushBold/><a exist="12345678" noun="goblin">goblin</a><popBold/> falls to the ground, kicks several times and dies.
The <pushBold/><a exist="12345678" noun="troll">hill troll</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="troll">hill troll</a><popBold/> screams one last time and dies.
<pushBold/>A <a exist="12345678" noun="orc">dark orc</a><popBold/> gives a last shudder and dies.
The <pushBold/><a exist="12345678" noun="wraith">wraith</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="wraith">wraith</a><popBold/> screams evilly one last time and goes still.
The <pushBold/><a exist="12345678" noun="marmot">giant marmot</a><popBold/> collapses to the ground, emits a final squeal, and dies.
The <pushBold/><a exist="12345678" noun="marmot">giant marmot</a><popBold/> twitches and dies.
The <pushBold/><a exist="12345678" noun="troll">war troll</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="wolf">ghost wolf</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="troll">war troll</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="ogre">mountain ogre</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="ogre">mountain ogre</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="zombie">zombie</a><popBold/> falls to the ground, a lifeless lump of flesh.
The <pushBold/><a exist="12345678" noun="lion">mountain lion</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="shepherd">kobold shepherd</a><popBold/> crumples to the ground motionless.
The <pushBold/><a exist="12345678" noun="shepherd">kobold shepherd</a><popBold/> howls in agony one last time and dies.
The <pushBold/><a exist="12345678" noun="gak">spotted gak</a><popBold/> collapses to the ground, emits a final bellow, and dies.
The <pushBold/><a exist="12345678" noun="gak">striped gak</a><popBold/> lets out a final agonized bellow and dies.
The <pushBold/><a exist="12345678" noun="hobgoblin">hobgoblin</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="hobgoblin">hobgoblin</a><popBold/> lets out a final scream and goes still.
The <pushBold/><a exist="12345678" noun="lynx">spotted lynx</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="shaman">hobgoblin shaman</a><popBold/> screams up at the heavens, then collapses and dies.
The <pushBold/><a exist="12345678" noun="lynx">spotted lynx</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="hobgoblin">mongrel hobgoblin</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="shaman">hobgoblin shaman</a><popBold/> struggles to utter a final prayer, then goes still.
The <pushBold/><a exist="12345678" noun="troll">thunder troll</a><popBold/> howls in agony one last time and dies.
<pushBold/>The <a exist="12345678" noun="grub">grub</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="gremlin">blue gremlin</a><popBold/> falls to the ground and dies with a gentle sigh.
The <pushBold/><a exist="12345678" noun="gremlin">black gremlin</a><popBold/> sighs one last time and dies.
The <pushBold/><a exist="12345678" noun="gnome">cave gnome</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="gnoll">cave gnoll</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="gnome">cave gnome</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="troglodyte">troglodyte</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="snowcat">mountain snowcat</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="velnalin">velnalin</a><popBold/> lets out a final agonized sigh and dies.
The <pushBold/><a exist="12345678" noun="velnalin">velnalin</a><popBold/> collapses to the ground, emits a final sigh, and dies.
The <pushBold/><a exist="12345678" noun="kobold">kobold</a><popBold/> cries out in pain one last time and dies.
The <pushBold/><a exist="12345678" noun="rolton">rolton</a><popBold/> lets out a final agonized bleat and dies.
The <pushBold/><a exist="12345678" noun="squirrel">rabid squirrel</a><popBold/> twitches its tail one last time and dies.
The <pushBold/><a exist="12345678" noun="kobold">kobold</a><popBold/> crumples to a heap on the floor and dies.
The <pushBold/><a exist="12345678" noun="kobold">big ugly kobold</a><popBold/> keels over and twitches on the ground a few times before dying.
The <pushBold/><a exist="12345678" noun="servant">Arachne servant</a><popBold/> slumps to the ground and dies.
The <pushBold/><a exist="12345678" noun="spider">major spider</a><popBold/> collapses to the ground and dies.
The <pushBold/><a exist="12345678" noun="spider">major spider's</a><popBold/> body jerks one last time and dies.
The <pushBold/><a exist="12345678" noun="servant">Arachne servant</a><popBold/> exhales a final curse and dies.
The <pushBold/><a exist="12345678" noun="priestess">Arachne priestess</a><popBold/> slumps to the ground and dies.
The <pushBold/><a exist="12345678" noun="priest">Arachne priest</a><popBold/> exhales a final curse and dies.
The <pushBold/><a exist="12345678" noun="acolyte">Arachne acolyte</a><popBold/> slumps to the ground and dies.
The <pushBold/><a exist="12345678" noun="acolyte">Arachne acolyte</a><popBold/> exhales a final curse and dies.
The <pushBold/><a exist="12345678" noun="arachnid">mammoth arachnid's</a><popBold/> body jerks one last time and dies.
The <pushBold/><a exist="12345678" noun="boar">black boar</a><popBold/> collapses to the ground, emits a final squeal, and dies.
The <pushBold/><a exist="12345678" noun="viper">winged viper</a><popBold/> crashes to the ground, motionless.
The <pushBold/><a exist="12345678" noun="direbear">direbear</a><popBold/> lets out a blood-curdling roar and dies.
The <pushBold/><a exist="12345678" noun="direbear">direbear</a><popBold/> collapses heavily into a heap on the ground and dies.
The <pushBold/><a exist="12345678" noun="direwolf">monstrous direwolf</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="direwolf">monstrous direwolf</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="sprite">Ilvari sprite's</a><popBold/> eyes grow dim as <pushBold/><a exist="12345678" noun="sprite">her</a><popBold/> lifeforce fades away.
The <pushBold/><a exist="12345678" noun="pixie">Ilvari pixie's</a><popBold/> eyes grow dim as <pushBold/><a exist="12345678" noun="pixie">his</a><popBold/> lifeforce fades away.
The <pushBold/><a exist="12345678" noun="druid">treekin druid</a><popBold/> crumbles to the ground!
The <pushBold/><a exist="12345678" noun="warrior">treekin warrior</a><popBold/> crumbles to the ground!
The <pushBold/><a exist="12345678" noun="mercenary">krolvin mercenary</a><popBold/> hits the ground with a less than elegant thud.
The <pushBold/><a exist="12345678" noun="mercenary">krolvin mercenary</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="warcat">striped warcat</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="warcat">striped warcat</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="reiver">reiver</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="reiver">reiver</a><popBold/> takes one last breath, then dies.
The <pushBold/><a exist="12345678" noun="rolton">mountain rolton</a><popBold/> collapses to the ground, emits a final bleat, and dies.
The <pushBold/><a exist="12345678" noun="warfarer">krolvin warfarer</a><popBold/> rolls over on the ground and goes still.
<pushBold/>The <a exist="12345678" noun="worm">worm</a><popBold/> rolls over and dies.
<pushBold/>A <a exist="12345678" noun="golem">crystal golem's</a><popBold/> eyes flare in a final puff of fire before <pushBold/><a exist="12345678" noun="golem">it</a><popBold/> falls to the floor, motionless.
<pushBold/>A <a exist="12345678" noun="golem">crystal golem's</a><popBold/> eyes flare in a final puff of fire before <pushBold/><a exist="12345678" noun="golem">it</a><popBold/> goes motionless.
The <pushBold/><a exist="12345678" noun="bear">black bear</a><popBold/> collapses heavily into a heap on the ground and dies.
The <pushBold/><a exist="12345678" noun="boar">great boar</a><popBold/> lets out a final agonized squeal and dies.
The <pushBold/><a exist="12345678" noun="warrior">ghostly warrior</a><popBold/> shudders one final time before lying motionless.
Ethereal vapor wanes off the <pushBold/><a exist="12345678" noun="warrior">ghostly warrior</a><popBold/> as <pushBold/><a exist="12345678" noun="warrior">she</a><popBold/> falls to the floor.
Ethereal vapor wanes off the <pushBold/><a exist="12345678" noun="warrior">ghostly warrior</a><popBold/> as <pushBold/><a exist="12345678" noun="warrior">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="cat">fire cat</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="rat">fire rat</a><popBold/> collapses to the ground, emits a final squeal, and dies.
The <pushBold/><a exist="12345678" noun="rat">fire rat</a><popBold/> twitches and dies.
The <pushBold/><a exist="12345678" noun="monk">spectral monk</a><popBold/> wails horribly as <pushBold/><a exist="12345678" noun="monk">he</a><popBold/> begins to fade away!
The <pushBold/><a exist="12345678" noun="lich">monastic lich</a><popBold/> collapses to the ground, <pushBold/><a exist="12345678" noun="lich">his</a><popBold/> spirit released.
The <pushBold/><a exist="12345678" noun="lich">monastic lich</a><popBold/> seems to collapse in upon <pushBold/><a exist="12345678" noun="lich">himself</a><popBold/>, leaving only a withered husk.
The <pushBold/><a exist="12345678" noun="nonomino">nonomino</a><popBold/> wails in terrifying pain one last time and lies still.
The <pushBold/><a exist="12345678" noun="carceris">carceris</a><popBold/> wails in terrifying pain one last time and lies still.
The <pushBold/><a exist="12345678" noun="hornet">greenwing hornet</a><popBold/> falls back into a heap and dies.
<pushBold/>A <a exist="12345678" noun="spirit">moaning spirit</a><popBold/> collapses into a puddle of jelly, falling silent at last.
The <pushBold/><a exist="12345678" noun="nonomino">nonomino</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="elemental">earth elemental</a><popBold/> shudders violently for a moment, then goes still.
The <pushBold/><a exist="12345678" noun="elder">Illoke elder</a><popBold/> grumbles in pain one last time before lying still.
The <pushBold/><a exist="12345678" noun="jarl">Illoke jarl</a><popBold/> grumbles in pain one last time before lying still.
The <pushBold/><a exist="12345678" noun="krynch">greater krynch</a><popBold/> shudders violently for a moment, then goes still.
The <pushBold/><a exist="12345678" noun="elemental">earth elemental</a><popBold/> topples to the ground motionless.
The <pushBold/><a exist="12345678" noun="bear">red bear</a><popBold/> collapses heavily into a heap on the ground and dies.
<pushBold/>A <a exist="12345678" noun="scorpion">giant albino scorpion</a><popBold/> falls to the ground with an echoing clatter, dead.
The <pushBold/><a exist="12345678" noun="krynch">krynch</a><popBold/> shudders, then topples to the ground.
<pushBold/>A <a exist="12345678" noun="scorpion">giant albino scorpion</a><popBold/> twitches a few times before finally dying.
The <pushBold/><a exist="12345678" noun="krynch">krynch</a><popBold/> shudders violently for a moment, then goes still.
<pushBold/>A <a exist="12345678" noun="wraith">troll wraith</a><popBold/> falls to the ground, lying completely motionless.  A last minute twitch causes the <pushBold/><a exist="12345678" noun="wraith">wraith's</a><popBold/> arm to spasm up into the air before falling limply back to <pushBold/><a exist="12345678" noun="wraith">his</a><popBold/> side.
<pushBold/>A <a exist="12345678" noun="wraith">troll wraith</a><popBold/> slumps to the ground, lying completely motionless.  A last minute twitch causes the <pushBold/><a exist="12345678" noun="wraith">wraith's</a><popBold/> arm to spasm up into the air before falling limply back to <pushBold/><a exist="12345678" noun="wraith">her</a><popBold/> side.
The <pushBold/><a exist="12345678" noun="bat">undertaker bat</a><popBold/> flaps its wings in a last ditch effort to ascend from the ground, but fails and finally lies still.
The <pushBold/><a exist="12345678" noun="zombie">troll zombie</a><popBold/> tears off a piece of <pushBold/><a exist="12345678" noun="zombie">her</a><popBold/> flesh, gnawing upon the decayed meat in a vain attempt to nourish <pushBold/><a exist="12345678" noun="zombie">her</a><popBold/> continued tormented existence.  With the attempt failing, the <pushBold/><a exist="12345678" noun="zombie">troll zombie</a><popBold/> topples to the ground motionless.
<pushBold/>A <a exist="12345678" noun="wraith">troll wraith</a><popBold/> slumps to the ground, lying completely motionless.  A last minute twitch causes the <pushBold/><a exist="12345678" noun="wraith">wraith's</a><popBold/> arm to spasm up into the air before falling limply back to <pushBold/><a exist="12345678" noun="wraith">his</a><popBold/> side.
The <pushBold/><a exist="12345678" noun="zombie">troll zombie</a><popBold/> tears off a piece of <pushBold/><a exist="12345678" noun="zombie">her</a><popBold/> flesh, gnawing upon the decayed meat in a vain attempt to nourish <pushBold/><a exist="12345678" noun="zombie">her</a><popBold/> continued tormented existence.  With the attempt failing, the <pushBold/><a exist="12345678" noun="zombie">troll zombie</a><popBold/> slumps to the ground motionless.
The <pushBold/><a exist="12345678" noun="zombie">troll zombie</a><popBold/> tears off a piece of <pushBold/><a exist="12345678" noun="zombie">his</a><popBold/> flesh, gnawing upon the decayed meat in a vain attempt to nourish <pushBold/><a exist="12345678" noun="zombie">his</a><popBold/> continued tormented existence.  With the attempt failing, the <pushBold/><a exist="12345678" noun="zombie">troll zombie</a><popBold/> topples to the ground motionless.
The <pushBold/><a exist="12345678" noun="lizard">cave lizard</a><popBold/> drops to the ground and shudders a final time.
<pushBold/>A <a exist="12345678" noun="veaba">giant veaba</a><popBold/> dies in a squirming, quivering heap.
<pushBold/>A <a exist="12345678" noun="veaba">giant veaba</a><popBold/> shudders violently as it dies.
All that remains of the <pushBold/><a exist="12345678" noun="krynch">krynch</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
The glimmer of a <a exist="12345678" noun="stone">turquoise stone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="rat">giant rat</a><popBold/> collapses to the ground, emits a final squeal, and dies.
The <pushBold/><a exist="12345678" noun="rat">giant rat</a><popBold/> twitches and dies.
The <pushBold/><a exist="12345678" noun="shade">lesser shade</a><popBold/> falls to the ground motionless.
All that remains of the <pushBold/><a exist="12345678" noun="scorpion">scorpion</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
The <pushBold/><a exist="12345678" noun="ant">giant ant</a><popBold/> falls to the ground and dies, its feelers twitching.
The <pushBold/><a exist="12345678" noun="ant">giant ant</a><popBold/> feebly twitches a feeler one last time and dies.
The <pushBold/><a exist="12345678" noun="relnak">relnak</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="relnak">relnak</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="vysan">dark vysan</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="vysan">dark vysan</a><popBold/> screams evilly one last time and goes still.
<pushBold/>A <a exist="12345678" noun="orc">lesser red orc</a><popBold/> collapses in a red mess and dies.
The <pushBold/><a exist="12345678" noun="ghost">ghost</a><popBold/> slowly settles to the ground and begins to dissipate.
The <pushBold/><a exist="12345678" noun="nymph">sea nymph</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="leaper">leaper</a><popBold/> twitches and dies.
The <pushBold/><a exist="12345678" noun="leaper">leaper</a><popBold/> collapses to the ground, emits a final snarl, and dies.
The <pushBold/><a exist="12345678" noun="soldier">shelfae soldier</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="soldier">shelfae soldier</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="gargoyle">stone gargoyle</a><popBold/> rears its head, screaming, trying desperately to stand and then it collapses.  With a final labored breath it stops moving.
The <pushBold/><a exist="12345678" noun="boulder">large boulder</a><popBold/> shudders, then topples to the ground.
<pushBold/>The <a exist="12345678" noun="golem">golem</a><popBold/> stops moving.
<pushBold/>The <a exist="12345678" noun="golem">golem</a><popBold/> falls to the ground and stops moving.
The <pushBold/><a exist="12345678" noun="sentinel">stone sentinel</a><popBold/> totters for a moment and then falls to the ground like a pillar, breaking into pieces that fly out in every direction.
The <pushBold/><a exist="12345678" noun="banshee">banshee</a><popBold/> slumps to the floor, exhales a sigh of relief, and begins to quickly decay away.
The <pushBold/><a exist="12345678" noun="sentinel">stone sentinel</a><popBold/> shudders violently, all its joints growing loose and useless.  In moments it stops moving altogether.
The <pushBold/><a exist="12345678" noun="harbinger">Sheruvian harbinger</a><popBold/> collapses on the ground and lies still.
The <pushBold/><a exist="12345678" noun="king">troll king</a><popBold/> lies still.
The <pushBold/><a exist="12345678" noun="king">troll king</a><popBold/> falls to the ground dead.
The <pushBold/><a exist="12345678" noun="steed">nightmare steed</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="steed">nightmare steed</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="harbinger">Sheruvian harbinger</a><popBold/> releases a horrible wail then lies still.
The <pushBold/><a exist="12345678" noun="figure">hooded figure</a><popBold/> screams one last time and lies still.
The <pushBold/><a exist="12345678" noun="figure">hooded figure</a><popBold/> falls to the ground and lies still.
The <pushBold/><a exist="12345678" noun="initiate">Sheruvian initiate</a><popBold/> screams emotionlessly one last time and lies still.
The <pushBold/><a exist="12345678" noun="initiate">Sheruvian initiate</a><popBold/> falls to the ground and lies still.
The <pushBold/><a exist="12345678" noun="assistant">cook's assistant</a><popBold/> screams one last time and lies still.
The <pushBold/><a exist="12345678" noun="monk">Sheruvian monk</a><popBold/> falls to the ground and lies still.
The <pushBold/><a exist="12345678" noun="monk">Sheruvian monk</a><popBold/> screams emotionlessly one last time and lies still.
The <pushBold/><a exist="12345678" noun="myklian">red myklian</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="myklian">young myklian</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="magru">magru</a><popBold/> collapses into a heap of quivering jelly.
The <pushBold/><a exist="12345678" noun="tiger">sabre-tooth tiger</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="tiger">sabre-tooth tiger</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="seeker">seeker</a><popBold/> mutters, "...the Eye, the Eye..." and lies still.
The <pushBold/><a exist="12345678" noun="golem">ice golem</a><popBold/> writhes in cold agony and dies.
The <pushBold/><a exist="12345678" noun="seeker">seeker</a><popBold/> screams, "Nooooo!" as <pushBold/><a exist="12345678" noun="seeker">he</a><popBold/> clatters to the ground into a lump of ancient bones and rotting robes.
The <pushBold/><a exist="12345678" noun="seeker">seeker</a><popBold/> screams, "Nooooo!" as <pushBold/><a exist="12345678" noun="seeker">she</a><popBold/> clatters to the ground into a lump of ancient bones and rotting robes.
The deep blue glow emanating from the <pushBold/><a exist="12345678" noun="elemental">ice elemental</a><popBold/> goes dark suddenly.
The <pushBold/><a exist="12345678" noun="golem">ice golem</a><popBold/> tumbles to the ground motionless.
The <pushBold/><a exist="12345678" noun="bear">polar bear</a><popBold/> lets out a blood-curdling roar and dies.
The <pushBold/><a exist="12345678" noun="wraith">ice wraith</a><popBold/> slumps silently to the ground and begins to rapidly dissipate.
The <pushBold/><a exist="12345678" noun="corpse">frozen corpse</a><popBold/> wails in terrifying pain one last time and lies still.
The deep blue glow emanating from the <pushBold/><a exist="12345678" noun="glacei">major glacei</a><popBold/> goes dark suddenly.
The <pushBold/><a exist="12345678" noun="leopard">snow leopard</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="corpse">frozen corpse</a><popBold/> falls to the ground, rotting flesh falling from <pushBold/><a exist="12345678" noun="corpse">her</a><popBold/> bones.
The <pushBold/><a exist="12345678" noun="crone">snow crone</a><popBold/> cries out in cold agony one last time and dies.
The <pushBold/><a exist="12345678" noun="giant">ice giant</a><popBold/> cries out in cold agony one last time and dies.
The <pushBold/><a exist="12345678" noun="giant">ice giant</a><popBold/> falls to the ground motionless.
<pushBold/>A <a exist="12345678" noun="orc">silverback orc</a><popBold/> curls up in the snow and dies.
All that remains of the <pushBold/><a exist="12345678" noun="janissary">janissary</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="scout">himself</a><popBold/>, then collapses with a wheeze.
The glimmer of a <a exist="12345678" noun="starstone">white starstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="herald">he</a><popBold/> collapses.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="janissary">she</a><popBold/> falls, "Letta, Leth, Latoth..."
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="initiate">her</a><popBold/> pupil-less green eyes frozen in a dead stare.
All that remains of the <pushBold/><a exist="12345678" noun="initiate">initiate</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="qyn'arj">lich qyn'arj</a><popBold/> spasms violently and suddenly goes still, its body turning to stone.
The glimmer of an <a exist="12345678" noun="emerald">uncut emerald</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The glimmer of a <a exist="12345678" noun="moonstone">blue moonstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> screams as <pushBold/><a exist="12345678" noun="initiate">she</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> falls to the ground dead, his skin still pulsating with a blinding white hue.
All that remains of the <pushBold/><a exist="12345678" noun="hound">hound</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> slumps over dead, his skin still pulsating with a blinding white hue.
The glimmer of a <a exist="12345678" noun="tourmaline">blue tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="initiate">herself</a><popBold/>, then collapses with a wheeze.
The <pushBold/><a exist="12345678" noun="griffin">war griffin</a><popBold/> falls to the ground dead, its skin still pulsating with a blinding white hue.
The glimmer of a <a exist="12345678" noun="garnet">green garnet</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="dreamstone">white dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="janissary">himself</a><popBold/>, then collapses with a wheeze.
The glimmer of a <a exist="12345678" noun="opal">black opal</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The glimmer of a <a exist="12345678" noun="emerald">star emerald</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> slumps over dead, her skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="pillager">giantman pillager</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="scout">human scout</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="pirate">giantman pirate</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="raider">giantman raider</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="waylayer">human waylayer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="scout">giantman scout</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pillager">half-elven pillager</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="scout">half-elven scout</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="brigand">halfling brigand</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="scout">halfling scout</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="waylayer">half-elven waylayer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="pirate">gnomish pirate</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="pirate">halfling pirate</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pillager">half-elven pillager</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pillager">giantman pillager</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="raider">human raider</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="Captain">Pirate Captain</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="shaman">krolvin shaman</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="sniper">krolvin sniper</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="wayfarer">krolvin wayfarer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="wayfarer">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> hits the ground with a less than elegant thud.
All that remains of the <pushBold/><a exist="12345678" noun="sniper">sniper</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="shaman">burly krolvin shaman's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="shaman">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="wayfarer">krolvin wayfarer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="wayfarer">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> collapses to the ground, dead as a pickled herring.
The <pushBold/><a exist="12345678" noun="warmonger">burly krolvin warmonger</a><popBold/> crashes to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="wayfarer">krolvin wayfarer</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="scourge">burly krolvin scourge</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="slayer">krolvin slayer</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="scout">krolvin scout</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="vanquisher">krolvin vanquisher</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="sniper">krolvin sniper's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="sniper">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="slayer">krolvin slayer</a><popBold/> rolls over on the ground and goes still.
All that remains of the <pushBold/><a exist="12345678" noun="warmonger">warmonger</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="slayer">burly krolvin slayer</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="vanquisher">krolvin vanquisher</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="Captain">Krolvin Captain's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="Captain">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="vanquisher">burly krolvin vanquisher</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="wayfarer">krolvin wayfarer</a><popBold/> hits the ground with a less than elegant thud.
The <pushBold/><a exist="12345678" noun="sniper">krolvin sniper's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="sniper">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="slayer">burly krolvin slayer</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="dissembler">krolvin dissembler</a><popBold/> crashes to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="dissembler">krolvin dissembler</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="sniper">krolvin sniper</a><popBold/> crashes to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="sniper">krolvin sniper</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="dissembler">krolvin dissembler's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="dissembler">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="dissembler">krolvin dissembler's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="dissembler">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="warmonger">burly krolvin warmonger</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="shaman">krolvin shaman</a><popBold/> crashes to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="warmonger">burly krolvin warmonger</a><popBold/> collapses to the ground, dead as a pickled herring.
The <pushBold/><a exist="12345678" noun="conjurer">krolvin conjurer</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="wayfarer">burly krolvin wayfarer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="wayfarer">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="dissembler">krolvin dissembler</a><popBold/> flattens out on the ground, dead as a salted flounder.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> spins to the ground, dead as an iced halibut.
The <pushBold/><a exist="12345678" noun="sniper">krolvin sniper</a><popBold/> spins to the ground, dead as an iced halibut.
The <pushBold/><a exist="12345678" noun="dissembler">krolvin dissembler</a><popBold/> falls lifeless to the ground with a heavy thump.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> slams to the ground, dead as a salmon bear snack.
The <pushBold/><a exist="12345678" noun="scout">krolvin scout</a><popBold/> flattens out on the ground, dead as a salted flounder.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> crashes to the ground, dead as a carp on a rock.
The <pushBold/><a exist="12345678" noun="slayer">krolvin slayer</a><popBold/> crashes to the ground, dead as a carp on a rock.
The <pushBold/><a exist="12345678" noun="shaman">krolvin shaman</a><popBold/> spins to the ground, dead as an iced halibut.
The <pushBold/><a exist="12345678" noun="warmonger">burly krolvin warmonger</a><popBold/> thuds to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="sniper">burly krolvin sniper</a><popBold/> flattens out on the ground, dead as a salted flounder.
The <pushBold/><a exist="12345678" noun="slayer">krolvin slayer</a><popBold/> spins to the ground, dead as an iced halibut.
The <pushBold/><a exist="12345678" noun="slayer">krolvin slayer</a><popBold/> flattens out on the ground, dead as a salted flounder.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> thuds to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="warmonger">burly krolvin warmonger</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="sniper">krolvin sniper</a><popBold/> collapses to the ground, dead as a pickled herring.
The <pushBold/><a exist="12345678" noun="huntmistress">burly krolvin huntmistress</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="shaman">krolvin shaman</a><popBold/> hits the ground with a less than elegant thud.
The <pushBold/><a exist="12345678" noun="warmonger">burly krolvin warmonger's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="warmonger">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="slayer">burly krolvin slayer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="slayer">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="shaman">krolvin shaman</a><popBold/> tries to crawl away on the ground but collapses and goes still.
All that remains of the <pushBold/><a exist="12345678" noun="conjurer">conjurer</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="sniper">krolvin sniper</a><popBold/> thuds to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="sniper">krolvin sniper</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="slayer">krolvin slayer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="slayer">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="warmonger">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="dissembler">krolvin dissembler</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="dissembler">krolvin dissembler</a><popBold/> hits the ground with a less than elegant thud.
The <pushBold/><a exist="12345678" noun="warmonger">burly krolvin warmonger</a><popBold/> hits the ground with a less than elegant thud.
The <pushBold/><a exist="12345678" noun="dissembler">burly krolvin dissembler</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="scourge">krolvin scourge</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="scout">krolvin scout</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="Captain">Krolvin Captain</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="scout">human scout</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pillager">halfling pillager</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="waylayer">human waylayer</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="brigand">half-elven brigand</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="pirate">elven pirate</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="waylayer">half-elven waylayer</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pillager">human pillager</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="raider">elven raider</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="waylayer">elven waylayer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="brigand">human brigand</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="pirate">half-elven pirate</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="pirate">gnomish pirate</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="raider">human raider</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="waylayer">giantman waylayer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="brigand">giantman brigand</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="waylayer">halfling waylayer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="raider">half-elven raider</a><popBold/> falls to the ground and dies.
The glimmer of a <a exist="12345678" noun="deathstone">black deathstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="templar">hulking krolvin templar</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="warlord">hulking krolvin warlord</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="warlord">hulking krolvin warlord's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="warlord">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="warden">hulking krolvin warden</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="slayer">burly krolvin slayer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="slayer">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="warlord">krolvin warlord's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="warlord">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="warlord">krolvin warlord</a><popBold/> spins to the ground, dead as an iced halibut.
The <pushBold/><a exist="12345678" noun="templar">hulking krolvin templar's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="templar">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="warden">krolvin warden's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="warden">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="slayer">burly krolvin slayer</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="archmage">krolvin archmage</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="warden">krolvin warden</a><popBold/> crashes to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="warlord">krolvin warlord</a><popBold/> crashes to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="huntmistress">krolvin huntmistress</a><popBold/> hits the ground with a less than elegant thud.
The <pushBold/><a exist="12345678" noun="templar">hulking krolvin templar</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="destroyer">krolvin destroyer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="destroyer">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="obliterator">krolvin obliterator</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="huntmistress">hulking krolvin huntmistress</a><popBold/> thuds to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="warlord">krolvin warlord</a><popBold/> thuds to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> crashes to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="vanquisher">burly krolvin vanquisher</a><popBold/> thuds to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="Captain">Krolvin Captain's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="Captain">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="pillager">ethereal pillager</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="waylayer">unworldly waylayer</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="brigand">ethereal brigand</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="Captain">Ethereal Captain</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="scout">unworldly scout</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="scout">ethereal scout</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="pirate">unworldly pirate</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="pirate">ethereal pirate</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="waylayer">ethereal waylayer</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="pillager">unworldly pillager</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="pillager">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="raider">ethereal raider</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="scout">ethereal scout</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="scout">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="waylayer">ethereal waylayer</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="waylayer">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="waylayer">unworldly waylayer</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="waylayer">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="pillager">ethereal pillager</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="pillager">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="waylayer">ethereal waylayer's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The glimmer of a <a exist="12345678" noun="dreamstone">yellow dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="tourmaline">green tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="spinel">blue spinel</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="opal">black opal</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="zircon">green zircon</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="topaz">pink topaz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="tourmaline">green tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="opal">white opal</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The glimmer of an <a exist="12345678" noun="gem">aquamarine gem</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="waylayer">giantman waylayer</a><popBold/> falls to the ground and dies.
All that remains of the <pushBold/><a exist="12345678" noun="raider">raider</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="pirate">human pirate</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="raider">half-elven raider</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="brigand">human brigand</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pirate">halfling pirate</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="brigand">half-elven brigand</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="waylayer">half-krolvin waylayer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="scout">half-elven scout</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pirate">human pirate</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pirate">half-elven pirate</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pirate">giantman pirate</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="brigand">giantman brigand</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="brigand">gnomish brigand</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="pillager">human pillager</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="raider">gnomish raider</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="pillager">dwarven pillager</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="assassin">triton assassin</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="assassin">her</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="warlock">triton warlock</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="warlock">her</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="brawler">triton brawler</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="brawler">her</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="assassin">triton assassin</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="assassin">his</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="warlock">triton warlock</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="warlock">her</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="assassin">triton assassin</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="assassin">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="brawler">triton brawler</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="brawler">his</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="crab">coconut crab</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="rat">wharf rat</a><popBold/> collapses to the ground, emits a final squeal, and dies.
The <pushBold/><a exist="12345678" noun="crab">coconut crab</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="assassin">triton assassin</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="assassin">her</a><popBold/> face before expiring.
All that remains of the <pushBold/><a exist="12345678" noun="protector">protector</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="warden">triton warden</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="warden">his</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="fanatic">triton fanatic</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="fanatic">his</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="fanatic">triton fanatic</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="fanatic">her</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="fanatic">triton fanatic</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="fanatic">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="fanatic">triton fanatic</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="fanatic">her</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="psionicist">triton psionicist's</a><popBold/> face begins to hideously contort as ribbons of essence begin to wend away from <pushBold/><a exist="12345678" noun="psionicist">her</a><popBold/> and into nothingness!
The <pushBold/><a exist="12345678" noun="warden">triton warden</a><popBold/> gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" noun="warden">her</a><popBold/> face.
The <pushBold/><a exist="12345678" noun="warden">triton warden</a><popBold/> collapses, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="warden">his</a><popBold/> face before expiring.
All that remains of the <pushBold/><a exist="12345678" noun="warlock">warlock</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="assailant">shelfae assailant</a><popBold/> falls to the ground and dies.
All that remains of the <pushBold/><a exist="12345678" noun="assailant">assailant</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="assailant">shelfae assailant</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="canine">crazed canine</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="guard">shelfae guard</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="canine">crazed canine</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="monkey">monkey</a><popBold/> screeches one last time and dies.
The <pushBold/><a exist="12345678" noun="elk">imposing elk</a><popBold/> collapses to the ground, emits a final sigh, and dies.
The <pushBold/><a exist="12345678" noun="brindlecat">muscular brindlecat's</a><popBold/> tail twitches feebly as <pushBold/><a exist="12345678" noun="brindlecat">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="bear">spectacled bear</a><popBold/> lets out a blood-curdling roar and dies.
The <pushBold/><a exist="12345678" noun="elk">imposing elk</a><popBold/> lets out a final agonized sigh and dies.
The <pushBold/><a exist="12345678" noun="hog">muddy hog</a><popBold/> lets out a final agonized squeal and dies.
The <pushBold/><a exist="12345678" noun="bear">spectacled bear</a><popBold/> collapses heavily into a heap on the ground and dies.
The <pushBold/><a exist="12345678" noun="brindlecat">muscular brindlecat's</a><popBold/> tail twitches feebly as <pushBold/><a exist="12345678" noun="brindlecat">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="swine">ebon swine</a><popBold/> lets out a final agonized squeal and dies.
Spines litter the ground as the <pushBold/><a exist="12345678" noun="urchin">cavern urchin</a><popBold/> crumbles into a pile of splinters and skin.
The <pushBold/><a exist="12345678" noun="sentry">ogre sentry</a><popBold/> falls to the floor and dies.
The <pushBold/><a exist="12345678" noun="sentry">ogre sentry</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="triggerman">krolvin triggerman</a><popBold/> spins to the ground, dead as an iced halibut.
The <pushBold/><a exist="12345678" noun="destroyer">krolvin destroyer</a><popBold/> hits the ground with a less than elegant thud.
The <pushBold/><a exist="12345678" noun="triggerman">krolvin triggerman's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="triggerman">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="destroyer">hulking krolvin destroyer</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="warlord">krolvin warlord</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="templar">krolvin templar</a><popBold/> flattens out on the ground, dead as a salted flounder.
The <pushBold/><a exist="12345678" noun="scout">burly krolvin scout</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="paragon">krolvin paragon</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="tormentor">krolvin tormentor</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="triggerman">hulking krolvin triggerman's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="triggerman">he</a><popBold/> dies.
All that remains of the <pushBold/><a exist="12345678" noun="slayer">slayer</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="shaman">burly krolvin shaman</a><popBold/> crashes to the ground, dead as a carp on a rock.
The <pushBold/><a exist="12345678" noun="destroyer">krolvin destroyer</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="conjurer">krolvin conjurer</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="paragon">hulking krolvin paragon</a><popBold/> thuds to the ground in a plume of dust.
The <pushBold/><a exist="12345678" noun="warlord">krolvin warlord</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="warlord">hulking krolvin warlord</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="sniper">burly krolvin sniper's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="sniper">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="huntmaster">krolvin huntmaster</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="warmonger">burly krolvin warmonger</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="warlord">krolvin warlord</a><popBold/> hits the ground with a less than elegant thud.
The <pushBold/><a exist="12345678" noun="scout">dwarven scout</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pillager">erithian pillager</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="scout">elven scout</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="scout">halfling scout</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pirate">elven pirate</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="waylayer">halfling waylayer</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="brigand">half-krolvin brigand</a><popBold/> rolls over and dies.
All that remains of the <pushBold/><a exist="12345678" noun="pillager">pillager</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="pillager">halfling pillager</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pillager">elven pillager</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="scout">giantman scout</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="brigand">half-krolvin brigand</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="warden">krolvin warden</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="obliterator">krolvin obliterator</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="destroyer">krolvin destroyer</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="tormentor">hulking krolvin tormentor</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="sniper">burly krolvin sniper's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="sniper">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="conjurer">burly krolvin conjurer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="conjurer">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="obliterator">krolvin obliterator</a><popBold/> slams to the ground, dead as a salmon bear snack.
The <pushBold/><a exist="12345678" noun="scout">krolvin scout's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="scout">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="paragon">krolvin paragon</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="wayfarer">burly krolvin wayfarer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="wayfarer">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="destroyer">hulking krolvin destroyer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="destroyer">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="triggerman">krolvin triggerman</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="scourge">burly krolvin scourge</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="archmage">krolvin archmage</a><popBold/> hits the ground with a less than elegant thud.
The <pushBold/><a exist="12345678" noun="huntmaster">burly krolvin huntmaster</a><popBold/> tries to crawl away on the ground but collapses and goes still.
The <pushBold/><a exist="12345678" noun="destroyer">hulking krolvin destroyer</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="warmonger">krolvin warmonger</a><popBold/> flattens out on the ground, dead as a salted flounder.
The <pushBold/><a exist="12345678" noun="destroyer">krolvin destroyer's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="destroyer">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="warlord">krolvin warlord's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="warlord">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="triggerman">hulking krolvin triggerman</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="warmonger">burly krolvin warmonger's</a><popBold/> body goes stiff and cold as <pushBold/><a exist="12345678" noun="warmonger">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> falls to the ground dead, his skin still pulsating with a blinding white hue.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="commoner">ethereal commoner's</a><popBold/> body and rises into the heavens.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="traveller">ethereal traveller's</a><popBold/> body and rises into the heavens.
The <pushBold/><a exist="12345678" noun="traveller">ethereal traveller</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="traveller">she</a><popBold/> flickers in and out of existence.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="villager">ethereal villager's</a><popBold/> body and rises into the heavens.
The <pushBold/><a exist="12345678" noun="villager">ethereal villager</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="villager">her</a><popBold/> body.
You hear a sound like a child weeping as a white glow separates itself from the <pushBold/><a exist="12345678" noun="peasant">ethereal peasant's</a><popBold/> body and rises into the heavens.
The <pushBold/><a exist="12345678" noun="villager">ethereal villager</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="villager">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="townswoman">ethereal townswoman</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="townswoman">she</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="denizen">ethereal denizen</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="denizen">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="Bartender">Bartender</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="Bartender">it</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="commoner">ethereal commoner</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="commoner">he</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="villager">ethereal villager's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="commoner">ethereal commoner</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="commoner">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="peasant">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="villager">ethereal villager</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="bandit">ghostly bandit</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="bandit">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="bandit">ghostly bandit</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="bandit">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="guardswoman">ethereal guardswoman</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="guardswoman">her</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="guardswoman">ethereal guardswoman</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="guardswoman">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="swordswoman">ethereal swordswoman</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="Captain">Guard Captain</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="Captain">its</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="guard">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="commoner">ethereal commoner's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="swordswoman">ethereal swordswoman</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="bandit">ghostly bandit</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="swordswoman">ethereal swordswoman</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="guard">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="bandit">ghostly bandit</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="bandit">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="highwayman">ghostly highwayman</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="highwayman">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="waylayer">ghostly waylayer</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="squire">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="knight">ethereal knight</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="knight">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="squire">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="guard">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="Sergeant">Drill Sergeant</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="knight">ethereal knight</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="squire">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="slave">unworldly slave</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="waylayer">ghostly waylayer's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="guard">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> crashes to the ground in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> crashes to the ground in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="steward">unworldly steward</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="steward">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="maid">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid</a><popBold/> rolls over on the floor and goes still.
The <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> rolls over on the floor and goes still.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="slave">unworldly slave</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="slave">she</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="slave">unworldly slave</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="slave">her</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="steward">unworldly steward</a><popBold/> tries to crawl away on the floor but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> shudders before falling into a lifeless heap on the floor.
The <pushBold/><a exist="12345678" noun="noble">unworldly noble</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="noble">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="visitor">unworldly visitor</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="visitor">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="guest">unworldly guest</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="guest">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="guest">unworldly guest</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="guest">her</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="guest">unworldly guest</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="guest">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="visitor">unworldly visitor</a><popBold/> shudders before falling into a lifeless heap on the floor.
The <pushBold/><a exist="12345678" noun="guard">royal guard</a><popBold/> crashes to the floor in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="knight">royal knight</a><popBold/> shudders before falling into a lifeless heap on the floor.
The <pushBold/><a exist="12345678" noun="guard">royal guard's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="knight">royal knight</a><popBold/> tries to crawl away on the floor but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="guard">royal guard</a><popBold/> tries to crawl away on the floor but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="noble">unworldly noble</a><popBold/> tries to crawl away on the floor but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="noble">unworldly noble</a><popBold/> rolls over on the floor and goes still.
The <pushBold/><a exist="12345678" noun="visitor">unworldly visitor</a><popBold/> rolls over on the floor and goes still.
The <pushBold/><a exist="12345678" noun="knight">royal knight</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="knight">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="servant">him</a><popBold/> fades away.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="servant">she</a><popBold/> falls to the floor.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="guard">royal guard</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="guard">she</a><popBold/> falls to the floor.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="knight">royal knight</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="knight">she</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="knight">royal knight</a><popBold/> rolls over on the floor and goes still.
The <pushBold/><a exist="12345678" noun="knight">royal knight</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="knight">her</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="knight">royal knight</a><popBold/> collapses to the floor as <pushBold/><a exist="12345678" noun="knight">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> crashes to the floor in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="noble">unworldly noble</a><popBold/> shudders before falling into a lifeless heap on the floor.
The <pushBold/><a exist="12345678" noun="Jester">Royal Jester</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="Jester">it</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="guard">royal guard</a><popBold/> collapses to the floor as <pushBold/><a exist="12345678" noun="guard">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="naisirc">naisirc</a><popBold/> slumps silently to the floor and begins to rapidly dissipate.
The <pushBold/><a exist="12345678" noun="seraceris">seraceris</a><popBold/> slumps silently to the floor and begins to rapidly dissipate.
The <pushBold/><a exist="12345678" noun="seraceris">seraceris</a><popBold/> slumps silently to the ground and begins to rapidly dissipate.
The <pushBold/><a exist="12345678" noun="naisirc">naisirc</a><popBold/> slumps silently to the ground and begins to rapidly dissipate.
The <pushBold/><a exist="12345678" noun="n'ecare">n'ecare</a><popBold/> wails in terrifying pain one last time and lies still.
The <pushBold/><a exist="12345678" noun="n'ecare">n'ecare</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="vaespilon">vaespilon</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="vaespilon">vaespilon</a><popBold/> wails in terrifying pain one last time and lies still.
As the <pushBold/><a exist="12345678" noun="crawler">rift crawler</a><popBold/> dies, the beast's massive body curls in on itself, convulses once, and stills.
The <pushBold/><a exist="12345678" noun="soul">lost soul</a><popBold/> slumps silently to the floor, <pushBold/><a exist="12345678" noun="soul">his</a><popBold/> red eyes fading to grey.
The <pushBold/><a exist="12345678" noun="crusader">fallen crusader</a><popBold/> clutches at the air as <pushBold/><a exist="12345678" noun="crusader">her</a><popBold/> incorporeal form begins to dissipate.
An intangible ripple of pure energy courses through the air as <pushBold/>the <a exist="12345678" noun="cerebralite">cerebralite's</a><popBold/> pupils widen a final time, <pushBold/><a exist="12345678" noun="cerebralite">its</a><popBold/> eyes clouding over as <pushBold/><a exist="12345678" noun="cerebralite">it</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="crawler">rift crawler</a><popBold/> falls to the floor dead, its skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="crusader">fallen crusader</a><popBold/> clutches at the air as <pushBold/><a exist="12345678" noun="crusader">his</a><popBold/> incorporeal form begins to dissipate.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="commoner">ethereal commoner</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="traveller">ethereal traveller</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="traveller">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="traveller">ethereal traveller</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="traveller">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="peasant">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="villager">ethereal villager</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="villager">she</a><popBold/> flickers in and out of existence.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="townswoman">ethereal townswoman</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="townswoman">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="Shopkeeper">Shopkeeper</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="commoner">ethereal commoner</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="traveller">ethereal traveller</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="bandit">ghostly bandit</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="bandit">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="bandit">ghostly bandit</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="marauder">ghostly marauder</a><popBold/> crashes to the ground in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="bandit">ghostly bandit</a><popBold/> rolls over on the ground and goes still.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="squire">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="swordswoman">ethereal swordswoman</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="swordswoman">her</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="Captain">Guard Captain</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="Captain">he</a><popBold/> falls to the ground.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="swordsman">ethereal swordsman</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="swordsman">he</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="guard">he</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="marauder">ghostly marauder</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="waylayer">ghostly waylayer</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="waylayer">his</a><popBold/> body.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="bandit">ghostly bandit</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="bandit">he</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="guardswoman">ethereal guardswoman</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="marauder">ghostly marauder</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="marauder">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="waylayer">ghostly waylayer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="swordsman">ethereal swordsman</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="bandit">ghostly bandit</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="squire">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="knight">ethereal knight's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="prisoner">ethereal prisoner</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="prisoner">he</a><popBold/> falls to the floor.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="madman">ethereal madman</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="madman">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="prisoner">ethereal prisoner</a><popBold/> rolls over on the floor and goes still.
The <pushBold/><a exist="12345678" noun="knight">ethereal knight</a><popBold/> crashes to the ground in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> crashes to the ground in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="Sergeant">Drill Sergeant's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="guardsman">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="steward">unworldly steward</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="steward">her</a><popBold/> body.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="slave">unworldly slave</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="slave">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="servant">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="steward">unworldly steward</a><popBold/> collapses to the floor as <pushBold/><a exist="12345678" noun="steward">he</a><popBold/> flickers in and out of existence.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="maid">unworldly maid</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="maid">she</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid</a><popBold/> crashes to the floor in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="servant">unworldly servant's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="maid">her</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="slave">unworldly slave</a><popBold/> collapses to the floor as <pushBold/><a exist="12345678" noun="slave">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid</a><popBold/> shudders before falling into a lifeless heap on the floor.
The <pushBold/><a exist="12345678" noun="Butler">Butler</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="Butler">its</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="slave">unworldly slave</a><popBold/> crashes to the floor in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="slave">unworldly slave</a><popBold/> tries to crawl away on the floor but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid</a><popBold/> collapses to the floor as <pushBold/><a exist="12345678" noun="maid">she</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="maid">she</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="slave">unworldly slave</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="slave">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="guest">unworldly guest</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="guest">him</a><popBold/> fades away.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="noble">unworldly noble</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="noble">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="visitor">unworldly visitor</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="visitor">she</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="Dignitary">Foreign Dignitary</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="Dignitary">it</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="guard">royal guard</a><popBold/> rolls over on the floor and goes still.
The <pushBold/><a exist="12345678" noun="noble">unworldly noble</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="noble">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="knight">royal knight</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="knight">she</a><popBold/> falls to the floor.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="guard">royal guard</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="guard">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="Prince">Royal Prince</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="servant">her</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="Empress">Royal Empress's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="Emperor">Royal Emperor</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="Emperor">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="guardswoman">ethereal guardswoman</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="guardsman">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="highwayman">ghostly highwayman</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="highwayman">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="highwaywoman">ghostly highwaywoman</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="guard">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="squire">her</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="waylayer">ghostly waylayer</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="waylayer">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="guard">she</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="guard">royal guard</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="peasant">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="traveller">ethereal traveller</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="Bartender">Bartender's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="denizen">ethereal denizen</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="denizen">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="traveller">ethereal traveller's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="peasant">her</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="highwaywoman">ghostly highwaywoman</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="marauder">ghostly marauder</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="guard">he</a><popBold/> falls to the ground.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="guardswoman">ethereal guardswoman</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="guardswoman">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="swordsman">ethereal swordsman</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="swordsman">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="guardsman">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="marauder">ghostly marauder</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="marauder">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="waylayer">ghostly waylayer's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="highwaywoman">ghostly highwaywoman</a><popBold/> rolls over on the ground and goes still.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="marauder">ghostly marauder</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="marauder">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="swordswoman">ethereal swordswoman</a><popBold/> crashes to the ground in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="highwayman">ghostly highwayman</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="highwayman">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="highwayman">ghostly highwayman</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="highwaywoman">ghostly highwaywoman</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="highwaywoman">her</a><popBold/> fades away.
A nebulous haze shimmers into view around <pushBold/>an <a exist="12345678" noun="sentry">ethereal triton sentry</a><popBold/>, plunging inward in a dizzying spiral to envelop <pushBold/><a exist="12345678" noun="sentry">him</a><popBold/> completely!  Silhouetted within the shifting spiritual miasma, the <pushBold/><a exist="12345678" noun="sentry">sentry's</a><popBold/> form withers, wasting away to an attenuated mockery of <pushBold/><a exist="12345678" noun="sentry">himself</a><popBold/>.  Even this pale shadow disintegrates, dissolving on the air as the last cloudy tendrils vanish.
The glimmer of a <a exist="12345678" noun="stone">turquoise stone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="combatant">triton combatant</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
The glimmer of a <a exist="12345678" noun="pearl">medium pink pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="sunstone">yellow sunstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="spinel">pink spinel</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="sunstone">white sunstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="pearl">large white pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> collapses to the ground with a splash, gurgling once with a wrathful look on <pushBold/><a exist="12345678" noun="dissembler">his</a><popBold/> face before expiring.
The <pushBold/><a exist="12345678" noun="waylayer">dwarven waylayer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="waylayer">gnomish waylayer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="scout">elven scout</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="brigand">elven brigand</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="brigand">halfling brigand</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="pirate">ethereal pirate's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="pillager">unworldly pillager</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="raider">ethereal raider</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="pirate">unworldly pirate's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="waylayer">ethereal waylayer's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="pirate">unworldly pirate</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="raider">unworldly raider</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="scout">ethereal scout</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="Captain">Ethereal Captain</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="scout">he</a><popBold/> collapses.
The <pushBold/><a exist="12345678" noun="chieftain">troll chieftain</a><popBold/> snarls <pushBold/><a exist="12345678" noun="chieftain">his</a><popBold/> defiance one last time before going still.
As the fire leaves <pushBold/><a exist="12345678" noun="ogre">her</a><popBold/> eyes, the <pushBold/><a exist="12345678" noun="ogre">fire ogre</a><popBold/> cries out in pain one last time and expires.
As the fire leaves <pushBold/><a exist="12345678" noun="ogre">his</a><popBold/> eyes, the <pushBold/><a exist="12345678" noun="ogre">fire ogre</a><popBold/> cries out in pain one last time and expires.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> screams as <pushBold/><a exist="12345678" noun="initiate">he</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="herald">she</a><popBold/> falls, "Letta, Leth, Latoth..."
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> screams as <pushBold/><a exist="12345678" noun="herald">he</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="janissary">his</a><popBold/> lips as <pushBold/><a exist="12345678" noun="janissary">he</a><popBold/> falls.
The glimmer of a <a exist="12345678" noun="sapphire">pink sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
<pushBold/>A <a exist="12345678" noun="construct">greater construct</a><popBold/> falls to the ground!
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="scout">her</a><popBold/> face as <pushBold/><a exist="12345678" noun="scout">she</a><popBold/> falls.
The glimmer of a <a exist="12345678" noun="tourmaline">blue tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="moonstone">grey moonstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="moonstone">grey moonstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="topaz">smoky topaz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="herald">himself</a><popBold/>, then collapses with a wheeze.
The <pushBold/><a exist="12345678" noun="commoner">ethereal commoner's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="townsman">ethereal townsman</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="townsman">he</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="denizen">ethereal denizen</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="villager">ethereal villager's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="townsman">ethereal townsman</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="Leader">Patrol Leader</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="Leader">it</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="villager">ethereal villager</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="commoner">ethereal commoner</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="commoner">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="traveller">ethereal traveller</a><popBold/> falls to the ground motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="traveller">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="townsman">ethereal townsman</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="highwaywoman">ghostly highwaywoman</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="highwaywoman">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="waylayer">ghostly waylayer</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="waylayer">he</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="Captain">Guard Captain</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="knight">ethereal knight</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="knight">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="guard">ethereal guard</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="guard">his</a><popBold/> body.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="knight">ethereal knight</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="knight">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> shudders before falling into a lifeless heap on the floor.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> rolls over on the floor and goes still.
The <pushBold/><a exist="12345678" noun="guardswoman">ethereal guardswoman</a><popBold/> collapses to the floor as <pushBold/><a exist="12345678" noun="guardswoman">she</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="guardsman">he</a><popBold/> falls to the floor.
A monstrous, too-wide smile spreads across <pushBold/>the <a exist="12345678" noun="cannibal">cannibal's</a><popBold/> face as <pushBold/><a exist="12345678" noun="cannibal">he</a><popBold/> collapses to the ground, dead.
With a final discordant squeal, <pushBold/>an <a exist="12345678" noun="hinterboar">immense gold-bristled hinterboar's</a><popBold/> great head sinks to the ground as <pushBold/><a exist="12345678" noun="hinterboar">its</a><popBold/> form goes still.
A rush of silent thunder explodes outward from <pushBold/>the <a exist="12345678" noun="golem">golem</a><popBold/> as the power animating <pushBold/><a exist="12345678" noun="golem">it</a><popBold/> disperses.
<pushBold/>A <a exist="12345678" noun="bloodspeaker">stunted halfling bloodspeaker's</a><popBold/> eyes bulge as <pushBold/><a exist="12345678" noun="bloodspeaker">she</a><popBold/> stares toward the heavens, mouthing a gurgling prayer as <pushBold/><a exist="12345678" noun="bloodspeaker">she</a><popBold/> succumbs to death.
<pushBold/>A <a exist="12345678" noun="warg">niveous giant warg</a><popBold/> rolls over onto <pushBold/><a exist="12345678" noun="warg">its</a><popBold/> side with a whimper before surrendering to death.
Rage flickers in <pushBold/>the <a exist="12345678" noun="wendigo">wendigo's</a><popBold/> eyes as <pushBold/><a exist="12345678" noun="wendigo">it</a><popBold/> collapses, bloody maw still working hungrily until the last hint of life goes out of <pushBold/><a exist="12345678" noun="wendigo">its</a><popBold/> form.
As <pushBold/>a <a exist="12345678" noun="mastodon">heavily armored battle mastodon</a><popBold/> collapses, <pushBold/><a exist="12345678" noun="mastodon">it</a><popBold/> lets out a shrill trumpet of despair.  <pushBold/><a exist="12345678" noun="mastodon">Its</a><popBold/> trunk flails futilely before slamming to the ground, still.
<pushBold/>A <a exist="12345678" noun="berserker">tattooed gigas berserker's</a><popBold/> fists tense with impotent rage as <pushBold/><a exist="12345678" noun="berserker">she</a><popBold/> surrenders to death.
<pushBold/>A <a exist="12345678" noun="skald">grim gigas skald</a><popBold/> raises a hand as if to grasp for support as <pushBold/><a exist="12345678" noun="skald">she</a><popBold/> collapses, life going out of <pushBold/><a exist="12345678" noun="skald">her</a><popBold/> form.
Light goes out of <pushBold/>a <a exist="12345678" noun="grotesque">horned basalt grotesque's</a><popBold/> eyes and animation departs <pushBold/><a exist="12345678" noun="grotesque">its</a><popBold/> form in a swift jerk that travels through <pushBold/><a exist="12345678" noun="grotesque">its</a><popBold/> stony limbs.  With a thud, <pushBold/><a exist="12345678" noun="grotesque">it</a><popBold/> collapses to the ground, looking for all the world like a lifeless statue.
<pushBold/>A <a exist="12345678" noun="banshee">flickering mist-wreathed banshee's</a><popBold/> features twist, caught in grief and agony as <pushBold/><a exist="12345678" noun="banshee">she</a><popBold/> sinks to the ground.  Slowly, <pushBold/><a exist="12345678" noun="banshee">her</a><popBold/> form and garments leak into gauzy mist as <pushBold/><a exist="12345678" noun="banshee">her</a><popBold/> shape begins to lose cohesion.
<pushBold/><a exist="12345678" noun="knight">He</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="knight">his</a><popBold/> armored chest.  <pushBold/><a exist="12345678" noun="knight">His</a><popBold/> flaming eyes blaze precipitously as white-hot fire erupts from <pushBold/><a exist="12345678" noun="knight">his</a><popBold/> floating head, consuming it in a burst of blinding light!  The headless corpse sinks to the ground, unmoving.
<pushBold/>A <a exist="12345678" noun="ghast">cadaverous tatterdemalion ghast</a><popBold/> lets out a hoarse cry that devolves into dry, rasping coughs.  Spasms race through <pushBold/><a exist="12345678" noun="ghast">his</a><popBold/> form, dead muscles seizing and clenching before at last going still.
<pushBold/>A <a exist="12345678" noun="ghast">cadaverous tatterdemalion ghast</a><popBold/> lets out a hoarse cry that devolves into dry, rasping coughs.  Spasms race through <pushBold/><a exist="12345678" noun="ghast">her</a><popBold/> form, dead muscles seizing and clenching before at last going still.
<pushBold/>A <a exist="12345678" noun="dreadsteed">smouldering skeletal dreadsteed's</a><popBold/> head tosses and <pushBold/><a exist="12345678" noun="dreadsteed">it</a><popBold/> lets out a terrible death whinny that slices coldly through the air.  <pushBold/><a exist="12345678" noun="dreadsteed">It</a><popBold/> sags, lifeless, the blue flames of <pushBold/><a exist="12345678" noun="dreadsteed">its</a><popBold/> mane winking out one by one.
<pushBold/><a exist="12345678" noun="knight">She</a><popBold/> clutches at <pushBold/><a exist="12345678" noun="knight">her</a><popBold/> armored chest.  <pushBold/><a exist="12345678" noun="knight">Her</a><popBold/> flaming eyes blaze precipitously as white-hot fire erupts from <pushBold/><a exist="12345678" noun="knight">her</a><popBold/> floating head, consuming it in a burst of blinding light!  The headless corpse sinks to the ground, unmoving.
<pushBold/>An <a exist="12345678" noun="vampire">ashen patrician vampire's</a><popBold/> lightless eyes go wide.  A shriek of rage and horror builds in <pushBold/><a exist="12345678" noun="vampire">her</a><popBold/> throat but never escapes.  <pushBold/><a exist="12345678" noun="vampire">She</a><popBold/> collapses, lifeless as a puppet with its strings cut, as the vestiges of otherworldly beauty retreat to reveal a corpse rapidly succumbing to decay.
<pushBold/>A <a exist="12345678" noun="conjurer">gaudy phantasmic conjurer</a><popBold/> staggers dramatically, a phantasmal hand trailing wisps of fog as it rises to <pushBold/><a exist="12345678" noun="conjurer">his</a><popBold/> chest.  With a last, surprised blink, <pushBold/><a exist="12345678" noun="conjurer">he</a><popBold/> collapses and rapidly begins losing cohesion.
The <pushBold/><a exist="12345678" noun="siphon">soul siphon</a><popBold/> twitches and writhes spasmodically before collapsing to the ground.
The <pushBold/><a exist="12345678" noun="siphon">soul siphon</a><popBold/> twitches and writhes spasmodically before collapsing to the floor.
The <pushBold/><a exist="12345678" noun="destroyer">Vvrael destroyer</a><popBold/> crumples to the floor motionless.
The <pushBold/><a exist="12345678" noun="destroyer">Vvrael destroyer</a><popBold/> writhes in black agony and dies.
As <pushBold/>a <a exist="12345678" noun="master">darkly inked fetish master</a><popBold/> slumps to the floor, the darkly lined tattoos traversing <pushBold/><a exist="12345678" noun="master">its</a><popBold/> skin lose the luminescence that had seemed to radiate from them.
A sheen of ice forms a glossy rime over each of the <pushBold/><a exist="12345678" noun="lich">frostborne lich's</a><popBold/> eyes as <pushBold/><a exist="12345678" noun="lich">she</a><popBold/> grasps at the <a exist="12345678" noun="phylactery">gnarled bone phylactery</a> hanging around <pushBold/><a exist="12345678" noun="lich">her</a><popBold/> neck and collapses to the ground.
Cracks begin to snake across the <pushBold/><a exist="12345678" noun="construct">greater construct's</a><popBold/> skin as <pushBold/><a exist="12345678" noun="construct">its</a><popBold/> movement completely ceases.
A final bone-jarring rumble escapes from the <pushBold/><a exist="12345678" noun="construct">lesser construct</a><popBold/> as <pushBold/><a exist="12345678" noun="construct">its</a><popBold/> stone skin cracks open in a myriad of deep gashes.
Light goes out of <pushBold/>a <a exist="12345678" noun="stalker">sleek black kiramon stalker's</a><popBold/> eyes as <pushBold/><a exist="12345678" noun="stalker">it</a><popBold/> sinks to the ground and ceases to move.
With a thunderous crash, <pushBold/>a <a exist="12345678" noun="ravager">corpulent kresh ravager</a><popBold/> falls to the ground, tiny legs kicking at the air before going still.
Stitches pop horrendously all over the surface of <pushBold/>a <a exist="12345678" noun="monstrosity">patchwork flesh monstrosity's</a><popBold/> body as <pushBold/><a exist="12345678" noun="monstrosity">it</a><popBold/> collapses to the floor, vitrified organs leaking free with <pushBold/><a exist="12345678" noun="monstrosity">its</a><popBold/> surrender to death.
<pushBold/>A <a exist="12345678" noun="fanatic">deathsworn fanatic</a><popBold/> collapses to the floor in a susurrus of robes.
<pushBold/>A <a exist="12345678" noun="sentinel">lithe veiled sentinel</a><popBold/> lets out a ragged gasp before collapsing.
With a last inhuman twitch, <pushBold/>a <a exist="12345678" noun="lurk">shambling lurk</a><popBold/> falls down, decay rapidly eating away at <pushBold/><a exist="12345678" noun="lurk">its</a><popBold/> lifeless body.
The <pushBold/><a exist="12345678" noun="thug">elven thug</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="robber">human robber</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="thug">half-elven thug</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="janissary">his</a><popBold/> pupil-less green eyes frozen in a dead stare.
The glimmer of a <a exist="12345678" noun="sapphire">pink sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="initiate">his</a><popBold/> lips as <pushBold/><a exist="12345678" noun="initiate">he</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="herald">he</a><popBold/> falls, "Letta, Leth, Latoth..."
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> screams as <pushBold/><a exist="12345678" noun="janissary">she</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="herald">his</a><popBold/> lips as <pushBold/><a exist="12345678" noun="herald">he</a><popBold/> falls.
The glimmer of a <a exist="12345678" noun="zircon">green zircon</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="janissary">he</a><popBold/> falls, "Letta, Leth, Latoth..."
The glimmer of a <a exist="12345678" noun="sapphire">violet sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="denizen">ethereal denizen</a><popBold/> crashes to the ground in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="traveller">ethereal traveller</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="traveller">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> collapses to the ground as the light within <pushBold/><a exist="12345678" noun="peasant">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="Bartender">Bartender</a><popBold/> falls to the ground and dies.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="villager">ethereal villager</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="villager">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="denizen">ethereal denizen</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="townswoman">ethereal townswoman's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="peasant">he</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="denizen">ethereal denizen's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="peasant">ethereal peasant</a><popBold/> crashes to the ground in a plume of ethereal energy.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="waylayer">ghostly waylayer</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="waylayer">she</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="Captain">Guard Captain</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="swordsman">ethereal swordsman's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="swordsman">ethereal swordsman</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="swordsman">he</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="guardswoman">ethereal guardswoman</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="guardswoman">she</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="guardsman">ethereal guardsman</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="guardsman">he</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="knight">royal knight</a><popBold/> crashes to the ground in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="highwayman">ghostly highwayman</a><popBold/> rolls over on the ground and goes still.
The <pushBold/><a exist="12345678" noun="bandit">ghostly bandit</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> shudders before falling into a lifeless heap on the ground.
The <pushBold/><a exist="12345678" noun="squire">ethereal squire</a><popBold/> collapses to the ground as <pushBold/><a exist="12345678" noun="squire">she</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="Sergeant">Drill Sergeant</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="steward">unworldly steward</a><popBold/> crashes to the floor in a plume of ethereal energy.
The <pushBold/><a exist="12345678" noun="steward">unworldly steward's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="steward">unworldly steward</a><popBold/> rolls over on the floor and goes still.
The <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> tries to crawl away on the floor but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="servant">her</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="steward">unworldly steward</a><popBold/> falls to the ground and dies.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="steward">unworldly steward</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="steward">she</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="slave">unworldly slave</a><popBold/> rolls over on the floor and goes still.
The <pushBold/><a exist="12345678" noun="Cook">Cook</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="Cook">she</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid</a><popBold/> tries to crawl away on the floor but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="maid">unworldly maid</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="noble">unworldly noble</a><popBold/> tries to crawl away on the ground but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="knight">royal knight</a><popBold/> is consumed by ethereal flames as <pushBold/><a exist="12345678" noun="knight">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="visitor">unworldly visitor</a><popBold/> tries to crawl away on the floor but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="noble">unworldly noble's</a><popBold/> body falls to the ground as it is consumed by ethereal flame.
The <pushBold/><a exist="12345678" noun="Dignitary">Foreign Dignitary</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="guest">unworldly guest</a><popBold/> shudders before falling into a lifeless heap on the floor.
The <pushBold/><a exist="12345678" noun="guard">royal guard</a><popBold/> falls to the floor motionless as small motes of light encompass <pushBold/><a exist="12345678" noun="guard">his</a><popBold/> body.
The <pushBold/><a exist="12345678" noun="noble">unworldly noble</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="noble">her</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="noble">unworldly noble</a><popBold/> collapses to the floor as <pushBold/><a exist="12345678" noun="noble">she</a><popBold/> flickers in and out of existence.
The <pushBold/><a exist="12345678" noun="noble">unworldly noble</a><popBold/> collapses to the floor as <pushBold/><a exist="12345678" noun="noble">he</a><popBold/> flickers in and out of existence.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="servant">she</a><popBold/> falls to the ground.
The ethereal light surrounding the <pushBold/><a exist="12345678" noun="servant">unworldly servant</a><popBold/> grows dim as <pushBold/><a exist="12345678" noun="servant">he</a><popBold/> falls to the floor.
The <pushBold/><a exist="12345678" noun="Princess">Royal Princess</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="Empress">Royal Empress</a><popBold/> tries to crawl away on the floor but is instead consumed by ethereal light.
The <pushBold/><a exist="12345678" noun="Emperor">Royal Emperor</a><popBold/> collapses to the floor as the light within <pushBold/><a exist="12345678" noun="Emperor">him</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="vruul">lesser vruul</a><popBold/> falls to the ground and lies still.
The <pushBold/><a exist="12345678" noun="vruul">lesser vruul</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="vruul">lesser vruul</a><popBold/> screams one last time and lies still.
The <pushBold/><a exist="12345678" noun="priestess">gnoll priestess</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="guard">gnoll guard</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="priestess">gnoll priestess</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="priest">gnoll priest</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="guard">gnoll guard</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="priest">gnoll priest</a><popBold/> rolls over and dies.
All that remains of the <pushBold/><a exist="12345678" noun="adept">adept</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
<pushBold/>A <a exist="12345678" noun="fanatic">deathsworn fanatic</a><popBold/> collapses to the floor in a susurrus of robes, crying out, "It is the end, but the moment has been prepared for!"
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="janissary">she</a><popBold/> collapses.
The <pushBold/><a exist="12345678" noun="elemental">earth elemental</a><popBold/> suddenly ceases all movement.
The <pushBold/><a exist="12345678" noun="elemental">air elemental</a><popBold/> shudders and then whirls away into nothingness.
The <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> begins bubbling violently before evaporating into nothingness.
The <pushBold/><a exist="12345678" noun="elemental">ice elemental</a><popBold/> dissipates into a cool breeze that fades rapidly away.
The <pushBold/><a exist="12345678" noun="elemental">fire elemental</a><popBold/> sputters violently, cascading flames all around as <pushBold/><a exist="12345678" noun="elemental">it</a><popBold/> collapses in a final fiery display.
The <pushBold/><a exist="12345678" noun="elemental">lightning elemental</a><popBold/> vanishes into a flurry of sparks that rapidly dissipates away.
The <pushBold/><a exist="12345678" noun="elemental">steam elemental</a><popBold/> dissipates into a warm breeze that fades rapidly away.
The <pushBold/><a exist="12345678" noun="elemental">lava elemental</a><popBold/> hardens into a chalky rock that quickly crumbles away into nothingness.
The <pushBold/><a exist="12345678" noun="sprite">wood sprite's</a><popBold/> eyes grow dim as <pushBold/><a exist="12345678" noun="sprite">her</a><popBold/> lifeforce fades away.
The glimmer of a <a exist="12345678" noun="tourmaline">pink tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="golem">gorefrost golem</a><popBold/> slumps over dead, its husk still pulsating with a blinding white hue.
A monstrous, too-wide smile spreads across <pushBold/>the <a exist="12345678" noun="cannibal">cannibal's</a><popBold/> face as <pushBold/><a exist="12345678" noun="cannibal">she</a><popBold/> collapses to the ground, dead.
Life and animation depart <pushBold/>the <a exist="12345678" noun="oozeling">oozeling</a><popBold/>, leaving behind a spreading puddle of protoplasm.
Gouting corrosive liquid from <pushBold/><a exist="12345678" noun="undansormr">its</a><popBold/> great maw, <pushBold/>a <a exist="12345678" noun="undansormr">colossal boreal undansormr</a><popBold/> wheels and flails, sending tremors through the ground with <pushBold/><a exist="12345678" noun="undansormr">its</a><popBold/> death throes.  At last, the great worm falls still and <pushBold/><a exist="12345678" noun="undansormr">its</a><popBold/> many eyes close.
Life and animation depart <pushBold/>the <a exist="12345678" noun="ooze">ooze</a><popBold/>, leaving behind a spreading puddle of protoplasm.
<pushBold/>A <a exist="12345678" noun="mutant">squamous reptilian mutant</a><popBold/> collapses, reaching out one clawed hand to the heavens.  A look of sorrow crosses <pushBold/><a exist="12345678" noun="mutant">his</a><popBold/> face as death claims <pushBold/><a exist="12345678" noun="mutant">him</a><popBold/> and the misshapen hand falls to <pushBold/><a exist="12345678" noun="mutant">his</a><popBold/> side.
<pushBold/>A <a exist="12345678" noun="mutant">squamous reptilian mutant</a><popBold/> collapses, reaching out one clawed hand to the heavens.  A look of sorrow crosses <pushBold/><a exist="12345678" noun="mutant">her</a><popBold/> face as death claims <pushBold/><a exist="12345678" noun="mutant">her</a><popBold/> and the misshapen hand falls to <pushBold/><a exist="12345678" noun="mutant">her</a><popBold/> side.
Blinding light explodes from <pushBold/>the <a exist="12345678" noun="disir">disir's</a><popBold/> eyes and mouth as <pushBold/><a exist="12345678" noun="disir">her</a><popBold/> wings spread, unfurled by the throes of <pushBold/><a exist="12345678" noun="disir">her</a><popBold/> agony.  The radiance sears <pushBold/><a exist="12345678" noun="disir">her</a><popBold/> shadow onto the ground behind <pushBold/><a exist="12345678" noun="disir">her</a><popBold/> as <pushBold/><a exist="12345678" noun="disir">she</a><popBold/> topples backward, lifeless.
As the radiance dims around <pushBold/><a exist="12345678" noun="valravn">black valravn's</a><popBold/> body, <pushBold/><a exist="12345678" noun="valravn">its</a><popBold/> shadow stretches long and strange as unsettling silence fills the air.  Heralded by a sound like the stirring of great wings, the noise of your surroundings crashes back down upon you, more noticeable for its brief absence.
Half-formed arms grasp futilely at empty air and melting mouths work soundlessly as <pushBold/>the <a exist="12345678" noun="angargeist">angargeist</a><popBold/> collapses into a puddle of inert ectoplasm.
<pushBold/>A <a exist="12345678" noun="bloodspeaker">stunted halfling bloodspeaker's</a><popBold/> eyes bulge as <pushBold/><a exist="12345678" noun="bloodspeaker">he</a><popBold/> stares toward the heavens, mouthing a gurgling prayer as <pushBold/><a exist="12345678" noun="bloodspeaker">he</a><popBold/> succumbs to death.
Electric blue light pours from <pushBold/>the <a exist="12345678" noun="draugr">draugr's</a><popBold/> eye sockets and erupts from <pushBold/><a exist="12345678" noun="draugr">her</a><popBold/> tattoos, leaving only a shadowy cadaver behind as animation departs <pushBold/>a <a exist="12345678" noun="draugr">withered shadow-cloaked draugr</a><popBold/>.
Electric blue light pours from <pushBold/>the <a exist="12345678" noun="draugr">draugr's</a><popBold/> eye sockets and erupts from <pushBold/><a exist="12345678" noun="draugr">his</a><popBold/> tattoos, leaving only a shadowy cadaver behind as animation departs <pushBold/>a <a exist="12345678" noun="draugr">withered shadow-cloaked draugr</a><popBold/>.
<pushBold/>A <a exist="12345678" noun="berserker">tattooed gigas berserker's</a><popBold/> fists tense with impotent rage as <pushBold/><a exist="12345678" noun="berserker">he</a><popBold/> surrenders to death.
A plaintive look passes across <pushBold/>a <a exist="12345678" noun="shield-maiden">brawny gigas shield-maiden's</a><popBold/> eyes like a fleeting shadow as <pushBold/><a exist="12345678" noun="shield-maiden">she</a><popBold/> goes still in death.
The <pushBold/><a exist="12345678" noun="angargeist">crimson angargeist</a><popBold/> falls to the ground and dies.
<pushBold/>A <a exist="12345678" noun="ravager">corpulent kresh ravager's</a><popBold/> spasms, rolling over.  <pushBold/><a exist="12345678" noun="ravager">Its</a><popBold/> tiny legs kick at the air before going still.
<pushBold/>A <a exist="12345678" noun="myrmidon">chitinous kiramon myrmidon</a><popBold/> collapses, <pushBold/><a exist="12345678" noun="myrmidon">its</a><popBold/> forelegs spasming and twitching before <pushBold/><a exist="12345678" noun="myrmidon">it</a><popBold/> at last surrenders to death.
<pushBold/>A <a exist="12345678" noun="strandweaver">translucent kiramon strandweaver</a><popBold/> collapses to the ground, <pushBold/><a exist="12345678" noun="strandweaver">her</a><popBold/> ghostly pale legs kicking spastically before abruptly stilling as <pushBold/><a exist="12345678" noun="strandweaver">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="thrall">hive thrall</a><popBold/> falls to the floor dead, her skin still pulsating with a blinding white hue.
Light goes out of <pushBold/>a <a exist="12345678" noun="stalker">sleek black kiramon stalker's</a><popBold/> eyes as <pushBold/><a exist="12345678" noun="stalker">she</a><popBold/> sinks to the ground and ceases to move.
Acid belches from <pushBold/>a <a exist="12345678" noun="thrall">disfigured hive thrall's</a><popBold/> mouth, raising blisters on <pushBold/><a exist="12345678" noun="thrall">her</a><popBold/> face as <pushBold/><a exist="12345678" noun="thrall">she</a><popBold/> gasps for breath.  Then <pushBold/><a exist="12345678" noun="thrall">she</a><popBold/> ceases to breathe, and a look of blessed peace dawns over <pushBold/><a exist="12345678" noun="thrall">her</a><popBold/> twisted features as <pushBold/><a exist="12345678" noun="thrall">she</a><popBold/> gives in to death.
Acid belches from <pushBold/>a <a exist="12345678" noun="thrall">disfigured hive thrall's</a><popBold/> mouth, raising blisters on <pushBold/><a exist="12345678" noun="thrall">his</a><popBold/> face as <pushBold/><a exist="12345678" noun="thrall">he</a><popBold/> gasps for breath.  Then <pushBold/><a exist="12345678" noun="thrall">he</a><popBold/> ceases to breathe, and a look of blessed peace dawns over <pushBold/><a exist="12345678" noun="thrall">his</a><popBold/> twisted features as <pushBold/><a exist="12345678" noun="thrall">he</a><popBold/> gives in to death.
<pushBold/>A <a exist="12345678" noun="broodtender">bloated kiramon broodtender's</a><popBold/> legs kick savagely as <pushBold/><a exist="12345678" noun="broodtender">she</a><popBold/> collapses, belching swarms of tiny, pale larvae.  They scatter wildly as <pushBold/><a exist="12345678" noun="broodtender">she</a><popBold/> surrenders to death.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="seer">his</a><popBold/> pupil-less green eyes frozen in a dead stare.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="herald">his</a><popBold/> pupil-less green eyes frozen in a dead stare.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="herald">she</a><popBold/> collapses.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="scout">he</a><popBold/> falls, "Letta, Leth, Latoth..."
The glimmer of a <a exist="12345678" noun="pearl">small grey pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="sunstone">red sunstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> sneers, "Urok vas derop tal kalissar kamath," then collapses.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="adept">he</a><popBold/> collapses.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> whispers, "Ra dro, Te lothre on ka nuko," then collapses.
The glimmer of a <a exist="12345678" noun="starstone">blue starstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="adept">his</a><popBold/> pupil-less green eyes frozen in a dead stare.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="seer">her</a><popBold/> pupil-less green eyes frozen in a dead stare.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="adept">his</a><popBold/> face as <pushBold/><a exist="12345678" noun="adept">he</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="seer">his</a><popBold/> lips as <pushBold/><a exist="12345678" noun="seer">he</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="troll">jungle troll</a><popBold/> falls to the ground as the stillness of death overtakes <pushBold/><a exist="12345678" noun="troll">him</a><popBold/>.
The <pushBold/><a exist="12345678" noun="sentry">triton sentry</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="seer">she</a><popBold/> falls, "Letta, Leth, Latoth..."
The <pushBold/><a exist="12345678" noun="puma">puma</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="warrior">ogre warrior</a><popBold/> screams one last time and dies.
The glimmer of <a exist="12345678" noun="lapis lazuli">some blue lapis lazuli</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> screams as <pushBold/><a exist="12345678" noun="herald">she</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> whispers, "Ra dro, Te lothre on ka nuko," then collapses.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> falls to the floor dead, his skin still pulsating with a blinding white hue.
The glimmer of a <a exist="12345678" noun="pearl">medium white pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="radical">grizzled triton radical</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="janissary">he</a><popBold/> collapses.
The glimmer of a <a exist="12345678" noun="agate">chameleon agate</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="pearl">large grey pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="janissary">her</a><popBold/> pupil-less green eyes frozen in a dead stare.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> whispers, "Ra dro, Te lothre on ka nuko," then collapses.
The glimmer of a <a exist="12345678" noun="dreamstone">black dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> screams as <pushBold/><a exist="12345678" noun="scout">he</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="radical">triton radical</a><popBold/> implodes inward upon itself, leaving behind no support for her body or life.  The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> falls to the floor in a lifeless mass of flesh and fractured bones.
The glimmer of a <a exist="12345678" noun="sapphire">blue sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="scout">his</a><popBold/> lips as <pushBold/><a exist="12345678" noun="scout">he</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="adept">himself</a><popBold/>, then collapses with a wheeze.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="initiate">his</a><popBold/> face as <pushBold/><a exist="12345678" noun="initiate">he</a><popBold/> falls.
The glimmer of <a exist="12345678" noun="quartz">some asterfire quartz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
All that remains of the <pushBold/><a exist="12345678" noun="seer">seer</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The glimmer of a <a exist="12345678" noun="tourmaline">blue tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> falls to the floor dead, her skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="janissary">his</a><popBold/> face as <pushBold/><a exist="12345678" noun="janissary">he</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> falls to the ground dead, his skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> falls to the ground dead, her skin still pulsating with a blinding white hue.
The glimmer of a <a exist="12345678" noun="stone">light pink morganite stone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> whispers, "Ra dro, Te lothre on ka nuko," then collapses.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="initiate">his</a><popBold/> pupil-less green eyes frozen in a dead stare.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> sneers, "Urok vas derop tal kalissar kamath," then collapses.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="herald">herself</a><popBold/>, then collapses with a wheeze.
The <pushBold/><a exist="12345678" noun="warrior">ogre warrior</a><popBold/> falls to the ground and dies.
The internal skeletal structure of <pushBold/>an <a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> implodes inward upon itself, leaving behind no support for his body or life.  The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The glimmer of a <a exist="12345678" noun="pearl">small black pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="siren">siren</a><popBold/> slumps over dead, her skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> slumps over dead, its  still pulsating with a blinding white hue.
A nebulous haze shimmers into view around <pushBold/>an <a exist="12345678" noun="defender">ancient triton defender</a><popBold/>, plunging inward in a dizzying spiral to envelop <pushBold/><a exist="12345678" noun="defender">her</a><popBold/> completely!  Silhouetted within the shifting spiritual miasma, the <pushBold/><a exist="12345678" noun="defender">defender's</a><popBold/> form withers, wasting away to an attenuated mockery of <pushBold/><a exist="12345678" noun="defender">herself</a><popBold/>.  Even this pale shadow disintegrates, dissolving on the air as the last cloudy tendrils vanish.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="scout">she</a><popBold/> collapses.
The <pushBold/><a exist="12345678" noun="initiate">Ithzir initiate</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="initiate">she</a><popBold/> falls, "Letta, Leth, Latoth..."
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="seer">he</a><popBold/> falls, "Letta, Leth, Latoth..."
The <pushBold/><a exist="12345678" noun="warthog">warthog</a><popBold/> lets out a final agonized snuffle and dies.
The <pushBold/><a exist="12345678" noun="weasel">giant weasel</a><popBold/> lets out a final agonized cry and dies.
<pushBold/>A <a exist="12345678" noun="rattlesnake">banded rattlesnake</a><popBold/> twitches and gives one last rattle before falling silent.
The <pushBold/><a exist="12345678" noun="weasel">giant weasel</a><popBold/> collapses to the ground, emits a final cry, and dies.
The <pushBold/><a exist="12345678" noun="warthog">warthog</a><popBold/> collapses to the ground, emits a final snuffle, and dies.
The mass of hair and bone that was the <pushBold/><a exist="12345678" noun="yeti">yeti</a><popBold/> finally goes still.
The <pushBold/><a exist="12345678" noun="griffin">lesser griffin</a><popBold/> crashes to the ground, motionless.
The <pushBold/><a exist="12345678" noun="grifflet">grifflet</a><popBold/> crashes to the ground, motionless.
The <pushBold/><a exist="12345678" noun="griffin">storm griffin</a><popBold/> crashes to the ground, motionless.
<pushBold/>An <a exist="12345678" noun="hierophant">emaciated hierophant</a><popBold/> thrashes violently and then dies.
With an ear-piercing cry of agony, the <pushBold/><a exist="12345678" noun="hierophant">emaciated hierophant</a><popBold/> dies.
<pushBold/>A <a exist="12345678" noun="supplicant">muscular supplicant</a><popBold/> thrashes violently and then dies.
<pushBold/>A <a exist="12345678" noun="supplicant">muscular supplicant</a><popBold/> drops to the floor, quite dead!
Silence hangs heavy in the air as the <pushBold/><a exist="12345678" noun="dogmatist">dogmatist</a><popBold/> exhales his final breath, collapsing lifelessly to the ground.
<pushBold/>An <a exist="12345678" noun="hierophant">emaciated hierophant</a><popBold/> dies, falling down like a rag doll.
<pushBold/>An <a exist="12345678" noun="hierophant">emaciated hierophant</a><popBold/> spasms one last time and then dies.
<pushBold/>The <a exist="12345678" noun="phoenix">phoenix</a><popBold/> crashes to the ground, sending searing flames in all directions.
Ash explodes in all directions as <pushBold/>an <a exist="12345678" noun="guardian">ash guardian</a><popBold/> succumbs to <pushBold/><a exist="12345678" noun="guardian">its</a><popBold/> final blow.
The flames of <pushBold/>the <a exist="12345678" noun="firebird">firebird</a><popBold/> disappear into the air as <pushBold/><a exist="12345678" noun="firebird">its</a><popBold/> body crashes to the ground in a ball of feathers.
The <pushBold/><a exist="12345678" noun="golem">lava golem</a><popBold/> topples to the ground as the fire slowly leaves <pushBold/><a exist="12345678" noun="golem">it</a><popBold/>.
The <pushBold/><a exist="12345678" noun="skayl">skayl</a><popBold/> goes limp and <pushBold/><a exist="12345678" noun="skayl">it</a><popBold/> falls over as the fire slowly fades from <pushBold/><a exist="12345678" noun="skayl">its</a><popBold/> eyes.
The fire in the <pushBold/><a exist="12345678" noun="tsark">red tsark's</a><popBold/> eyes slowly fades.
The <pushBold/><a exist="12345678" noun="golem">lava golem</a><popBold/> writhes in fiery agony and dies.
The <pushBold/><a exist="12345678" noun="dervish">steam dervish</a><popBold/> falls to the ground, leaking steam profusely.
The <pushBold/><a exist="12345678" noun="skayl">greater skayl</a><popBold/> goes limp and <pushBold/><a exist="12345678" noun="skayl">it</a><popBold/> falls over as the fire slowly fades from <pushBold/><a exist="12345678" noun="skayl">its</a><popBold/> eyes.
The fire in the <pushBold/><a exist="12345678" noun="skayl">greater skayl's</a><popBold/> eyes slowly fades.
As the steam dissipates from <pushBold/><a exist="12345678" noun="dervish">him</a><popBold/>, the <pushBold/><a exist="12345678" noun="dervish">steam dervish</a><popBold/> cries out in pain one last time and expires.
The <pushBold/><a exist="12345678" noun="tsark">red tsark</a><popBold/> goes limp and <pushBold/><a exist="12345678" noun="tsark">he</a><popBold/> falls over as the fire slowly fades from <pushBold/><a exist="12345678" noun="tsark">his</a><popBold/> eyes.
Disillusioned, the <pushBold/><a exist="12345678" noun="herald">Veiki herald</a><popBold/> surrenders, and the azure sparks in <pushBold/><a exist="12345678" noun="herald">his</a><popBold/> eyes fade to black.
<pushBold/>A <a exist="12345678" noun="tyrant">titan tempest tyrant</a><popBold/> stretches a hand skyward, fumbling for something unseen as <pushBold/><a exist="12345678" noun="tyrant">she</a><popBold/> surrenders to death.
With a white-hot corruscation of sparks, <pushBold/>a <a exist="12345678" noun="fiend">crackling lightning fiend</a><popBold/> collapses into a buzzing tangle of glowing filaments.
A ragged gasp fills <pushBold/>a <a exist="12345678" noun="stormcaller">stooped titan stormcaller's</a><popBold/> lungs with a last breath that wooshes out as <pushBold/><a exist="12345678" noun="stormcaller">she</a><popBold/> dies.
Disillusioned, the <pushBold/><a exist="12345678" noun="herald">Veiki herald</a><popBold/> surrenders, and the azure sparks in <pushBold/><a exist="12345678" noun="herald">her</a><popBold/> eyes fade to black.
As the strength drains out of the <pushBold/><a exist="12345678" noun="bat">undertaker bat's</a><popBold/> wings, it falls to the ground in a motionless heap.
<pushBold/>A <a exist="12345678" noun="wraith">troll wraith</a><popBold/> falls to the ground, lying completely motionless.  A last minute twitch causes the <pushBold/><a exist="12345678" noun="wraith">wraith's</a><popBold/> arm to spasm up into the air before falling limply back to <pushBold/><a exist="12345678" noun="wraith">her</a><popBold/> side.
The <pushBold/><a exist="12345678" noun="vourkha">vourkha</a><popBold/> slumps to the ground as the light departs her eyes.
The <pushBold/><a exist="12345678" noun="vulture">colossus vulture</a><popBold/> writhes in agony, <pushBold/><a exist="12345678" noun="vulture">its</a><popBold/> wings flapping fruitlessly as <pushBold/><a exist="12345678" noun="vulture">it</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="baesrukha">baesrukha</a><popBold/> collapses to the ground in a motionless heap, sending a plume of dust up from her unwashed body.
<pushBold/>A <a exist="12345678" noun="wight">lesser moor wight</a><popBold/> lets loose a final wail as <pushBold/><a exist="12345678" noun="wight">it</a><popBold/> is released.
The evil glint leaves the <pushBold/><a exist="12345678" noun="vourkha">vourkha's</a><popBold/> eyes as he falls still.
The <pushBold/><a exist="12345678" noun="scout">troll scout</a><popBold/> spins backwards and collapses dead.
The light in the <pushBold/><a exist="12345678" noun="scout">troll scout's</a><popBold/> eyes goes out and <pushBold/><a exist="12345678" noun="scout">he</a><popBold/> ceases to move.
<pushBold/>The <a exist="12345678" noun="golem">golem's</a><popBold/> form sags to the floor, <pushBold/><a exist="12345678" noun="golem">its</a><popBold/> reptilian head finally freed from <pushBold/><a exist="12345678" noun="golem">its</a><popBold/> monstrous glaes form.
The <pushBold/><a exist="12345678" noun="warrior">troll warrior</a><popBold/> attempts to get up but the effort drains the last of <pushBold/><a exist="12345678" noun="warrior">her</a><popBold/> life and <pushBold/><a exist="12345678" noun="warrior">she</a><popBold/> collapses dead.
With a loud crash, <pushBold/>the <a exist="12345678" noun="golem">golem's</a><popBold/> form sags to the floor, <pushBold/><a exist="12345678" noun="golem">its</a><popBold/> reptilian head finally freed from <pushBold/><a exist="12345678" noun="golem">its</a><popBold/> monstrous glaes form.
<pushBold/>A <a exist="12345678" noun="ogre">black forest ogre</a><popBold/> twitches one last time and dies.
The <pushBold/><a exist="12345678" noun="boar">black boar</a><popBold/> lets out a final agonized squeal and dies.
The light in <pushBold/>a <a exist="12345678" noun="ogre">black forest ogre's</a><popBold/> eyes goes out and he finally dies.
The lights in <pushBold/>a <a exist="12345678" noun="orc">lesser burrow orc's</a><popBold/> eyes dim and finally go out.
<pushBold/>A <a exist="12345678" noun="orc">lesser orc</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="mare">shadow mare</a><popBold/> falls to the ground motionless.
The fire leaves the <pushBold/><a exist="12345678" noun="mare">mare's</a><popBold/> eyes as <pushBold/><a exist="12345678" noun="mare">she</a><popBold/> falls still.
Reduced to a bloody tangle of beak and feathers, the lifeless <pushBold/><a exist="12345678" noun="daggerbeak">daggerbeak</a><popBold/> falls to the ground.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> screams as <pushBold/><a exist="12345678" noun="adept">he</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The <pushBold/><a exist="12345678" noun="crab">crystal crab</a><popBold/> clacks its pincers a final agonizing time and dies.
The <pushBold/><a exist="12345678" noun="monkey">green monkey</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="monkey">pink monkey</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="crab">crystal crab</a><popBold/> collapses to the ground, clacks its pincers and dies.
The <pushBold/><a exist="12345678" noun="monkey">orange monkey</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="guardian">wall guardian</a><popBold/> vainly tries to sound a warning, then collapses.
The <pushBold/><a exist="12345678" noun="sentry">deranged sentry</a><popBold/> vainly tries to sound a warning, then collapses.
The <pushBold/><a exist="12345678" noun="sentry">deranged sentry</a><popBold/> vainly tries to shout a warning, then goes still.
The <pushBold/><a exist="12345678" noun="guardian">wall guardian</a><popBold/> vainly tries to shout a warning, then goes still.
The <pushBold/><a exist="12345678" noun="dog">guard dog</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="dog">guard dog</a><popBold/> rolls over and dies.
<pushBold/>A <a exist="12345678" noun="worm">phosphorescent worm</a><popBold/> slumps to the ground, its glowing form now motionless and dull.
The <pushBold/><a exist="12345678" noun="arachnid">luminous arachnid</a><popBold/> collapses to the ground and dies.
The <pushBold/><a exist="12345678" noun="grahnk">massive grahnk</a><popBold/> growls one last time in defiance, then slumps to the ground.
The <pushBold/><a exist="12345678" noun="grahnk">massive grahnk</a><popBold/> growls one last time in defiance, then goes still.
<pushBold/>A <a exist="12345678" noun="bush">writhing icy bush</a><popBold/> collapses to the ground, shakes one last time and dies.
<pushBold/>A <a exist="12345678" noun="vine">writhing frost-glazed vine</a><popBold/> shudders briefly before discontinuing its assault.
<pushBold/>A <a exist="12345678" noun="tumbleweed">blackened decaying tumbleweed</a><popBold/> twists unnaturally as it decomposes into itself.
<pushBold/>A <a exist="12345678" noun="plant">dark frosty plant</a><popBold/> collapses to the ground, twitches one last time and dies.
<pushBold/>A <a exist="12345678" noun="creeper">shriveled icy creeper</a><popBold/> collapses to the ground, twitches one last time and dies.
<pushBold/>A <a exist="12345678" noun="shrub">large thorned shrub</a><popBold/> collapses to the ground, shakes one last time and dies.
<pushBold/>A <a exist="12345678" noun="creeper">shriveled icy creeper</a><popBold/> twitches one last time and dies.
The <pushBold/><a exist="12345678" noun="bear">polar bear</a><popBold/> collapses heavily into a heap on the ground and dies.
<pushBold/>A <a exist="12345678" noun="golem">steel golem</a><popBold/> freezes completely before falling to the floor in pieces.
<pushBold/>A <a exist="12345678" noun="golem">steel golem</a><popBold/> freezes completely before falling to pieces.
The <pushBold/><a exist="12345678" noun="viper">tree viper</a><popBold/> twists and coils violently in its death throes, finally going still.
The <pushBold/><a exist="12345678" noun="panther">dark panther</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="panther">dark panther</a><popBold/> crumples to the ground and dies.
<pushBold/>A <a exist="12345678" noun="shaman">forest trali shaman</a><popBold/> collapses upon the ground and the life fades from her eyes.
<pushBold/>A <a exist="12345678" noun="trali">forest trali</a><popBold/> collapses upon the ground and the life fades from her eyes.
The <pushBold/><a exist="12345678" noun="ursian">tusked ursian</a><popBold/> lets out a blood-curdling roar and dies.
The <pushBold/><a exist="12345678" noun="sprite">wood sprite's</a><popBold/> eyes grow dim as <pushBold/><a exist="12345678" noun="sprite">his</a><popBold/> lifeforce fades away.
The <pushBold/><a exist="12345678" noun="sprite">wood sprite's</a><popBold/> eyes dim, and <pushBold/><a exist="12345678" noun="sprite">she</a><popBold/> falls to the ground with a dry crackling sound.
The <pushBold/><a exist="12345678" noun="ursian">tusked ursian</a><popBold/> collapses heavily into a heap on the ground and dies.
The <pushBold/><a exist="12345678" noun="bendith">forest bendith</a><popBold/> drops lifelessly to the ground.
The <pushBold/><a exist="12345678" noun="bendith">forest bendith's</a><popBold/> eyes grow dim as <pushBold/><a exist="12345678" noun="bendith">her</a><popBold/> lifeforce fades away.
<pushBold/>A <a exist="12345678" noun="shrickhen">shrickhen</a><popBold/>'s arms, legs and head separate from her torso as the dissimilar parts finally fall still.
<pushBold/>A <a exist="12345678" noun="shrickhen">shrickhen</a><popBold/>'s arms, legs and head separate from his torso as the dissimilar parts finally fall still.
The <pushBold/><a exist="12345678" noun="goleras">dhu goleras</a><popBold/> opens <pushBold/><a exist="12345678" noun="goleras">her</a><popBold/> mouth wide and lets out a choked, shrill scream and <pushBold/><a exist="12345678" noun="goleras">her</a><popBold/> eyes cloud over to a solid milky white as <pushBold/><a exist="12345678" noun="goleras">she</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="goleras">dhu goleras</a><popBold/> opens <pushBold/><a exist="12345678" noun="goleras">his</a><popBold/> mouth wide and lets out a choked, shrill scream and <pushBold/><a exist="12345678" noun="goleras">his</a><popBold/> eyes cloud over to a solid milky white as <pushBold/><a exist="12345678" noun="goleras">he</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="moulis">moulis</a><popBold/> flails wildly for a moment before collapsing, <pushBold/><a exist="12345678" noun="moulis">its</a><popBold/> appendages dropping lifelessly to the ground.
The <pushBold/><a exist="12345678" noun="scraping">moulis scraping</a><popBold/> collapses to the ground and with a last ripple, dies.
The <pushBold/><a exist="12345678" noun="madrinol">snow madrinol</a><popBold/> flips onto its back, kicks several times and dies.
<pushBold/>An <a exist="12345678" noun="slush">animated slush</a><popBold/> quivers violently and collapses, its conical form flattening into a wide pancake.
<pushBold/>A <a exist="12345678" noun="morph">glacial morph</a><popBold/> releases a low rumble before becoming completely still.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> screams as <pushBold/><a exist="12345678" noun="scout">she</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The <pushBold/><a exist="12345678" noun="madrinol">snow madrinol</a><popBold/> rolls over onto its back, kicks several times and dies.
<pushBold/>A <a exist="12345678" noun="sheep">bighorn sheep</a><popBold/> collapses, <pushBold/><a exist="12345678" noun="sheep">her</a><popBold/> head dropping heavily to the ground as <pushBold/><a exist="12345678" noun="sheep">she</a><popBold/> goes still.
The <pushBold/><a exist="12345678" noun="goat">mountain goat</a><popBold/> collapses to the ground, emits a final bray, and dies.
The <pushBold/><a exist="12345678" noun="leopard">snow leopard</a><popBold/> crumples to the ground and dies.
<pushBold/>A <a exist="12345678" noun="sheep">bighorn sheep</a><popBold/> collapses, <pushBold/><a exist="12345678" noun="sheep">his</a><popBold/> head dropping heavily to the ground as <pushBold/><a exist="12345678" noun="sheep">he</a><popBold/> goes still.
The <pushBold/><a exist="12345678" noun="goat">mountain goat</a><popBold/> lets out a final agonized bray and dies.
The <pushBold/><a exist="12345678" noun="relnak">striped relnak</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="leaper">spotted leaper</a><popBold/> twitches and dies.
The <pushBold/><a exist="12345678" noun="leaper">spotted leaper</a><popBold/> collapses to the ground, emits a final snarl, and dies.
<pushBold/>A <a exist="12345678" noun="orc">raider orc</a><popBold/> screams <pushBold/><a exist="12345678" noun="orc">her</a><popBold/> defiance skyward one last time and dies.
<pushBold/>A <a exist="12345678" noun="orc">raider orc</a><popBold/> screams <pushBold/><a exist="12345678" noun="orc">his</a><popBold/> defiance skyward one last time and dies.
The <pushBold/><a exist="12345678" noun="lizard">cave lizard</a><popBold/> shudders a final time and goes still.
<pushBold/>A <a exist="12345678" noun="veaba">giant veaba</a><popBold/> dies; vitreous fluids escape its body.
<pushBold/>A <a exist="12345678" noun="wraith">wind wraith</a><popBold/> releases a groan of mingled ecstasy and relief as <pushBold/><a exist="12345678" noun="wraith">it</a><popBold/> fades away.
The <pushBold/><a exist="12345678" noun="pyrothag">massive pyrothag</a><popBold/> falls to the ground and lies still.
The <pushBold/><a exist="12345678" noun="wasp">cinder wasp</a><popBold/> falls to the ground dead, its skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="thrak">red-scaled thrak</a><popBold/> hisses one last time and dies.
The <pushBold/><a exist="12345678" noun="thrak">red-scaled thrak</a><popBold/> falls back into a heap and dies.
The <pushBold/><a exist="12345678" noun="wasp">cinder wasp</a><popBold/> flutters its wings one last time and dies.
The <pushBold/><a exist="12345678" noun="wasp">cinder wasp</a><popBold/> careens to the ground and crumples in a heap.
The <pushBold/><a exist="12345678" noun="pyrothag">massive pyrothag</a><popBold/> vibrates violently one final time and then lies still.
The <pushBold/><a exist="12345678" noun="vor'taz">horned vor'taz's</a><popBold/> horn dims as <pushBold/><a exist="12345678" noun="vor'taz">her</a><popBold/> lifeforce fades away.
The <pushBold/><a exist="12345678" noun="vor'taz">horned vor'taz's</a><popBold/> horn dims as <pushBold/><a exist="12345678" noun="vor'taz">his</a><popBold/> lifeforce fades away.
<pushBold/>A <a exist="12345678" noun="faeroth">greater faeroth</a><popBold/> releases a roar as he falls to the ground and goes still.
<pushBold/>A <a exist="12345678" noun="faeroth">lesser faeroth</a><popBold/> releases a shriek as she falls to the ground and goes still.
<pushBold/>A <a exist="12345678" noun="faeroth">greater faeroth</a><popBold/> emits a roar as he goes still.
<pushBold/>A <a exist="12345678" noun="faeroth">lesser faeroth</a><popBold/> emits a shriek as she goes still.
<pushBold/>A <a exist="12345678" noun="faeroth">greater faeroth</a><popBold/> emits a roar as she goes still.
The <pushBold/><a exist="12345678" noun="soldier">giant soldier</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="yeti">yeti</a><popBold/> collapses into a pile of hair and bones and goes still.
<pushBold/>A <a exist="12345678" noun="ogre">black forest ogre</a><popBold/> falls prone to the ground, twitches one last time and dies.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="scout">she</a><popBold/> falls, "Letta, Leth, Latoth..."
The <pushBold/><a exist="12345678" noun="viper">black forest viper</a><popBold/> twists and coils violently in its death throes, finally going still.
The light in <pushBold/>a <a exist="12345678" noun="ogre">black forest ogre's</a><popBold/> eyes goes out as he collapses and finally dies.
The <pushBold/><a exist="12345678" noun="troll">hunter troll</a><popBold/> slumps to the ground with a final snarl.
The <pushBold/><a exist="12345678" noun="tegu">three-toed tegu</a><popBold/> stumbles and falls to the ground, twitches and dies.
The <pushBold/><a exist="12345678" noun="tegu">three-toed tegu</a><popBold/> arches its back in a tortured spasm and dies.
The <pushBold/><a exist="12345678" noun="shade">warrior shade</a><popBold/> shudders in spectral agony, then begins to rapidly dissipate.
<pushBold/>A <a exist="12345678" noun="sentry">tegursh sentry</a><popBold/> rasps a final scream and dies.
The <pushBold/><a exist="12345678" noun="hawk-owl">giant hawk-owl</a><popBold/> crashes to the ground, motionless.
The <pushBold/><a exist="12345678" noun="mara">ghostly mara</a><popBold/> slumps silently to the ground and begins to rapidly dissipate.
The <pushBold/><a exist="12345678" noun="lord">spectral lord</a><popBold/> slumps silently to the ground, <pushBold/><a exist="12345678" noun="lord">his</a><popBold/> brilliant eyes fading to grey.
<pushBold/>A <a exist="12345678" noun="lord">spectral lord</a><popBold/> calls out an oath as <pushBold/><a exist="12345678" noun="lord">his</a><popBold/> brilliant eyes fade to grey.
The <pushBold/><a exist="12345678" noun="mara">ghostly mara</a><popBold/> shudders in spectral agony, then begins to rapidly dissipate.
<pushBold/>A <a exist="12345678" noun="scout">plains orc scout</a><popBold/> jerks one last time and expires.
The <pushBold/><a exist="12345678" noun="stag">great stag</a><popBold/> collapses to the ground, emits a final sigh, and dies.
<pushBold/>A <a exist="12345678" noun="chieftain">plains orc chieftain</a><popBold/>'s chest heaves one last time then she dies.
The <pushBold/><a exist="12345678" noun="brindlecat">tawny brindlecat's</a><popBold/> tail twitches feebly as <pushBold/><a exist="12345678" noun="brindlecat">he</a><popBold/> dies.
<pushBold/>A <a exist="12345678" noun="shaman">plains orc shaman</a><popBold/> mutters belaboring his fate and then dies.
The <pushBold/><a exist="12345678" noun="dog">black wild dog</a><popBold/> falls to the ground and dies.
<pushBold/>A <a exist="12345678" noun="warrior">plains orc warrior</a><popBold/>'s face turns upward in a tortured rictus then his body goes slack.
The <pushBold/><a exist="12345678" noun="basilisk">crested basilisk</a><popBold/> emits a final hiss and dies.
The <pushBold/><a exist="12345678" noun="boar">ridgeback boar</a><popBold/> lets out a final agonized squeal and dies.
The <pushBold/><a exist="12345678" noun="boar">ridgeback boar</a><popBold/> collapses to the ground, emits a final squeal, and dies.
<pushBold/>A <a exist="12345678" noun="chieftain">plains orc chieftain</a><popBold/>'s chest heaves one last time then he dies.
<pushBold/>A <a exist="12345678" noun="warrior">plains orc warrior</a><popBold/>'s face turns upward in a tortured rictus then her body goes slack.
The <pushBold/><a exist="12345678" noun="basilisk">crested basilisk</a><popBold/> rolls over on its back, emits a final hiss and dies.
<pushBold/>A <a exist="12345678" noun="wight">lesser moor wight</a><popBold/> crumples to a heap on the ground.
The evil glint leaves the <pushBold/><a exist="12345678" noun="vourkha">vourkha's</a><popBold/> eyes as she falls still.
The <pushBold/><a exist="12345678" noun="barghest">barghest</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="baesrukha">baesrukha</a><popBold/> collapses to the ground in a motionless heap, sending a plume of dust up from his unwashed body.
The <pushBold/><a exist="12345678" noun="baesrukha">baesrukha's</a><popBold/> face twists into a final silent screech and then he lies motionless.
The <pushBold/><a exist="12345678" noun="pooka">ghostly pooka</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="hound">night hound</a><popBold/> falls on its side and lets out one last whimpering sigh of dark and shadowy whirlwinds.
The <pushBold/><a exist="12345678" noun="hound">night hound</a><popBold/> lets out one last whimpering sigh of dark and shadowy whirlwinds and dies.
The <pushBold/><a exist="12345678" noun="pooka">ghostly pooka</a><popBold/> ceases all attempts at movement.
The <pushBold/><a exist="12345678" noun="miner">spectral miner</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="miner">spectral miner</a><popBold/> ceases all attempts at movement.
The <pushBold/><a exist="12345678" noun="fenghai">fenghai</a><popBold/> cries out one last time and lies still.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="herald">his</a><popBold/> face as <pushBold/><a exist="12345678" noun="herald">he</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="viper">tree viper</a><popBold/> writhes in its death throes, its violent writhing causing it to fall from its perch.
<pushBold/>A <a exist="12345678" noun="orc">ridge orc</a><popBold/> gives a last gasp and dies.
The <pushBold/><a exist="12345678" noun="spectre">swirling spectre</a><popBold/> lets loose a long sigh, as the air around <pushBold/><a exist="12345678" noun="spectre">her</a><popBold/> calms and <pushBold/><a exist="12345678" noun="spectre">she</a><popBold/> begins to fade.
The <pushBold/><a exist="12345678" noun="troglodyte">troglodyte</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="gnoll">cave gnoll</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="scout">her</a><popBold/> lips as <pushBold/><a exist="12345678" noun="scout">she</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> falls to the floor dead, her skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="construct">lesser construct</a><popBold/> collapses, <pushBold/><a exist="12345678" noun="construct">its</a><popBold/> eyes fading to a lifeless gaze and stone shell cracking into a barely discernible form.
<pushBold/>A <a exist="12345678" noun="sheep">bighorn sheep</a><popBold/> rolls over, <pushBold/><a exist="12345678" noun="sheep">his</a><popBold/> head dropping heavily to the ground as <pushBold/><a exist="12345678" noun="sheep">he</a><popBold/> goes still.
The <pushBold/><a exist="12345678" noun="troll">hunter troll</a><popBold/> looks up with hatred as <pushBold/><a exist="12345678" noun="troll">she</a><popBold/> lets out <pushBold/><a exist="12345678" noun="troll">her</a><popBold/> final breath.
The <pushBold/><a exist="12345678" noun="troglodyte">troglodyte</a><popBold/> screams silently one last time and dies.
The <pushBold/><a exist="12345678" noun="mummy">lesser mummy</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="master">ghoul master</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="wight">tomb wight</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="spider">tomb spider</a><popBold/> collapses to the ground and dies.
The <pushBold/><a exist="12345678" noun="troll">stone troll</a><popBold/> topples to the ground motionless.
The <pushBold/><a exist="12345678" noun="giant">stone giant</a><popBold/> rumbles in agony and goes still.
The <pushBold/><a exist="12345678" noun="troll">stone troll</a><popBold/> shudders violently for a moment, then goes still.
The <pushBold/><a exist="12345678" noun="mystic">Illoke mystic</a><popBold/> grumbles in pain one last time before lying still.
The <pushBold/><a exist="12345678" noun="mastiff">stone mastiff</a><popBold/> rolls over and dies.
<pushBold/>A <a exist="12345678" noun="mastiff">stone mastiff</a><popBold/> crumbles into a pile of rubble.
The <pushBold/><a exist="12345678" noun="shaman">Illoke shaman</a><popBold/> grumbles in pain one last time before lying still.
The glimmer of a <a exist="12345678" noun="sapphire">dragonsbreath sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="dreamstone">pink dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="tourmaline">black tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The fire in the <pushBold/><a exist="12345678" noun="mage">fire mage's</a><popBold/> eyes slowly fades away.
The <pushBold/><a exist="12345678" noun="steed">shadow steed</a><popBold/> collapses to the ground, a thick grey mist pouring from <pushBold/><a exist="12345678" noun="steed">his</a><popBold/> nostrils.
The <pushBold/><a exist="12345678" noun="mare">night mare</a><popBold/> collapses to the ground, a thick grey mist pouring from her nostrils.
The <pushBold/><a exist="12345678" noun="vor'taz">horned vor'taz's</a><popBold/> horn dims, and <pushBold/><a exist="12345678" noun="vor'taz">he</a><popBold/> falls to the ground dead.
<pushBold/>A <a exist="12345678" noun="orc">greater burrow orc</a><popBold/> growls one last time and dies.
The <pushBold/><a exist="12345678" noun="warfarer">krolvin warfarer</a><popBold/> crashes to the floor in a plume of dust.
The <pushBold/><a exist="12345678" noun="warrior">krolvin warrior</a><popBold/> rolls over on the floor and goes still.
The <pushBold/><a exist="12345678" noun="warrior">krolvin warrior</a><popBold/> falls lifeless to the floor with a heavy thump.
The <pushBold/><a exist="12345678" noun="centaur">white centaur</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="ranger">bay centaur ranger</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="centaur">roan centaur</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="centaur">bay centaur</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="snake">grass snake</a><popBold/> is sliced neatly in two.
The <pushBold/><a exist="12345678" noun="thyril">thyril</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="gnarp">spotted gnarp</a><popBold/> lets out a final agonized cry and dies.
The <pushBold/><a exist="12345678" noun="rolton">black rolton</a><popBold/> collapses to the ground, emits a final bleat, and dies.
The <pushBold/><a exist="12345678" noun="rolton">black rolton</a><popBold/> lets out a final agonized bleat and dies.
The <pushBold/><a exist="12345678" noun="gak">brown gak</a><popBold/> lets out a final agonized bellow and dies.
The <pushBold/><a exist="12345678" noun="gnarp">spotted gnarp</a><popBold/> collapses to the ground, emits a final cry, and dies.
The <pushBold/><a exist="12345678" noun="bear">Agresh bear</a><popBold/> lets out a blood-curdling roar and dies.
The <pushBold/><a exist="12345678" noun="ant">fire ant</a><popBold/> feebly twitches a feeler one last time and dies.
The <pushBold/><a exist="12345678" noun="ant">fire ant</a><popBold/> falls to the ground and dies, its feelers twitching.
<pushBold/>A <a exist="12345678" noun="trali">forest trali</a><popBold/> collapses upon the floor and the life fades from her eyes.
The <pushBold/><a exist="12345678" noun="leopard">mastodonic leopard</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="raptor">dreadnought raptor</a><popBold/> crashes to the ground, motionless.
The <pushBold/><a exist="12345678" noun="raptor">dreadnought raptor</a><popBold/> writhes in agony, <pushBold/><a exist="12345678" noun="raptor">its</a><popBold/> wings flapping fruitlessly as <pushBold/><a exist="12345678" noun="raptor">it</a><popBold/> dies.
<pushBold/>A <a exist="12345678" noun="shaman">forest trali shaman</a><popBold/> collapses upon the ground and the life fades from his eyes.
<pushBold/>A <a exist="12345678" noun="trali">forest trali</a><popBold/> collapses upon the ground and the life fades from his eyes.
The <pushBold/><a exist="12345678" noun="rodent">fanged rodent</a><popBold/> twitches and dies.
The <pushBold/><a exist="12345678" noun="rodent">fanged rodent</a><popBold/> collapses to the ground, emits a final squeal, and dies.
The <pushBold/><a exist="12345678" noun="goblin">fanged goblin</a><popBold/> screams, shudders one last time and dies.
The <pushBold/><a exist="12345678" noun="viper">fanged viper</a><popBold/> is sliced neatly in two.
The <pushBold/><a exist="12345678" noun="siren">Mistydeep siren</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="phantom">moaning phantom</a><popBold/> slowly settles to the ground and begins to dissipate.
The <pushBold/><a exist="12345678" noun="bobcat">bobcat</a><popBold/> lets out a final caterwaul and dies.
The <pushBold/><a exist="12345678" noun="bobcat">bobcat</a><popBold/> crumples to the ground and dies.
The <pushBold/><a exist="12345678" noun="cockatrice">plumed cockatrice</a><popBold/> rolls over on its back, emits a final screech and dies.
The <pushBold/><a exist="12345678" noun="troll">Neartofar troll</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="sprite">lesser wood sprite's</a><popBold/> eyes grow dim as <pushBold/><a exist="12345678" noun="sprite">his</a><popBold/> lifeforce fades away.
The <pushBold/><a exist="12345678" noun="eagle">martial eagle</a><popBold/> crashes to the ground, motionless.
The <pushBold/><a exist="12345678" noun="sprite">lesser wood sprite's</a><popBold/> eyes dim, and <pushBold/><a exist="12345678" noun="sprite">she</a><popBold/> falls to the ground with a dry crackling sound.
The <pushBold/><a exist="12345678" noun="eagle">martial eagle</a><popBold/> writhes in agony, <pushBold/><a exist="12345678" noun="eagle">its</a><popBold/> wings flapping fruitlessly as <pushBold/><a exist="12345678" noun="eagle">it</a><popBold/> dies.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="adept">his</a><popBold/> lips as <pushBold/><a exist="12345678" noun="adept">he</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="adept">she</a><popBold/> collapses.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="adept">her</a><popBold/> face as <pushBold/><a exist="12345678" noun="adept">she</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="seer">himself</a><popBold/>, then collapses with a wheeze.
The <pushBold/><a exist="12345678" noun="siren">siren</a><popBold/> falls to the floor dead, her skin still pulsating with a blinding white hue.
The glimmer of a <a exist="12345678" noun="starstone">white starstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The internal skeletal structure of <pushBold/>a <a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> implodes inward upon itself, leaving behind no support for his body or life.  The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> falls to the ground in a lifeless mass of flesh and fractured bones.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="seer">his</a><popBold/> face as <pushBold/><a exist="12345678" noun="seer">he</a><popBold/> falls.
The <pushBold/><a exist="12345678" noun="hound">ice hound</a><popBold/> lets out one last whimpering sigh of frosty mist and dies.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> screams as <pushBold/><a exist="12345678" noun="seer">she</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The <pushBold/><a exist="12345678" noun="troll">ice troll</a><popBold/> cries out in cold agony one last time and dies.
The <pushBold/><a exist="12345678" noun="warrior">ogre warrior</a><popBold/> screams silently one last time and dies.
The glimmer of a <a exist="12345678" noun="sapphire">dragonsbreath sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="pearl">medium pink pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="agate">chameleon agate</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The glimmer of a <a exist="12345678" noun="amber">piece of golden amber</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The glimmer of a <a exist="12345678" noun="spinel">blue spinel</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">large puddle</a> on the floor.
The glimmer of a <a exist="12345678" noun="deathstone">black deathstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="highwayman">half-elven highwayman</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="bandit">human bandit</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="marauder">half-krolvin marauder</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="thug">giantman thug</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="adept">she</a><popBold/> falls, "Letta, Leth, Latoth..."
The glimmer of a <a exist="12345678" noun="gem">golden beryl gem</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="vysan">white vysan</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="phantom">phantom</a><popBold/> slowly settles to the ground and begins to dissipate.
The <pushBold/><a exist="12345678" noun="vysan">white vysan</a><popBold/> screams evilly one last time and goes still.
The <pushBold/><a exist="12345678" noun="spider">greater ice spider's</a><popBold/> body jerks one last time and dies.
The <pushBold/><a exist="12345678" noun="cockatrice">snowy cockatrice</a><popBold/> rolls over on its back, emits a final screech and dies.
The <pushBold/><a exist="12345678" noun="spider">greater ice spider</a><popBold/> collapses to the ground and dies.
The <pushBold/><a exist="12345678" noun="shade">frost shade</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="spectre">snow spectre</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="gremlin">green gremlin</a><popBold/> falls to the ground and dies with a gentle sigh.
The <pushBold/><a exist="12345678" noun="gremlin">orange gremlin</a><popBold/> sighs one last time and dies.
The <pushBold/><a exist="12345678" noun="ranger">troll ranger</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="troll">hunter troll</a><popBold/> looks up with hatred as <pushBold/><a exist="12345678" noun="troll">he</a><popBold/> lets out <pushBold/><a exist="12345678" noun="troll">his</a><popBold/> final breath.
All that remains of the <pushBold/><a exist="12345678" noun="tegu">tegu</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
All that remains of the <pushBold/><a exist="12345678" noun="troll">troll</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="seer">herself</a><popBold/>, then collapses with a wheeze.
The <pushBold/><a exist="12345678" noun="hobgoblin">mongrel hobgoblin</a><popBold/> lets out a final scream and goes still.
All that remains of the <pushBold/><a exist="12345678" noun="troll">troll</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> spits an unintelligible oath as <pushBold/><a exist="12345678" noun="seer">he</a><popBold/> collapses.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="herald">her</a><popBold/> pupil-less green eyes frozen in a dead stare.
The glimmer of a <a exist="12345678" noun="pearl">large pink pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="janissary">Ithzir janissary</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="janissary">her</a><popBold/> lips as <pushBold/><a exist="12345678" noun="janissary">she</a><popBold/> falls.
The glimmer of a <a exist="12345678" noun="tourmaline">green tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The glimmer of a <a exist="12345678" noun="tourmaline">black tourmaline</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">large puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> slumps over dead, her skin still pulsating with a blinding white hue.
The glimmer of <a exist="12345678" noun="coral">some polished red coral</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The glimmer of <a exist="12345678" noun="coral">some polished red coral</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="pearl">tiny grey pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="rolton">rolton</a><popBold/> collapses to the ground, emits a final bleat, and dies.
The glimmer of a <a exist="12345678" noun="pearl">medium grey pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> falls to the floor dead, her skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="radical">triton radical</a><popBold/> slumps over dead, her skin still pulsating with a blinding white hue.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> wheezes, an incredulous look on <pushBold/><a exist="12345678" noun="seer">her</a><popBold/> face as <pushBold/><a exist="12345678" noun="seer">she</a><popBold/> falls.
The glimmer of a <a exist="12345678" noun="peridot">blue peridot</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="guard">shelfae guard</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="swine">ebon swine</a><popBold/> collapses to the ground, emits a final squeal, and dies.
The <pushBold/><a exist="12345678" noun="woodsman">spectral woodsman</a><popBold/> slumps silently to the ground and begins to rapidly dissipate.
The <pushBold/><a exist="12345678" noun="farmhand">rotting farmhand</a><popBold/> falls to the ground, rotting flesh falling from <pushBold/><a exist="12345678" noun="farmhand">her</a><popBold/> bones.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> screams as <pushBold/><a exist="12345678" noun="adept">she</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The glimmer of a <a exist="12345678" noun="amethyst">deep purple amethyst</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The glimmer of a <a exist="12345678" noun="starstone">green starstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">large puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="witch">water witch</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="bard">shan bard</a><popBold/> yips in pain as <pushBold/><a exist="12345678" noun="bard">he</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="sorceress">shan sorceress</a><popBold/> yips in pain as <pushBold/><a exist="12345678" noun="sorceress">she</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="sorcerer">shan sorcerer</a><popBold/> howls out one last time and dies.
The <pushBold/><a exist="12345678" noun="shaman">shan shaman</a><popBold/> yips in pain as <pushBold/><a exist="12345678" noun="shaman">she</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="warrior">shan warrior</a><popBold/> yips in pain as <pushBold/><a exist="12345678" noun="warrior">he</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="wizard">shan wizard</a><popBold/> yips in pain as <pushBold/><a exist="12345678" noun="wizard">he</a><popBold/> falls to the ground motionless.
All that remains of the <pushBold/><a exist="12345678" noun="gremlock">gremlock</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
A nebulous haze shimmers into view around <pushBold/>an <a exist="12345678" noun="sentry">ethereal triton sentry</a><popBold/>, plunging inward in a dizzying spiral to envelop <pushBold/><a exist="12345678" noun="sentry">her</a><popBold/> completely!  Silhouetted within the shifting spiritual miasma, the <pushBold/><a exist="12345678" noun="sentry">sentry's</a><popBold/> form withers, wasting away to an attenuated mockery of <pushBold/><a exist="12345678" noun="sentry">herself</a><popBold/>.  Even this pale shadow disintegrates, dissolving on the air as the last cloudy tendrils vanish.
The <pushBold/><a exist="12345678" noun="herald">Ithzir herald</a><popBold/> coughs, causing a greenish fluid to dribble down <pushBold/><a exist="12345678" noun="herald">her</a><popBold/> lips as <pushBold/><a exist="12345678" noun="herald">she</a><popBold/> falls.
The glimmer of a <a exist="12345678" noun="sapphire">star sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The glimmer of a <a exist="12345678" noun="ruby">star ruby</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="troll">jungle troll</a><popBold/> falls to the ground as the stillness of death overtakes <pushBold/><a exist="12345678" noun="troll">her</a><popBold/>.
The <pushBold/><a exist="12345678" noun="seer">Ithzir seer</a><popBold/> screams as <pushBold/><a exist="12345678" noun="seer">he</a><popBold/> collapses, "Granoth!  Tal issar leti!"
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> staggers, feebly trying to catch <pushBold/><a exist="12345678" noun="adept">herself</a><popBold/>, then collapses with a wheeze.
The <pushBold/><a exist="12345678" noun="scout">Ithzir scout</a><popBold/> asks incredulously, "Hor?  Kla val ptath...?" then falls, <pushBold/><a exist="12345678" noun="scout">his</a><popBold/> pupil-less green eyes frozen in a dead stare.
All that remains of the <pushBold/><a exist="12345678" noun="wraith">wraith</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="dissembler">triton dissembler</a><popBold/> falls to the floor dead, his skin still pulsating with a blinding white hue.
All that remains of the <pushBold/><a exist="12345678" noun="griffin">griffin</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="mugger">gnomish mugger</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="thug">human thug</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="bandit">giantman bandit</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="mugger">dwarven mugger</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="marauder">half-elven marauder</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="brigand">dwarven brigand</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="rogue">elven rogue</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="bandit">dwarven bandit</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="rogue">half-elven rogue</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="mugger">half-elven mugger</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="mugger">human mugger</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="robber">elven robber</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="thug">human thug</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="thug">dwarven thug</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="bandit">halfling bandit</a><popBold/> rolls over and dies.
The glimmer of a <a exist="12345678" noun="gem">golden beryl gem</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="adept">Ithzir adept</a><popBold/> chuckles wryly as <pushBold/><a exist="12345678" noun="adept">he</a><popBold/> falls, "Letta, Leth, Latoth..."
The glimmer of <a exist="12345678" noun="quartz">some dragonfire quartz</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The glimmer of a <a exist="12345678" noun="pearl">tiny pink pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into the water.
The glimmer of a <a exist="12345678" noun="amber">piece of golden amber</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="spinel">red spinel</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The glimmer of an <a exist="12345678" noun="emerald">uncut emerald</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="pearl">small pink pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="guard">troll guard</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="initiate">troll initiate</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="hunter">troll hunter</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="cleric">troll cleric</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="guard">troll guard</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="dissembler">troll dissembler</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="zealot">troll zealot</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="marauder">troll marauder</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="archer">troll archer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="ranger">troll ranger</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="scout">troll scout</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="sniper">troll sniper</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="soldier">troll soldier</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="scout">troll scout</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="healer">troll healer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="destroyer">troll destroyer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="barbarian">troll barbarian</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="fighter">troll fighter</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="sorcerer">troll sorcerer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="barbarian">troll barbarian</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="cleric">troll cleric</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pillager">troll pillager</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="wrathbringer">troll wrathbringer</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="warlock">troll warlock</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="wizard">troll wizard</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="paladin">troll paladin</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="skirmisher">troll skirmisher</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="sorceress">troll sorceress</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="wizard">troll wizard</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="scourge">troll scourge</a><popBold/> rolls over and dies.
All that remains of the <pushBold/><a exist="12345678" noun="giant">giant</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="empath">troll empath</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="adept">troll adept</a><popBold/> rolls over and dies.
All that remains of the <pushBold/><a exist="12345678" noun="titan">titan</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="pillager">troll pillager</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="fighter">troll fighter</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="archer">troll archer</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="witch">troll witch</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="warrior">troll warrior</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="raider">troll raider</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="skirmisher">troll skirmisher</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="raider">troll raider</a><popBold/> rolls over and dies.
The glimmer of a <a exist="12345678" noun="dreamstone">green dreamstone</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
The <pushBold/><a exist="12345678" noun="healer">troll healer</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="initiate">troll initiate</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="empath">troll empath</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="sentinel">troll sentinel</a><popBold/> rolls over and dies.
The <pushBold/><a exist="12345678" noun="pillager">half-krolvin pillager</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="pirate">dwarven pirate</a><popBold/> falls to the ground and dies.
All that remains of the <pushBold/><a exist="12345678" noun="defender">defender</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
All that remains of the <pushBold/><a exist="12345678" noun="elemental">elemental</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
All that remains of the <pushBold/><a exist="12345678" noun="elemental">elemental</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
All that remains of the <pushBold/><a exist="12345678" noun="siren">siren</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The <pushBold/><a exist="12345678" noun="executioner">triton executioner</a><popBold/> falls to the floor dead, his skin still pulsating with a blinding white hue.
The glimmer of a <a exist="12345678" noun="spinel">violet spinel</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
All that remains of the <pushBold/><a exist="12345678" noun="defender">defender</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The glimmer of a <a exist="12345678" noun="sapphire">blue sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">small puddle</a> on the floor.
All that remains of the <pushBold/><a exist="12345678" noun="siren">siren</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
All that remains of the <pushBold/><a exist="12345678" noun="executioner">executioner</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
All that remains of the <pushBold/><a exist="12345678" noun="combatant">combatant</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
All that remains of the <pushBold/><a exist="12345678" noun="radical">radical</a><popBold/> is a charred ashen figure of its former self lying upon the ground.
The glimmer of a <a exist="12345678" noun="agate">chameleon agate</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The glimmer of a <a exist="12345678" noun="sapphire">yellow sapphire</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">large puddle</a> on the floor.
All that remains of the <pushBold/><a exist="12345678" noun="combatant">combatant</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
All that remains of the <pushBold/><a exist="12345678" noun="radical">radical</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
All that remains of the <pushBold/><a exist="12345678" noun="dissembler">dissembler</a><popBold/> is a charred ashen figure of its former self lying upon the floor.
The <pushBold/><a exist="12345678" noun="sorceress">troll sorceress</a><popBold/> rolls over and dies.
As the fire leaves <pushBold/><a exist="12345678" noun="troll">her</a><popBold/> eyes, the <pushBold/><a exist="12345678" noun="troll">lava troll</a><popBold/> cries out in pain one last time and expires.
The <pushBold/><a exist="12345678" noun="troll">lava troll</a><popBold/> falls to the ground, <pushBold/><a exist="12345678" noun="troll">her</a><popBold/> living fire extinguished.
The <pushBold/><a exist="12345678" noun="troll">lava troll</a><popBold/> falls to the ground, <pushBold/><a exist="12345678" noun="troll">his</a><popBold/> living fire extinguished.
The <pushBold/><a exist="12345678" noun="ogre">fire ogre</a><popBold/> falls to the ground, <pushBold/><a exist="12345678" noun="ogre">her</a><popBold/> living fire extinguished.
As the fire leaves <pushBold/><a exist="12345678" noun="giant">her</a><popBold/> eyes, the <pushBold/><a exist="12345678" noun="giant">fire giant</a><popBold/> cries out in pain one last time and expires.
As the fire leaves <pushBold/><a exist="12345678" noun="troll">his</a><popBold/> eyes, the <pushBold/><a exist="12345678" noun="troll">lava troll</a><popBold/> cries out in pain one last time and expires.
The <pushBold/><a exist="12345678" noun="sprite">fire sprite</a><popBold/> goes limp and <pushBold/><a exist="12345678" noun="sprite">she</a><popBold/> falls over as the fire slowly fades from <pushBold/><a exist="12345678" noun="sprite">her</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="mage">fire mage</a><popBold/> goes limp and <pushBold/><a exist="12345678" noun="mage">he</a><popBold/> falls over as the fire slowly fades from <pushBold/><a exist="12345678" noun="mage">his</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="tsark">red tsark</a><popBold/> goes limp and <pushBold/><a exist="12345678" noun="tsark">she</a><popBold/> falls over as the fire slowly fades from <pushBold/><a exist="12345678" noun="tsark">her</a><popBold/> eyes.
The <pushBold/><a exist="12345678" noun="nest">wasp nest</a><popBold/> collapses into a pile of rubble.
The glimmer of a <a exist="12345678" noun="pearl">small white pearl</a> catches your eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles eerily and collapses into a puddle of water.
The <pushBold/><a exist="12345678" noun="elemental">water elemental</a><popBold/> gurgles and collapses into the <a exist="12345678" noun="puddle">large puddle</a> on the floor.
The deep blue glow emanating from the <pushBold/><a exist="12345678" noun="glacei">minor glacei</a><popBold/> goes dark suddenly.
The <pushBold/><a exist="12345678" noun="bear">grizzly bear</a><popBold/> lets out a blood-curdling roar and dies.
The <pushBold/><a exist="12345678" noun="manticore">arctic manticore</a><popBold/> falls to the ground and dies.
The <pushBold/><a exist="12345678" noun="guardian">cold guardian</a><popBold/> falls to the ground motionless.
The <pushBold/><a exist="12345678" noun="manticore">arctic manticore</a><popBold/> screams one last time and dies.
The <pushBold/><a exist="12345678" noun="giant">tundra giant</a><popBold/> cries out in cold agony one last time and dies.
The <pushBold/><a exist="12345678" noun="troll">ice troll</a><popBold/> screams evilly one last time and goes still.
The <pushBold/><a exist="12345678" noun="farmhand">rotting farmhand</a><popBold/> wails in terrifying pain one last time and lies still.
The <pushBold/><a exist="12345678" noun="wight">tomb wight</a><popBold/> screams evilly one last time and goes still.
The <pushBold/><a exist="12345678" noun="spider">tomb spider's</a><popBold/> body jerks one last time and dies.
__DEATH_CORPUS__

CONTROL_CORPUS = <<'__CONTROL_CORPUS__'.freeze
A <a exist="12345678" noun="sling">thick canvas sling</a> falls to the ground.
A <a exist="12345678" noun="harpoon">lackluster blue steel harpoon</a> falls to the ground.
The <pushBold/><a exist="829974211" noun="warrior">warrior's</a><popBold/> <a exist="829974212" noun="hammer">war hammer</a> falls to the ground.
The <pushBold/><a exist="834140194" noun="troll">troll's</a><popBold/> <a exist="834140196" noun="knurl">wooden knurl</a> falls to the ground.
The <pushBold/><a exist="833193072" noun="guardsman">guardsman's</a><popBold/> <a exist="833193073" noun="Hammer of Kai">rusted Hammer of Kai</a> falls to the ground.
__CONTROL_CORPUS__

RSpec.describe "Lich::Gemstone::Infomon::XMLParser NpcDeathMessage" do
  npc_death_message = Lich::Gemstone::Infomon::XMLParser::Pattern::NpcDeathMessage

  positive_lines = DEATH_CORPUS.each_line.to_a
  negative_lines = CONTROL_CORPUS.each_line.to_a

  describe "positive corpus (real death messages must be detected)" do
    it "exposes the NpcDeathMessage pattern" do
      expect(npc_death_message).to be_a(Regexp)
    end

    it "matches every real death line in the embedded corpus" do
      expect(positive_lines).not_to be_empty

      misses = positive_lines.each_with_index.filter_map do |line, idx|
        "  ##{idx + 1}: #{line.strip[0, 120]}" unless line =~ npc_death_message
      end

      expect(misses).to be_empty,
                        "Expected every death line to match, but #{misses.size} did not:\n#{misses.join("\n")}"
    end
  end

  describe "negative corpus (item-drop messages must NOT be detected)" do
    it "does not match any control game line in the embedded corpus" do
      expect(negative_lines).not_to be_empty

      false_positives = negative_lines.filter_map do |line|
        "  #{line.strip[0, 120]}" if line =~ npc_death_message
      end

      expect(false_positives).to be_empty,
                                 "Item-drop lines were wrongly detected as deaths:\n#{false_positives.join("\n")}"
    end
  end

  # A few explicit, human-readable cases so a reviewer can see the intent directly,
  # independent of the bulk corpus loops above.
  describe "representative cases" do
    it "matches a wrathful-look triton death" do
      line = %(The <pushBold/><a exist="12345678" noun="combatant">triton combatant</a><popBold/> ) +
             %(gurgles once and goes still, a wrathful look on <pushBold/><a exist="12345678" ) +
             %(noun="combatant">his</a><popBold/> face.\r\n)
      expect(line =~ npc_death_message).not_to be_nil
    end

    it "matches a gem-glimmer water elemental death" do
      line = %(The glimmer of a <a exist="12345678" noun="zircon">yellow zircon</a> catches your ) +
             %(eye as the <pushBold/><a exist="12345678" noun="elemental">water elemental</a>) +
             %(<popBold/> gurgles eerily and collapses into the water.\r\n)
      expect(line =~ npc_death_message).not_to be_nil
    end

    it "matches a soul-rising spectre death" do
      line = %(You hear a sound like a child weeping as a white glow separates itself from the ) +
             %(<pushBold/><a exist="12345678" noun="spectre">shadowy spectre's</a><popBold/> ) +
             %(body and rises into the heavens.\r\n)
      expect(line =~ npc_death_message).not_to be_nil
    end

    it "matches the bare-pronoun grey-mist death" do
      line = %(The <pushBold/><a exist="12345678" noun="mare">night mare</a><popBold/> ) +
             %(collapses to the ground, a thick grey mist pouring from her nostrils.\r\n)
      expect(line =~ npc_death_message).not_to be_nil
    end

    it "does NOT match a war hammer falling to the ground" do
      line = %(The <pushBold/><a exist="829974211" noun="warrior">warrior's</a><popBold/> ) +
             %(<a exist="829974212" noun="hammer">war hammer</a> falls to the ground.\r\n)
      expect(line =~ npc_death_message).to be_nil
    end

    it "does NOT match a dropped Hammer of Kai" do
      line = %(The <pushBold/><a exist="833193072" noun="guardsman">guardsman's</a><popBold/> ) +
             %(<a exist="833193073" noun="Hammer of Kai">rusted Hammer of Kai</a> ) +
             %(falls to the ground.\r\n)
      expect(line =~ npc_death_message).to be_nil
    end
  end
end
