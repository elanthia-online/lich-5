module CharSetting
  def CharSetting.load(*args)
    Setting.load(args.collect { |a| "#{XMLData.game}:#{XMLData.name}:#{a}" })
  end

  def CharSetting.save(hash)
    game_hash = Hash.new
    hash.each_pair { |k, v| game_hash["#{XMLData.game}:#{XMLData.name}:#{k}"] = v }
    Setting.save(game_hash)
  end
end
