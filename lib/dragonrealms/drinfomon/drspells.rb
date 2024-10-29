module DRSpells
  @@known_spells = {}
  @@known_feats = {}
  @@spellbook_format = nil # 'column-formatted' or 'non-column'

  @@grabbing_known_spells = false

  # Use this to silence the initial output
  # of calling 'spells' command to populate our data.
  @@silence_known_spells_hook = false

  def self.active_spells
    XMLData.dr_active_spells
  end

  def self.known_spells
    @@known_spells
  end

  def self.known_feats
    @@known_feats
  end

  def self.slivers
    XMLData.dr_active_spells_slivers
  end

  def self.stellar_percentage
    XMLData.dr_active_spells_stellar_percentage
  end

  def self.grabbing_known_spells
    @@grabbing_known_spells
  end

  def self.grabbing_known_spells=(val)
    @@grabbing_known_spells = val
  end

  def self.spellbook_format
    @@spellbook_format
  end

  def self.spellbook_format=(val)
    @@spellbook_format = val
  end
end
