# frozen_string_literal: true

require 'rubygems/resolver'
require_relative 'dependency_recovery'

module Lich
  # Windows startup policy comes from the accepted manifest, not a shipped
  # lockfile. Installed newer versions remain eligible; active versions count.
  class AcceptedGemPolicy
    Error = DependencyRecovery::Error
    # Policy acquisition/coverage failures are distinct from broken local gems.
    class LocalInstallationError < Error; end
    class PolicyError < Error; end
    class AcquisitionError < PolicyError; end
    class InvalidPolicyError < PolicyError; end
    class CoverageError < PolicyError; end

    Check = Struct.new(:plan, :needed, :specs, keyword_init: true)

    class InstalledSet < Gem::Resolver::Set
      def initialize(find_specs, platforms)
        super()
        @find_specs = find_specs
        @platforms = platforms
        self.remote = false
      end

      def find_all(request)
        @find_specs.call(request.name).select do |spec|
          request.match?(spec) && (@platforms.key?(spec.name) ? spec.platform.to_s == @platforms[spec.name] : Gem::Platform.match_spec?(spec))
        end
      end
    end

    def initialize(recovery: DependencyRecovery.new, find_specs: Gem::Specification.method(:find_all_by_name), loaded_specs: Gem.loaded_specs)
      @recovery = recovery
      @find_specs = find_specs
      @loaded_specs = loaded_specs
    end

    def check(dependencies)
      dependencies = Array(dependencies)
      raise Error, 'no required startup dependencies were declared' if dependencies.empty?
      plan = @recovery.policy_plan(dependencies.map(&:name))
      unless plan.success?
        type = plan.error_kind == :acquisition ? AcquisitionError : InvalidPolicyError
        raise type, plan.error
      end
      supplied = self.class.supplied_gems(plan.target)
      covered = plan.units.flat_map { |unit| unit.fetch('members') }
      supplied_roots = {}
      dependencies.each do |dep|
        next if covered.include?(dep.name)
        unless supplied.key?(dep.name)
          raise CoverageError, "accepted recovery policy does not cover required gem #{dep.name}; ask the release maintainer to restore supported-client coverage"
        end
        floor = Gem::Version.new(supplied.fetch(dep.name).fetch('version'))
        active = @loaded_specs[dep.name]
        unless @find_specs.call(dep.name).any? { |spec| spec.version >= floor && dep.requirement.satisfied_by?(spec.version) } && (!active || active.version >= floor)
          raise Error, "installed RubyInstaller gem #{dep.name} does not satisfy its inventory floor and declared requirement; repair the Ruby installation"
        end
        supplied_roots[dep.name] = floor
      end
      packages = {}
      plan.units.each do |unit|
        unit.fetch('packages').each do |package|
          name = package.fetch('name')
          if packages.key?(name) && RecoveryUnitPolicy.package_identity(packages[name], plan.target.fetch('platform')) != RecoveryUnitPolicy.package_identity(package, plan.target.fetch('platform'))
            raise InvalidPolicyError, "conflicting accepted package identities for #{name}"
          end
          packages[name] = package
        end
      end
      platforms = packages.transform_values do |package|
        RecoveryUnitPolicy.package_platform(package, plan.target.fetch('platform'))
      end
      needed = packages.filter_map do |name, package|
        floor = Gem::Version.new(package.fetch('version'))
        acceptable = @find_specs.call(name).select { |spec| spec.version >= floor && spec.platform.to_s == platforms.fetch(name) }
        active = @loaded_specs[name]
        name if acceptable.empty? || (active && (active.version < floor || active.platform.to_s != platforms.fetch(name)))
      end
      if needed.any?
        units = plan.units.select { |unit| unit.fetch('packages').any? { |package| needed.include?(package.fetch('name')) } }
        return Check.new(plan: DependencyRecovery::Plan.new(units: units, target: plan.target), needed: needed, specs: [])
      end

      requirements = dependencies.map { |dep| Gem::Dependency.new(dep.name, *dep.requirement.as_list) }
      packages.each do |name, package|
        requirements << Gem::Dependency.new(name, ">= #{package.fetch('version')}")
        active = @loaded_specs[name]
        requirements << Gem::Dependency.new(name, "= #{active.version}") if active
      end
      supplied_roots.each do |name, floor|
        requirements << Gem::Dependency.new(name, ">= #{floor}")
        requirements << Gem::Dependency.new(name, "= #{@loaded_specs[name].version}") if @loaded_specs[name]
      end
      requests = Gem::Resolver.new(requirements, InstalledSet.new(@find_specs, platforms)).resolve
      Check.new(plan: plan, needed: [], specs: requests.map(&:spec))
    rescue Gem::UnsatisfiableDependencyError => e
      if @find_specs.call(e.name).empty?
        raise LocalInstallationError, "installed dependency #{e.name} is missing; repair or reinstall Ruby4Lich5: #{e.message}"
      end
      raise PolicyError, "installed gems cannot satisfy accepted startup policy: #{e.message}"
    rescue Gem::Exception => e
      raise PolicyError, "installed gems cannot satisfy accepted startup policy: #{e.message}"
    end

    def self.supplied_gems(target)
      supplied = target.dig('contract', 'ruby_inventory', 'gems') || {}
      unless supplied.is_a?(Hash) && supplied.all? do |name, entry|
        name.is_a?(String) && entry.is_a?(Hash) && entry['version'].is_a?(String) &&
        Gem::Version.correct?(entry['version']) && entry.fetch('dependencies', {}).is_a?(Hash)
      end
        raise InvalidPolicyError, 'accepted RubyInstaller inventory is malformed'
      end
      supplied
    rescue TypeError => e
      raise InvalidPolicyError, "accepted RubyInstaller inventory is malformed: #{e.message}"
    end

    def activate!(check)
      raise Error, 'startup repairs require a restart before activation' unless check.needed.empty?
      by_name = check.specs.to_h { |spec| [spec.name, spec] }
      visited = {}
      activate = lambda do |name|
        return if visited[name]
        visited[name] = true
        spec = by_name.fetch(name)
        spec.runtime_dependencies.each { |dep| activate.call(dep.name) if by_name.key?(dep.name) }
        spec.activate
        active = @loaded_specs[name]
        raise Error, "#{name} activated a different version than startup selected" unless active && active.version == spec.version && active.platform.to_s == spec.platform.to_s
      end
      by_name.each_key { |name| activate.call(name) }
      true
    rescue Gem::LoadError => e
      raise Error, "could not activate accepted runtime gems: #{e.message}"
    end
  end
end
