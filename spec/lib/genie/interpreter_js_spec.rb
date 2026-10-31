# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative 'support/js_library'
require_relative '../../../lib/genie'

# JavaScript on the REAL interpreter, headless -- `js` / `jscall` (Script.cs:2833-2846,
# 2861-2877 R) and the jsblock rows of `<% %>` blocks and `.js` includes (RunScript,
# Script.cs:1736-1815 R; RunJsblock 3614-3619 R; PrintJSError 4362-4386 R). "(tNNN)" marks the
# frozen Remix golden an expectation comes from.
RSpec.describe Lich::Genie::Interpreter do
  lab = GenieSpecSupport::JsLibrary

  def run(source, lines: [], include_loader: nil)
    clock = [0.0]
    input = GenieSpecSupport::TimedInput.new(lines, clock: clock, gap: 0.0)
    out = []
    sends = []
    game = Object.new.tap { |g| g.define_singleton_method(:send_command) { |t| sends << t } }
    vars = Lich::Genie::Variables.new(game_state: Lich::Genie::GameState.new)
    interp = Lich::Genie::Engine.build(source, name: 't', file_name: 't.cmd', variables: vars, game: game, input: input,
                                               echo: ->(t) { out << [:echo, t] }, print: ->(t, k) { out << [k, t] },
                                               clock: -> { clock[0] }, wall_clock: -> { Time.new(2026, 1, 1, 0, 0, 0, '+13:00') + clock[0] },
                                               include_loader: include_loader)
    interp.run
    { out: out, sends: sends, vars: vars }
  end

  # A synthetic js_arrays.js (2025-08-31 e9794af version), recognised through stub_const (the
  # real file is third-party GPL code, kept out of the repo).
  let(:js_arrays) do
    text, bodies = lab.synthetic_library(:'5e08eba')
    stub_const('Lich::Genie::JsArrays::FUNCTION_BODIES', bodies)
    text
  end

  def texts(result, *kinds)
    result[:out].select { |kind, _| kinds.include?(kind) }.map(&:last)
  end

  describe 'js / jscall' do
    it 'hands the ROW text to JavaScript, not the variable-expanded line (Script.cs:2836 R)' do
      r = run("var s Gamma\njs setVar(\"x\", \"%s\")\njs setVar(\"y\", \"$1\")\n")
      expect([r[:vars].local_get('x'), r[:vars].local_get('y')]).to eq(%w[%s $1])
    end

    it 'stores the result through setvariable ("<var> <result>"), "undefined" after an error (t227 fi)' do
      r = run("debug 4\njscall r getVar(\"none\")\njscall  q   nosuch() ;\n")
      expect([r[:vars].local_get('r'), r[:vars].local_get('q')]).to eq(%w[undefined undefined])
      expect(texts(r, :debug)).to eq(['t.cmd(2): setvariable r undefined', 't.cmd(3): setvariable q undefined'])
      expect(texts(r, :error)).to eq(['[Script error in t.cmd(3): nosuch is not defined]'])
      expect(r[:vars].local_get('lastscripterror')).to eq('nosuch is not defined')
    end

    it 'goes on after a JavaScript error (PrintError only, no AbortOnScriptError)' do
      r = run("js nosuch()\necho next\n")
      expect(r[:out]).to eq([[:error, '[Script error in t.cmd(1): nosuch is not defined]'], [:echo, 'next']])
    end

    it 'raises "%name" from setVar and from the jscall store, synchronously (t229 changed-v/changed-w)' do
      src = "action echo v=%v when eval %v = 5\naction echo w=%w when eval %w = undefined\njs setVar(\"v\", \"5\")\n" \
            "echo between\njscall w nosuch()\necho end\n"
      expect(texts(run(src), :echo)).to eq(%w[v=5 between w=undefined end])
    end

    it 'announces JavaScript it cannot run, with the reason, and leaves the jscall variable alone' do
      r = run("var r keep\njscall r 1+2\njs a.b()\necho %r\n")
      expect(r[:out]).to eq([[:echo, '[Genie: #jscall not supported in the in-Lich engine: 1+2 (JavaScript outside the supported slice)]'],
                             [:echo, '[Genie: #js not supported in the in-Lich engine: a.b() (JavaScript outside the supported slice)]'],
                             [:echo, 'keep']])
    end

    it 'names a function body it does not recognise when a script calls it' do
      src = "include mine.js\njs doPush(\"a\", \"x\")\njscall r myFn(\t1)\necho a=%a r=%r\n"
      r = run(src, include_loader: ->(_) { "#{js_arrays}function myFn(n)\t{\n\treturn n;\n}\n" })
      expect(r[:out]).to eq([[:echo, '[Genie: #jscall not supported in the in-Lich engine: myFn( 1) (myFn() -- a function body this port ' \
                                     'does not recognise (only the published js_arrays.js versions are replayed))]'],
                             [:echo, 'a=x r=%r']])
    end

    it 'sends put() through Script.SendText (no %lastcommand) and echoes echo()' do
      r = run("js put(\"look\")\njs echo(1e21)\n")
      expect(r[:sends]).to eq(['look'])
      expect(texts(r, :echo)).to eq(['1E+21'])
      expect(r[:vars].local_key?('lastcommand')).to be(false)
    end

    it 'runs js in an action body with $1 substituted and quotes removed (t234)' do
      r = run("include js_arrays.js\naction js doPush(\"p\",\"$1\") when ^Your (\\S+) pouch\nwaitfor done\necho %p\n",
              lines: ['Your red pouch', 'Your "blue" pouch', 'done'], include_loader: ->(_) { js_arrays })
      expect(texts(r, :echo)).to eq(['red|blue'])
    end
  end

  describe 'jsblock rows' do
    it 'runs a block at the next ordinary row, a skipped one never (t230)' do
      src = "<% setVar(\"x\", \"1\");\nsetVar(\"y\", \"2\") %>\necho x=%x y=%y\nif 0 then\n{\n<%\nsetVar(\"z\", \"3\")\n%>\n}\necho z=%z\n"
      expect(texts(run(src), :echo)).to eq(['x=1 y=2', 'z=%z'])
    end

    it 'keeps the previous source for a skipped block, which an open end then runs again (t237)' do
      src = "<%\nput(\"A\")\n%>\necho mid\nif 0 then\n{\n<%\nput(\"B\")\n"
      expect(run(src)[:sends]).to eq(%w[A A])
    end

    it 'skips a block AND the next row after a false single-line if (t236)' do
      src = "if 0 then\n<%\nsetVar(\"s\", \"1\")\n%>\necho skipped\necho s=%s\n"
      expect(texts(run(src), :echo)).to eq(['s=%s'])
    end

    it 'prints "[Javascript error ...]" naming the first block row, without %lastscripterror, and aborts (t232/t233)' do
      r = run("echo start\n<%\nsetVar(\"a\", \"1\");\nsetVar(\"b\",\n%>\necho not-here\n")
      expect(r[:out]).to eq([[:echo, 'start'], [:error, '[Javascript error in t.cmd(3): Unexpected end of input (<anonymous>:4:1)]'], [:text, '[Script aborted! (Run time: 0.00 seconds): t.cmd]']])
      expect(r[:vars].local_key?('a')).to be(false) # parsed whole: nothing ran
      expect(r[:vars].local_key?('lastscripterror')).to be(false)
    end

    it 'names an include and its row for a block of a .js include' do
      r = run("include bad.js\necho not-here\n", include_loader: ->(_) { "\n  nosuch();\n" })
      expect(texts(r, :error)).to eq(['[Javascript error in t.cmd, bad.js(2): nosuch is not defined]'])
    end

    it 'drops the engine on a block error: what a .js include defined is gone (t236)' do
      src = "include js_arrays.js\njs doPush(\"a\", \"x\")\n<%\nnosuch()\n%>\nscripterror:\njs doPush(\"a\", \"y\")\necho a=%a\n"
      r = run(src, include_loader: ->(_) { js_arrays })
      expect(texts(r, :error)).to eq(['[Javascript error in t.cmd(4): nosuch is not defined]', '[Script error in t.cmd(7): doPush is not defined]'])
      expect(texts(r, :echo)).to eq(['a=x'])
    end

    it 'runs a block open at the end there, and again at the next ordinary row (bJSBlock kept, t231)' do
      src = "echo start\ngoto skip\nscripterror:\necho at-scripterror\nexit\nskip:\n<%\nput(\"tail\");\nnosuch()\n"
      r = run(src)
      expect(r[:sends]).to eq(%w[tail tail])
      expect(texts(r, :echo)).to eq(%w[start at-scripterror])
      expect(texts(r, :error).uniq).to eq(['[Javascript error in t.cmd(8): nosuch is not defined]'])
    end

    it 'strips a " at line " suffix from the message (PrintJSError)' do
      printed = []
      interp = Lich::Genie::Engine.build("echo x\n", name: 't', file_name: 't.cmd', variables: Lich::Genie::Variables.new,
                                                     input: GenieSpecSupport::TimedInput.new([], clock: [0.0], gap: 0.0),
                                                     echo: ->(_) {}, print: ->(t, k) { printed << [k, t] })
      interp.send(:print_js_error, 'Boom at line 3 column 2', Lich::Genie::Lexer::Instruction.new(0, 5, 'x', :jsblock))
      expect(printed).to eq([[:error, '[Javascript error in t.cmd(5): Boom]']])
    end

    it 'announces an unknown block, its first row with white space runs as one space, and goes on' do
      r = run("<%\nvar f =\tfunction ()  { return 1; };\n%>\necho next\n")
      expect(r[:out]).to eq([[:echo, '[Genie: JavaScript not supported in the in-Lich engine: t.cmd(2) var f = function () { return 1; }; ' \
                                     '(JavaScript outside the supported slice)]'],
                             [:echo, 'next']])
    end

    it 'keeps the %> of a one-line <% .. %> block in the code: Unexpected token, abort to scripterror (t246)' do
      src = "var a 1\n<% setVar(\"a\", \"2\") %>\necho inside [%a]\nsetVar(\"a\", \"3\") %>\necho after [%a]\nexit\n" \
            "scripterror:\necho handler [%a]\n"
      r = run(src)
      expect(texts(r, :error)).to eq(["[Javascript error in t.cmd(2): Unexpected token '>' (<anonymous>:1:20)]"])
      expect(texts(r, :echo)).to eq(['handler [1]'])
    end

    it 'recognises the corpus SkillData block and fails like Jint 4 (t233, lab)' do
      path = lab.lab_path('t233_js_skilldata.cmd')
      skip(lab.lab_missing('t233_js_skilldata.cmd')) unless path
      r = run(File.read(path))
      expect(r[:out]).to eq([[:echo, 'start'], [:error, "[Javascript error in t.cmd(5): #{Lich::Genie::JsArrays::LENGTH_FAULT}]"], [:text, '[Script aborted! (Run time: 0.00 seconds): t.cmd]']])
    end

    it 'runs ubercombat TEXT_TO_NUMBER as AMMO_SET calls it (t238, lab)' do
      path = lab.lab_path('t238_js_uber_text_to_number.cmd')
      skip(lab.lab_missing('t238_js_uber_text_to_number.cmd')) unless path
      text = File.binread(path).force_encoding(Encoding::UTF_8)
      block = text[text.index("TEXT_TO_NUMBER:\r\n")..]
      r = run("var AmmoCount twenty-three\ngosub TEXT_TO_NUMBER %AmmoCount\nvar AmmoCount %text_to_number\necho * Counted %AmmoCount\nexit\n#{block}")
      expect(texts(r, :echo)).to eq(['Received text string: twenty-three, numeric value is: 23', '* Counted 23'])
    end
  end
end
