# frozen_string_literal: true

module Infomon
  # this module handles all of the logic for parsing game lines that infomon depends on
  module XMLParser
    module Pattern
      NpcDeathMessage = /^The (?:<pushBold\/>)?<a.*?exist=["'](?<npc_id>\-?[0-9]+)["'].*?>.*?<\/a>(?:<popBold\/>)? falls to the ground (?:motionless|and dies)[\.!]\r?\n?$/

      All = Regexp.union(NpcDeathMessage)
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
