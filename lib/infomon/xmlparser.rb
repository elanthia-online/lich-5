# frozen_string_literal: true

module Infomon
  # this module handles all of the logic for parsing game lines that infomon depends on
  module XMLParser
    module Pattern
      NpcDeathMessage = /^The (?:<pushBold\/>)?<a.*?exist=["'](?<npc_id>\-?[0-9]+)["'].*?>.*?<\/a>(?:<popBold\/>)? (?:falls to the ground|howls in agony one last time) (?:motionless|and dies)[\.!]\r?\n?$/
      Group_Short = /(?:group|following you|IconJOINED)|^You are leading/

      All = Regexp.union(NpcDeathMessage, Group_Short)
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
          if (match_data = Group::Observer.wants?(line))
            Group::Observer.consume(line.strip, match_data)
            :ok
          else
            :noop
          end
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
