# frozen_string_literal: true

# Loads single definitions out of lib/global_defs.rb so specs run the shipped
# code without requiring the whole file. Requiring it redefines the
# script-facing DSL (respond, get, put, ...) against game infrastructure the
# suite does not have, which breaks every spec that runs after it.
#
# Every lookup fails loudly: a def that is missing, defined twice (Ruby keeps
# the last one, so a spec would test code that does not ship) or has no
# column-0 `end` raises instead of quietly loading the wrong lines.
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

  # Evaluates at the top level the block that starts at the one line
  # containing marker and runs to the next column-0 `end`.
  def self.eval_toplevel_block(marker, path: PATH)
    lines = File.readlines(path)
    found = lines.each_index.select { |i| lines[i].include?(marker) }
    raise "#{File.basename(path)}: block marker #{marker.inspect} missing" if found.empty?
    raise "#{File.basename(path)}: block marker #{marker.inspect} found #{found.size} times" if found.size > 1

    first = found.first
    last = terminator_index(lines, first, "block #{marker.inspect}", path)
    eval(lines[first..last].join, TOPLEVEL_BINDING, path, first + 1)
  end

  # The source of one top-level method and the 1-based line it starts on.
  def self.method_source(name, qualify_script: false, path: PATH)
    lines = File.readlines(path)
    first = def_index(lines, name, path)
    last = one_line_def?(lines[first], name) ? first : terminator_index(lines, first, "def #{name}", path)
    code = lines[first..last].join
    code = code.gsub(UNQUALIFIED_SCRIPT_CALL, QUALIFIED_SCRIPT_CALL) if qualify_script
    [code, first + 1]
  end

  # The 1-based line of a method's def.
  def self.line_of(name, path: PATH)
    def_index(File.readlines(path), name, path) + 1
  end

  def self.def_index(lines, name, path)
    pattern = /^def #{Regexp.escape(name)}(?:[(\s;]|$)/
    found = lines.each_index.select { |i| lines[i].match?(pattern) }
    raise "#{File.basename(path)}: def #{name} missing" if found.empty?
    raise "#{File.basename(path)}: def #{name} defined #{found.size} times" if found.size > 1

    found.first
  end

  # `def n; 'north'; end` and endless `def x = ...` close on their own line;
  # searching on for a column-0 `end` would take in the defs that follow.
  def self.one_line_def?(line, name)
    line.match?(/;\s*end\s*(?:#.*)?$/) || line.match?(/^def #{Regexp.escape(name)}(?:\([^)]*\))?\s*=/)
  end

  def self.terminator_index(lines, first, what, path)
    offset = lines[(first + 1)..].index { |line| line.match?(/^end\s*$/) }
    raise "#{File.basename(path)}: #{what} terminator missing" unless offset

    first + offset + 1
  end
  private_class_method :def_index, :one_line_def?, :terminator_index
end
