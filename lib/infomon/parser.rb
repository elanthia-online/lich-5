module Infomon
    # this module handles all of the logic for parsing game lines that infomon depends on
  module Parser
    module Pattern
      Stat = %r[\s+(?<stat>\w+)\s\(\w{3}\):\s+(?<value>\d+)\s\((?<bonus>[\w-]+)\)\s+\.\.\.\s+(?<enhanced_value>\d+)\s\((?<enhanced_bonus>\w+)\)]
      Citizenship = /^You currently have .*? citizenship in (?<town>.*)\.$/
      NoCitizenship = /You don't seem to have citizenship\./
      Society = /^\s+You are a (?:Master|member) (?:in|of) the (?<society>Order of Voln|Council of Light|Guardians of Sunfist)( at rank (?<rank>[0-9]+)| at step (?<rank>[0-9]+))?\.$/
      NoSociety = %r[^\s+You are not a member of any society at this time.]
      PSM = %r[^\s+(?<name>[\w\s\-']+)\s+(?<command>[a-z]+)\s+(?<ranks>\d)\/(?<max>\d)\s+]
    end

    def self.parse(line)
      begin
        case line
        when Pattern::Citizenship
          Infomon.set("citizenship", Regexp.last_match[:town])
          :ok
        when Pattern::NoCitizenship
          Infomon.set("citizenship", nil)
          :ok
        when Pattern::Stat
          match = Regexp.last_match
          Infomon.set("stat.%s" % match[:stat], match[:value].to_i)
          Infomon.set("stat.%s.bonus" % match[:stat], match[:bonus].to_i)
          Infomon.set("stat.%s.enhanced" % match[:stat], match[:enhanced_value].to_i)
          Infomon.set("stat.%s.enhanced_bonus" % match[:stat], match[:enhanced_bonus].to_i)
          :ok
        when Pattern::Society
          match = Regexp.last_match
          Infomon.set("society.status", match[:society])
          Infomon.set("society.rank", match[:rank])
          :ok
        when Pattern::NoSociety
          # todo: should this be nil?
          Infomon.set("society.status", "None")
          Infomon.set("society.rank", 0)
          :ok
        when Pattern::PSM
          match = Regexp.last_match
          Infomon.set("psm.%s" % match[:command], match[:ranks].to_i)
          :ok
        else
          :noop
        end
      rescue => exception
        puts exception
      end
    end
  end
end