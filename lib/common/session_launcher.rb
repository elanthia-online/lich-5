# frozen_string_literal: true

require 'rbconfig'
require_relative 'authentication/login_helpers'

module Lich
  module Common
    # Launches independent child Lich sessions using prepared launch_data
    # mapped to CLI-style argv.
    module SessionLauncher
      class << self
        # Launches a detached child Lich process from prebuilt launch data.
        #
        # @param launch_data [Array<String>] Launch lines from Authentication::LaunchData.prepare
        # @param launch_context [Hash, nil] Optional context keys:
        #   :char_name, :game_code, :frontend, :custom_launch
        # @return [Hash] Structured result:
        #   - success: { ok: true, pid: Integer }
        #   - failure: { ok: false, error: String }
        def launch(launch_data, launch_context: nil)
          unless launch_data.is_a?(Array) && launch_data.any?
            return { ok: false, error: 'launch_data must be a non-empty Array' }
          end

          pid = spawn_process(launch_data, launch_context: launch_context)
          { ok: true, pid: pid }
        rescue StandardError => e
          { ok: false, error: e.message }
        end

        private

        # Spawns a detached child process using the same CLI footprint as direct login.
        #
        # @param launch_data [Array<String>]
        # @param launch_context [Hash, nil]
        # @return [Integer] Child PID
        def spawn_process(launch_data, launch_context: nil)
          ruby_bin = ruby_binary
          entrypoint = File.expand_path($PROGRAM_NAME)
          working_dir = defined?(LICH_DIR) ? LICH_DIR : Dir.pwd
          launch_map = parse_launch_data(launch_data)
          spawn_args = build_spawn_args(entrypoint, launch_map, launch_context)

          pid = spawn(ruby_bin, *spawn_args, chdir: working_dir)
          Process.detach(pid)
          pid
        end

        def build_spawn_args(entrypoint, launch_map, launch_context)
          context = launch_context || {}
          character = context[:char_name] || launch_map['CHARACTER'] || launch_map['NAME']
          game_code = context[:game_code] || launch_map['GAMECODE']
          frontend = context[:frontend] || frontend_from_launch(launch_map)
          custom_launch = context[:custom_launch] || launch_map['CUSTOMLAUNCH']

          raise ArgumentError, 'missing character for launcher spawn' if character.to_s.empty?

          args = [entrypoint, '--login', character.to_s]
          if game_code && !game_code.to_s.empty?
            game_flag = Lich::Common::Authentication::LoginHelpers.format_launch_flag(game_code)
            args << game_flag if game_flag
          end
          args << "--#{frontend}" if frontend && !frontend.to_s.empty?
          args << "--custom-launch=#{custom_launch}" if custom_launch && !custom_launch.to_s.empty?
          args
        end

        def parse_launch_data(launch_data)
          launch_data.each_with_object({}) do |line, data|
            next unless line.include?('=')

            key, value = line.split('=', 2)
            data[key.to_s.upcase] = value.to_s
          end
        end

        def frontend_from_launch(launch_map)
          case launch_map['GAME'].to_s.upcase
          when 'STORM' then 'stormfront'
          when 'WIZ' then 'wizard'
          when 'AVALON' then 'avalon'
          when 'SUKS' then 'suks'
          else nil
          end
        end

        # Mirrors existing CLI spawn behavior: use rubyw on Windows to avoid console.
        def ruby_binary
          if windows?
            RbConfig.ruby.sub(/ruby(?:\.exe)?$/i, 'rubyw.exe')
          else
            RbConfig.ruby
          end
        end

        def windows?
          RUBY_PLATFORM =~ /mingw|mswin|cygwin/i
        end
      end
    end
  end
end
