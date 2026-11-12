# frozen_string_literal: true

module Lich
  module Genie
    # The in-Lich stand-in for the Jint 4.0.0 engine Remix gives each script (m_JintEngine,
    # Script.cs:691-706 R; Genie4.csproj:237 R). Ruby has no JavaScript engine, so this runs:
    #   * the host functions Remix registers with Engine.SetValue -- echo, put, getGlobal, getVar,
    #     setGlobal, setVar (Script.cs:699-776 R) -- with Jint's argument conversions;
    #   * the JavaScript it recognises by fingerprint, reproducing what Jint 4 does with it, faults
    #     included (`list.length()` throws in Jint 4): every function declaration of the
    #     published js_arrays.js versions ({JsArrays::FUNCTION_BODIES}, via {JsSource}) and the
    #     `<% %>` blocks of the corpus ({JsArrays::SOURCES});
    #   * the expression-statement slice of {JsParser} (`doPush("arr","$1")`, `getVar("x")`, ...).
    # A function declaration it does not recognise is defined, but calling it is {Unsupported}.
    # Anything else is {Unsupported} (the caller announces it): a real engine would be a Lich
    # Gemfile change, which this port does not make (docs/genie-engine/open-items.md L1).
    class JsRuntime
      # A JavaScriptException: +message+ is Jint's ex.Message.
      class JsError < Error; end

      # JavaScript this stand-in cannot run.
      class Unsupported < Error; end

      # A global this stand-in holds but cannot represent (SkillData's `list` array).
      OPAQUE = Object.new.freeze

      HOST_FUNCTIONS = %w[echo put getGlobal getVar setGlobal setVar].freeze

      # The script side of the host functions.
      # @!attribute local [#call] name => the local's value or nil (m_oLocalVarList)
      # @!attribute global [#call] name => the global's value or nil (m_oGlobals.VariableList)
      # @!attribute set_local [#call] (name, value): AddLocalVariable (raises "%name")
      # @!attribute set_global [#call] (name, value): the VariableList write of JsSetGlobalVariable
      # @!attribute echo [#call] text: PrintEcho
      # @!attribute send_text [#call] text: Script.SendText
      Host = Struct.new(:local, :global, :set_local, :set_global, :echo, :send_text, keyword_init: true)

      # @param host [Host]
      def initialize(host)
        @host = host
        @functions = {} # name => JsArrays callable, from a recognised source
        @globals = {}   # name => value, what a recognised source left behind (`i` of a for loop)
        @opaque = false # set once JavaScript ran that we could not: anything may be defined now
      end

      # Engine.Execute(source) (RunJsblock, Script.cs:3614-3619 R).
      # @param source [String] the block's rows, each followed by a line break
      # @return [void]
      # @raise [JsError, Unsupported]
      def execute(source)
        guard_unsupported do
          known = JsArrays.source_for(source)
          known ? known.run(self) : run_program(source)
        end
        nil
      end

      # Engine.Evaluate(text) (EvalJS, Script.cs:2861-2877 R).
      # @param text [String]
      # @return [String, true, false, Float, nil, JsValue::NULL] the completion value
      # @raise [JsError, Unsupported]
      def evaluate(text)
        guard_unsupported { run(JsParser.parse(text)) }
      end

      # --- for JsArrays: what a recognised source does ---------------------------------------

      # Function declarations of a recognised source.
      # @param functions [Hash{String=>#call}]
      def define(functions)
        @functions.merge!(functions)
      end

      # A call of +name+ from a recognised function (doRemove's `findIndex(..)`): whatever the
      # engine holds under that name now.
      # @param args [Array] JS values
      def call_function(name, args)
        invoke(callee(name), name, args)
      end

      # A global assignment of a recognised source (`for(i = 0; ...)` leaves `i`).
      def assign(name, value)
        @globals[name] = value
      end

      # `getVar(name)` (JsGetVariable, Script.cs:739-752 R). @return [String]
      def get_var(name)
        key = JsValue.param_string(name)
        return 'undefined' if key.nil?

        @host.local.call(key)&.to_s || 'undefined'
      end

      # `getGlobal(name)` (JsGetGlobalVariable -> GetVariable, Script.cs:730-737, 2272-2280 R).
      # @return [String]
      def get_global(name)
        key = JsValue.param_string(name)
        key.nil? ? 'undefined' : @host.global.call(key).to_s
      end

      # `setVar(name, value)` (JsSetVariable, Script.cs:770-776 R): AddLocalVariable, so "%name"
      # is raised; nothing when either is undefined/null.
      def set_var(name, value)
        key = JsValue.param_string(name)
        text = JsValue.clr_string(value)
        @host.set_local.call(key, text) unless key.nil? || text.nil?
        nil
      end

      private

      def guard_unsupported
        yield
      rescue Unsupported
        @opaque = true
        raise
      end

      # Engine.Execute of a program that is not a whole {JsArrays::SOURCES} block: the whole program
      # is parsed first (a syntax error runs nothing), then its function declarations are hoisted (a
      # later one of the same name wins; each a known body's replay or unsupported when called),
      # then its statements run.
      def run_program(source)
        declarations, rest = JsSource.split(source)
        statements = JsParser.parse(rest)
        declarations.each { |declaration| @functions[declaration.name] = JsArrays.callable_for(declaration) }
        run(statements)
      end

      # @return the completion value of the last expression statement (undefined if none)
      def run(statements)
        statements.inject(nil) { |_, node| value_of(node) }
      end

      def value_of(node)
        case node
        when JsParser::Literal then node.value
        when JsParser::Ref then lookup(node.name)
        else call(node)
        end
      end

      def lookup(name)
        case name
        when 'undefined' then nil
        when 'NaN' then Float::NAN
        when 'Infinity' then Float::INFINITY
        else
          value = @globals.fetch(name) { return missing(name) }
          raise Unsupported, "the value of #{name}" if value.equal?(OPAQUE)

          value
        end
      end

      # An unresolvable reference: Jint 4's ReferenceError (genieflow probe), unless JavaScript we
      # could not run may have defined it.
      def missing(name)
        raise Unsupported, "a function value (#{name})" if function?(name)
        raise Unsupported, "#{name} (after JavaScript this port could not run)" if @opaque

        raise JsError, "#{name} is not defined"
      end

      def function?(name)
        @functions.key?(name) || HOST_FUNCTIONS.include?(name)
      end

      # The callee resolves before the arguments are evaluated (an unknown name throws first).
      def call(node)
        function = callee(node.name)
        invoke(function, node.name, node.args.map { |arg| value_of(arg) })
      end

      # @return [#call, :host] a declared function (it shadows a host function of its name) or :host
      def callee(name)
        return @functions[name] if @functions.key?(name)
        return :host if HOST_FUNCTIONS.include?(name)

        lookup(name) # an unknown name: the ReferenceError
        raise Unsupported, "a call of #{name}" # undefined(), i(): Jint's TypeError is not modelled
      end

      def invoke(function, name, args)
        function == :host ? host_call(name, args) : function.call(self, args)
      end

      def host_call(name, args)
        case name
        when 'echo' then @host.echo.call(JsValue.clr_string(args[0]) || 'undefined')
        when 'put' then (text = JsValue.clr_string(args[0])) && @host.send_text.call(text)
        when 'getGlobal' then return get_global(args[0])
        when 'getVar' then return get_var(args[0])
        when 'setGlobal' then set_global(args[0], args[1])
        else set_var(args[0], args[1])
        end
        nil
      end

      # JsSetGlobalVariable (Script.cs:754-768 R): the VariableList indexer (an existing name keeps
      # its type) or Add (a new SaveToFile one); no variable-change event.
      def set_global(name, value)
        key = JsValue.param_string(name)
        text = JsValue.clr_string(value)
        @host.set_global.call(key, text) unless key.nil? || text.nil?
      end
    end
  end
end
