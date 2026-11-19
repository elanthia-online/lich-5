# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# The load model of Remix Script.cs AppendFile / AddLine / AddLabel
# (Script.cs:3683-4338 R) and PrintError's load-time format (Script.cs:4340-4360 R: the file
# name is still empty while the script loads). Expectations marked "(tNN)" are the frozen
# Remix golden of that flow case; "loadcheck" = genieflow --loadcheck over the tester's corpus.
RSpec.describe Lich::Genie::Lexer do
  def compile(source, **opts)
    described_class.compile(source, file_name: 'f.cmd', **opts)
  end

  def load_error(source, **opts)
    compile(source, **opts)
    nil
  rescue described_class::LoadFailed => e
    e
  end

  describe '.split_lines (StreamReader.ReadLine)' do
    it 'ends a line at CR, LF or CRLF and needs no final terminator (t202)' do
      expect(described_class.split_lines("a\rb\nc\r\nd")).to eq(%w[a b c d])
      expect(described_class.split_lines("a\n\nb\n")).to eq(['a', '', 'b'])
      expect(described_class.split_lines('')).to eq([])
    end

    it 'drops a BOM at the start only and decodes invalid UTF-8 to U+FFFD' do
      bom = [0xFEFF].pack('U')
      expect(described_class.split_lines("#{bom}a\n#{bom}b")).to eq(['a', "#{bom}b"])
      expect(described_class.split_lines("x#{[0xA4].pack('C')}y".b)).to eq(["x#{[0xFFFD].pack('U')}y"])
    end

    # StreamReader(stream) detects FE FF / FF FE / FF FE 00 00 / 00 00 FE FF and EF BB BF
    # (genieflow probes u16le/u16be/u32le: "echo a" echoes "a").
    it 'decodes a UTF-16 or UTF-32 file by its byte-order mark (lone surrogate or odd byte -> U+FFFD)' do
      bytes = ->(bom, text, enc) { bom.pack('C*') + text.encode(enc).b }
      expect(described_class.split_lines(bytes.call([0xFF, 0xFE], "echo a\r\nlbl:\n", 'UTF-16LE'))).to eq(['echo a', 'lbl:'])
      expect(described_class.split_lines(bytes.call([0xFE, 0xFF], "echo a\rb", 'UTF-16BE'))).to eq(['echo a', 'b'])
      expect(described_class.split_lines(bytes.call([0xFF, 0xFE, 0, 0], "echo a\n", 'UTF-32LE'))).to eq(['echo a'])
      expect(described_class.split_lines(bytes.call([0, 0, 0xFE, 0xFF], "echo a\n", 'UTF-32BE'))).to eq(['echo a'])
      fffd = [0xFFFD].pack('U')
      expect(described_class.split_lines([0xFF, 0xFE, 0x61, 0, 0, 0xD8, 0x62, 0, 0x78].pack('C*'))).to eq(["a#{fffd}b#{fffd}"])
      expect(described_class.split_lines([0xFF, 0xFE].pack('C*'))).to eq([])
    end

    it 'compiles a UTF-16 file\'s rows, an unknown command in it named like any other (probe e9)' do
      source = [0xFE, 0xFF].pack('C*') + "echo ok\nbogus seven\n".encode('UTF-16BE').b
      expect(load_error(source).message).to eq('[Script error(2): Unknown script command: bogus seven]')
    end
  end

  describe 'rows' do
    it 'keeps a trailing NUL or space in the row: only the start is trimmed (t203)' do
      program = compile("  echo first\u0000\nvar a 1  \n")
      expect(program.instructions.map(&:content)).to eq(["echo first\u0000", 'var a 1  '])
    end

    it 'counts the row number over blank and comment lines (the error names the file row)' do
      expect(load_error("echo a\n\n# note\n  \nblarg\n").message).to eq('[Script error(5): Unknown script command: blarg]')
    end

    it 'replaces every " = " of a % or $ row (t207)' do
      expect(compile("%x = a = b\n$y = c = d\n").instructions.map(&:content)).to eq(['setvariable x a b', 'put #var y c d'])
    end

    it 'shares one instruction object between the U+00A4 parts of a row, the last part winning' do
      sep = [0xA4].pack('U')
      program = compile("echo a#{sep}echo b\n")
      expect(program.instructions.map(&:content)).to eq(['echo b', 'echo b'])
      expect(program.instructions.first).to equal(program.instructions.last)
    end
  end

  describe 'if / while / else at load' do
    it 'refuses an if without " then " and a block if without a trailing then, whatever the settings (t198, loadcheck)' do
      expect(load_error("echo a\nif 1\n{\n").message).to eq('[Script error(2): Invalid IF statement: if 1]')
      expect(load_error("if ($x = 1) goto T\n", ignore_warnings: true).message)
        .to eq('[Script error(1): Invalid IF statement: if ($x = 1) goto T]')
      expect(load_error("if then\n").message).to eq('[Script error(1): Invalid IF statement: if then]')
    end

    it 'rewrites if_N to an %argcount test before splitting (never invalid: the rewrite adds " then ")' do
      expect(compile("if_2 echo x\nif_1\n").instructions.map(&:content)).to eq(['if %argcount >= 2 then', 'echo x', 'if %argcount >= 1 then '])
    end

    it 'finds " do " case-sensitively and lowercases the head of a one-line while (t195, t196)' do
      expect(load_error("echo a\nwhile 1 DO echo x\n").message).to eq('[Script error(2): Invalid WHILE statement: while 1 DO echo x]')
      expect(compile("while %A = 0 do echo Y\n").instructions.map(&:content)).to eq(['while %a = 0 do', 'echo Y'])
      expect(compile("while %A = 0 Do\n").instructions.map(&:content)).to eq(['while %A = 0 Do']) # a block head keeps its case
    end

    it 'refuses a block while without do (t197)' do
      expect(load_error("echo a\nwhile 1\n{\n").message).to eq('[Script error(2): Invalid WHILE statement: while 1]')
    end

    it 'runs the rest of an inline if through AddLine, so "then #echo" is an unknown command (t199)' do
      expect(load_error("if 1 then #echo foo\n").message).to eq('[Script error(1): Unknown script command: #echo foo]')
      expect(compile("if 1 then #echo foo\n", ignore_warnings: true).instructions.map(&:content)).to eq(['if 1 then'])
    end

    it 'splits else / elseif / } with a rest, and keeps them whole without one' do
      program = compile("else echo a\nelseif x then echo b\n} echo c\nelse\n}\n")
      expect(program.instructions.map { |i| [i.function, i.content] })
        .to eq([[:else_func, 'else'], [:echo, 'echo a'], [:else_func, 'else'], [:if_func, 'if x then'], [:echo, 'echo b'],
                [:blockend, '}'], [:echo, 'echo c'], [:else_func, 'else'], [:blockend, '}']])
    end
  end

  describe 'labels' do
    it 'warns about a duplicate label, keeps the last, and leaves the text as the last error (t194, loadcheck kal.cmd)' do
      program = compile("x:\necho a\nX:\necho b\n")
      expect(program.labels).to eq('x' => 2)
      expect(program.messages).to eq(['[Script error(3): Replacing duplicate label: x]'])
      expect(program.last_error).to eq('Replacing duplicate label: x')
    end

    it 'stays silent about a duplicate label under ignorescriptwarnings (t187)' do
      program = compile("x:\nx:\n", ignore_warnings: true)
      expect([program.messages, program.last_error]).to eq([[], nil])
    end

    it 'treats a row ending in ":" with a NUL after it as no label (ordinal; Remix ICU ignores the NUL, tracked)' do
      expect(load_error("lbl:\u0000\n").message).to eq("[Script error(1): Unknown script command: lbl:\u0000]")
    end
  end

  describe 'includes' do
    it 'loads exactly the named file and refuses a missing or empty one with no row (t200, t201)' do
      loader = ->(name) { { 'inc.cmd' => "echo in\n", 'empty.cmd' => '' }[name] }
      expect(compile("include inc.cmd\n", include_loader: loader).instructions.map(&:content)).to eq(['echo in'])
      expect(load_error("include nonexist.cmd\n", include_loader: loader).message).to eq('[Script error: File not found: nonexist.cmd]')
      expect(load_error("include empty.cmd\n", include_loader: loader).message).to eq('[Script error: Unable to load file: empty.cmd]')
    end

    it "names an include's file and row (t200)" do
      loader = ->(_name) { "echo in-inc\nblarg zz\n" }
      expect(load_error("echo a\ninclude _inc.cmd\n", include_loader: loader).message)
        .to eq('[Script error, _inc.cmd(2): Unknown script command: blarg zz]')
    end

    it 'skips an include of a file already loaded, the main file included (t206)' do
      calls = []
      loader = lambda do |name|
        calls << name
        "include f.cmd\ninclude a.cmd\necho a\n"
      end
      program = compile("include a.cmd\ninclude a.cmd\necho main\n", include_loader: loader)
      expect(calls).to eq(['a.cmd'])
      expect(program.instructions.map(&:content)).to eq(['echo a', 'echo main'])
    end

    # .NET's FileInfo throws ArgumentException ("Null character in path.") out of AppendFile,
    # which catches only FileNotFound/FileLoad: Remix's script never starts (a host exception).
    # Ours refuses the load with that text instead of letting Ruby's
    # ArgumentError escape the script thread; the loader is never asked.
    it 'refuses an include whose name holds a NUL without asking the loader' do
      asked = []
      e = load_error("echo a\ninclude a\u0000b.inc\n", include_loader: ->(name) { asked << name and nil })
      expect([e.lines, e.text, asked]).to eq([["[Script error: Null character in path. (Parameter 'path')]"],
                                              "Null character in path. (Parameter 'path')", []])
    end

    it 'refuses a zero-byte main file like AppendFile (fi.Length > 0), but loads a BOM-only one' do
      expect(load_error('').message).to eq('[Script error: Unable to load file: f.cmd]')
      expect(compile([0xEF, 0xBB, 0xBF].pack('C*')).instructions).to eq([])
      expect(compile([]).instructions).to eq([]) # pre-split lines: no file to measure
    end

    it 'requires a .js include to exist and never compiles its lines as Genie rows' do
      expect(load_error("include js_arrays.js\n", include_loader: ->(_) {}).message).to eq('[Script error: File not found: js_arrays.js]')
      expect(load_error("include js_arrays.js\n", include_loader: ->(_) { '' }).message).to eq('[Script error: Unable to load file: js_arrays.js]')
      expect(compile("include js_arrays.js\necho ok\n", include_loader: ->(_) { "if (a) {\n" }).instructions.map(&:function))
        .to eq(%i[jsblock jsblockend echo])
    end

    it 'prints the warnings before the fatal error, all on the exception' do
      loader = ->(_) {}
      e = load_error("x:\nx:\ninclude gone.cmd\n", include_loader: loader)
      expect(e.lines).to eq(['[Script error(2): Replacing duplicate label: x]', '[Script error: File not found: gone.cmd]'])
      expect(e.text).to eq('File not found: gone.cmd')
    end
  end

  describe '.error_line (PrintError)' do
    it 'adds " in <file>", ", <include>" for another file and "(<row>)" for a row' do
      files = ['f.cmd', 'inc.cmd', 'f.cmd']
      line = ->(id, row, name) { described_class.error_line('x', file_id: id, file_row: row, files: files, file_name: name) }
      expect([line.call(0, 3, 'f.cmd'), line.call(1, 3, 'f.cmd'), line.call(2, 3, 'f.cmd'), line.call(0, 0, 'f.cmd'), line.call(1, 0, '')])
        .to eq(['[Script error in f.cmd(3): x]', '[Script error in f.cmd, inc.cmd(3): x]', '[Script error in f.cmd(3): x]',
                '[Script error in f.cmd: x]', '[Script error, inc.cmd: x]'])
    end
  end

  describe 'Engine.build' do
    it "prints the load's warnings and fatal error through the print port and seeds %lastscripterror" do
      printed = []
      vars = Lich::Genie::Variables.new
      Lich::Genie::Engine.build("x:\nx:\necho hi\n", name: 'f', variables: vars, print: ->(t, k) { printed << [k, t] })
      expect(printed).to eq([[:error, '[Script error(2): Replacing duplicate label: x]']])
      expect(vars.local_get('lastscripterror')).to eq('Replacing duplicate label: x')
      printed.clear
      expect { Lich::Genie::Engine.build("blarg\n", name: 'f', print: ->(t, k) { printed << [k, t] }) }
        .to raise_error(described_class::LoadFailed)
      expect(printed).to eq([[:error, '[Script error(1): Unknown script command: blarg]']])
    end
  end
end
