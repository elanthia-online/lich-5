# frozen_string_literal: true

=begin
  ArgParser provides argument parsing for lich scripts.

  Matches script arguments against definition patterns and returns
  an OpenStruct of matched values, or displays help and exits if
  no match is found.

  @see https://elanthipedia.play.net/Lich_script_development#dependency
=end

require 'ostruct'

module Lich
  module Common
    CORE_ARGPARSER = true

    class ArgParser
      # Parses script arguments against definition patterns.
      #
      # @param data [Array<Array<Hash>>] array of definition sets
      # @param flex_args [Boolean] whether to allow unmatched args
      # @return [OpenStruct] matched arguments
      def parse_args(data, flex_args = false)
        raw_args = variable.first
        baselist = variable.drop(1).dup || Array.new

        unless baselist.size == 1 && baselist.grep(/^help$|^\?$|^h$/).any?
          result = data.map { |definition| check_match(definition, baselist.dup, flex_args) }.compact

          return result.first if result.length == 1

          if result.empty?
            echo "***INVALID ARGUMENTS DON'T MATCH ANY PATTERN***"
            respond "Provided Arguments: '#{raw_args}'"
          elsif result.length > 1
            echo '***INVALID ARGUMENTS MATCH MULTIPLE PATTERNS***'
            respond "Provided Arguments: '#{raw_args}'"
          end
        end

        display_args(data)
        exit
      end

      # Displays help/usage information for a script.
      #
      # @param data [Array<Array<Hash>>] argument definition sets
      def display_args(data)
        return if Script.current.name == "bootstrap"

        data.each do |def_set|
          def_set
            .select { |x| x[:name].to_s == "script_summary" }
            .each { |x| respond " SCRIPT SUMMARY: #{x[:description]} " }
          respond ''
          respond " SCRIPT CALL FORMAT AND ARG DESCRIPTIONS (arguments in brackets are optional):"
          respond "  ;#{Script.current.name} " + def_set.map { |x| format_item(x) unless x[:name].to_s == "script_summary" }.join(' ')
          def_set
            .reject { |x| x[:name].to_s == "script_summary" }
            .each { |x| respond "   #{(x[:display] || x[:name]).ljust(12)} #{x[:description]} #{x[:options] ? '[' + x[:options].join(', ') + ']' : ''}" }
        end

        # Display help output for settings used in the script. Relies on base-help.yaml.
        if respond_to?(:get_data, true)
          yaml_data = get_data('help').to_h
          yaml_settings = yaml_data.select { |_field, info| info.is_a?(Hash) && info["referenced_by"]&.include?(Script.current.name) }

          unless yaml_settings.empty?
            respond ''
            respond " YAML SETTINGS USED:"
            yaml_settings.each do |field, info|
              setting_line = "   #{field}: #{info["description"]} #{info.dig("specific_descriptions", Script.current.name)}"
              setting_line += " [Ex: #{info["example"]}]" unless info["example"].to_s.empty?
              respond setting_line
            end
            respond ""
          end
        end
      end

      private

      def matches_def(definition, item)
        echo "#{definition}:#{item}" if UserVars.parse_args_debug
        return true if definition[:regex] && definition[:regex] =~ item
        return true if definition[:options] && definition[:options].find { |option| item =~ /^#{option}#{'$' if definition[:option_exact]}/i }

        false
      end

      def check_match(defs, vars, flex)
        args = OpenStruct.new

        defs.reject { |x| x[:optional] }.each do |definition|
          return nil unless matches_def(definition, vars.first)

          args[definition[:name]] = vars.first.downcase
          vars.shift
        end

        defs.select { |x| x[:optional] }.each do |definition|
          if (match = vars.find { |x| matches_def(definition, x) })
            args[definition[:name]] = match.downcase
            vars.delete(match)
          end
        end

        if flex
          args.flex = vars

          profiles = Dir[File.join(SCRIPT_DIR, 'profiles/*.*')]
          profiles.each do |profile|
            profile = profile[/.*#{Regexp.escape(checkname)}-(\w*).yaml/, 1]
            args.to_h.values.each do |arg|
              if arg == profile
                echo "WARNING: yaml profile '#{checkname}-#{arg}.yaml' matches script argument '#{arg}'."
                echo "Favoring the script argument. Rename the file if you intend to call it as a flexed settings file."
              end
            end
          end
        else
          return nil unless vars.empty?
        end

        args
      end

      def format_item(definition)
        item = definition[:display] || definition[:name]
        if definition[:optional]
          item = "[#{item}]"
        elsif definition[:variable] || definition[:options]
          item = "<#{item}>"
        end
        item
      end
    end
  end
end

# Top-level alias so scripts can use bare `ArgParser.new` without
# fully qualifying the Lich::Common namespace.
ArgParser = Lich::Common::ArgParser unless defined?(::ArgParser)
