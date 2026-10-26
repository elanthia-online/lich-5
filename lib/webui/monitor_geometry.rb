# frozen_string_literal: true

require 'json'
require 'open3'
require 'timeout'
require_relative 'native_host'

module Lich
  module WebUI
    # Bounded display discovery and selection shared by native and shim consumers.
    # Measurements are hints; the host retains authority over window placement.
    class MonitorGeometry
      UNAVAILABLE = { source: 'unavailable', screens: [] }.freeze
      WINDOWS_QUERY = <<~'POWERSHELL'.freeze
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class LichMonitorWindow { [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); }'
        $active = [System.Windows.Forms.Screen]::FromHandle([LichMonitorWindow]::GetForegroundWindow())
        $screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
          @{ x=$_.Bounds.X; y=$_.Bounds.Y; width=$_.Bounds.Width; height=$_.Bounds.Height;
             primary=$_.Primary; active=($_.DeviceName -eq $active.DeviceName) }
        })
        @{ source='native'; screens=$screens } | ConvertTo-Json -Compress -Depth 4
      POWERSHELL

      # Rejects malformed provider data; returned snapshots contain no native identifiers.
      # @param value [Hash] source and at most 32 display rectangles
      # @return [Hash] fresh, validated snapshot, or the unavailable sentinel
      def self.normalize(value)
        return UNAVAILABLE unless value.is_a?(Hash)

        value = value.transform_keys(&:to_sym)
        screens = value[:screens]
        return UNAVAILABLE unless %w[native browser unavailable].include?(value[:source]) && screens.is_a?(Array) && screens.length <= 32

        normalized = screens.map do |screen|
          return UNAVAILABLE unless screen.is_a?(Hash)

          screen = screen.transform_keys(&:to_sym)
          return UNAVAILABLE unless %i[x y].all? { |key| screen[key].is_a?(Integer) && screen[key].between?(-65_536, 65_536) }
          return UNAVAILABLE unless %i[width height].all? { |key| screen[key].is_a?(Integer) && screen[key].between?(1, 65_536) }
          return UNAVAILABLE unless %i[primary active].all? { |key| [true, false].include?(screen[key]) }

          screen.slice(:x, :y, :width, :height, :primary, :active).freeze
        end
        { source: value[:source].dup.freeze, screens: normalized.freeze }.freeze
      end

      # Resolves one request, retaining an explicit fallback flag when selection is unavailable.
      # @param snapshot [Hash] provider snapshot
      # @param target [Symbol] :active, :primary, or :point
      # @param point [Array<Integer>, nil] signed desktop point for :point
      # @return [Hash] rectangle/source/fallback, or source unavailable
      # @raise [ArgumentError] for malformed requests
      def self.select(snapshot, target: :active, point: nil)
        valid = %i[active primary point].include?(target)
        valid &&= if target == :point
                    point.is_a?(Array) && point.length == 2 && point.all? { |n| n.is_a?(Integer) && n.between?(-65_536, 65_536) }
                  else
                    point.nil?
                  end
        raise ArgumentError, 'invalid monitor selection' unless valid

        snapshot = normalize(snapshot)
        screens = snapshot[:screens]
        return { source: 'unavailable', fallback: true }.freeze if screens.empty?

        selected = screens.find do |screen|
          if target == :point
            point[0] >= screen[:x] && point[0] < screen[:x] + screen[:width] &&
              point[1] >= screen[:y] && point[1] < screen[:y] + screen[:height]
          else
            screen[target]
          end
        end
        fallback = selected.nil?
        selected ||= screens.find { |screen| screen[:active] } || screens.find { |screen| screen[:primary] } || screens.first
        selected.slice(:x, :y, :width, :height).merge(source: snapshot[:source], fallback: fallback).freeze
      end

      # Discovers local host screens before a viewer exists; failures remain explicit.
      # @return [Hash] bounded snapshot, never invented dimensions
      def snapshot
        raw = if OS.mac?
                JSON.parse(run([NativeHost::EXECUTABLE, '--monitors']))
              elsif OS.windows?
                JSON.parse(run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', WINDOWS_QUERY]))
              else
                linux_snapshot(run(['xrandr', '--listactivemonitors']))
              end
        self.class.normalize(raw)
      rescue StandardError
        UNAVAILABLE
      end

      private

      # Bounds helper lifetime/output and always reaps the owned discovery process.
      def run(argv)
        Open3.popen2e(*argv) do |input, output, process|
          input.close
          begin
            Timeout.timeout(3) do
              result = output.read(65_537)
              raise Error, 'monitor discovery output exceeds limit' if result.bytesize > 65_536
              raise Error, 'monitor discovery failed' unless process.value.success?

              result
            end
          ensure
            unless process.join(0)
              Process.kill('KILL', process.pid) rescue nil
              process.join
            end
          end
        end
      end

      # XRandR is optional; Wayland/restricted hosts use browser measurements or unavailable.
      def linux_snapshot(output)
        screens = output.lines.filter_map do |line|
          match = line.match(/\s\d+:\s+(\S+)\s+(\d+)\/\d+x(\d+)\/\d+([+-]\d+)([+-]\d+)/)
          next unless match

          { x: match[4].to_i, y: match[5].to_i, width: match[2].to_i, height: match[3].to_i,
            primary: match[1].include?('*'), active: false }
        end
        # XRandR reports topology but not the user's active window. Primary is a fallback.
        { source: 'native', screens: screens }
      end
    end
  end
end
