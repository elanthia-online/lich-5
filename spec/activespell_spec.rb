require 'infomon/activespell'

# actual format of XMLData.active_spells is a hash represented as
# "Spell.name"=>String where string is a Time obj converted to string.
# To test capture we will use the following format in the response
# "Spell.name"=>"String" which allows the hash to be instantiated

module XMLData
  def self.active_spells
    testbed = {"Spirit Warding I"=>"2023-03-16 20:53:54.138611 -0400", "Iron Skin"=>"2023-03-16 21:01:58.138801 -0400", "Foresight"=>"2023-03-16 21:02:26.139419 -0400", "Mindward"=>"2023-03-16 21:02:32.139583 -0400", "Dragonclaw"=>"2023-03-16 21:02:38.139756 -0400", "Rolling Krynch Stance"=>"2033-03-13 20:33:39.139986 -0400" }

    return testbed
  end

  def self.process_spell_durations=(val)
    val
  end
end

describe ActiveSpell do
  context "updates spell information" do
    it "queries XMLData" do
      XMLData.process_spell_durations = true
      ActiveSpell.get_spell_info

      expect(ActiveSpell.instance_variable_get("@update_spell_names")).to eql(["Spirit Warding I", "Iron Skin", "Foresight", "Mindward", "Dragonclaw", "Rolling Krynch Stance"])

      expect(ActiveSpell.instance_variable_get("@update_spell_durations").keys[0]).to eql(%[Spirit Warding I])
      expect(ActiveSpell.instance_variable_get("@update_spell_durations").values[2]).to eql(%[2023-03-16 21:02:26.139419 -0400])
      expect(ActiveSpell.instance_variable_get("@update_spell_durations").keys[5]).to eql(%[Rolling Krynch Stance])
    end
  end
end
