# frozen_string_literal: true

module Lich
  module Genie
    # A character's Genie global variables, held in memory for the life of the Lich
    # process (one character per process). Port of Remix's Globals.VariableList model
    # (Globals.cs:547-818 R):
    #
    #   * one namespace; each key carries Genie's bSaveToFile flag (`persist`): true for
    #     `#var`/`#math` (VariableType.SaveToFile), false for `#tvar` (Temporary) and
    #     `#svar` (Server). Setting a key replaces both value and flag (Variables.Add,
    #     Globals.cs:605-618 R).
    #   * NO disk I/O on set/delete. variables.cfg is read once when the store is built
    #     (engine start, FormMain.cs:2311 R) and written only by {#save} (`#var save`,
    #     `#save vars|all`). Remix's FormClosing saves nothing (FormMain.cs:1592-1705 R)
    #     and a script ending saves nothing, so neither does Lich exiting.
    #   * {#load} merges a file in without clearing (`#var load`); `#load vars` first
    #     calls {#clear_user}. There is no mtime watch: another process's save is seen
    #     only after an explicit load, as with two native Genie sessions.
    #   * Remix's reserved names ({Reserved::GENIE_RESERVED_NAMES}) are never written to
    #     or read from the file: our reserved values are live game state, and a loaded or
    #     saved copy would shadow it. This is a decided approximation. In Remix a
    #     script's `#var NAME x` re-types the key SaveToFile, so `#var save` writes it:
    #     game-updated names (health, roundtime, ...) until the next update re-types them
    #     Reserved, and names Remix sets only once in SetDefaultGlobalVars (client,
    #     version, repeatregex, roomnote, scriptdir/mapdir/..., Globals.cs:825-919 R)
    #     for good -- startup runs SetDefaultGlobalVars and then Load overrides it.
    #   * Every write carries a {WriteClock} stamp ({#stamp}) so Variables#global_get can let
    #     a later game update of a reserved name win over a script's `#var`.
    #
    # Concurrency: one instance is shared by every Genie thread in the process -- each
    # script's thread AND the downstream thread that fires #triggers (`#var misty 1`
    # from a combat trigger). Every public method runs under @mutex, including the
    # file write in {#save} (Remix holds the list's reader lock while writing,
    # Globals.cs:792-808 R), so a save never snapshots a half-applied load.
    class GlobalStore
      # @return [String, nil] the path {#save}/{#load} use by default: the last path
      #   given to {#load} (Remix's m_FileName, Globals.cs:722-737 R)
      attr_reader :file

      # @param file [String, nil] variables.cfg to read now, or nil for a store with
      #   no backing file (specs, flow harness)
      # @param write_clock [WriteClock] stamps each write so a later game update of a
      #   reserved name can win over it (see Variables#global_get)
      def initialize(file: nil, write_clock: WriteClock::SHARED)
        @file = file
        @write_clock = write_clock
        @values = {}
        @persistent = {}
        @server = {} # #svar keys (VariableType.Server), for the listing
        @stamps = {}
        @mutex = Mutex.new
        @save_mutex = Mutex.new
        merge_file(file) if file
      end

      # @param name [String]
      # @return [String, nil]
      def get(name)
        @mutex.synchronize { @values[name] }
      end

      # @param name [String]
      # @return [Boolean]
      def key?(name)
        @mutex.synchronize { @values.key?(name) }
      end

      # @param name [String]
      # @param value [Object] coerced to String
      # @param persist [Boolean] Genie's bSaveToFile: true for #var/#math, false for
      #   #tvar/#svar
      # @param server [Boolean] VariableType.Server (`#svar`, Command.cs:983 R): only the
      #   listing tells it from a temporary one ({#kind})
      # @return [String] the stored value
      def set(name, value, persist: true, server: false)
        @mutex.synchronize do
          @values[name] = value.to_s
          @persistent[name] = persist ? true : false
          server ? @server[name] = true : @server.delete(name)
          @stamps[name] = @write_clock.tick
          @values[name]
        end
      end

      # Remix's VariableList indexer set (`VariableList[key] = value`, Globals.cs:665-690 R): an
      # existing key keeps its type (SaveToFile, Temporary or Server) and only takes the value; a
      # new one is added SaveToFile. Game.SendText's $lastinput (Game.cs:529 R).
      # @param name [String]
      # @param value [Object] coerced to String
      # @return [String] the stored value
      def assign(name, value)
        @mutex.synchronize do
          @values[name] = value.to_s
          @persistent[name] = true unless @persistent.key?(name)
          @stamps[name] = @write_clock.tick
          @values[name]
        end
      end

      # The key's VariableType as ListVariables groups it (Command.cs:3002-3079 R).
      # @param name [String]
      # @return [Symbol, nil] :save (SaveToFile), :temporary, :server; nil when absent
      def kind(name)
        @mutex.synchronize do
          if !@values.key?(name) then nil
          elsif @server[name] then :server
          else @persistent[name] ? :save : :temporary
          end
        end
      end

      # @param name [String]
      # @return [Integer, nil] the {WriteClock} stamp of the last write of +name+
      def stamp(name)
        @mutex.synchronize { @stamps[name] }
      end

      # @param name [String]
      # @return [String, nil] the removed value, if any
      def delete(name)
        @mutex.synchronize do
          @persistent.delete(name)
          @server.delete(name)
          @stamps.delete(name)
          @values.delete(name)
        end
      end

      # @return [Array<String>]
      def keys
        @mutex.synchronize { @values.keys }
      end

      # @param name [String]
      # @return [Boolean] whether +name+ would be written by {#save}
      def persistent?(name)
        @mutex.synchronize { savable?(name) }
      end

      # Write every bSaveToFile key (except Remix-reserved names) to +path+, in
      # Remix's order and format (Variables.Save, Globals.cs:776-818 R). Does not
      # change {#file}.
      # @param path [String, nil] defaults to {#file}
      # @return [Boolean] false when there is no path or the write failed (Remix's
      #   Save swallows the exception and returns false)
      def save(path = nil)
        # @save_mutex orders whole saves (an older snapshot never lands last); the
        # snapshot is taken under @mutex but written outside it, so a contended Windows
        # rename (ConfigFile.atomic_replace retries) never blocks get/set on the
        # trigger thread -- Remix's Add does not take the lock Save holds.
        @save_mutex.synchronize do
          target, rows = @mutex.synchronize { [path || @file, @values.select { |key, _| savable?(key) }] }
          return false if target.nil?

          VariableFile.save(target, rows)
          true
        end
      rescue StandardError # Save is catch (Exception) -> false (Globals.cs:818-822 R)
        false
      end

      # Merge +path+ in (Variables.Load, Globals.cs:724-763 R): each row sets a
      # bSaveToFile key; keys absent from the file are kept. Remembers +path+ as
      # {#file} even when the file does not exist (Globals.cs:737 R).
      # @param path [String, nil] defaults to {#file}
      # @param clear_first [Boolean] `#load vars`: {#clear_user} first (Command.cs:
      #   653-660 R), in the same critical section so no other thread sees the gap
      # @return [Boolean] false when absent or unreadable, or a malformed row aborted
      #   the rest (never raises: Load is catch (Exception), Globals.cs:757-762 R)
      def load(path = nil, clear_first: false)
        @mutex.synchronize do
          @file = path if path
          drop_persistent if clear_first
          return false if @file.nil?

          merge_file(@file)
        end
      end

      # Drop every bSaveToFile key, keeping #tvar/#svar keys (Variables.ClearUser,
      # Globals.cs:637-660 R). Used by `#var clear` and `#load vars`.
      # @return [void]
      def clear_user
        @mutex.synchronize { drop_persistent }
        nil
      end

      private

      def drop_persistent
        @persistent.select { |_, persist| persist }.each_key do |key|
          @persistent.delete(key)
          @server.delete(key)
          @stamps.delete(key)
          @values.delete(key)
        end
      end

      def savable?(key)
        @persistent[key] == true && !Reserved.genie_reserved?(key)
      end

      def merge_file(path)
        entries, ok = VariableFile.read(path)
        entries.each do |key, value|
          next if Reserved.genie_reserved?(key)

          @values[key] = value
          @persistent[key] = true
          @server.delete(key)
          @stamps[key] = @write_clock.tick
        end
        ok
      end
    end
  end
end
