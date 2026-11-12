# frozen_string_literal: true

require_relative 'runtime_gem_contract'
require_relative 'dependency_recovery'

module Lich
  # Release-time verification, intentionally separate from startup recovery.
  class R4L5ContractCheck
    Error = RuntimeGemContract::Error

    def self.verify!(gemfile:, lockfile:, manifest_bytes:, provenance:, candidate_sha: nil, installer_path: nil,
                     lich_version: (defined?(LICH_VERSION) ? LICH_VERSION : nil), platform: RuntimeGemContract::PLATFORM)
      reader = RuntimeGemContract.new(gemfile: gemfile, lockfile: lockfile, platform: platform)
      manifest = JSON.parse(manifest_bytes)
      require_object!(manifest, 'recovery manifest')
      require_object!(provenance, 'installer provenance')
      raise Error, 'unsupported recovery manifest' unless manifest['schema'] == 1
      targets = manifest.fetch('targets')
      raise Error, 'recovery targets must be an array' unless targets.is_a?(Array)
      targets.each { |target| require_object!(target, 'recovery target') }
      targets = targets.select { |target| target['platform'] == platform && target['ruby_abi'] == '4.0' }
      raise Error, 'expected exactly one Windows Ruby 4.0 target' unless targets.length == 1
      target = targets.first
      contract = target.fetch('contract')
      require_object!(contract, 'runtime contract')
      raise Error, 'unsupported runtime contract' unless contract['schema'] == 2
      raise Error, 'runtime contract must name a full lich-5 commit SHA' unless RuntimeGemContract::COMMIT.match?(contract.fetch('lich5_commit'))
      if candidate_sha && contract['lich5_commit'] != candidate_sha
        raise Error, 'served runtime contract names a different candidate SHA'
      end
      raise Error, 'override or diagnostic builds cannot be accepted' unless contract['promotable'] == true && contract['overrides'] == {}
      %w[gemfile_sha256 lock_sha256 windows_contract_sha256].each do |field|
        raise Error, "runtime contract has invalid #{field}" unless RuntimeGemContract::SHA256.match?(contract.fetch(field))
      end
      inventory = contract.fetch('ruby_inventory')
      require_object!(inventory, 'RubyInstaller inventory')
      supplied_gems = inventory.fetch('gems')
      require_object!(supplied_gems, 'RubyInstaller gems')
      supplied_gems.each_value do |entry|
        require_object!(entry, 'RubyInstaller gem')
        require_object!(entry.fetch('dependencies'), 'RubyInstaller gem dependencies')
      end
      roles = contract.fetch('build_roles', {})
      require_object!(roles, 'build roles')
      resolved = reader.resolve(inventory)
      units = target.fetch('units')
      raise Error, 'recovery units must be a nonempty array' unless units.is_a?(Array) && !units.empty?
      recovery = DependencyRecovery.new
      units.each do |unit|
        require_object!(unit, 'recovery unit')
        recovery.send(:validate_unit!, unit)
      end
      raise Error, 'duplicate recovery unit ids' unless units.map { |unit| unit['id'] }.uniq.length == units.length
      units = RecoveryUnitPolicy.select(target, lich_version, strict: true)
      required = resolved.fetch('packages')
      advertised = units.flat_map { |unit| unit.fetch('members') }
      gtk = roles.fetch('gtk', [])
      identity = reader.windows_contract_digest(inventory, build_roles: roles, advertised_members: advertised)
      unless contract['windows_contract_sha256'] == identity
        raise Error, 'served runtime contract does not match this Windows projection; build and promote this candidate first'
      end
      checked = reader.locked_packages.select { |name, _spec| !gtk.include?(name) && !contract.fetch('ruby_inventory').fetch('gems').key?(name) && (required.key?(name) || advertised.include?(name)) }
      checked.each do |name, spec|
        # Existing consumers use the first unit advertising a member.
        unit = units.find { |entry| entry.fetch('members').include?(name) }
        raise Error, "recovery does not cover #{name}" unless unit
        package = unit.fetch('packages').find { |entry| entry['name'] == name }
        raise Error, "first recovery unit for #{name} omits its package" unless package
        occurrences = units.flat_map { |entry| entry.fetch('packages') }.select { |entry| entry['name'] == name }
        unless occurrences.all? { |entry| entry['version'] == spec.fetch('version') }
          raise Error, "recovery version mismatch for #{name}: lock requires #{spec.fetch('version')}"
        end
        # Each package's minimum was validated against its version above;
        # minimums are compared by version value.
        raise Error, "recovery minimum mismatch for #{name}" unless occurrences.map { |entry| RecoveryUnitPolicy.minimum_identity(entry) }.uniq.length == 1
        # Unmodified upstream files retain the lock checksum. Built/repacked
        # packages have new digests and are checked by the producer smoke gate.
        if unit.dig('artifact', 'url')&.start_with?('https://rubygems.org/downloads/') && package['sha256'] != "sha256:#{spec.fetch('sha256')}"
          raise Error, "upstream package checksum mismatch for #{name}"
        end
      end
      supplied = resolved.fetch('bundled').keys
      shipped_supplied = units.flat_map { |unit| unit.fetch('packages').map { |package| package.fetch('name') } } & supplied
      raise Error, "RubyInstaller-supplied gems must not be shipped: #{shipped_supplied.join(', ')}" unless shipped_supplied.empty?

      unless provenance['runtime_contract_sha256'] == RuntimeGemContract.digest(contract) && provenance['recovery_manifest_sha256'] == Digest::SHA256.hexdigest(manifest_bytes)
        raise Error, 'matching installer predecessor is missing or was built for a different accepted manifest/contract'
      end
      ruby_version = contract.fetch('ruby_inventory').fetch('ruby_version')
      installer_version = provenance.fetch('ruby_installer_version')
      unless installer_version.is_a?(String) && installer_version.match?(/\A\d+\.\d+\.\d+-\d+\z/) && installer_version.split('-').first == ruby_version
        raise Error, 'installer Ruby version does not match measured inventory'
      end
      unless RuntimeGemContract::SHA256.match?(provenance.fetch('installer_sha256'))
        raise Error, 'installer predecessor has no valid executable digest'
      end
      if installer_path && Digest::SHA256.file(installer_path).hexdigest != provenance['installer_sha256']
        raise Error, 'downloaded installer checksum does not match the accepted predecessor'
      end
      resolved
    rescue JSON::ParserError, KeyError, TypeError, ArgumentError, DependencyRecovery::Error, RecoveryUnitPolicy::Error => e
      raise Error, "invalid R4L5 contract: #{e.message}"
    end

    def self.require_object!(value, name)
      raise Error, "#{name} must be an object" unless value.is_a?(Hash)
    end
    private_class_method :require_object!
  end
end
