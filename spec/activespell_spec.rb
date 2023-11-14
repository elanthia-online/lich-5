# actual format of XMLData.active_spells is a hash represented as
# "Spell.name"=>String where string is a Time obj converted to string.
# To test capture we will use the following format in the response
# "Spell.name"=>"String") which allows the hash to be instantiated

require 'infomon/activespell'

describe ActiveSpell do
  context "updates spell information" do
    it "queries XMLData" do
      testbed = { "Bravery" => "2023-03-16 16:23:01.205027 -0400", "Heroism" => "2023-03-16 16:23:01.205062 -0400", "Elemental Defense I" => "2023-03-16 18:35:20.205097 -0400", "Elemental Defense II" => "2023-03-16 18:35:20.205133 -0400", "Elemental Defense III" => "2023-03-16 18:35:20.205167 -0400", "Elemental Targeting" => "2023-03-16 18:35:20.205202 -0400", "Elemental Barrier" => "2023-03-16 18:35:20.205238 -0400", "Thurfel's Ward" => "2023-03-16 18:35:20.205272 -0400", "Elemental Deflection" => "2023-03-16 18:35:20.205304 -0400", "Elemental Bias" => "2023-03-16 18:35:20.205339 -0400", "Strength" => "2023-03-16 18:35:20.205373 -0400", "Elemental Focus" => "2023-03-16 18:35:20.205405 -0400", "Mage Armor - Fire" => "2023-03-16 18:35:20.205442 -0400", "Haste" => "2023-03-16 18:35:20.205472 -0400", "Temporal Reversion" => "2023-03-16 18:35:20.205507 -0400", "Prismatic Guard" => "2023-03-16 18:35:20.205541 -0400", "Mass Blur" => "2023-03-16 18:35:20.205575 -0400", "Melgorehn's Aura" => "2023-03-16 18:35:20.205606 -0400" }

      update_spell_names, update_spell_durations = ActiveSpell.get_spell_info(testbed)

      expect(update_spell_names).to eq(["Bravery", "Heroism", "Elemental Defense I", "Elemental Defense II", "Elemental Defense III", "Elemental Targeting", "Elemental Barrier", "Thurfel's Ward", "Elemental Deflection", "Elemental Bias", "Strength", "Elemental Focus", "Mage Armor", "Haste", "Temporal Reversion", "Prismatic Guard", "Mass Blur", "Melgorehn's Aura"])

      expect(update_spell_durations.keys[0]).to eq(%[Bravery])
      expect(update_spell_durations.values[2]).to eq(%[2023-03-16 18:35:20.205097 -0400])
      expect(update_spell_durations.keys[17]).to eq(%[Mage Armor])
    end
  end
end
