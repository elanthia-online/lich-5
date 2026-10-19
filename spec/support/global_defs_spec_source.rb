# frozen_string_literal: true

require 'prism'

# Loads single definitions out of lib/global_defs.rb so specs run the shipped
# code without requiring the whole file. Requiring it redefines the
# script-facing DSL (respond, get, put, ...) against game infrastructure the
# suite does not have, which breaks every spec that runs after it.
#
# Def and block extents come from Prism, so a def is exactly what Ruby
# parses, whatever its shape (one-line, endless, `end` indented or shared with
# other code). Every lookup fails loudly: a file that does not parse, a def
# that is missing or defined twice at the top level (Ruby keeps the last one,
# so a spec would test code that does not ship) raises instead of quietly
# loading the wrong code.
module GlobalDefsSpecSource
  PATH = File.expand_path('../../lib/global_defs.rb', __dir__)

  # Production refers to Script, which only resolves through the
  # `include Lich::Common` of the real boot. Specs that load the real
  # Lich::Common::Script rather than spec_helper's stand-in pass
  # qualify_script: true to point the calls at it.
  UNQUALIFIED_SCRIPT_CALL = /(?<![\w:])Script\./
  QUALIFIED_SCRIPT_CALL = 'Lich::Common::Script.'

  # Defines each named top-level method on target (a class or module), so
  # the definitions stay scoped to it and calls inside resolve through
  # target's own method lookup, stubs included.
  def self.define(target, *names, qualify_script: false, path: PATH)
    names.each do |name|
      code, line = method_source(name, qualify_script: qualify_script, path: path)
      target.class_eval(code, path, line)
    end
  end

  # Defines each named method at the top level, the way lib/global_defs.rb
  # itself does: a private method on Object, visible to every later spec in
  # the process. Prefer define into a scoped target where the spec allows it.
  def self.define_toplevel(*names, qualify_script: false, path: PATH)
    names.each do |name|
      code, line = method_source(name, qualify_script: qualify_script, path: path)
      eval(code, TOPLEVEL_BINDING, path, line)
    end
  end

  # Evaluates at the top level the first top-level statement that starts on
  # or after the one line containing marker (usually a comment above it).
  def self.eval_toplevel_block(marker, path: PATH)
    found = File.readlines(path).each_with_index.filter_map { |line, i| i + 1 if line.include?(marker) }
    raise "#{File.basename(path)}: block marker #{marker.inspect} missing" if found.empty?
    raise "#{File.basename(path)}: block marker #{marker.inspect} found #{found.size} times" if found.size > 1

    marker_line = found.first
    statements = toplevel_statements(path)
    enclosing = statements.find { |node| node.location.start_line < marker_line && node.location.end_line >= marker_line }
    if enclosing
      raise "#{File.basename(path)}: block marker #{marker.inspect} is inside the statement on lines " \
            "#{enclosing.location.start_line}-#{enclosing.location.end_line}"
    end

    block = statements.find { |node| node.location.start_line >= marker_line }
    raise "#{File.basename(path)}: no top-level statement follows block marker #{marker.inspect}" unless block

    eval(block.slice, TOPLEVEL_BINDING, path, block.location.start_line)
  end

  # The source of one top-level method and the 1-based line it starts on.
  def self.method_source(name, qualify_script: false, path: PATH)
    node = def_node(name, path)
    code = node.slice
    code = code.gsub(UNQUALIFIED_SCRIPT_CALL, QUALIFIED_SCRIPT_CALL) if qualify_script
    [code, node.location.start_line]
  end

  # The 1-based line of a method's def.
  def self.line_of(name, path: PATH)
    def_node(name, path).location.start_line
  end

  def self.def_node(name, path)
    found = toplevel_statements(path).select do |node|
      node.is_a?(Prism::DefNode) && node.receiver.nil? && node.name == name.to_sym
    end
    raise "#{File.basename(path)}: def #{name} missing" if found.empty?
    raise "#{File.basename(path)}: def #{name} defined #{found.size} times" if found.size > 1

    found.first
  end

  def self.toplevel_statements(path)
    result = Prism.parse_file(path)
    unless result.success?
      error = result.errors.first
      raise "#{File.basename(path)} does not parse: line #{error.location.start_line}: #{error.message}"
    end

    result.value.statements.body
  end
  private_class_method :def_node, :toplevel_statements
end
