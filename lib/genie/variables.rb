# frozen_string_literal: true

module Lich
  module Genie
    # A Genie script's variable view. Two namespaces addressed by sigil (not a
    # fallback chain):
    #   * local (`%name`)  -- per-script, in-memory (set by `var`/`setvariable`)
    #   * global (`$name`) -- shared via an injected {GlobalStore} (#var/#tvar/#svar)
    #
    # Reserved globals that reflect live game state (`$health`, ...) are resolved
    # through an injected `game_state` object ({ReservedState}); between it and the store
    # the later write wins ({#global_get}), so this class stays free of any Lich/XMLData
    # dependency.
    class Variables
      # @param game_state [#[], #key?, nil] reserved-global resolver (e.g. XMLData adapter)
      # @param global_store [GlobalStore, nil] shared global store (in-memory if nil)
      def initialize(game_state: nil, global_store: nil)
        @local = {}
        @game_state = game_state
        @store = global_store || GlobalStore.new(file: nil)
      end

      # @return [#[], #key?, nil] the reserved-global resolver ({Specials} reads the
      #   spell timer from it)
      attr_reader :game_state

      # --- local (%) --------------------------------------------------------

      # @return [String, nil]
      def local_get(name)
        @local[name]
      end

      # @return [String]
      def local_set(name, value)
        @local[name] = value.to_s
      end

      # @return [String, nil] the removed value, if any
      def local_delete(name)
        @local.delete(name)
      end

      # @return [Boolean]
      def local_key?(name)
        @local.key?(name)
      end

      # --- global ($) -------------------------------------------------------

      # @return [String, nil] the last-written of the store value and the reserved game
      #   state value
      #
      # Remix keeps one variable list, so a script's `#var invisible 0` holds until the
      # next game update of `invisible` and no longer (Globals.cs:604-617 R). The
      # store and the game state each stamp their writes from one {WriteClock}: the
      # store's value wins unless the game state wrote the name after it. A name the
      # game state never wrote (client, version, scriptdir, ... which Remix sets only
      # once at start-up) keeps the script's value for good, as in Remix.
      #
      # A few names the game state resolves live with no update to stamp (the EXPTracker
      # and TimeTracker plugin namespaces, $scriptlist): for those the resolver declares
      # itself authoritative and live state wins over a stored copy.
      def global_get(name)
        if @game_state.respond_to?(:authoritative?) && @game_state.authoritative?(name)
          live = @game_state[name]
          return live unless live.nil?
        end

        value = @store.get(name)
        return value unless value.nil? || game_wrote_later?(name)

        live = @game_state && @game_state[name]
        live.nil? ? value : live
      end

      # @param persist [Boolean] Genie's bSaveToFile: true for #var/#math, false for
      #   #tvar and #svar (see {GlobalStore#set})
      # @param server [Boolean] `#svar` (VariableType.Server; {GlobalStore#kind})
      # @return [String]
      def global_set(name, value, persist: true, server: false)
        @game_state.observe(name) if @game_state.respond_to?(:observe)
        @store.set(name, value, persist: persist, server: server)
      end

      # JsSetGlobalVariable's write (Script.cs:754-768 R): the VariableList indexer, so an
      # existing name keeps its type and a new one is added SaveToFile ({GlobalStore#assign}).
      # @return [String]
      def global_assign(name, value)
        @game_state.observe(name) if @game_state.respond_to?(:observe)
        @store.assign(name, value)
      end

      # ListVariables (Command.cs:3002-3079 R): "Active variables: ", "Filter: <pattern>" when one
      # is given, then every global whose name contains +pattern+ (ordinal), grouped SaveToFile,
      # "(temporary) ", "(reserved) ", "(server) " -- each group in SortedList order -- as
      # "$name=value", or "None.". A reserved name a script re-set ({#global_get}'s last writer)
      # lists under the script's type, as in Remix's one variable list; a reserved value is its
      # raw stored text (`@time@`). The blank line Remix prints first is not produced (the echo
      # port takes single lines).
      # @param pattern [String]
      # @return [Array<String>]
      def listing(pattern)
        rows = global_names.filter_map do |name|
          next unless pattern.empty? || name.include?(pattern)

          kind, value = global_entry(name)
          kind && [kind, name, value]
        end
        lines = ['Active variables: ']
        lines << "Filter: #{pattern}" unless pattern.empty?
        LISTING_GROUPS.each do |kind, prefix|
          group = rows.select { |row| row[0] == kind }.to_h { |_, name, value| [name, value] }
          Collation.sort(group.keys).each { |name| lines << "#{prefix}$#{name}=#{group[name]}" }
        end
        lines << 'None.' if rows.empty?
        lines
      end

      # ListVariables' type order and prefixes.
      LISTING_GROUPS = [[:save, ''], [:temporary, '(temporary) '], [:reserved, '(reserved) '], [:server, '(server) ']].freeze

      # @return [String, nil]
      def global_delete(name)
        @store.delete(name)
      end

      # @return [Boolean]
      def global_key?(name)
        @store.key?(name) || (@game_state&.key?(name) || false)
      end

      # `#var save`: write the persistent globals to the store's variables.cfg.
      # @return [Boolean]
      def global_save
        @store.save
      end

      # `#var load` (merge) / `#load vars` (clear_first: drop persistent globals first).
      # @return [Boolean]
      def global_load(clear_first: false)
        @store.load(clear_first: clear_first)
      end

      # `#var clear`: drop every persistent global, keep #tvar/#svar ones.
      # @return [void]
      def global_clear_user
        @store.clear_user
      end

      # --- uniform accessors (used by shared resolution logic) --------------

      # @param scope [:local, :global]
      # @return [String, nil]
      def get(scope, name)
        scope == :local ? local_get(name) : global_get(name)
      end

      # @param scope [:local, :global]
      # @return [Boolean]
      def key?(scope, name)
        scope == :local ? local_key?(name) : global_key?(name)
      end

      private

      def global_names
        reserved = @game_state.respond_to?(:names) ? @game_state.names : []
        (@store.keys + reserved).uniq
      end

      # [kind, value] of one global as the listing shows it.
      def global_entry(name)
        kind = @store.kind(name)
        return [kind, @store.get(name)] if kind && !game_wrote_later?(name)

        live = @game_state && @game_state[name]
        return [:reserved, live] unless live.nil?

        kind && [kind, @store.get(name)]
      end

      # @return [Boolean] whether the game state wrote +name+ after the store did
      def game_wrote_later?(name)
        return false unless @game_state.respond_to?(:stamp)

        game = @game_state.stamp(name)
        !game.nil? && game > @store.stamp(name).to_i
      end
    end
  end
end
