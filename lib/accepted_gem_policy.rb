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

    # A RubyInstaller-supplied gem the Gemfile declares is below the floor
    # the accepted manifest's inventory sets. Lich never ships these gems, so
    # the fix is a Ruby install that supplies them, not a gem repair.
    class RubyInventoryFloorError < LocalInstallationError
      # @return [Array<Hash>] one entry per gem: name, floor, installed
      #   versions, active version (or nil) and the Gemfile requirement
      attr_reader :gems
      # @return [String, nil] the Ruby the accepted Ruby4Lich5 build ships
      #   (+ruby_inventory.ruby_version+). The floors can come from an older
      #   RubyInstaller, so this is not the Ruby they were taken from.
      attr_reader :ruby_version
      # @return [String] the Ruby this start runs on
      attr_reader :running_ruby

      # @param gems [Array<Hash>]
      # @param ruby_version [String, nil]
      # @param running_ruby [String]
      def initialize(gems, ruby_version, running_ruby: RUBY_VERSION)
        @gems = gems
        @ruby_version = ruby_version
        @running_ruby = running_ruby
        super(self.class.describe(gems, ruby_version, running_ruby))
      end

      # What the player should do. A Ruby older than the one Ruby4Lich5 ships
      # needs that install. On the shipped Ruby or newer, a gem below its
      # floor means the install is damaged or downgraded, so reinstall it.
      # @param ruby_version [String, nil]
      # @param running_ruby [String]
      # @return [String] a sentence start, without the closing period
      def self.remedy(ruby_version, running_ruby)
        return 'Reinstall Ruby4Lich5' unless ruby_version

        verb = begin
          Gem::Version.new(running_ruby) < Gem::Version.new(ruby_version) ? 'Install' : 'Reinstall'
        rescue ArgumentError
          'Install'
        end
        "#{verb} Ruby4Lich5, which currently ships Ruby #{ruby_version}"
      end

      # @return [String]
      def remedy
        self.class.remedy(ruby_version, running_ruby)
      end

      # @param gems [Array<Hash>]
      # @param ruby_version [String, nil]
      # @param running_ruby [String]
      # @return [String]
      def self.describe(gems, ruby_version, running_ruby = RUBY_VERSION)
        parts = gems.map do |entry|
          installed = entry.fetch(:installed).empty? ? 'not installed' : "installed #{entry.fetch(:installed).join(', ')}"
          active = entry.fetch(:active) ? ", active #{entry.fetch(:active)}" : ''
          requirement = entry.fetch(:requirement).to_s == '>= 0' ? '' : ", Gemfile requires #{entry.fetch(:requirement)}"
          "#{entry.fetch(:name)} #{installed}#{active}, floor #{entry.fetch(:floor)}#{requirement}"
        end
        "RubyInstaller gems below this Lich's floor: #{parts.join('; ')}. #{remedy(ruby_version, running_ruby)}."
      end
    end

    class PolicyError < Error; end
    class AcquisitionError < PolicyError; end
    class InvalidPolicyError < PolicyError; end
    class CoverageError < PolicyError; end

    # The running Ruby is older than the target's minimum_ruby_version.
    class RubyTooOldError < LocalInstallationError
      # @return [String] the target's minimum_ruby_version
      attr_reader :minimum
      # @return [String] the running Ruby
      attr_reader :running

      # @param minimum [String]
      # @param running [String]
      def initialize(minimum, running)
        @minimum = minimum
        @running = running
        super("Ruby #{running} is older than this runtime policy's minimum Ruby #{minimum}; install Ruby4Lich5 with Ruby #{minimum} or newer")
      end
    end

    # The accepted manifest is valid but publishes no target for this Ruby
    # ABI/platform. Not a PolicyError: GemCheck treats it as "no accepted
    # policy applies here" and falls back to the plain missing-gem check.
    class UnsupportedRuntimeError < Error; end

    # +needed+ is below a package minimum and requires a repair. +recommended+
    # starts on an installed version below the accepted one, at or above its
    # minimum; startup only logs it.
    # +relaxed_floors+ lists RubyInstaller gems started below their inventory
    # floor because the running Ruby is older than the inventory's
    # +ruby_version+, the Ruby the accepted Ruby4Lich5 build ships.
    Check = Struct.new(:plan, :needed, :specs, :recommended, :relaxed_floors, keyword_init: true)

    class InstalledSet < Gem::Resolver::Set
      # @param find_specs [#call] installed specs by name
      # @param platforms [Hash{String => String}] accepted package platforms
      # @param accepted [Hash{String => Gem::Version, nil}, nil] versions a
      #   self-built gem must exceed (nil for a package that accepts only its
      #   accepted build), or nil to accept only the accepted builds
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
    # its own DLLs. That holds only where the dependents pin exactly, so a
    # package with a loosely pinned dependent in its unit (cairo, which
    # cairo-gobject requires as `>= 1.16.2`) gets no version here; see
    # #newer_self_built_versions. At the accepted version itself the R4L5
    # build is preferred, because Ruby4Lich5 patches the GTK stack.
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

    # @param ruby_version [String] the Ruby to judge the target against: the
    #   running one at startup, the inventory's +ruby_version+ (the Ruby the
    #   build ships) in a pre-publication check
    def initialize(recovery: DependencyRecovery.new, find_specs: Gem::Specification.method(:find_all_by_name), loaded_specs: Gem.loaded_specs,
                   ruby_version: RUBY_VERSION)
      @recovery = recovery
      @find_specs = find_specs
      @loaded_specs = loaded_specs
      @ruby_version = Gem::Version.new(ruby_version)
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
      begin
        minimum_ruby = RecoveryUnitPolicy.minimum_ruby_version(plan.target)
      rescue RecoveryUnitPolicy::Error => e
        raise InvalidPolicyError, e.message
      end
      raise RubyTooOldError.new(minimum_ruby.to_s, @ruby_version.to_s) if minimum_ruby && @ruby_version < minimum_ruby
      supplied = self.class.supplied_gems(plan.target)
      shipped = plan.target.dig('contract', 'ruby_inventory', 'ruby_version')
      older_ruby = shipped.is_a?(String) && Gem::Version.correct?(shipped) && @ruby_version < Gem::Version.new(shipped)
      covered = plan.units.flat_map { |unit| unit.fetch('members') }
      supplied_roots = {}
      below = []
      @relaxed_floors = []
      dependencies.each do |dep|
        next if covered.include?(dep.name)
        unless supplied.key?(dep.name)
          raise CoverageError, "accepted recovery policy does not cover required gem #{dep.name}; ask the release maintainer to restore supported-client coverage"
        end
        floor = Gem::Version.new(supplied.fetch(dep.name).fetch('version'))
        active = @loaded_specs[dep.name]
        installed = @find_specs.call(dep.name)
        unless installed.any? { |spec| spec.version >= floor && dep.requirement.satisfied_by?(spec.version) } && (!active || active.version >= floor)
          entry = { name: dep.name, floor: floor, installed: installed.map(&:version).uniq.sort, active: active&.version, requirement: dep.requirement }
          # On a Ruby older than the one the build ships, a gem below its
          # floor that still satisfies the Gemfile starts, with a note. Floors
          # taken from the oldest Ruby Lich accepts make this a downgraded
          # install on every accepted patch, but a contract whose floors are
          # the build Ruby's own capture (built before that change), or a
          # REQUIRED_RUBY raise the manifest has not caught up with, sets
          # floors an older patch never shipped. On the shipped Ruby or newer
          # a gem below its floor still stops startup.
          if older_ruby && installed.any? { |spec| dep.requirement.satisfied_by?(spec.version) } && (!active || dep.requirement.satisfied_by?(active.version))
            @relaxed_floors << entry
            supplied_roots[dep.name] = nil
          else
            below << entry
          end
          next
        end
        supplied_roots[dep.name] = floor
      end
      raise RubyInventoryFloorError.new(below, shipped, running_ruby: @ruby_version.to_s) unless below.empty?
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
      newer = newer_self_built_versions(plan, strict)
      begin
        check = decide(plan, dependencies, packages, platforms, supplied_roots, minimums, strict, newer)
      rescue Gem::Exception
        # A newer self-built gem can be acceptable on its own and still leave
        # no consistent set, for example a self-built gtk3 4.4.0 whose glib2
        # 4.4.0 is not installed. RubyGems' resolver does not fall back to an
        # older candidate then, so decide again exactly as before self-built
        # gems were accepted: the accepted builds, or a repair to them.
        raise unless self_built_candidates?(packages, platforms, newer)

        return decide(plan, dependencies, packages, platforms, supplied_roots, minimums, strict, nil)
      end
      # With a package minimum, decide's own fallback can turn that same
      # resolver failure into a repair instead of raising. So when this pass
      # needs a repair, decide again on the accepted builds alone, exactly
      # as before self-built gems were accepted:
      # - If that needs no repair, it is used.
      # - If what stays installed after this pass's repair holds together
      #   (every package outside the units it repairs, at its floor, with
      #   the newer self-built gems), this pass's repair is kept. It leaves
      #   those gems in use, so the next start has nothing left to repair,
      #   while the accepted-only repair would list and repair every unit
      #   holding one, for example a complete self-built GTK stack beside an
      #   ox that needs repair.
      # - Otherwise this pass may have turned the self-built gems' conflict
      #   into a repair of units the accepted builds never needed, leaving
      #   the one they do need for a second repair on the next start, so
      #   the accepted-only repair is used when it repairs different units.
      # Either repair runs with preserve_newer, so it leaves strictly newer
      # self-built gems installed.
      return check unless check.needed.any? && self_built_candidates?(packages, platforms, newer)

      begin
        accepted_only = decide(plan, dependencies, packages, platforms, supplied_roots, minimums, strict, nil)
      rescue Gem::Exception
        return check
      end
      return accepted_only if accepted_only.needed.empty?
      return check if self_built_consistent?(check, packages, platforms, minimums, newer)
      return accepted_only if unit_ids(accepted_only) != unit_ids(check)

      check
    rescue Gem::UnsatisfiableDependencyError => e
      if @find_specs.call(e.name).empty?
        raise LocalInstallationError, "installed dependency #{e.name} is missing; repair or reinstall Ruby4Lich5: #{e.message}"
      end
      raise PolicyError, "installed gems cannot satisfy accepted startup policy: #{e.message}"
    rescue Gem::Exception => e
      raise PolicyError, "installed gems cannot satisfy accepted startup policy: #{e.message}"
    end

    # @param floors [Hash{String => Gem::Version}] per-package startup floors
    # @param accepted [Hash{String => Gem::Version, nil}, nil] accepted package
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
        # A relaxed root (nil floor) keeps only its Gemfile requirement.
        requirements << Gem::Dependency.new(name, ">= #{floor}") if floor
        requirements << Gem::Dependency.new(name, "= #{@loaded_specs[name].version}") if @loaded_specs[name]
      end
      specs = Gem::Resolver.new(requirements, InstalledSet.new(@find_specs, platforms, accepted)).resolve.map(&:spec)
      recommended = specs.select { |spec| packages.key?(spec.name) && spec.version < Gem::Version.new(packages.fetch(spec.name).fetch('version')) }.map(&:name)
      Check.new(plan: plan, needed: [], specs: specs, recommended: recommended, relaxed_floors: Array(@relaxed_floors))
    end
    private :evaluate

    # @param check [Check]
    # @return [Array<String>] the ids of the units +check+ would repair
    def unit_ids(check)
      check.plan.units.map { |unit| unit.fetch('id') }.sort
    end
    private :unit_ids

    # Applies the package minimums, then the accepted versions where the
    # minimums cannot resolve.
    # @param self_built [Hash{String => Gem::Version, nil}, nil] accepted
    #   versions a self-built gem must exceed, or nil to accept only the
    #   accepted builds
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

    # @param newer [Hash{String => Gem::Version, nil}] see
    #   #newer_self_built_versions
    # @return [Boolean] whether any installed gem is acceptable only as a
    #   newer self-built gem
    def self_built_candidates?(packages, platforms, newer)
      packages.each_key.any? do |name|
        @find_specs.call(name).any? { |spec| spec.platform.to_s != platforms.fetch(name) && self.class.acceptable_build?(spec, platforms.fetch(name), newer.fetch(name)) }
      end
    end
    private :self_built_candidates?

    # Whether what stays installed after +check+'s repair holds together:
    # every package outside the units it repairs, at its floor, and each
    # newer self-built gem that may be used, above its accepted version.
    # A self-built gtk3 4.4.0 without a self-built glib2 4.4.0 does not, and
    # neither does a self-built glib2 4.4.0 beside an R4L5 gtk3 4.3.9, which
    # pins glib2 exactly.
    # @param check [Check] the repair the self-built pass chose
    # @return [Boolean]
    def self_built_consistent?(check, packages, platforms, minimums, newer)
      repaired = check.plan.units.flat_map { |unit| unit_package_names(unit) }
      kept = (packages.keys - repaired).map { |name| Gem::Dependency.new(name, ">= #{minimums.fetch(name)}") }
      requirements = kept + packages.each_key.filter_map do |name|
        next unless newer.fetch(name)
        next unless @find_specs.call(name).any? { |spec| spec.platform.to_s != platforms.fetch(name) && self.class.acceptable_build?(spec, platforms.fetch(name), newer.fetch(name)) }

        Gem::Dependency.new(name, "> #{newer.fetch(name)}")
      end
      Gem::Resolver.new(requirements, InstalledSet.new(@find_specs, platforms, newer)).resolve
      true
    rescue Gem::Exception
      false
    end
    private :self_built_consistent?

    # The version a newer self-built copy of each package must exceed, or nil
    # where only the accepted build may be used. A self-built copy is only
    # considered when every other package of its units that depends on it
    # pins it exactly, judged by every installed copy of those packages (the
    # manifest carries no gem dependencies). Ruby-GNOME's exact pins then keep
    # a self-built gem from resolving next to an accepted build of the stack.
    # cairo is the exception: cairo-gobject depends on `cairo >= 1.16.2`, so a
    # newer self-built cairo next to an accepted cairo-gobject would mix with
    # the accepted GTK stack, and only the accepted cairo is used there. A
    # self-built Ruby-GNOME stack over the accepted cairo is still kept,
    # because nothing pins cairo-gobject, glib2 or gtk3 loosely.
    # @return [Hash{String => Gem::Version, nil}]
    def newer_self_built_versions(plan, strict)
      strict.to_h do |name, version|
        others = plan.units.select { |unit| unit_package_names(unit).include?(name) }.flat_map { |unit| unit_package_names(unit) }.uniq - [name]
        pinned = others.all? do |other|
          copies = @find_specs.call(other) + [@loaded_specs[other]].compact
          copies.all? { |spec| spec.runtime_dependencies.none? { |dep| dep.name == name && !exact_pin?(dep) } }
        end
        [name, pinned ? version : nil]
      end
    end
    private :newer_self_built_versions

    def unit_package_names(unit)
      unit.fetch('packages').map { |package| package.fetch('name') }
    end
    private :unit_package_names

    def exact_pin?(dependency)
      dependency.requirement.requirements.all? { |operator, _version| operator == '=' }
    end
    private :exact_pin?

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
      Check.new(plan: DependencyRecovery::Plan.new(units: units, target: plan.target), needed: needed, specs: [], recommended: [], relaxed_floors: Array(@relaxed_floors))
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
