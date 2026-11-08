# frozen_string_literal: true

require_relative 'accepted_gem_policy'
require_relative 'runtime_gem_contract'

module Lich
  # Pre-publication check of a proposed policy against supported client
  # declarations. It models the served package floors, never a host install.
  # Native activation and package dependency metadata need separate acceptance.
  class StartupPolicyCompatibility
    def self.verify!(manifest_bytes:, clients:)
      raise ArgumentError, 'supported clients must be a nonempty array' unless clients.is_a?(Array) && !clients.empty? && clients.all? { |client| client.is_a?(Hash) }
      names = clients.map { |client| client.fetch('id') }
      raise ArgumentError, 'supported client IDs must be unique nonempty strings' unless names.all? { |name| name.is_a?(String) && !name.empty? } && names.uniq == names

      clients.to_h do |client|
        groups = client.fetch('groups')
        raise ArgumentError, 'startup groups must be an explicit nonempty array of strings' unless groups.is_a?(Array) && !groups.empty? && groups.all? { |group| group.is_a?(String) }
        reader = RuntimeGemContract.new(gemfile: client.fetch('gemfile'), groups: groups)
        dependencies = reader.roots.map { |name, requirements| Gem::Dependency.new(name, *requirements) }
        recovery = DependencyRecovery.new(http_get: ->(_url) { manifest_bytes }, lich_version: client['lich_version'])
        plan = recovery.policy_plan(dependencies.map(&:name))
        raise AcceptedGemPolicy::InvalidPolicyError, plan.error unless plan.success?
        supplied = AcceptedGemPolicy.supplied_gems(plan.target)
        available = supplied.to_h { |name, entry| [name, specification(name, entry.fetch('version'), 'ruby', entry.fetch('dependencies', {}))] }
        plan.units.each do |unit|
          unit.fetch('packages').each do |package|
            platform = package.fetch('filename').end_with?("-#{plan.target.fetch('platform')}.gem") ? plan.target.fetch('platform') : 'ruby'
            available[package.fetch('name')] = specification(package.fetch('name'), package.fetch('version'), platform)
          end
        end
        policy = AcceptedGemPolicy.new(recovery: recovery, find_specs: ->(name) { available.key?(name) ? [available.fetch(name)] : [] }, loaded_specs: {})
        check = policy.check(dependencies)
        raise AcceptedGemPolicy::CoverageError, 'served package floors cannot supply a complete startup' unless check.needed.empty?
        [client.fetch('id'), reader.roots.keys.sort]
      rescue AcceptedGemPolicy::Error, RuntimeGemContract::Error, KeyError, TypeError, ArgumentError => e
        raise AcceptedGemPolicy::PolicyError, "supported client #{client.fetch('id', '(missing ID)')}: #{e.message}"
      end
    end

    def self.specification(name, version, platform, dependencies = {})
      Gem::Specification.new do |spec|
        spec.name = name
        spec.version = version
        spec.platform = platform
        dependencies.each { |child, requirements| spec.add_runtime_dependency(child, *Array(requirements)) }
      end
    end
    private_class_method :specification
  end
end
