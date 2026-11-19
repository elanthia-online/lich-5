# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Lexer do
  def compile(lines, **opts)
    described_class.compile(Array(lines), **opts)
  end

  def functions(program)
    program.instructions.map(&:function)
  end

  def contents(program)
    program.instructions.map(&:content)
  end

  describe 'basic classification' do
    it 'classifies verbs and preserves content' do
      program = compile(['echo hi', 'put foo'])
      expect(functions(program)).to eq([:echo, :put])
      expect(contents(program)).to eq(['echo hi', 'put foo'])
    end

    it 'skips blank lines' do
      program = compile(['echo a', '', '   ', 'echo b'])
      expect(functions(program)).to eq([:echo, :echo])
    end

    it 'splits a line on the U+00A4 inline-newline sentinel' do
      program = compile(["echo a#{[0xA4].pack('U')}echo b"])
      expect(functions(program)).to eq([:echo, :echo])
    end
  end

  describe 'labels' do
    it 'records a lowercased label at the instruction index' do
      program = compile(['echo a', 'Start:', 'echo b'])
      expect(program.labels).to eq({ 'start' => 1 })
      expect(program.instructions[1].function).to eq(:label)
    end

    it 'does not treat a line with a space as a label' do
      program = compile(['echo done:'])
      expect(functions(program)).to eq([:echo])
    end
  end

  describe '%/$ line prefixes' do
    it 'rewrites %x = y to setvariable and $x = y to put #var' do
      program = compile(['%health = 100', '$mode = hunt'])
      expect(contents(program)).to eq(['setvariable health 100', 'put #var mode hunt'])
      expect(functions(program)).to eq([:setvariable, :put])
    end
  end

  describe 'if / while splitting' do
    it 'splits an inline if...then...' do
      program = compile(['if %hp > 50 then put advance'])
      expect(functions(program)).to eq([:if_func, :put])
      expect(contents(program)).to eq(['if %hp > 50 then', 'put advance'])
    end

    it 'keeps a block-opening if...then as a single instruction' do
      program = compile(['if %hp > 50 then'])
      expect(functions(program)).to eq([:if_func])
    end

    it 'splits an inline while...do...' do
      program = compile(['while %hp > 50 do put advance'])
      expect(functions(program)).to eq([:while_func, :put])
    end

    it 'raises on a malformed if with no then' do
      expect { compile(['if %hp > 50 put advance']) }.to raise_error(Lich::Genie::Error)
    end
  end

  describe 'else / elseif' do
    it 'splits an inline else' do
      program = compile(['else put retreat'])
      expect(functions(program)).to eq([:else_func, :put])
    end

    it 'desugars elseif into else + if' do
      program = compile(['elseif %hp > 20 then put heal'])
      expect(functions(program)).to eq([:else_func, :if_func, :put])
      expect(contents(program)).to eq(['else', 'if %hp > 20 then', 'put heal'])
    end
  end

  describe 'blocks' do
    it 'classifies block markers' do
      program = compile(['{', '}'])
      expect(functions(program)).to eq([:blockstart, :blockend])
    end

    it 'splits a } with a trailing command' do
      program = compile(['} put foo'])
      expect(functions(program)).to eq([:blockend, :put])
    end
  end

  describe 'if_N' do
    it 'rewrites if_N to an argcount check and splits' do
      program = compile(['if_2 then echo ready'])
      expect(functions(program)).to eq([:if_func, :echo])
      expect(contents(program)).to eq(['if %argcount >= 2 then', 'echo ready'])
    end
  end

  describe 'include' do
    it 'skips an include with no loader but records the file' do
      program = compile(['include lib.cmd', 'echo done'])
      expect(functions(program)).to eq([:echo])
      expect(program.files).to include('lib.cmd')
    end

    it 'expands an include through the loader' do
      loader = ->(name) { name == 'lib.cmd' ? "echo from-lib\nput ready" : nil }
      program = compile(['include lib.cmd', 'echo main'], include_loader: loader)
      expect(functions(program)).to eq([:echo, :put, :echo])
    end
  end

  describe 'comments' do
    it 'skips lines beginning with # (Genie comment char)' do
      program = compile(['# a comment', 'echo hi', '   # indented comment', 'put go'])
      expect(functions(program)).to eq([:echo, :put])
    end
  end

  describe 'unknown commands' do
    it 'raises by default' do
      expect { compile(['frobnicate x']) }.to raise_error(Lich::Genie::Error)
    end

    it 'skips and records a warning when warnings are ignored' do
      program = compile(['frobnicate x', 'echo ok'], ignore_warnings: true)
      expect(functions(program)).to eq([:echo])
      expect(program.warnings.map { |w| w[:content] }).to eq(['frobnicate x'])
    end
  end

  # AppendFile (Script.cs:3715-3768 R): the rows of a `<% %>` block are jsblock rows, exactly as
  # read (TrimStart()ed, blank lines dropped), never Genie commands, labels or comments.
  describe 'JavaScript blocks (<% ... %>)' do
    def rows(program)
      program.instructions.map { |i| [i.function, i.content, i.file_row] }
    end

    it 'keeps a multi-line block as jsblock rows (the `%>` line minus `%>`, even empty)' do
      program = compile(['echo before', '<%', 'if (x !== undefined) {', '  doThing();', '', 'x: # not a label', '}', '%>', 'echo after'])
      expect(rows(program)).to eq([[:echo, 'echo before', 1], [:jsblock, 'if (x !== undefined) {', 3],
                                   [:jsblock, 'doThing();', 4], [:jsblock, 'x: # not a label', 6], [:jsblock, '}', 7],
                                   [:jsblock, '', 8], [:echo, 'echo after', 9]])
      expect(program.labels).to be_empty
    end

    it 'keeps the rest of the `<%` line (untrimmed) and of the `%>` line, without the markers' do
      program = compile(['<% setVar("a", "1");', 'setVar("b", "2") %>', 'echo x'])
      expect(rows(program)).to eq([[:jsblock, ' setVar("a", "1");', 1], [:jsblock, 'setVar("b", "2") ', 2], [:echo, 'echo x', 3]])
    end

    it 'drops a `<%` line whose rest is blank' do
      expect(rows(compile(["<% \t", 'a()', '%>']))).to eq([[:jsblock, 'a()', 2], [:jsblock, '', 3]])
    end

    it 'does not misread a real if that merely contains <% (a < and a %var)' do
      program = compile(['if (%y<%khri.length) then echo go'])
      expect(functions(program)).to eq(%i[if_func echo])
    end

    # Remix enters the block on any `<%` line, even one that ends with `%>` (Script.cs:3737-3745
    # R): the block runs to the NEXT line ending with `%>` (genieflow probe l13).
    it 'treats a single-line <% ... %> as the start of a block that runs to the next %> line' do
      program = compile(['echo a', '<% var x = 1 %>', 'echo b', 'echo c %>', 'echo d'])
      expect(rows(program)).to eq([[:echo, 'echo a', 1], [:jsblock, ' var x = 1 %>', 2], [:jsblock, 'echo b', 3],
                                   [:jsblock, 'echo c ', 4], [:echo, 'echo d', 5]])
    end

    it 'runs an unclosed block to the end of the file, with no jsblockend row' do
      expect(rows(compile(['<%', 'a()']))).to eq([[:jsblock, 'a()', 2]])
    end
  end

  describe 'robustness for real-world corpora' do
    # StreamReader drops a BOM at the start of a FILE only (genieflow probe l11: a BOM on line 2 is
    # "Unknown script command: <BOM>echo second").
    it 'strips a UTF-8 BOM at the start of the file text, and only there' do
      bom = [0xFEFF].pack('U')
      program = described_class.compile("#{bom}include lib.cmd\n#{bom}echo hi\n", ignore_warnings: true)
      expect(functions(program)).to eq([])
      expect(program.files).to include('lib.cmd')
      expect(program.warnings.map { |w| w[:content] }).to eq(["#{bom}echo hi"])
      expect { described_class.compile("echo a\n#{bom}echo b\n", file_name: 'b.cmd') }
        .to raise_error(described_class::LoadFailed, "[Script error(2): Unknown script command: #{bom}echo b]")
    end

    # AppendFile(file, bJSBlock: true) (Script.cs:3721-3768 R): every non-blank line (a `#` one too)
    # is a jsblock row of the include, then one jsblockend row (row -1, no content).
    it 'compiles a .js include (pure JavaScript) to jsblock rows closed by a jsblockend row' do
      loader = ->(_name) { "function doSort() {\r\n\r\n  # x:\r\n}" }
      program = compile(['include js_arrays.js', 'echo ok'], include_loader: loader, ignore_warnings: true)
      js = program.files.index('js_arrays.js')
      expect(program.instructions.map { |i| [i.file_id, i.file_row, i.content, i.function] })
        .to eq([[js, 1, 'function doSort() {', :jsblock], [js, 3, '# x:', :jsblock], [js, 4, '}', :jsblock],
                [js, -1, '', :jsblockend], [0, 2, 'echo ok', :echo]])
      expect(program.warnings).to be_empty
      expect(program.labels).to be_empty
    end

    # An invalid IF is fatal whatever ignorescriptwarnings says (Script.cs:3923-3961 R).
    it 'refuses a malformed if even under ignore_warnings' do
      expect { compile(['if (bad javascript) {', 'echo ok'], ignore_warnings: true) }
        .to raise_error(described_class::LoadFailed, '[Script error(1): Invalid IF statement: if (bad javascript) {]')
    end
  end
end
