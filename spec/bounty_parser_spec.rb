require 'bounty'

class Bounty
  describe Parser, "#parse" do
    it "can tell when we don't have a task" do
      bounty = described_class.parse "You are not currently assigned a task."
        expect(bounty[:task]).to eq(:none)
        expect(bounty[:status]).to eq(:none)
    end

    context "when assigned a task" do
      it "can tell we were assigned a cull task" do
        bounty = described_class.parse "It appears they have a creature problem they'd like you to solve"
        expect(bounty[:task]).to eq(:cull)
        expect(bounty[:status]).to eq(:assigned)
      end

      it "can tell we were assigned an heirloom task" do
        bounty = described_class.parse "It appears they need your help in tracking down some kind of lost heirloom"
        expect(bounty[:task]).to eq(:heirloom)
        expect(bounty[:status]).to eq(:assigned)
      end

      it "can tell we were assigned a skins task" do
        bounty = described_class.parse "The local furrier Furrier has an order to fill and wants our help"
        expect(bounty[:task]).to eq(:skins)
        expect(bounty[:status]).to eq(:assigned)
      end

      it "can tell we were assigned a gem task" do
        bounty = described_class.parse "The local gem dealer, GemTrader, has an order to fill and wants our help"
        expect(bounty[:task]).to eq(:gem)
        expect(bounty[:status]).to eq(:assigned)
      end

      it "can tell we were assigned a gem task" do
        bounty = described_class.parse "The taskmaster told you:  \"Hmm, I've got a task here from the town of Ta'Vaalor.  The local gem dealer, Areacne, has an order to fill and wants our help. Head over there and see what you can do.  Be sure to ASK about BOUNTIES.\""
        expect(bounty[:task]).to eq(:gem)
        expect(bounty[:status]).to eq(:assigned)
      end

      it "can tell we were assigned a herb task" do
        bounty = described_class.parse "Hmm, I've got a task here from the town of Ta'Illistim.  The local herbalist's assistant, Jhiseth, has asked for our aid.  Head over there and see what you can do.  Be sure to ASK about BOUNTIES."
        expect(bounty[:task]).to eq(:herb)
        expect(bounty[:status]).to eq(:assigned)
        expect(bounty[:town]).to eq("Ta'Illistim")
      end

      it "can tell we were assigned a rescue task" do
        bounty = described_class.parse "It appears that a local resident urgently needs our help in some matter"
        expect(bounty[:task]).to eq(:rescue)
        expect(bounty[:status]).to eq(:assigned)
      end

      it "can tell we were assigned a bandit task" do
        bounty = described_class.parse "The taskmaster told you:  \"Hmm, I've got a task here from the town of Ta'Illistim.  It appears they have a bandit problem they'd like you to solve.  Go report to one of the guardsmen just inside the Ta'Illistim City Gate to find out more.  Be sure to ASK about BOUNTIES.\""
        expect(bounty[:task]).to eq(:bandit)
        expect(bounty[:status]).to eq(:assigned)
      end
    end

    context "completed a task" do
      it "can tell we have completed a taskmaster task" do
        bounty = described_class.parse "You have succeeded in your task and can return to the Adventurer's Guild"
        expect(bounty[:task]).to eq(:taskmaster)
        expect(bounty[:status]).to eq(:done)
      end

      it "knows the heirloom item name for a completed heirloom task" do
        bounty = described_class.parse "You have located an elegantly carved jade tiara and should bring it back to one of the guardsmen just inside the Ta'Illistim City Gate."
        expect(bounty[:task]).to eq(:heirloom)
        expect(bounty[:status]).to eq(:done)
        expect(bounty[:requirements][:item]).to eq("elegantly carved jade tiara")
        expect(bounty[:town]).to eq("Ta'Illistim")
      end

      it "knows the heirloom item name for a completed heirloom task" do
        bounty = described_class.parse "You have located some moonstone inset mithril earrings and should bring it back to one of the guardsmen just inside the Ta'Illistim City Gate."
        expect(bounty[:task]).to eq(:heirloom)
        expect(bounty[:status]).to eq(:done)
        expect(bounty[:requirements][:item]).to eq("moonstone inset mithril earrings")
        expect(bounty[:town]).to eq("Ta'Illistim")
      end

      it "a completed heirloom task in the Landing" do
        bounty = described_class.parse "You have located a bloodstone studded hair pin and should bring it back to Quin Telaren of Wehnimer's Landing."
        expect(bounty[:task]).to eq(:heirloom)
        expect(bounty[:status]).to eq(:done)
        expect(bounty[:requirements][:item]).to eq("bloodstone studded hair pin")
        expect(bounty[:town]).to eq("Wehnimer's Landing")
      end


      [
        ["Ta'Illistim", "You succeeded in your task and should report back to one of the guardsmen just inside the Ta'Illistim City Gate."],
        ["Icemule Trace", "You succeeded in your task and should report back to one of the Icemule Trace gate guards."],
        ["Ta'Vaalor", "You succeeded in your task and should report back to one of the Ta'Vaalor gate guards."],
        ["Vornavis" , "You succeeded in your task and should report back to one of the Vornavis gate guards."],
        ["Wehnimer's Landing", "You succeeded in your task and should report back to Quin Telaren of Wehnimer's Landing."],
        ["Kharam-Dzu", "You succeeded in your task and should report back to the dwarven militia sergeant near the Kharam-Dzu town gates."],
        ["Kraken's Fall", "You succeeded in your task and should report back to the sentry just outside Kraken's Fall."],
        ["Kraken's Fall", "You succeeded in your task and should report back to the sentry just outside town."],
        ["Zul Logoth", "You succeeded in your task and should report back to one of the Zul Logoth tunnel guards."],
      ].each do |(town, task_desc)|
        it "in #{town}" do
          bounty = described_class.parse task_desc
          expect(bounty).to_not be_nil
          expect(bounty[:status]).to eq(:done)
          expect(bounty[:town]).to eq(town)
        end
      end
    end

    context "triggered a task" do
        it "can tell we have triggered a rescue task for a male child" do
          bounty = described_class.parse "You have made contact with the child you are to rescue and you must get him back alive to one of the guardsmen just inside the Sapphire Gate."
          expect(bounty[:task]).to eq(:rescue)
          expect(bounty[:status]).to eq(:triggered)
        end

        it "can tell we have triggered a rescue task for a female child" do
          bounty = described_class.parse "You have made contact with the child you are to rescue and you must get her back alive to Quin Telaren of Wehnimer's Landing."
          expect(bounty[:task]).to eq(:rescue)
          expect(bounty[:status]).to eq(:triggered)
          expect(bounty[:town]).to eq("Wehnimer's Landing")
        end

        it "can tell we have triggered a rescue task for a female child" do
          bounty = described_class.parse "You have made contact with the child you are to rescue and you must get her back alive to one of the guardsmen just inside the gate."
          expect(bounty[:task]).to eq(:rescue)
          expect(bounty[:status]).to eq(:triggered)
        end

        it "can tell we have triggered a rescue task for a female child in Solhaven" do
          bounty = described_class.parse "You have made contact with the child you are to rescue and you must get her back alive to one of the Vornavis gate guards."
          expect(bounty[:task]).to eq(:rescue)
          expect(bounty[:status]).to eq(:triggered)
          expect(bounty[:town]).to eq("Vornavis")
        end

        it "can tell we have triggered a rescue task for a child in Icemule" do
          bounty = described_class.parse "You have made contact with the child you are to rescue and you must get her back alive to one of the Icemule Trace gate guards or the halfing Belle at the Pinefar Trading Post."
          expect(bounty[:task]).to eq(:rescue)
          expect(bounty[:status]).to eq(:triggered)
          expect(bounty[:town]).to eq("Icemule Trace")
        end

        it "can tell we have triggered a rescue task for a child on Teras" do
          bounty = described_class.parse "You have made contact with the child you are to rescue and you must get her back alive to the dwarven militia sergeant near the Kharam-Dzu town gates."
          expect(bounty[:task]).to eq(:rescue)
          expect(bounty[:status]).to eq(:triggered)
          expect(bounty[:town]).to eq("Kharam-Dzu")
        end

        it "can tell we have triggered a rescue task for a child in Vaalor" do
          bounty = described_class.parse "You have made contact with the child you are to rescue and you must get him back alive to one of the Ta'Vaalor gate guards."
          expect(bounty[:task]).to eq(:rescue)
          expect(bounty[:status]).to eq(:triggered)
          expect(bounty[:town]).to eq("Ta'Vaalor")
        end

        it "can tell we have triggered a dangerous task (male critter)" do
          bounty = described_class.parse "You have been tasked to hunt down and kill a particularly dangerous critter type that has established a territory in some hunting ground near a place.  You have provoked his attention and now you must kill him!"
          expect(bounty[:task]).to eq(:dangerous)
          expect(bounty[:status]).to eq(:triggered)
          expect(bounty.dig(:requirements, :area)).to eq("some hunting ground")
          expect(bounty.dig(:requirements, :creature)).to eq("critter type")
        end

        it "can tell we have triggered a dangerous task (female critter)" do
          bounty = described_class.parse "You have been tasked to hunt down and kill a particularly dangerous critter type that has established a territory in some hunting ground near a place.  You have provoked his attention and now you must kill her!"
          expect(bounty[:task]).to eq(:dangerous)
          expect(bounty[:status]).to eq(:triggered)
          expect(bounty.dig(:requirements, :area)).to eq("some hunting ground")
          expect(bounty.dig(:requirements, :creature)).to eq("critter type")
        end

        it "can tell we have triggered a dangerous task (unsexed critter)" do
          bounty = described_class.parse "You have been tasked to hunt down and kill a particularly dangerous critter type that has established a territory in some hunting ground near a place.  You have provoked his attention and now you must kill it!"
          expect(bounty[:task]).to eq(:dangerous)
          expect(bounty[:status]).to eq(:triggered)
          expect(bounty.dig(:requirements, :area)).to eq("some hunting ground")
          expect(bounty.dig(:requirements, :creature)).to eq("critter type")
      end

        it "can tell we have triggered a dangerous task (return to area)" do
          bounty = described_class.parse "You have been tasked to hunt down and kill a particularly dangerous critter type that has established a territory in some hunting ground near a place.  You have provoked his attention and now you must return to where you left her and kill it!"
          expect(bounty[:task]).to eq(:dangerous)
          expect(bounty[:status]).to eq(:triggered)
          expect(bounty.dig(:requirements, :area)).to eq("some hunting ground")
          expect(bounty.dig(:requirements, :creature)).to eq("critter type")
        end
    end

    context "have an unfinished task" do
      it "can tell we have an unfinished bandit task (fresh)" do
        bounty = described_class.parse "You have been tasked to suppress bandit activity on Sylvarraend Road near Ta'Illistim.  You need to kill 20 of them to complete your task."
        expect(bounty[:task]).to eq(:bandit)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:town]).to eq("Ta'Illistim")
        expect(bounty[:requirements]).to include({ :area => "Sylvarraend Road", :number => 20, :creature => 'bandit' })
      end

      it "can tell we have an unfinished bandit task in KF (partially completed)" do
        bounty = described_class.parse "You have been tasked to suppress bandit activity near Widowmaker's Road near Kraken's Fall.  You need to kill 11 more of them to complete your task."
        expect(bounty[:task]).to eq(:bandit)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:town]).to eq("Kraken's Fall")
        expect(bounty[:requirements]).to include({ :area => "Widowmaker's Road", :number => 11, :creature => 'bandit' })
      end

      it "can tell we have an unfinished cull task (fresh)" do
        bounty = described_class.parse "You have been tasked to suppress glacial morph activity in Gossamer Valley near Ta'Illistim.  You need to kill 24 of them to complete your task."
        expect(bounty[:task]).to eq(:cull)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:town]).to eq("Ta'Illistim")
        expect(bounty[:requirements]).to include({ :creature => "glacial morph", :area => "Gossamer Valley", :number => 24 })
      end

      it "can tell we have an unfinished cull task (fresh assist)" do
        bounty = described_class.parse "You have been tasked to help Brikus suppress war griffin activity in Old Ta'Faendryl.  You need to kill 14 of them to complete your task."
        expect(bounty[:task]).to eq(:cull)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :creature => "war griffin", :area => "Old Ta'Faendryl", :number => 14 })
      end

      it "can tell we have an unfinished cull task (partially completed assist)" do
        bounty = described_class.parse "You have been tasked to help Buddy suppress triton radical activity in the Ruined Temple near Kharam-Dzu.  You need to kill 12 more of them to complete your task."
        expect(bounty[:task]).to eq(:cull)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:town]).to eq("Kharam-Dzu")
        expect(bounty[:requirements]).to include({ :creature => "triton radical", :area => "Ruined Temple", :number => 12 })
      end

      context "can tell we have an unfinished heirloom task" do
        it "can parse a loot task" do
          bounty = described_class.parse "You have been tasked to recover a dainty pearl string bracelet that an unfortunate citizen lost after being attacked by a festering taint in Old Ta'Faendryl.  The heirloom can be identified by the initials VF engraved upon it.  Hunt down the creature and LOOT the item from its corpse."
          expect(bounty[:task]).to eq(:heirloom)
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:requirements]).to include({
            :action => "loot", :area => "Old Ta'Faendryl", :creature => "festering taint",
            :item => "dainty pearl string bracelet"
          })
        end

        it "can parse a loot task" do
          bounty = described_class.parse "You have been tasked to recover an onyx-inset copper torc that an unfortunate citizen lost after being attacked by a centaur near Darkstone Castle near Wehnimer's Landing.  The heirloom can be identified by the initials ZK engraved upon it.  Hunt down the creature and LOOT the item from its corpse."
          expect(bounty[:task]).to eq(:heirloom)
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:town]).to eq("Wehnimer's Landing")
          expect(bounty[:requirements]).to include({
            :action => "loot", :area => "Darkstone Castle", :creature => "centaur",
            :item => "onyx-inset copper torc"
          })
        end

        it "can parse a loot task between two towns" do
          bounty = described_class.parse "You have been tasked to recover a gold-trimmed mithril circlet that an unfortunate citizen lost after being attacked by a swamp troll in the Central Caravansary between Wehnimer's Landing and Solhaven.  The heirloom can be identified by the initials CT engraved upon it.  Hunt down the creature and LOOT the item from its corpse."
          expect(bounty[:task]).to eq(:heirloom)
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:town]).to eq("Wehnimer's Landing and Solhaven")
          expect(bounty[:requirements]).to include({
            :action => "loot", :area => "Central Caravansary", :creature => "swamp troll",
            :item => "gold-trimmed mithril circlet"
          })
        end

        it "can parse a bandit task between two towns" do
          bounty = described_class.parse "You have been tasked to help Buddy suppress bandit activity in the grasslands between Wehnimer's Landing and Solhaven.  You need to kill 18 of them to complete your task."
          expect(bounty[:task]).to eq(:bandit)
          expect(bounty[:town]).to eq("Wehnimer's Landing and Solhaven")
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:requirements]).to include({
            :area => "grasslands",
            :creature => "bandit",
            :number => 18,
          })
        end


        it "can parse a search task" do
          bounty = described_class.parse "You have been tasked to recover an interlaced gold and ora ring that an unfortunate citizen lost after being attacked by a black forest viper in the Blighted Forest near Ta'Illistim.  The heirloom can be identified by the initials MS engraved upon it.  SEARCH the area until you find it."
          expect(bounty[:task]).to eq(:heirloom)
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:town]).to eq("Ta'Illistim")
          expect(bounty[:requirements]).to include({
            :action => "search", :area => "Blighted Forest", :creature => "black forest viper",
            :item => "interlaced gold and ora ring"
          })
        end
      end

      context "can tell we have an unfinished skins task" do
        it "with a one word town name" do
          bounty = described_class.parse "You have been tasked to retrieve 8 madrinol skins of at least fair quality for Gaedrein in Ta'Illistim.  You can SKIN them off the corpse of a snow madrinol or purchase them from another adventurer.  You can SELL the skins to the furrier as you collect them.\""
          expect(bounty[:task]).to eq(:skins)
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:town]).to eq("Ta'Illistim")
          expect(bounty[:requirements]).to include({
            :creature => "snow madrinol",
            :quality => "fair",
            :number => 8,
            :skin => "madrinol skin",
            :town => "Ta'Illistim",
          })
        end

        it "with a multipart town name" do
          bounty = described_class.parse "You have been tasked to retrieve 5 thrak tails of at least exceptional quality for the furrier in the Company Store in Kharam-Dzu.  You can SKIN them off the corpse of a red-scaled thrak or purchase them from another adventurer.  You can SELL the skins to the furrier as you collect them.\""
          expect(bounty[:task]).to eq(:skins)
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:town]).to eq("Kharam-Dzu")
          expect(bounty[:requirements]).to include({
            :creature => "red-scaled thrak",
            :quality => "exceptional",
            :number => 5,
            :skin => "thrak tail",
            :town => "Kharam-Dzu",
          })
        end
      end

      it "can tell we have an unfinished gem task" do
        bounty = described_class.parse "The gem dealer in Ta'Illistim, Tanzania, has received orders from multiple customers requesting an azure blazestar.  You have been tasked to retrieve 10 of them.  You can SELL them to the gem dealer as you find them."
        expect(bounty[:task]).to eq(:gem)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :gem => "azure blazestar", :number => 10, :town => "Ta'Illistim" })
      end

      it "can tell we have an unfinished escort task" do
        bounty = described_class.parse "The taskmaster told you:  \"I've got a special mission for you.  A certain client has hired us to provide a protective escort on his upcoming journey.  Go to the area just inside the Sapphire Gate and WAIT for him to meet you there.  You must guarantee his safety to Zul Logoth as soon as you can, being ready for any dangers that the two of you may face.  Good luck!\""
        expect(bounty[:task]).to eq(:escort)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :destination => "Zul Logoth", :start => "the area just inside the Sapphire Gate" })
      end

      it "can tell we have an unfinished escort task" do
        bounty = described_class.parse "I've got a special mission for you.  A certain client has hired us to provide a protective escort on her upcoming journey.  Go to the south end of North Market and WAIT for her to meet you there.  You must guarantee her safety to Zul Logoth as soon as you can, being ready for any dangers that the two of you may face.  Good luck!"
        expect(bounty[:task]).to eq(:escort)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :destination => "Zul Logoth", :start => "the south end of North Market" })
      end

      context 'for herbs' do
        it "can tell we have an unfinished herb task" do
          bounty = described_class.parse "The herbalist's assistant in Ta'Illistim, Jhiseth, is working on a concoction that requires a sprig of holly found in Griffin's Keen near Ta'Illistim.  These samples must be in pristine condition.  You have been tasked to retrieve 6 samples."
          expect(bounty[:task]).to eq(:herb)
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:requirements]).to include({
            :herb   => "sprig of holly",
            :area   => "Griffin's Keen",
            :number => 6,
            :town   => "Ta'Illistim",
          })
        end

        it 'can parse an Icemule herb task' do
          bounty = described_class.parse "The healer in Icemule Trace, Mirtag, is working on a concoction that requires a withered deathblossom found in the Rift.  These samples must be in pristine condition.  You have been tasked to retrieve 7 samples."
          expect(bounty[:task]).to eq(:herb)
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:requirements]).to include({
            :herb   => "withered deathblossom",
            :area   => "Rift",
            :number => 7,
            :town   => "Icemule Trace",
          })
        end

        it 'can parse an Icemule herb task' do
          bounty = described_class.parse "The healer in Icemule Trace, Mirtag, is working on a concoction that requires a withered black mushroom found in the subterranean tunnels under Icemule Trace.  These samples must be in pristine condition.  You have been tasked to retrieve 5 samples."
          expect(bounty[:task]).to eq(:herb)
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:requirements]).to include({
            :herb   => "withered black mushroom",
            :area   => "subterranean tunnels",
            :number => 5,
            :town   => "Icemule Trace",
          })
        end

        it "can parse an Icemule task for an area between two towns" do
          bounty = described_class.parse "The healer in Icemule Trace, Mirtag, is working on a concoction that requires some bolmara lichen found on the Icemule Trail between Wehnimer's Landing and Icemule Trace.  These samples must be in pristine condition.  You have been tasked to retrieve 9 samples."
          expect(bounty[:task]).to eq(:herb)
          expect(bounty[:status]).to eq(:unfinished)
          expect(bounty[:requirements]).to include({
            :herb   => "bolmara lichen",
            :area   => "Icemule Trail",
            :number => 9,
            :town   => "Icemule Trace",
          })
        end
      end

      it "can tell we have an unfinished dangerous task" do
        bounty = described_class.parse "You have been tasked to hunt down and kill a particularly dangerous gnarled being that has established a territory in Old Ta'Faendryl.  You can get its attention by killing other creatures of the same type in its territory."
        expect(bounty[:task]).to eq(:dangerous)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :creature => "being", :area => "Old Ta'Faendryl" })
      end

      it "can tell we have an unfinished rescue task" do
        bounty = described_class.parse "You have been tasked to rescue the young runaway son of a local citizen.  A local divinist has had visions of the child fleeing from a black forest ogre in the Blighted Forest near Ta'Illistim.  Find the area where the child was last seen and clear out the creatures that have been tormenting him in order to bring him out of hiding."
        expect(bounty[:task]).to eq(:rescue)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :area => "Blighted Forest", :creature => "black forest ogre" })
      end

      it "can tell we have an unfinished rescue task" do
        bounty = described_class.parse "You have been tasked to rescue the young kidnapped daughter of a local citizen.  A local divinist has had visions of the child fleeing from a stone sentinel in Darkstone Castle near Wehnimer's Landing.  Find the area where the child was last seen and clear out the creatures that have been tormenting her in order to bring her out of hiding."
        expect(bounty[:task]).to eq(:rescue)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :area => "Darkstone Castle", :creature => "stone sentinel" })
      end

      it "can tell we have an unfinished rescue task" do
        bounty = described_class.parse "You have been tasked to rescue the young kidnapped son of a local citizen.  A local divinist has had visions of the child fleeing from a ghostly pooka in the Shadow Valley.  Find the area where the child was last seen and clear out the creatures that have been tormenting him in order to bring him out of hiding."
        expect(bounty[:task]).to eq(:rescue)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :area => "Shadow Valley", :creature => "ghostly pooka" })
      end

      it "can parse a rescue task for a 'near' area" do
        bounty = described_class.parse "You have been tasked to rescue the young runaway daughter of a local citizen.  A local divinist has had visions of the child fleeing from a nedum vereri near the Temple of Love near Wehnimer's Landing.  Find the area where the child was last seen and clear out the creatures that have been tormenting her in order to bring her out of hiding."
        expect(bounty[:task]).to eq(:rescue)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :area => "Temple of Love", :creature => "nedum vereri" })
      end

      it "can parse a dangerous task for a 'near' area" do
        bounty = described_class.parse "You have been tasked to hunt down and kill a particularly dangerous nedum vereri that has established a territory near the Temple of Love near Wehnimer's Landing.  You can get its attention by killing other creatures of the same type in its territory."
        expect(bounty[:task]).to eq(:dangerous)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :area => "Temple of Love", :creature => "nedum vereri" })
      end

      it "can parse a rescue task for an area between two towns" do
        bounty = described_class.parse "You have been tasked to rescue the young runaway daughter of a local citizen.  A local divinist has had visions of the child fleeing from a rotting corpse in Castle Varunar between Wehnimer's Landing and Solhaven.  Find the area where the child was last seen and clear out the creatures that have been tormenting her in order to bring her out of hiding."
        expect(bounty[:task]).to eq(:rescue)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({ :area => "Castle Varunar", :creature => "rotting corpse" })
      end

      it "can tell we have an unfinished assist rescue by culling task" do
        bounty = described_class.parse "You have been tasked to help Someguy rescue a missing child by suppressing emaciated hierophant activity in Temple Wyneb near Ta'Illistim during the rescue attempt.  You need to kill 7 more of them to complete your task."
        expect(bounty[:task]).to eq(:cull)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({
          :area => "Temple Wyneb",
          :number => 7,
          :creature => "emaciated hierophant"
        })
      end

      it "can tell we have an unfinished assist heirloom by culling task" do
        bounty = described_class.parse "You have been tasked to help Someguy retrieve an heirloom by suppressing emaciated hierophant activity in Temple Wyneb near Ta'Illistim during the retrieval effort.  You need to kill 19 of them to complete your task."
        expect(bounty[:task]).to eq(:cull)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({
          :area => "Temple Wyneb",
          :number => 19,
          :creature => "emaciated hierophant"
        })
      end

      it "can tell we have an unfinished assist dangerous by culling task" do
        bounty = described_class.parse "You have been tasked to help Someguy kill a dangerous creature by suppressing gnarled being activity in Old Ta'Faendryl during the hunt.  You need to kill 20 of them to complete your task."
        expect(bounty[:task]).to eq(:cull)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({
          :area => "Old Ta'Faendryl",
          :number => 20,
          :creature => "being"
        })
      end

      it "can tell we have an unfinished assist heirloom by culling task in OTF ducts" do
        bounty = described_class.parse "You have been tasked to help Thisdude retrieve an heirloom by suppressing gnarled being activity in Old Ta'Faendryl during the retrieval effort.  You need to kill 2 more of them to complete your task."
        expect(bounty[:task]).to eq(:cull)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({
          :area => "Old Ta'Faendryl",
          :number => 2,
          :creature => "being"
        })
      end

      it "can tell we have an unfinished assist heirloom by culling task" do
        bounty = described_class.parse "You have been tasked to help Friendo retrieve an heirloom by suppressing nedum vereri activity near the Temple of Love near Wehnimer's Landing during the retrieval effort.  You need to kill 4 more of them to complete your task."
        expect(bounty[:task]).to eq(:cull)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({
          :area => "Temple of Love",
          :number => 4,
          :creature => "nedum vereri"
        })
      end

      it "can tell we have an unfinished assist dangerous by culling task" do
        bounty = described_class.parse "You have been tasked to help Someguy kill a dangerous creature by suppressing emaciated hierophant activity in Temple Wyneb near Ta'Illistim during the hunt.  You need to kill 12 of them to complete your task."
        expect(bounty[:task]).to eq(:cull)
        expect(bounty[:status]).to eq(:unfinished)
        expect(bounty[:requirements]).to include({
          :area => "Temple Wyneb",
          :number => 12,
          :creature => "emaciated hierophant"
        })
      end
    end

    it "can recognize a failed bounty" do
      bounty = described_class.parse "You have failed in your task.  Return to the Adventurer's Guild for further instructions."
      expect(bounty[:status]).to eq(:failed)
      expect(bounty[:task]).to eq(:taskmaster)
    end

    it 'can recognize a failed rescue task' do
      bounty = described_class.parse "The child you were tasked to rescue is gone and your task is failed.  Report this failure to the Adventurer's Guild."
      expect(bounty[:status]).to eq(:failed)
      expect(bounty[:task]).to eq(:taskmaster)
    end
  end
end
