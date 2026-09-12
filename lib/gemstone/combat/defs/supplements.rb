# frozen_string_literal: true

#
# Supplements - player-supplied combat definitions from a YAML file.
#
# The shipped defs (attacks, flares, statuses, outcomes) are frozen Ruby
# constants and only change with a Lich release. This module reads one
# global file, DATA_DIR/combat/defs.yaml, and compiles its entries into the
# very same Struct objects the shipped tables are built from, so a def file
# can splice them into its assembly step and every derived lookup, detector
# and PatternGate rebuilds from the combined set.
#
# Nothing here touches the shipped constants. With no file present every
# reader returns an empty frozen array, so the assembled tables are
# byte-identical to a build without supplements.
#
# Validation, timeout-bounded regex compilation, reporting and the memo
# come from Lich::Common::UserDefs (shared with DragonRealms'
# CustomSubstitutions). The rules are the same: one bad entry never
# disables the rest, and every rejection names the kind, index, value,
# reason and consequence.
#
# The file is re-read when its modification time changes, so a reload after
# an edit picks up the new contents; `reset!` forces a re-read regardless.
#
# This file must not require the def files it serves: they require it, and
# call the readers from their assembly step after their own Structs and
# shipped lists exist. Constants such as Flares::FLARE_DEFS are therefore
# resolved lazily, at call time.
#
# @example defs.yaml
#   attacks:
#     - name: ice_lance
#       slot: priority
#       patterns: ['You hurl a lance of ice at (?<target>[^!]+)!']
#   flares:
#     - name: acid            # shipped name: flags inherit from the shipped def
#       patterns: ['\*\* Your .+? spits a gob of acid at (?<target>.+?)! \*\*']
#
require 'yaml'
require_relative '../../../common/user_defs'
require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        module Supplements
          extend Lich::Common::UserDefs

          MESSAGE_PREFIX = '[combat.defs]'

          # Where the assembly points may place a supplemental attack. Match
          # order is load-bearing (see attacks.rb ALL_ATTACKS), so the player
          # picks a slot rather than a position.
          ATTACK_SLOTS = %i[priority generic third_person].freeze
          DEFAULT_ATTACK_SLOT = :generic

          # Markup-tolerance tokens a pattern string may carry. Expanded to
          # the same fragments the shipped defs interpolate, so user patterns
          # survive the live XML feed without seeing the fragments themselves.
          TOKENS = {
            '{{MK_PRE}}'  => MK_PRE,
            '{{MK_POST}}' => MK_POST
          }.freeze
          TOKEN_PATTERN = /\{\{[A-Z_]+\}\}/.freeze

          NAME_PATTERN = /\A[a-z][a-z0-9_]*\z/.freeze

          FLARE_FLAGS = %w[damaging aoe spawns].freeze

          class << self
            # The supplement file. Defaults to DATA_DIR/combat/defs.yaml;
            # assignable for tools and specs.
            #
            # @return [String]
            def path
              @path ||= File.join(DATA_DIR, 'combat', 'defs.yaml')
            end

            # @param new_path [String, nil] nil restores the default
            def path=(new_path)
              @path = new_path
              @loaded_mtime = nil
              reset!
            end

            # True when the file exists on disk.
            def present? = File.file?(path)

            # True when the file on disk (present or not) differs from what
            # the current def tables were assembled from, so a reload_defs!
            # would change something. Cheap: one stat.
            def stale?
              current = present? ? File.mtime(path) : nil
              @loaded_mtime != current
            end

            # Supplemental attack defs for one slot.
            #
            # @param slot [Symbol] one of ATTACK_SLOTS
            # @return [Array<Attacks::AttackDef>] frozen
            def attacks(slot = DEFAULT_ATTACK_SLOT)
              raise ArgumentError, "unknown attack slot #{slot.inspect}" unless ATTACK_SLOTS.include?(slot)

              memoize(:attacks)[slot]
            end

            # @return [Array<Flares::FlareDef>] frozen
            def flares = memoize(:flares)

            # @return [Array<Statuses::StatusDef>] frozen
            def statuses = memoize(:statuses)

            # @return [Array<Outcomes::OutcomeDef>] frozen
            def outcomes = memoize(:outcomes)

            # Counts per kind, for debug output and support: the first thing
            # to check when a report may stem from a player's own file.
            #
            # @return [Hash{Symbol=>Integer}]
            def summary
              {
                attacks: ATTACK_SLOTS.sum { |s| attacks(s).size },
                flares: flares.size,
                statuses: statuses.size,
                outcomes: outcomes.size
              }
            end

            # Every loaded def file, in load order: what `;hmr combat/defs/`
            # matches, minus this module's own file (re-reading it would
            # reset the memo a second time and re-extend UserDefs for no gain).
            DEF_FILE_PATTERN = %r{[/\\]gemstone[/\\]combat[/\\]defs[/\\](?!supplements\.rb\z)[^/\\]+\.rb\z}.freeze

            # Re-reads the supplement file and re-executes every loaded def
            # file so each rebinds its TABLE from shipped defs plus the
            # current supplements. Equivalent to `;hmr combat/defs/` with
            # Ruby's constant-redefinition warnings silenced. A file that
            # fails to load is reported and skipped; because each def module
            # binds its table last and in one assignment, its previous
            # complete table stays live.
            #
            # @return [Array<String>] the files that reloaded cleanly
            def reload_defs!
              reset!
              files = $LOADED_FEATURES.grep(DEF_FILE_PATTERN)
              reloaded = []
              verbose = $VERBOSE
              $VERBOSE = nil
              files.each do |file|
                load(file)
                reloaded << file
              rescue ScriptError, StandardError => e
                report("#{File.basename(file)} failed to reload: #{e.class}: #{e.message}. Its previous definitions remain in effect.")
              end
              $VERBOSE = verbose
              report_debug("reloaded #{reloaded.size} def files; supplements: #{summary}")
              reloaded
            end

            private

            # Memoized lookups keyed by kind; each computes from the parsed
            # document on first use. The document itself is refreshed when
            # the file's mtime changes, which clears every kind. The document
            # is loaded before the kind's lock is taken: the mutex is not
            # reentrant, and the builders run inside it.
            # Publication is validated against the document it was built
            # from: a reset! (an edit, a reload) between capturing the
            # document and taking the lock empties the cache, so the captured
            # document is no longer the cached one and the build is discarded
            # and retried against the current file. Without this an
            # overlapping reader could publish old definitions into the new
            # cache, where they would persist until the next edit.
            def memoize(key)
              loop do
                refresh_if_changed
                return @cache[key] if @cache.key?(key)

                doc = document
                built = @lock.synchronize do
                  next :stale unless @cache[:document].equal?(doc)

                  @cache.key?(key) ? @cache[key] : (@cache[key] = build(key, doc))
                end
                return built unless built == :stale
              end
            end

            def build(key, doc)
              case key
              when :attacks  then build_attacks(doc)
              when :flares   then build_flares(doc)
              when :statuses then build_statuses(doc)
              when :outcomes then build_outcomes(doc)
              end
            end

            # ---- file ---------------------------------------------------

            # Drops the memo when the file appeared, vanished or changed
            # since the document was last parsed.
            def refresh_if_changed
              current = present? ? File.mtime(path) : nil
              return if @loaded_mtime == current && @cache.key?(:document)

              reset!
              @loaded_mtime = current
            end

            # The parsed top-level Hash, or an empty one when the file is
            # missing or unusable. Never raises.
            def document
              @cache[:document] || @lock.synchronize { @cache[:document] ||= load_document }
            end

            def load_document
              return {} unless present?

              doc = YAML.safe_load_file(path, permitted_classes: [], permitted_symbols: [], aliases: false)
              return {} if doc.nil?

              unless doc.is_a?(Hash)
                report("#{path} ignored -- expected a mapping of kinds (attacks:, flares:, ...) at the top level, got #{doc.class}. No supplemental definitions were loaded.")
                return {}
              end

              doc
            rescue Psych::Exception, SystemCallError => e
              report("#{path} could not be read: #{e.message}. No supplemental definitions were loaded.")
              {}
            end

            # ---- kinds --------------------------------------------------

            def build_attacks(doc)
              by_slot = ATTACK_SLOTS.to_h { |s| [s, []] }
              validate_entries(doc['attacks'], :attacks) do |entry, index|
                next unless (h = entry_hash(entry, :attacks, index))
                next unless (name = validate_def_name(h['name'], :attacks, index))
                next unless (slot = validate_slot(h['slot'], :attacks, index))
                next unless (patterns = validate_patterns(h['patterns'], :attacks, index))

                if patterns.none? { |rx| rx.names.include?('target') || rx.names.include?('attacker') } &&
                   !Attacks::ATTACKERLESS.include?(name)
                  report("attacks[#{index}] warning -- no pattern names a (?<target>...) or (?<attacker>...) capture, so hits will not attribute to a creature. It will still be applied.")
                end

                by_slot[slot] << Attacks::AttackDef.new(name, patterns)
                true
              end
              by_slot.transform_values(&:freeze).freeze
            end

            def build_flares(doc)
              accepted = {} # name => [index, flags] of the first accepted entry for that name
              validate_entries(doc['flares'], :flares) do |entry, index|
                next unless (h = entry_hash(entry, :flares, index))
                next unless (name = validate_def_name(h['name'], :flares, index))
                next unless (patterns = validate_patterns(h['patterns'], :flares, index))
                next unless (flags = validate_flare_flags(h, name, index, accepted[name]))

                accepted[name] ||= [index, flags]
                Flares::FlareDef.new(name, patterns, *flags)
              end.freeze
            end

            def build_statuses(doc)
              validate_entries(doc['statuses'], :statuses) do |entry, index|
                next unless (h = entry_hash(entry, :statuses, index))
                next unless (name = validate_def_name(h['name'], :statuses, index))

                add    = validate_patterns(h['add'], :statuses, index, key_name: 'add', allow_missing: true)
                remove = validate_patterns(h['remove'], :statuses, index, key_name: 'remove', allow_missing: true)
                next if add.nil? || remove.nil?

                if add.empty? && remove.empty?
                  report("statuses[#{index}] skipped -- needs at least one pattern under add: or remove:. This entry will not be applied.")
                  next
                end

                Statuses::StatusDef.new(name, add, remove)
              end.freeze
            end

            def build_outcomes(doc)
              known = Outcomes::OUTCOME_DEFS.map(&:type)
              validate_entries(doc['outcomes'], :outcomes) do |entry, index|
                next unless (h = entry_hash(entry, :outcomes, index))
                next unless (type = validate_def_name(h['type'], :outcomes, index, key_name: 'type'))

                unless known.include?(type)
                  report("outcomes[#{index}] skipped -- unknown outcome type #{type.inspect}; use one of #{known.join(', ')}. This entry will not be applied.")
                  next
                end
                next unless (patterns = validate_patterns(h['patterns'], :outcomes, index))

                Outcomes::OutcomeDef.new(type, patterns)
              end.freeze
            end

            # ---- field validators -----------------------------------------

            def entry_hash(entry, kind, index)
              return entry if entry.is_a?(Hash)

              report("#{kind}[#{index}] skipped -- expected a mapping with name: and patterns:, got #{entry.inspect}. This entry will not be applied.")
              nil
            end

            # @return [Symbol, nil]
            def validate_def_name(value, kind, index, key_name: 'name')
              unless value.is_a?(String) && value.match?(NAME_PATTERN)
                report("#{kind}[#{index}] skipped -- #{key_name}: must be a lowercase identifier (letters, digits, underscores), got #{value.inspect}. This entry will not be applied.")
                return nil
              end

              value.to_sym
            end

            # @return [Symbol, nil]
            def validate_slot(value, kind, index)
              return DEFAULT_ATTACK_SLOT if value.nil?

              slot = value.to_s.to_sym
              return slot if ATTACK_SLOTS.include?(slot)

              report("#{kind}[#{index}] skipped -- slot: must be one of #{ATTACK_SLOTS.join(', ')}, got #{value.inspect}. This entry will not be applied.")
              nil
            end

            # Compiles a list of pattern strings. Returns nil when the list
            # is malformed or every pattern failed, so the entry is dropped;
            # returns a frozen (possibly empty, when allow_missing) array
            # otherwise.
            #
            # @return [Array<Regexp>, nil]
            def validate_patterns(value, kind, index, key_name: 'patterns', allow_missing: false)
              return [].freeze if value.nil? && allow_missing

              unless value.is_a?(Array) && !value.empty?
                report("#{kind}[#{index}] skipped -- #{key_name}: must be a non-empty list of pattern strings, got #{value.inspect}. This entry will not be applied.")
                return nil
              end

              label = "#{kind}[#{index}].#{key_name}"
              compiled = value.each_with_index.filter_map do |source, i|
                next unless (expanded = expand_tokens(source, label, i))

                validate_regex(expanded, label, i)
              end

              if compiled.empty?
                report("#{kind}[#{index}] skipped -- none of its #{key_name} compiled. This entry will not be applied.")
                return nil
              end

              compiled.freeze
            end

            # Replaces {{MK_PRE}} / {{MK_POST}}; rejects unknown tokens.
            #
            # @return [String, nil]
            def expand_tokens(source, label, index)
              return source unless source.is_a?(String)

              unknown = source.scan(TOKEN_PATTERN).reject { |t| TOKENS.key?(t) }
              unless unknown.empty?
                report("#{label}[#{index}] skipped -- unknown token #{unknown.first}; known tokens are #{TOKENS.keys.join(', ')}. This pattern will not be applied.")
                return nil
              end

              TOKENS.reduce(source) { |s, (token, fragment)| s.gsub(token, fragment) }
            end

            # Resolves the three FlareDef booleans. A name that reuses a
            # shipped flare inherits the shipped flags for anything omitted,
            # and an explicit flag that contradicts the shipped one rejects
            # the entry: one name must never carry two behaviours. A new
            # name defaults every omitted flag to false.
            #
            # @return [Array(Boolean, Boolean, Boolean), nil]
            # The name's flags are owned by whichever def carries it first:
            # the shipped def when the name is shipped, otherwise the first
            # accepted supplemental entry (+prior+ = [index, flags]). Later
            # entries inherit what they omit and are rejected on a
            # contradiction, so a name never carries two behaviours no
            # matter where it was introduced.
            #
            # @return [Array(Boolean, Boolean, Boolean), nil]
            def validate_flare_flags(h, name, index, prior)
              shipped = Flares::FLARE_DEFS.find { |d| d.name == name }
              owner, defaults =
                if shipped then ["the shipped #{name} flare", [shipped.damaging, shipped.aoe, shipped.spawns]]
                elsif prior then ["flares[#{prior[0]}] (#{name})", prior[1]]
                else [nil, [false, false, false]]
                end

              FLARE_FLAGS.each_with_index.map do |flag, i|
                value = h[flag]
                next defaults[i] if value.nil?

                unless [true, false].include?(value)
                  report("flares[#{index}] skipped -- #{flag}: must be true or false, got #{value.inspect}. This entry will not be applied.")
                  return nil
                end

                if owner && value != defaults[i]
                  report("flares[#{index}] skipped -- #{flag}: #{value} contradicts #{owner} (#{flag}: #{defaults[i]}); a reused name keeps the behaviour it was first given. Omit the flag or use a new name. This entry will not be applied.")
                  return nil
                end

                value
              end
            end
          end
        end
      end
    end
  end
end
