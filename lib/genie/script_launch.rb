# frozen_string_literal: true

module Lich
  module Genie
    # What a `.name args` launch (Command.RunScript -> FormMain.ClassCommand_RunScript,
    # Command.cs:2536-2539, 2695-2698 R; FormMain.cs:4678-4714 R) loads, exactly:
    #   * the name is ParseArgs token 0, ToLower, Trim, minus the script char
    #     ({ScriptArgs.split_launch}), plus ".cmd" unless it already ends with it
    #     (FormMain.cs:4682-4687 R) -- so `put .foo.cmd` loads foo.cmd and `put .` loads ".cmd";
    #   * that ONE file in the script dir (Script.AppendFile, Script.cs:3683-3697 R): no prefix
    #     match, no other extension, no `custom/` layer, no .gz -- Lich's finder (Script.start ->
    #     __find_script_file) does all of those, so through it `put .wait` would start dr-scripts'
    #     wait.lic and `put .foo.cmd` would find nothing;
    #   * a missing file is "File not found: <file>" (FileInfo.Length throws
    #     FileNotFoundException when the file does not exist, Script.cs:3698, 3779-3784 R), an
    #     empty one "Unable to load file: <file>" (Script.cs:3771-3777 R).
    # Remix runs on Windows, whose file system matches names case-insensitively: {.locate}
    # takes the exact spelling first, then the one entry of the directory that equals it
    # ignoring case (Linux). The rest of a launch -- the dupe check and the start -- is the
    # host's ({ScriptList#duplicates}, the glue's GenieScript.launch).
    module ScriptLaunch
      # Config.ScriptExtension's default (Config.cs:82 R). Not read from settings.cfg: Lich routes
      # only `.cmd` files to the engine (lib/common/script.rb), so another extension could never
      # run here (tracked, 0 corpus).
      EXTENSION = '.cmd'

      # A script file the launch cannot load; the message is Remix's PrintError text.
      class NotLoadable < Error; end

      # One parsed launch: ClassCommand_RunScript's ScriptName (= the new Script's FileName, the
      # dupe-check key) and al[1..] (the launch arguments).
      Request = Struct.new(:file_name, :args, keyword_init: true) do
        # @return [String] %scriptname ({ScriptLaunch.script_name})
        def script_name = ScriptLaunch.script_name(file_name)
      end

      module_function

      # ParseArgs(sText, true) then the name (FormMain.cs:4680-4687 R). ParseArgs runs first, so a
      # malformed argument string raises before any dupe is aborted.
      # @param name [String] token 0 minus the script char, lower-cased and trimmed
      # @param rest [String, Array<String>] the text after token 0
      # @return [Request]
      # @raise [Error] ParseArgs' "Invalid string in Parse Arguments" ({ScriptArgs.parse_launch})
      def request(name, rest)
        args = ScriptArgs.parse_launch(name, rest)
        Request.new(file_name: file_name(name), args: args)
      end

      # @param name [String] token 0 minus the script char, lower-cased and trimmed
      # @return [String] ScriptName: +name+, plus ".cmd" unless it already ends with it
      def file_name(name)
        name = name.to_s
        name.end_with?(EXTENSION) ? name : "#{name}#{EXTENSION}"
      end

      # %scriptname (Script.LoadFile, Script.cs:1985-1992 R): the file name minus its ".cmd"
      # when it ends with it (ToLower test), else the file name.
      # @param file_name [String]
      # @return [String]
      def script_name(file_name)
        file_name.downcase.end_with?(EXTENSION) ? file_name[0...-EXTENSION.length] : file_name
      end

      # $scriptlist's entry: Path.GetFileNameWithoutExtension(FileName) (FormMain.cs:4532 R) --
      # the part after the last `\` or `/`, up to its last `.` ("" for ".cmd").
      # @param file_name [String]
      # @return [String]
      def list_name(file_name)
        base = file_name.to_s[%r{[^\\/]*\z}]
        dot = base.rindex('.')
        dot ? base[0...dot] : base
      end

      # AppendFile's lookup (Script.cs:3683-3800 R) under +dir+.
      # @param dir [String] the engine's script dir ($scriptdir)
      # @param file_name [String]
      # @return [String] the path of the loadable file
      # @raise [NotLoadable] "File not found: <file>" or "Unable to load file: <file>"
      def resolve(dir, file_name)
        path = locate(dir, file_name)
        raise NotLoadable, "File not found: #{file_name}" if path.nil?
        raise NotLoadable, "Unable to load file: #{file_name}" if File.size(path).zero?

        path
      end

      # The file +file_name+ names under +dir+: the exact spelling, else the one directory entry
      # equal to it ignoring case. A `\` is a path separator, as on Windows; Remix takes a name
      # holding one as a path relative to its working directory instead of the script dir
      # (Script.cs:3686-3697 R) -- not modelled (tracked, 0 corpus).
      # @return [String, nil]
      def locate(dir, file_name)
        path = File.join(dir, file_name.tr('\\', '/'))
        return path if File.file?(path)

        parent = File.dirname(path)
        base = File.basename(path)
        return nil if base.empty? || !File.directory?(parent)

        match = Dir.children(parent).find { |entry| entry.casecmp?(base) && File.file?(File.join(parent, entry)) }
        match && File.join(parent, match)
      rescue SystemCallError
        nil
      end
    end
  end
end
