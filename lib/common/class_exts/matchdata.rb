# extension to class MatchData 2025-03-14

class MatchData
  def to_struct
    OpenStruct.new to_hash
  end

  def to_hash
    Hash[self.names.zip(self.captures.map(&:strip).map do |capture|
      if capture.is_i? then capture.to_i else capture end
    end)]
  end
end
