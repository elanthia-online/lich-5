# frozen_string_literal: true

module Lich
  module Genie
    # The global lists Remix keeps on its Globals object and the `#command` arms edit (Command.cs
    # R): the #triggers ({Triggers}), the class list ({ClassList}), the gags and substitutes
    # ({StreamFilters}) and the aliases ({AliasList}), plus where their files live (Config.
    # ConfigDir). One bundle per session: the glue's reads the process-wide registries through
    # callables (a rebuilt registry -- config_dir change, reload -- is followed); headless code
    # and the flow harness build their own.
    class Lists
      # @param triggers [Triggers, #call, nil] the registry, or a callable returning it
      # @param classes [ClassList, #call, nil]
      # @param filters [StreamFilters, #call, nil]
      # @param aliases [AliasList, #call, nil]
      # @param names [NameList, #call, nil] the name list's keys (`#name`; the colours are the front end's)
      # @param config_dir [String, #call, nil] Remix's Config.ConfigDir (where triggers.cfg,
      #   classes.cfg, gags.cfg, substitutes.cfg, aliases.cfg are read); nil = no files
      # @param writable [Boolean] whether the save arms write there (the flow harness: false --
      #   its files are fixtures)
      def initialize(triggers: nil, classes: nil, filters: nil, aliases: nil, names: nil, config_dir: nil, writable: true)
        @triggers = source(triggers) { Triggers.new }
        @classes = source(classes) { ClassList.new.tap(&:clear) }
        @filters = source(filters) { StreamFilters.new }
        @aliases = source(aliases) { AliasList.new }
        @names = source(names) { NameList.new }
        @config_dir = config_dir.respond_to?(:call) ? config_dir : -> { config_dir }
        @writable = writable
        @class_event = Mutex.new # serializes {#class_changed}
      end

      # @return [Triggers]
      def triggers = @triggers.call
      # @return [ClassList]
      def classes = @classes.call
      # @return [StreamFilters]
      def filters = @filters.call
      # @return [AliasList]
      def aliases = @aliases.call
      # @return [NameList]
      def names = @names.call

      # @param name [String] e.g. "triggers.cfg"
      # @return [String, nil] the path the load arms read (nil = no config dir)
      def file(name)
        dir = @config_dir.call
        dir && File.join(dir, name)
      end

      # @return [Boolean] whether the save arms write ({#save_file})
      def writable? = @writable

      # @param name [String]
      # @return [String, nil] the path the save arms write, nil when this bundle never writes
      def save_file(name)
        @writable ? file(name) : nil
      end

      # LocalDirectory.ValidateDirectory for a `#config` directory key ({ConfigSetting}): relative to
      # the folder above the config dir (Remix: LocalDirectory.Path, the parent of Config\); a
      # missing directory is created only by a writable bundle that has a config dir (a headless
      # one reports "Directory Created" relative to the working directory and creates nothing).
      # @param path [String]
      # @return [String] the message
      # @raise [Error]
      def validate_directory(path)
        dir = @config_dir.call
        base = dir ? File.dirname(dir) : Dir.pwd
        ConfigSetting.validate_directory(path, base: base, create: @writable && !dir.nil?)
      end

      # Command_EventClassChange (FormMain.cs:7483-7519 R): every class-list entry, in list order,
      # re-applied to the triggers and the gags/substitutes (the highlights are the front end's).
      # Two class events at once (two scripts' `#class`, a #trigger body's) are applied one after the
      # other: each reads the class list and applies all of it before the next reads it, so a stale
      # snapshot never lands after a newer one (Remix runs every class
      # event on its UI thread).
      # @return [void]
      def class_changed
        @class_event.synchronize do
          triggers = self.triggers
          filters = self.filters
          classes.each_state do |name, state|
            triggers.toggle_class(name, state)
            filters.toggle_class(name, state)
          end
        end
      end

      private

      def source(value)
        return value if value.respond_to?(:call)

        object = value || yield
        -> { object }
      end
    end
  end
end
