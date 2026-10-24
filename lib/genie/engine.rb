# frozen_string_literal: true

module Lich
  module Genie
    # Convenience facade tying the pipeline together: compile source with {Lexer},
    # build a {Variables} store, and construct/run an {Interpreter}. Used by the
    # GenieScript Lich glue and by tests.
    module Engine
      module_function

      # @param source [String, Array<String>] script source (or pre-split lines)
      # @param file_name [String] the main file's name ("<name>.cmd"; Remix's sFriendlyName)
      # @param include_loader [#call, nil]
      # @param ignore_warnings [Boolean]
      # @return [Lexer::Program]
      # @raise [Lexer::LoadFailed]
      def compile(source, file_name: 'script', include_loader: nil, ignore_warnings: false)
        Lexer.compile(source, file_name: file_name, include_loader: include_loader, ignore_warnings: ignore_warnings)
      end

      # Build an interpreter for +source+. Any remaining keyword ports (game:,
      # input:, echo:, print:, hooks:, clock:, specials:) are passed through to Interpreter.
      #
      # Script.LoadFile (Script.cs:1971-2017 R): the load's PrintError lines (duplicate-label
      # warnings, then a fatal error) go out through the +print+ port (else +echo+) as they
      # would in Remix, before the script runs; the warning text left in %lastscripterror
      # stays there. A failed load re-raises {Lexer::LoadFailed}: the script never starts.
      #
      # @param source [String, Array<String>]
      # @param name [String]
      # @param variables [Variables, nil]
      # @param game_state [#[], #key?, nil] reserved-global resolver
      # @return [Interpreter]
      # @raise [Lexer::LoadFailed]
      def build(source, name: 'genie', variables: nil, game_state: nil, file_name: nil,
                ignore_warnings: false, include_loader: nil, **ports)
        printer = ports[:print] || ->(text, _kind) { ports[:echo]&.call(text) }
        begin
          program = compile(source, file_name: file_name || "#{name}.cmd", include_loader: include_loader,
                                    ignore_warnings: ignore_warnings)
        rescue Lexer::LoadFailed => e
          e.lines.each { |line| printer.call(line, :error) }
          raise
        end
        program.messages.each { |line| printer.call(line, :error) }
        store = variables || Variables.new(game_state: game_state)
        store.local_set('lastscripterror', program.last_error) if program.last_error
        Interpreter.new(program: program, variables: store, name: name, **ports)
      end

      # Build and run in one call.
      # @return [void]
      def run(source, **opts)
        build(source, **opts).run
      end
    end
  end
end
