module GameSetting
  def GameSetting.load(*args)
    Setting.load(args.collect { |a| "#{XMLData.game}:#{a}" })
  end

  def GameSetting.save(hash)
    game_hash = Hash.new
    hash.each_pair { |k, v| game_hash["#{XMLData.game}:#{k}"] = v }
    Setting.save(game_hash)
  end
end
