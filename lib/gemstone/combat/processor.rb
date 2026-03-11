# frozen_string_literal: true

#
# Combat Processor V2 - State machine approach for efficient parsing
# Transitions: SEEKING_ATTACK -> SEEKING_DAMAGE -> SEEKING_CRIT -> (repeat)
#

require_relative '../creature'
require_relative '../critranks'

module Lich
  module Gemstone
    module Combat
      module Processor
        module_function

        # Process a chunk of game lines for combat events
        def process(chunk)
          events = parse_events(chunk)
          return if events.empty?

          events.each { |event| persist_event(event) }

          respond "[Combat] Processed #{events.size} events" if Tracker.debug?
        end

        # State machine parser
        def parse_events(lines)
          events = []
          current_event = nil
          parse_state = :seeking_attack
          current_target = nil

          lines.each_with_index do |line, index|
            next if line.strip.empty?

            # Always check for status effects on every line (even outside combat)
            if Tracker.settings[:track_statuses]
              if (status_result = Parser.parse_status(line))
                # Always try to extract target ID from XML first
                line_target = Parser.extract_target_from_line(line)

                if line_target && line_target[:id]
                  # Use ID-based lookup - this is most reliable
                  if status_result.is_a?(Hash)
                    apply_status_to_target(status_result[:status], line_target[:name], line_target[:id], status_result[:action])
                  else
                    # Legacy format - status_result is just the status symbol
                    apply_status_to_target(status_result, line_target[:name], line_target[:id], :add)
                  end
                elsif status_result.is_a?(Hash) && status_result[:target]
                  # Fallback to name-based lookup only if no ID available
                  apply_status_to_target(status_result[:status], status_result[:target], nil, status_result[:action])
                end
                respond "[Combat] Found status effect: #{status_result}" if Tracker.debug?
              end
            end

            # Always check for UCS events on every line
            if Tracker.settings[:track_ucs]
              if (ucs_result = Parser.parse_ucs(line))
                apply_ucs_to_target(ucs_result, current_target)
                respond "[Combat] Found UCS event: #{ucs_result}" if Tracker.debug?
              end
            end

            # Extract target from current line (for multi-target attacks like volley)
            line_target = Parser.extract_target_from_line(line)

            # If we found a new target and we're in combat, handle target switching
            if line_target && parse_state != :seeking_attack
              # Check if this is a real target switch (different creature)
              if current_target && current_target[:id] != line_target[:id]
                # Save previous event if it has data
                if current_event && current_event[:target][:id] &&
                   (!current_event[:damages].empty? || !current_event[:crits].empty? || !current_event[:statuses].empty?)
                  events << current_event
                  respond "[Combat] Saved event for #{current_event[:target][:name]}: #{current_event[:damages].size} damages, #{current_event[:crits].size} crits, #{current_event[:statuses].size} statuses" if Tracker.debug?
                end

                # Create new event for this target (inherit attack name from previous)
                current_event = {
                  name: current_event ? current_event[:name] : :unknown,
                  target: line_target,
                  damages: [],
                  crits: [],
                  statuses: []
                }
                current_target = line_target
                respond "[Combat] Switched to target: #{line_target[:name]} (#{line_target[:id]})" if Tracker.debug?

              elsif current_target.nil?
                # First target for current event - just set it, don't discard data
                current_event[:target] = line_target
                current_target = line_target
                respond "[Combat] Found target: #{line_target[:name]} (#{line_target[:id]})" if Tracker.debug?
              end
              # If current_target[:id] == line_target[:id], do nothing (same target)
            end

            case parse_state
            when :seeking_attack
              # Only check for attacks when we're looking for them
              if (attack = Parser.parse_attack(line))
                # Save previous event if exists
                events << current_event if current_event && current_event[:target][:id]

                current_event = {
                  name: attack[:name],
                  target: attack[:target] || {},
                  damages: [],
                  crits: [],
                  statuses: []
                }

                respond "[Combat] Found attack: #{attack[:name]}" if Tracker.debug?
                parse_state = :seeking_damage
              end

            when :seeking_damage
              # Once in damage phase, check EVERY line for damage and status

              # Always check for damage (accumulate all damage lines)
              if (damage = Parser.parse_damage(line))
                current_event[:damages] << damage
                respond "[Combat] Found damage: #{damage}" if Tracker.debug?

                # When we find damage, look ahead 2-3 lines for related crit
                if Tracker.settings[:track_wounds]
                  (1..3).each do |offset|
                    next_line_index = index + offset
                    break if next_line_index >= lines.size

                    next_line = lines[next_line_index]

                    # Stop looking if we hit another damage line (belongs to next damage)
                    if Parser.parse_damage(next_line)
                      respond "[Combat] Stopped crit search - found next damage line" if Tracker.debug?
                      break
                    end

                    # Look for crit on this line
                    if (c = CritRanks.parse(next_line.gsub(/<.+?>/, '')).values.first)
                      current_event[:crits] << {
                        type: c[:type],
                        location: c[:location],
                        rank: c[:rank],
                        wound_rank: c[:wound_rank],
                        fatal: c[:fatal]
                      }
                      respond "[Combat] Found critical hit: #{c[:location]} rank #{c[:wound_rank]}" if Tracker.debug?
                      break # Only take first crit found after this damage
                    end
                  end
                end
              end

              # Note: Status effects are now checked globally on every line above

              # Check for new attack (means we're done with previous)
              if Parser.parse_attack(line)
                # Save current event before starting new attack
                if current_event && current_event[:target][:id] &&
                   (!current_event[:damages].empty? || !current_event[:crits].empty?)
                  events << current_event
                  respond "[Combat] Completed event for #{current_event[:target][:name]}: #{current_event[:damages].size} damages, #{current_event[:crits].size} crits" if Tracker.debug?
                end
                parse_state = :seeking_attack
                redo # Process this line as new attack
              end
            end
          end

          # Don't forget the last event
          events << current_event if current_event && current_event[:target][:id]

          events
        end

        # Apply combat event to creature instance (same as before)
        def persist_event(event)
          target = event[:target]
          return unless target[:id]

          creature = Creature[target[:id].to_i]
          unless creature
            respond "[Combat] No creature found for ID #{target[:id]}" if Tracker.debug?
            return
          end

          respond "[Combat] Applying to #{creature.name} (#{target[:id]})" if Tracker.debug?

          # Apply direct damage
          total_damage = 0
          event[:damages].each do |damage|
            creature.add_damage(damage)
            total_damage += damage
            respond "  +#{damage} damage" if Tracker.debug?
          end

          # Apply critical wounds
          if Tracker.settings[:track_wounds]
            event[:crits].each do |crit|
              if crit[:wound_rank] && crit[:wound_rank] > 0
                # Map CritRanks location to creature body part format
                body_part = map_critranks_to_body_part(crit[:location])
                if body_part
                  creature.add_injury(body_part, crit[:wound_rank])
                  respond "  +wound: #{body_part} rank #{crit[:wound_rank]}" if Tracker.debug?
                else
                  respond "  !unknown body part: #{crit[:location]}" if Tracker.debug?
                end
              end

              # Check for fatal critical hit
              if crit[:fatal]
                creature.mark_fatal_crit!
                respond "  +FATAL CRIT: #{crit[:location]} - creature died from crit, not HP loss" if Tracker.debug?
              end
            end
          end

          # Apply status effects
          if Tracker.settings[:track_statuses]
            event[:statuses].each do |status|
              creature.add_status(status)
              respond "  +status: #{status}" if Tracker.debug?
            end
          end

          respond "  Total damage applied: #{total_damage}" if total_damage > 0 && Tracker.debug?
        end

        # Apply UCS event to a creature
        def apply_ucs_to_target(ucs_result, current_target = nil)
          target_id = ucs_result[:target_id]

          # For tierup events, use current combat target if no ID in the event
          target_id ||= current_target[:id] if current_target && ucs_result[:type] == :tierup

          return unless target_id

          creature = Creature[target_id.to_i]
          return unless creature

          case ucs_result[:type]
          when :position
            creature.set_ucs_position(ucs_result[:value])
            respond "[Combat] Set UCS position #{ucs_result[:value]} on #{creature.name} (#{creature.id})" if Tracker.debug?

          when :tierup
            creature.set_ucs_tierup(ucs_result[:value])
            respond "[Combat] Set UCS tierup #{ucs_result[:value]} on #{creature.name} (#{creature.id})" if Tracker.debug?

          when :smite_on
            creature.smite!
            respond "[Combat] Applied smite to #{creature.name} (#{creature.id})" if Tracker.debug?

          when :smite_off
            creature.clear_smote
            respond "[Combat] Cleared smite from #{creature.name} (#{creature.id})" if Tracker.debug?
          end
        rescue => e
          respond "[Combat] Error applying UCS: #{e.message}" if Tracker.debug?
        end

        # Apply status effect directly to a creature (outside combat events)
        def apply_status_to_target(status, target_name_or_id, target_id = nil, action = :add)
          # Handle both name lookup and direct ID
          if target_id
            creature = Creature[target_id.to_i]
          else
            # Try to find creature by name - this is less reliable
            # but might work for some cases
            return unless defined?(Creature)
            creatures = Creature.all.select { |c| c.name&.downcase&.include?(target_name_or_id.downcase) }
            creature = creatures.first if creatures.size == 1
          end

          if creature
            if action == :remove
              creature.remove_status(status)
              respond "[Combat] Removed status #{status} from #{creature.name} (#{creature.id})" if Tracker.debug?
            else
              creature.add_status(status)
              respond "[Combat] Applied status #{status} to #{creature.name} (#{creature.id})" if Tracker.debug?
            end
          else
            respond "[Combat] Could not find creature for status: #{status} -> #{target_name_or_id}" if Tracker.debug?
          end
        end

        # Map CritRanks location strings to creature body part constants
        def map_critranks_to_body_part(location)
          return nil unless location

          case location.to_s.downcase.gsub(/[^a-z]/, '')
          when 'leftarm', 'larm' then 'leftArm'
          when 'rightarm', 'rarm' then 'rightArm'
          when 'leftleg', 'lleg' then 'leftLeg'
          when 'rightleg', 'rleg' then 'rightLeg'
          when 'lefthand', 'lhand' then 'leftHand'
          when 'righthand', 'rhand' then 'rightHand'
          when 'leftfoot', 'lfoot' then 'leftFoot'
          when 'rightfoot', 'rfoot' then 'rightFoot'
          when 'lefteye', 'leye' then 'leftEye'
          when 'righteye', 'reye' then 'rightEye'
          when 'head' then 'head'
          when 'neck' then 'neck'
          when 'chest' then 'chest'
          when 'abdomen', 'abs' then 'abdomen'
          when 'back' then 'back'
          when 'nerves' then 'nerves'
          else
            # Try the location as-is in case it's already correct
            location.to_s if CreatureInstance::BODY_PARTS.include?(location.to_s)
          end
        end
      end
    end
  end
end
