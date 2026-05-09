# frozen_string_literal: true

require 'ostruct'
require 'prism'

module ScriptRuntimeHarness
  GLOBAL_DEFS_PATH = File.expand_path('../../lib/global_defs.rb', __dir__)

  def self.global_defs_module(*method_names)
    wanted = method_names.map(&:to_sym)
    lines = File.readlines(GLOBAL_DEFS_PATH)
    result = Prism.parse_file(GLOBAL_DEFS_PATH)
    nodes = []
    queue = [result.value]

    until queue.empty?
      node = queue.shift
      nodes << node if node.type == :def_node && wanted.include?(node.name)
      queue.concat(node.child_nodes.compact)
    end

    missing = wanted - nodes.map(&:name)
    raise "global_defs methods not found: #{missing.join(', ')}" unless missing.empty?

    Module.new.tap do |mod|
      nodes.sort_by { |node| node.location.start_line }.each do |node|
        source = lines[(node.location.start_line - 1)..(node.location.end_line - 1)].join
        mod.module_eval(source, GLOBAL_DEFS_PATH, node.location.start_line)
      end
    end
  end

  class FakeScript
    attr_accessor :name, :custom, :no_echo, :downstream_buffer, :match_stack_labels,
                  :match_stack_strings, :jump_label, :watchfor, :want_downstream,
                  :want_downstream_xml, :want_upstream, :want_script_output,
                  :silent, :hidden, :vars

    def initialize(name: 'test-script', lines: [])
      @name = name
      @custom = false
      @no_echo = false
      @downstream_buffer = lines.dup
      @match_stack_labels = []
      @match_stack_strings = []
      @watchfor = {}
      @want_downstream = true
      @want_downstream_xml = false
      @want_upstream = false
      @want_script_output = false
      @silent = false
      @hidden = false
      @vars = []
      @cleared = false
    end

    def custom?
      @custom
    end

    def gets
      @downstream_buffer.shift
    end

    def gets?
      @downstream_buffer.first
    end

    def clear
      @cleared = true
      @downstream_buffer.clear
    end

    def cleared?
      @cleared
    end

    def match_stack_add(label, string)
      @match_stack_labels << label
      @match_stack_strings << string
    end

    def match_stack_clear
      @match_stack_labels.clear
      @match_stack_strings.clear
    end
  end

  class FakeDb
    attr_reader :queries

    def initialize
      @queries = []
      @uservars = {}
    end

    def get_first_value(query, params = [])
      @queries << [:get_first_value, query, params]
      return @uservars[params.first] if query.match?(/\bfrom\s+uservars\b/i)

      nil
    end

    def execute(query, params = [])
      @queries << [:execute, query, params]
      if query.match?(/\binto\s+uservars\b/i)
        @uservars[params[0]] = params[1]
      end
    end

    def stored_uservars(scope)
      blob = @uservars[scope]
      blob ? Marshal.load(blob) : {}
    end
  end

  def reset_vars_state
    vars = Lich::Common::Vars
    vars.class_variable_set(:@@vars, {})
    vars.class_variable_set(:@@md5, nil)
    vars.class_variable_set(:@@load_state, vars::LoadState::UNLOADED)
  end
end
