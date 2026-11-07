# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/js_library'
require_relative '../../../lib/genie'

# The stand-in for Remix's per-script Jint 4 engine (Script.cs:691-776, 2861-2877, 3614-3619
# R). Expectations are Remix's (genieflow: frozen t229/t230 goldens and probes).
RSpec.describe Lich::Genie::JsRuntime do
  js_error = described_class::JsError
  unsupported = described_class::Unsupported
  null = Lich::Genie::JsValue::NULL

  let(:locals) { {} }
  let(:globals) { {} }
  let(:log) { [] }
  let(:runtime) do
    l = locals
    g = globals
    calls = log
    described_class.new(
      described_class::Host.new(
        local: ->(name) { calls << [:local, name] && l[name] },
        global: ->(name) { calls << [:global, name] && g[name] },
        set_local: ->(name, value) { calls << [:set_local, name, value] && l[name] = value },
        set_global: ->(name, value) { calls << [:set_global, name, value] && g[name] = value },
        echo: ->(text) { calls << [:echo, text] },
        send_text: ->(text) { calls << [:send, text] }
      )
    )
  end

  # A synthetic stand-in for a js_arrays.js version, recognised through stub_const (the real
  # files are third-party GPL code and stay in the lab; js_arrays_spec pins their fingerprints).
  def library_source(copy)
    text, bodies = GenieSpecSupport::JsLibrary.synthetic_library(copy)
    stub_const('Lich::Genie::JsArrays::FUNCTION_BODIES', bodies)
    text
  end

  describe '#evaluate: completion values' do
    it 'returns the last expression statement, undefined for none (t229 l1-l17)' do
      expect(runtime.evaluate('"a"; "b"')).to eq('b')
      expect(runtime.evaluate('5; ;')).to eq(5.0)
      expect([runtime.evaluate(''), runtime.evaluate('undefined'), runtime.evaluate('null')]).to eq([nil, nil, null])
      expect(runtime.evaluate('NaN')).to be_nan
      expect(runtime.evaluate('Infinity')).to eq(Float::INFINITY)
    end

    it 'throws ReferenceError for an unknown name, before evaluating the arguments (t229)' do
      expect { runtime.evaluate('nosuch(setVar("x", "1"))') }.to raise_error(js_error, 'nosuch is not defined')
      expect { runtime.evaluate('undefinedname') }.to raise_error(js_error, 'undefinedname is not defined')
      expect(log).to eq([])
    end

    it 'runs every statement before a later one throws, in order' do
      expect { runtime.evaluate('setVar("a", "1"); nosuch(); setVar("b", "2")') }.to raise_error(js_error)
      expect(locals).to eq('a' => '1')
    end

    it 'does not run a function value, a call of a non-function or a syntax it lacks' do
      expect { runtime.evaluate('setVar') }.to raise_error(unsupported)
      expect { runtime.evaluate('undefined()') }.to raise_error(unsupported)
      expect { runtime.evaluate('setVar("a", "1"); 1 + 2') }.to raise_error(unsupported)
      expect(locals).to be_empty # parsed whole before anything runs
    end
  end

  describe 'the host functions (Script.cs:699-776 R)' do
    it 'setVar converts the value like Conversions.ToString and skips undefined/null (t229 vals)' do
      runtime.evaluate('setVar("n", 3); setVar("n2", 2.5); setVar("n3", 1e21); setVar("b", true); setVar("b2", false)')
      runtime.evaluate('setVar("n", undefined); setVar(null, "q"); setVar(); setVar(1.5, "x")')
      expect(locals).to eq('n' => '3', 'n2' => '2.5', 'n3' => '1E+21', 'b' => 'True', 'b2' => 'False', '1.5' => 'x')
    end

    it 'getVar reads a local with a ToString name, "undefined" when absent or nameless (t229 g3-g5)' do
      locals.merge!('1.5' => 'onefive', 'True' => 'tru', 'x' => '')
      expect(%w[getVar(1.5) getVar(true) getVar() getVar(null) getVar("x") getVar("gone")].map { |c| runtime.evaluate(c) })
        .to eq(['onefive', 'undefined', 'undefined', 'undefined', '', 'undefined'])
    end

    it 'getGlobal reads a global, "" when absent, "undefined" when nameless (t229 g1/g2)' do
      globals['jsglob'] = 'gv'
      expect(%w[getGlobal("jsglob") getGlobal("nope") getGlobal()].map { |c| runtime.evaluate(c) }).to eq(['gv', '', 'undefined'])
    end

    it 'setGlobal writes through the host, nothing for undefined/null' do
      runtime.evaluate('setGlobal("g", 2.5); setGlobal("h"); setGlobal(null, "x")')
      expect(log).to eq([[:set_global, 'g', '2.5']])
    end

    it 'echo prints the CLR ToString, "undefined" for undefined/null; put sends unless undefined/null (t229)' do
      runtime.evaluate('echo("hello"); echo(1e21); echo(-0); echo(true); echo(); echo(null); echo(1e16, "x"); put("look"); put(); put(42)')
      expect(log).to eq([[:echo, 'hello'], [:echo, '1E+21'], [:echo, '-0'], [:echo, 'True'], [:echo, 'undefined'],
                         [:echo, 'undefined'], [:echo, '10000000000000000'], [:send, 'look'], [:send, '42']])
    end

    it 'returns undefined from echo/put/setVar/setGlobal' do
      expect(%w[echo("a") put("b") setVar("c","d") setGlobal("e","f")].map { |c| runtime.evaluate(c) }).to eq([nil, nil, nil, nil])
    end
  end

  describe '#execute' do
    it 'defines the functions of a js_arrays.js source by the fingerprints of their declarations' do
      expect { runtime.evaluate('doPush("a", "x")') }.to raise_error(js_error, 'doPush is not defined')
      runtime.execute(library_source(:'5e08eba'))
      runtime.evaluate('doPush("a", "x")')
      expect(locals['a']).to eq('x')
    end

    it 'leaves the Miner copy without doReplace (t228)' do
      runtime.execute(library_source(:a7f2496))
      expect { runtime.evaluate('doReplace("h", "1", "z")') }.to raise_error(js_error, 'doReplace is not defined')
      expect { runtime.evaluate('checkExists("h", "a")') }.to raise_error(js_error, Lich::Genie::JsArrays::LENGTH_FAULT)
    end

    it 'runs a block of the expression slice itself (t230)' do
      runtime.execute(%(// c\nsetVar("m", "multi")\nsetVar("m2", 'two')\nput("from-block")\n\n))
      expect(locals).to eq('m' => 'multi', 'm2' => 'two')
      expect(log.last).to eq([:send, 'from-block'])
    end

    it 'does not run an unknown block outside the slice, and then no longer claims a name is undefined' do
      expect { runtime.execute("var f = function () {};\n") }.to raise_error(unsupported)
      expect { runtime.evaluate('f()') }.to raise_error(unsupported)
      expect { runtime.evaluate('g') }.to raise_error(unsupported)
    end

    it 'shows the globals a recognised source leaves (`i` of a for loop, t227 i-*/j-*)' do
      runtime.execute(library_source(:'5e08eba'))
      expect { runtime.evaluate('i') }.to raise_error(js_error, 'i is not defined')
      expect { runtime.evaluate('findMax("t")') }.to raise_error(js_error)
      expect(runtime.evaluate('i')).to eq(1.0)
      expect { runtime.evaluate('zipArrays("t", "u")') }.to raise_error(js_error)
      expect(runtime.evaluate('j')).to eq(0.0)
      expect { runtime.evaluate('i()') }.to raise_error(unsupported)
    end
  end

  describe '#execute of a program with function declarations' do
    let(:bodies) do
      text = "function known(a) { /* synthetic */ }\n"
      { Lich::Genie::JsSource.fingerprint(text) => Lich::Genie::JsArrays::Body.new('known', ->(rt, args) { rt.set_var('k', args[0]) }, []) }
    end

    before { stub_const('Lich::Genie::JsArrays::FUNCTION_BODIES', bodies) }

    it 'replays a known declaration (whatever its comments and spacing) and defines an unknown one, unsupported when called' do
      runtime.execute("function  known(a)\t{ /* another comment */  }\nfunction mine(x) { return x + 1; }\n")
      runtime.evaluate('known("v")')
      expect(locals).to eq('k' => 'v')
      expect { runtime.evaluate('mine(1)') }.to raise_error(unsupported, /\Amine\(\) -- a function body this port does not recognise/)
      expect { runtime.evaluate('nosuch') }.to raise_error(unsupported) # after JavaScript it could not run: anything may exist
    end

    it 'hoists the declarations above the statements, a later one of the same name winning' do
      runtime.execute(%(known("first");\nfunction known(a) { /* synthetic */ }\nfunction other() {}\nfunction other() { 2 }\n))
      expect(locals).to eq('k' => 'first')
      expect { runtime.evaluate('nosuch') }.to raise_error(js_error, 'nosuch is not defined') # nothing unknown ran
    end

    it 'lets the later of two same-name declarations in one block win, both hoisted above a call before them' do
      # genieflow q1 (call before the declaration runs it), q4 (unknown then known: known runs), q4b (known then
      # unknown: Remix runs the user's body, which this port cannot)
      runtime.execute(%(known("early");\nfunction known(a) { 1 }\nfunction known(a) { /* synthetic */ }\n))
      expect(locals).to eq('k' => 'early')
      expect { runtime.execute(%(known("late");\nfunction known(a) { /* synthetic */ }\nfunction known(a) { 1 }\n)) }
        .to raise_error(unsupported, /\Aknown\(\) -- a function body this port does not recognise/)
      expect(locals).to eq('k' => 'early')
    end

    it 'runs a block whose declaration holds a regular expression after an if/while/for head (genieflow q6/q6b)' do
      runtime.execute(%(function u2() { if (1) /}}/; }\nsetVar("r6", "ok")\n))
      runtime.execute(%(function u3() { while (x) /}/.test("a"); for (;;) /{/; }\nsetVar("r7", "ok")\n))
      expect(locals).to eq('r6' => 'ok', 'r7' => 'ok')
      expect { runtime.evaluate('u2()') }.to raise_error(unsupported, /\Au2\(\)/)
    end

    it 'does not cut a declaration out of an argument list or an array literal (genieflow q8)' do
      # Remix: "Unexpected token 'function'"; this port: a function expression it does not run
      expect { runtime.execute(%(setVar("r8", "v"\nfunction bar(){}\n)\n)) }.to raise_error(unsupported)
      expect { runtime.execute(%(setVar("r9", [1\nfunction bar(){}\n])\n)) }.to raise_error(Lich::Genie::Error)
      expect(locals).to eq({})
    end

    it 'does not cut a declaration after a call on the same line (genieflow q19: a Remix syntax error)' do
      expect { runtime.execute(%(setVar("a19", "1") function f(){}\n)) }.to raise_error(Lich::Genie::Error)
      expect(locals).to eq({})
    end

    it 'decodes a \\u-escaped declaration name; one it cannot decode to an ASCII identifier is unsupported (q23e)' do
      runtime.execute(%(function \\u006Bnown(a) { /* synthetic */ }\n))
      expect { runtime.evaluate('known("v")') }.to raise_error(unsupported, /\Aknown\(\) -- a function body/) # the text differs
      runtime.execute(%(function kn\\u{6F}wn2(a) { }\n))
      expect { runtime.evaluate('known2()') }.to raise_error(unsupported, /\Aknown2\(\)/)
      ['function \\x6Bnown() {}', 'function \\u0020k() {}', 'function k\\u{110000}() {}', 'function \\u00E9() {}'].each do |text|
        expect { runtime.execute("#{text}\n") }.to raise_error(unsupported, /escaped name/)
      end
      expect(locals).to eq({})
    end

    it 'parses the whole program first: a syntax error after a declaration defines nothing' do
      expect { runtime.execute(%(function known(a) { /* synthetic */ }\nsetVar("x", 1 2)\n)) }
        .to raise_error(js_error, 'Unexpected number (<anonymous>:2:15)')
      expect { runtime.evaluate('known("v")') }.to raise_error(js_error, 'known is not defined')
      expect(locals).to eq({})
    end

    it 'lets a declaration shadow a host function of its name' do
      runtime.execute("function echo(t) { }\n")
      expect { runtime.evaluate('echo("x")') }.to raise_error(unsupported, /\Aecho\(\)/)
      expect(log).to eq([])
    end

    it 'does not run a function expression, nor a declaration it cannot scan' do
      expect { runtime.execute("setVar(\"f\", function known(a) { /* synthetic */ })\n") }.to raise_error(unsupported)
      expect { runtime.execute("function known(a) { \"open\n}\n") }.to raise_error(unsupported, /unterminated string/)
    end
  end

  describe '#execute of a recognised `<% %>` block (SOURCES, by JsSource fingerprint)' do
    let(:ran) { [] }
    let(:source_text) { "var map = { 'one': 1 };\nfunction f() {\n  return map; // c\n}\nf();\n" }

    before do
      effect = ->(rt) { ran << rt }
      stub_const('Lich::Genie::JsArrays::SOURCES',
                 { Lich::Genie::JsSource.fingerprint(source_text) => Lich::Genie::JsArrays::Source.new('synthetic', nil, effect, %w[map]) })
    end

    it 'recognises the block whatever its trailing spaces, indentation and comments' do
      runtime.execute(source_text)
      runtime.execute(source_text.gsub("\n", " \n").gsub(/^/, "\t").sub('// c', '/* other */'))
      expect(ran).to eq([runtime, runtime])
      expect { runtime.evaluate('map') }.to raise_error(unsupported) # the opaque global it leaves
    end

    it 'does not take a block that differs in a token or a line break for it' do
      expect { runtime.execute(source_text.sub("'one': 1", "'one': 2")) }.to raise_error(unsupported)
      expect { runtime.execute(source_text.sub("f();\n", "\nf\n();\n")) }.to raise_error(unsupported)
      expect(ran).to eq([])
    end

    it 'falls back to running the program when the block cannot be scanned (an unterminated comment)' do
      expect { runtime.execute("setVar(\"u\", \"1\") /* open\n") }.to raise_error(Lich::Genie::Error)
      expect(ran).to eq([])
    end
  end
end
