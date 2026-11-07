# frozen_string_literal: true

require 'digest'
require 'json'
require 'ripper'
require 'rubygems'

module Lich
  # Reads the Windows runtime contract without evaluating the Gemfile or using
  # Bundler. The producer vendors this reader from the selected Lich commit.
  class RuntimeGemContract
    class Error < StandardError; end

    PLATFORM = 'x64-mingw-ucrt'
    GROUPS = %w[default profanity].freeze
    SHA256 = /\A[0-9a-f]{64}\z/
    COMMIT = /\A[0-9a-f]{40}\z/

    attr_reader :roots, :gemfile_sha256, :lock_sha256, :locked_packages

    def initialize(gemfile:, lockfile:)
      @gemfile_sha256 = Digest::SHA256.hexdigest(gemfile)
      @lock_sha256 = Digest::SHA256.hexdigest(lockfile)
      @roots = {}
      tree = Ripper.sexp(gemfile)
      raise Error, 'Gemfile syntax is invalid' unless tree
      declarations(tree)
      raise Error, 'Gemfile has no Windows runtime roots' if roots.empty?
      @specs = parse_lock(lockfile)
      @locked_packages = @specs
    rescue ArgumentError => e
      raise Error, "invalid runtime declarations or lock: #{e.message}"
    end

    # Inventory must be captured from the pristine target RubyInstaller before
    # installing application gems. Supplied versions are reported, never shipped.
    def resolve(inventory)
      unless inventory['platform'] == PLATFORM && inventory['ruby_abi'] == '4.0' && inventory['gems'].is_a?(Hash)
        raise Error, 'inventory must describe the target Windows RubyInstaller (Ruby ABI 4.0)'
      end
      supplied = inventory.fetch('gems')
      packages = {}
      bundled = {}
      visiting = []
      visit = lambda do |name, requirement|
        raise Error, "dependency cycle at #{name}" if visiting.include?(name)
        entry = supplied[name] || @specs[name]
        raise Error, "#{name} is absent from the Windows lock and RubyInstaller" unless entry
        version = entry.fetch('version')
        unless Gem::Requirement.new(requirement).satisfied_by?(Gem::Version.new(version))
          raise Error, "#{name} #{version} does not satisfy #{requirement.inspect}"
        end
        next if packages.key?(name) || bundled.key?(name)

        visiting << name
        if supplied.key?(name)
          bundled[name] = { 'locked' => @specs.dig(name, 'version'), 'supplied' => version }
        else
          packages[name] = entry
        end
        entry.fetch('dependencies').each { |child, requirements| visit.call(child, requirements) }
        visiting.pop
      end
      roots.each { |name, requirements| visit.call(name, requirements) }
      { 'roots' => roots.keys.sort, 'packages' => packages.sort.to_h, 'bundled' => bundled.sort.to_h }
    rescue KeyError, ArgumentError => e
      raise Error, "invalid lock or RubyInstaller inventory: #{e.message}"
    end

    # Shared producer/consumer eligibility projection. Raw source hashes remain
    # provenance; only applicable Windows package constraints enter this digest.
    def windows_contract_digest(inventory, build_roles: {}, advertised_members: [])
      resolved = resolve(inventory)
      gtk = build_roles.fetch('gtk', [])
      unless gtk.is_a?(Array) && gtk.all? { |name| name.is_a?(String) }
        raise Error, 'GTK build role must be an array of package names'
      end
      relevant = resolved.fetch('packages').keys | advertised_members
      packages = locked_packages.select do |name, _spec|
        relevant.include?(name) && !gtk.include?(name) && !inventory.fetch('gems').key?(name)
      end.transform_values do |spec|
        spec.merge('dependencies' => spec.fetch('dependencies').transform_values { |requirements| normalized_requirements(requirements) })
      end
      self.class.digest('schema' => 1, 'platform' => PLATFORM, 'ruby_abi' => '4.0',
                        'roots' => roots.transform_values { |requirements| normalized_requirements(requirements) },
                        'packages' => packages, 'bundled' => resolved.fetch('bundled'), 'ruby_inventory' => inventory)
    end

    def self.digest(document)
      canonical = lambda do |value|
        case value
        when Hash then value.keys.sort.to_h { |key| [key, canonical.call(value.fetch(key))] }
        when Array then value.map { |item| canonical.call(item) }
        else value
        end
      end
      Digest::SHA256.hexdigest(JSON.generate(canonical.call(document)))
    end

    private

    def normalized_requirements(requirements)
      Gem::Requirement.new(requirements).requirements.map { |operator, version| [operator, version.to_s] }.uniq.sort
    end

    def declarations(node, groups = [])
      return unless node.is_a?(Array)
      case node.first
      when :program then node[1].each { |child| declarations(child, groups) }
      when :void_stmt then nil
      when :command
        method = node.dig(1, 1)
        if method == 'gem'
          add_root(node[2], groups)
        elsif !%w[source plugin].include?(method)
          raise Error, "unsupported Gemfile declaration #{method}"
        end
      when :method_add_block
        call = node[1]
        method = call[0] == :method_add_arg && call.dig(1, 0) == :fcall ? call.dig(1, 1, 1) : call.dig(1, 1)
        return if method == 'git_source'
        raise Error, 'unsupported Gemfile block (use literal group declarations)' unless method == 'group'
        selected = groups | arguments(call[2]).map { |arg| literal(arg) }
        body = node[2]
        raise Error, 'unsupported group body' unless body[0] == :do_block && body[2][0] == :bodystmt && body[2][2..].all?(&:nil?)
        body[2][1].each { |child| declarations(child, selected) }
      else
        raise Error, "unsupported Gemfile runtime syntax #{node.first}"
      end
    end

    def arguments(node)
      raise Error, 'Gemfile arguments must be literal' unless node && node[0] == :args_add_block && node[2] == false
      node[1]
    end

    def literal(node)
      case node[0]
      when :string_literal
        content = node[1]
        raise Error, 'interpolated Gemfile values are unsupported' unless content[0] == :string_content && content[1..].all? { |part| part[0] == :@tstring_content }
        content[1..].map { |part| part[1] }.join
      when :symbol_literal
        raise Error, 'Gemfile symbol must be literal' unless node.dig(1, 0) == :symbol && %i[@ident @op].include?(node.dig(1, 1, 0))
        node[1][1][1]
      when :array then (node[1] || []).map { |item| literal(item) }
      else raise Error, 'Gemfile values must be literal strings or symbols'
      end
    end

    def add_root(node, groups)
      return unless groups.empty? || (groups & GROUPS).any?
      args = arguments(node).dup
      options = args.last&.first == :bare_assoc_hash ? args.pop[1] : []
      platforms = nil
      options.each do |pair|
        raise Error, 'unsupported runtime gem option' unless pair[0] == :assoc_new && pair.dig(1, 0) == :@label && pair[1][1] == 'platforms:'
        platforms = Array(literal(pair[2]))
        unknown = platforms - %w[windows mingw x64_mingw mswin ruby mri jruby]
        raise Error, "unknown platform selectors #{unknown.inspect}" unless unknown.empty?
      end
      return if platforms && (platforms & %w[windows mingw x64_mingw]).empty?
      name, *requirements = args.map { |arg| literal(arg) }
      raise Error, 'unsafe or duplicate runtime gem name' unless name.is_a?(String) && name.match?(/\A[a-zA-Z0-9_][a-zA-Z0-9_.-]*\z/) && !roots.key?(name)
      requirements = ['>= 0'] if requirements.empty?
      Gem::Requirement.new(requirements)
      roots[name] = requirements
    end

    def parse_lock(text)
      specs = []
      checksums = {}
      section = nil
      current = nil
      text.each_line do |line|
        section = line.strip if line.match?(/\A[A-Z][A-Z ]*\n?\z/)
        if section == 'GEM' && (match = line.match(/\A    ([\w.-]+) \(([^)]+)\)\s*\z/))
          identity = match[2]
          version, platform = identity.split('-', 2)
          next unless Gem::Version.correct?(version)
          current = { 'name' => match[1], 'version' => version, 'platform' => platform || 'ruby', 'identity' => identity, 'dependencies' => {} }
          specs << current
        elsif section == 'GEM' && (match = line.match(/\A      ([\w.-]+)(?: \(([^)]+)\))?\s*\z/))
          raise Error, 'orphan lock dependency' unless current
          current['dependencies'][match[1]] = match[2] ? match[2].split(', ') : ['>= 0']
        elsif section == 'CHECKSUMS' && (match = line.match(/\A  ([\w.-]+) \(([^)]+)\) sha256=([0-9a-f]{64})\s*\z/))
          key = [match[1], match[2]]
          raise Error, "duplicate checksum #{key.inspect}" if checksums.key?(key)
          checksums[key] = match[3]
        end
      end
      raise Error, 'only a RubyGems lock with checksums is supported' unless text.start_with?("GEM\n") && !checksums.empty?
      specs.group_by { |spec| spec.fetch('name') }.filter_map do |name, variants|
        selected = variants.select { |spec| spec['platform'] == PLATFORM }
        selected = variants.select { |spec| spec['platform'] == 'ruby' } if selected.empty?
        next if selected.empty?
        raise Error, "ambiguous Windows lock entry for #{name}" unless selected.length == 1
        spec = selected.first
        spec['sha256'] = checksums.fetch([name, spec.delete('identity')]) { raise Error, "missing lock checksum for #{name}" }
        [name, spec]
      end.to_h
    end
  end
end
