# frozen_string_literal: true

require 'date'
require 'rubygems'

module Lich
  # Shared range/lifecycle interpretation; legacy readers ignore these fields.
  module RecoveryUnitPolicy
    class Error < StandardError; end
    NAME = /\A[a-zA-Z0-9_.-]+\z/

    def self.validate!(target)
      units = target.fetch('units')
      raise Error, 'recovery units must be an array' unless units.is_a?(Array)
      withdrawn = target.fetch('withdrawn_members', [])
      unless withdrawn.is_a?(Array) && withdrawn.uniq == withdrawn && withdrawn.all? { |name| name.is_a?(String) && NAME.match?(name) }
        raise Error, 'invalid withdrawn members'
      end
      units.each do |unit|
        range = unit['lich_versions']
        if unit.key?('lich_versions')
          unless range.is_a?(Hash) && !range.empty? && (range.keys - %w[min_inclusive max_exclusive]).empty? &&
                 range.values.all? { |version| version.is_a?(String) && !version.empty? && Gem::Version.correct?(version) }
            raise Error, 'invalid Lich version range'
          end
          if range.key?('min_inclusive') && range.key?('max_exclusive') && Gem::Version.new(range['min_inclusive']) >= Gem::Version.new(range['max_exclusive'])
            raise Error, 'empty Lich version range'
          end
          legacy = units.take_while { |item| !item.equal?(unit) }.reject { |item| item.key?('lich_versions') }
          covered = if unit.key?('legacy_unit')
                      legacy.any? { |item| item['id'] == unit['legacy_unit'] }
                    else
                      legacy.any? { |item| !(item.fetch('members') & unit.fetch('members')).empty? }
                    end
          unless covered
            raise Error, 'ranged units must follow legacy coverage for old first-match readers'
          end
        end
        names = unit.fetch('members') | unit.fetch('packages').map { |package| package.fetch('name') }
        raise Error, 'withdrawn member remains in a recovery unit' unless (names & withdrawn).empty?
        validate_lifecycle!(unit['lifecycle']) if unit.key?('lifecycle')
      end
      true
    end

    def self.validate_lifecycle!(data)
      unless data.is_a?(Hash) && data['state'] == 'obsolete' && (data.keys - %w[state until_date floor_lich_version]).empty? &&
             (data.keys & %w[until_date floor_lich_version]).length <= 1
        raise Error, 'invalid obsolete lifecycle metadata'
      end
      if data.key?('until_date')
        date = data['until_date']
        raise Error, 'invalid lifecycle end date' unless date.is_a?(String) && Date.iso8601(date).iso8601 == date
      end
      if data.key?('floor_lich_version')
        version = data['floor_lich_version']
        raise Error, 'invalid lifecycle floor' unless version.is_a?(String) && !version.empty? && Gem::Version.correct?(version)
      end
      true
    rescue ArgumentError
      raise Error, 'invalid lifecycle end date'
    end

    def self.applicable?(unit, version)
      range = unit['lich_versions']
      return true unless range
      raise Error, 'running Lich version is required for ranged recovery' unless version.is_a?(String) && !version.empty? && Gem::Version.correct?(version)
      current = Gem::Version.new(version)
      (!range['min_inclusive'] || current >= Gem::Version.new(range['min_inclusive'])) &&
        (!range['max_exclusive'] || current < Gem::Version.new(range['max_exclusive']))
    end

    def self.select(target, version)
      validate!(target)
      units = target.fetch('units')
      ranged = units.select { |unit| unit.key?('lich_versions') && applicable?(unit, version) }
      identities = {}
      ranged.each do |unit|
        unit.fetch('packages').each do |package|
          name = package.fetch('name')
          identity = package.values_at('version', 'sha256')
          raise Error, "ambiguous ranged recovery: #{name}" if identities.key?(name) && identities[name] != identity
          identities[name] = identity
        end
      end
      # A legacy closure is indivisible: retain it only if none of its members
      # are superseded, otherwise it could reintroduce an old shared package.
      replaced = ranged.flat_map { |unit| unit.fetch('members') }
      legacy = units.reject { |unit| unit.key?('lich_versions') || !(unit.fetch('members') & replaced).empty? }
      ranged + legacy
    end
  end
end
