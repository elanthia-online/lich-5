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
    # The accepted manifest is valid but publishes no target for this Ruby
    # ABI/platform. Not a PolicyError: GemCheck treats it as "no accepted
    # policy applies here" and falls back to the plain missing-gem check.
    class UnsupportedRuntimeError < Error; end

    # +needed+ is below a package minimum and requires a repair. +recommended+
    # starts on an installed version below the accepted one, at or above its
    # minimum; startup only logs it.
    Check = Struct.new(:plan, :needed, :specs, :recommended, keyword_init: true)

    class InstalledSet < Gem::Resolver::Set
      # @param find_specs [#call] installed specs by name
      # @param platforms [Hash{String => String}] accepted package platforms
      # @param accepted [Hash{String => Gem::Version}, nil] versions a self-built
      #   gem must exceed, or nil to accept only the accepted builds
      def initialize(find_specs, platforms, accepted)
        super()
        @find_specs = find_specs
        @platforms = platforms
        @accepted = accepted
        self.remote = false
      end

      def find_all(request)
        @find_specs.call(request.name).select do |spec|
          request.match?(spec) && (@platforms.key?(spec.name) ? AcceptedGemPolicy.acceptable_build?(spec, @platforms[spec.name], @accepted&.fetch(spec.name)) : Gem::Platform.match_spec?(spec))
        end
      end
    end

    # Whether an installed copy of a manifest package may satisfy startup.
    # The accepted build (the manifest's platform) always may. A build for
    # another platform this runtime can load, typically a gem the user
    # compiled with `gem install` or `gem update`, may only when it is
    # strictly newer than the accepted version and its native extension
    # finished building. Startup then keeps the user's newer gem instead of
    # replacing it with the older accepted build.
    #
    # The version must be strictly newer, not merely at a minimum. Ruby-GNOME
    # pins its gems to one exact version across the GTK stack, so a strictly
    # newer self-built gtk3 can only resolve with an equally new self-built
    # glib2 and the rest of the stack, never with an R4L5 build that bundles
    # its own DLLs. At the accepted version itself the R4L5 build is
    # preferred, because Ruby4Lich5 patches the GTK stack.
    # @param spec [Gem::Specification]
    # @param platform [String] the accepted package platform
    # @param accepted [Gem::Version, nil] the accepted package version, or nil
    #   to accept only the accepted build
    # @return [Boolean]
    def self.acceptable_build?(spec, platform, accepted)
      return true if spec.platform.to_s == platform
      return false unless accepted

      spec.version > accepted && Gem::Platform.match_spec?(spec) && !spec.missing_extensions?
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
        type = case plan.error_kind
               when :acquisition then AcquisitionError
               when :unsupported_runtime then UnsupportedRuntimeError
               else InvalidPolicyError
               end
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
      strict = packages.transform_values { |package| Gem::Version.new(package.fetch('version')) }
      minimums = packages.transform_values { |package| Gem::Version.new(RecoveryUnitPolicy.package_minimum(package)) }
      begin
        check = decide(plan, dependencies, packages, platforms, supplied_roots, minimums, strict, strict)
      rescue Gem::Exception
        # A newer self-built gem can be acceptable on its own and still leave
        # no consistent set, for example a self-built gtk3 4.4.0 whose glib2
        # 4.4.0 is not installed. RubyGems' resolver does not fall back to an
        # older candidate then, so decide again exactly as before self-built
        # gems were accepted: the accepted builds, or a repair to them.
        raise unless self_built_candidates?(packages, platforms, strict)

        return decide(plan, dependencies, packages, platforms, supplied_roots, minimums, strict, nil)
      end
      # With a package minimum, decide's own fallback can turn that same
      # resolver failure into a repair instead of raising. Start without a
      # repair whenever the accepted builds alone need none, which is exactly
      # the decision made before self-built gems were accepted. When both
      # need a repair, keep this one: it repairs the same units and does not
      # also replace the self-built gems it kept.
      return check unless check.needed.any? && self_built_candidates?(packages, platforms, strict)

      begin
        accepted_only = decide(plan, dependencies, packages, platforms, supplied_roots, minimums, strict, nil)
      rescue Gem::Exception
        return check
      end
      accepted_only.needed.empty? ? accepted_only : check
    rescue Gem::UnsatisfiableDependencyError => e
      if @find_specs.call(e.name).empty?
        raise LocalInstallationError, "installed dependency #{e.name} is missing; repair or reinstall Ruby4Lich5: #{e.message}"
      end
      raise PolicyError, "installed gems cannot satisfy accepted startup policy: #{e.message}"
    rescue Gem::Exception => e
      raise PolicyError, "installed gems cannot satisfy accepted startup policy: #{e.message}"
    end

    # @param floors [Hash{String => Gem::Version}] per-package startup floors
    # @param accepted [Hash{String => Gem::Version}, nil] accepted package
    #   versions a self-built gem must exceed, or nil for accepted builds only
    def evaluate(plan, dependencies, packages, platforms, supplied_roots, floors, accepted)
      needed = needed_at(packages, platforms, floors, accepted)
      return repair_check(plan, needed) if needed.any?

      requirements = dependencies.map { |dep| Gem::Dependency.new(dep.name, *dep.requirement.as_list) }
      packages.each_key do |name|
        requirements << Gem::Dependency.new(name, ">= #{floors.fetch(name)}")
        active = @loaded_specs[name]
        requirements << Gem::Dependency.new(name, "= #{active.version}") if active
      end
      supplied_roots.each do |name, floor|
        requirements << Gem::Dependency.new(name, ">= #{floor}")
        requirements << Gem::Dependency.new(name, "= #{@loaded_specs[name].version}") if @loaded_specs[name]
      end
      specs = Gem::Resolver.new(requirements, InstalledSet.new(@find_specs, platforms, accepted)).resolve.map(&:spec)
      recommended = specs.select { |spec| packages.key?(spec.name) && spec.version < Gem::Version.new(packages.fetch(spec.name).fetch('version')) }.map(&:name)
      Check.new(plan: plan, needed: [], specs: specs, recommended: recommended)
    end
    private :evaluate

    # Applies the package minimums, then the accepted versions where the
    # minimums cannot resolve.
    # @param self_built [Hash{String => Gem::Version}, nil] accepted versions a
    #   self-built gem must exceed, or nil to accept only the accepted builds
    def decide(plan, dependencies, packages, platforms, supplied_roots, minimums, strict, self_built)
      return evaluate(plan, dependencies, packages, platforms, supplied_roots, strict, self_built) if minimums == strict

      begin
        evaluate(plan, dependencies, packages, platforms, supplied_roots, minimums, self_built)
      rescue Gem::Exception => e
        # A lower floor must never stop startup where the accepted versions
        # would repair it, such as an installed newer dependent requiring more
        # than another member's minimum. Raise the floors of the units named by
        # the failure; if that requires no repair, decide exactly as without
        # minimums.
        names = failure_names(e) & packages.keys
        units = plan.units.select { |unit| unit.fetch('packages').any? { |package| names.include?(package.fetch('name')) } }
        floors = minimums.merge(units.flat_map { |unit| unit.fetch('packages') }.to_h { |package| [package.fetch('name'), strict.fetch(package.fetch('name'))] })
        needed = needed_at(packages, platforms, floors, self_built)
        return repair_check(plan, needed) if needed.any?

        evaluate(plan, dependencies, packages, platforms, supplied_roots, strict, self_built)
      end
    end
    private :decide

    # @return [Boolean] whether any installed gem is acceptable only as a
    #   newer self-built gem
    def self_built_candidates?(packages, platforms, strict)
      packages.each_key.any? do |name|
        @find_specs.call(name).any? { |spec| spec.platform.to_s != platforms.fetch(name) && self.class.acceptable_build?(spec, platforms.fetch(name), strict.fetch(name)) }
      end
    end
    private :self_built_candidates?

    def needed_at(packages, platforms, floors, accepted)
      packages.filter_map do |name, _package|
        floor = floors.fetch(name)
        usable = ->(spec) { spec.version >= floor && self.class.acceptable_build?(spec, platforms.fetch(name), accepted&.fetch(name)) }
        active = @loaded_specs[name]
        name if @find_specs.call(name).none?(&usable) || (active && !usable.call(active))
      end
    end
    private :needed_at

    # A repair installs every package of each affected unit at its version.
    def repair_check(plan, needed)
      units = plan.units.select { |unit| unit.fetch('packages').any? { |package| needed.include?(package.fetch('name')) } }
      Check.new(plan: DependencyRecovery::Plan.new(units: units, target: plan.target), needed: needed, specs: [], recommended: [])
    end
    private :repair_check

    def failure_names(error)
      case error
      when Gem::UnsatisfiableDependencyError then [error.name]
      when Gem::DependencyResolutionError then error.conflict.conflicting_dependencies.map(&:name)
      else []
      end
    rescue StandardError
      []
    end
    private :failure_names

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
