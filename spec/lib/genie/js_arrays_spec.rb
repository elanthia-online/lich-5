# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/js_library'
require_relative '../../../lib/genie'

# The js_arrays.js versions and corpus `<% %>` blocks as Remix's Jint 4 runs them.
# Every expectation is Remix's own result (genieflow: the frozen goldens t227/t228/t233/t234 and
# t238-t245, and probes): `list.length()` throws "Property 'length' of object is not a function",
# so most functions fail before they do anything. The real third-party (GPL) files stay in the lab:
# the replays run here by version ({Lich::Genie::JsArrays.functions_of}), and the examples that pin
# the stored fingerprints read the lab files when present.
RSpec.describe Lich::Genie::JsArrays do
  js_error = Lich::Genie::JsRuntime::JsError
  unsupported = Lich::Genie::JsRuntime::Unsupported
  lab = GenieSpecSupport::JsLibrary
  all21 = %w[doSort findIndex checkExists doInsert doRemove doReplace doConcat doXCompare doPush doPop doUnshift doShift buildArray
             buildArrayStr findMax findMin findMaxIndex findMinIndex findMaxGlobal findMinGlobal zipArrays].freeze

  let(:locals) { {} }
  let(:globals) { {} }
  let(:reads) { [] }
  let(:copy) { :'5e08eba' }
  let(:runtime) do
    l = locals
    g = globals
    r = reads
    Lich::Genie::JsRuntime.new(
      Lich::Genie::JsRuntime::Host.new(
        local: ->(name) { r << [:local, name] && l[name] }, global: ->(name) { r << [:global, name] && g[name] },
        set_local: ->(name, value) { r << [:set, name] && l[name] = value }, set_global: ->(*) {}, echo: ->(*) {}, send_text: ->(*) {}
      )
    ).tap { |rt| rt.define(described_class.functions_of(copy)) }
  end

  def js(code) = runtime.evaluate(code)

  def fault(code, message = nil)
    expect { js(code) }.to raise_error(Lich::Genie::JsRuntime::JsError, message || described_class::LENGTH_FAULT)
  end

  describe 'FUNCTION_BODIES (every js_arrays.js version, function by function)' do
    it 'gives each version the functions it declares (zipArrays since 2024, doReplace in the 2025 JS_Arrays copies)' do
      declared = described_class::COPIES.keys.to_h { |c| [c, described_class.functions_of(c).keys.sort] }
      expect(declared).to eq(
        b249849: (all21 - %w[doReplace zipArrays]).sort, '0ad2095': (all21 - %w[doReplace zipArrays]).sort,
        '1bfe9a2': (all21 - %w[doReplace zipArrays]).sort, '9a9462a': (all21 - %w[doReplace zipArrays]).sort,
        a7f2496: (all21 - %w[doReplace]).sort, c878a96: all21.sort, '5e08eba': all21.sort
      )
    end

    it 'names each function once per version, by distinct 64-hex fingerprints, for known versions only' do
      bodies = described_class::FUNCTION_BODIES
      expect(bodies.keys).to all(match(/\A\h{64}\z/))
      described_class::COPIES.each_key do |c|
        names = bodies.values.select { |b| b.copies.include?(c) }.map(&:name)
        expect(names).to eq(names.uniq)
      end
      expect(bodies.values.flat_map(&:copies).uniq - described_class::COPIES.keys).to eq([])
    end

    described_class::COPIES.each_key do |c|
      it "recognises every declaration of the real #{c} file, with nothing left over (lab)" do
        path = lab.lab_path(lab::LAB_FILES.fetch(c))
        skip(lab.lab_missing(lab::LAB_FILES.fetch(c))) unless path
        declarations, rest = Lich::Genie::JsSource.split(lab.include_source(path))
        expect(rest.strip).to eq('')
        known = declarations.map { |d| described_class::FUNCTION_BODIES[d.fingerprint] }
        expect(known).to all(be_a(described_class::Body))
        expect(known.map(&:name)).to eq(declarations.map(&:name))
        expect(known.map { |b| b.copies.include?(c) }).to all(be(true))
        expect(declarations.map(&:name).sort).to eq(described_class.functions_of(c).keys.sort)
      end
    end

    it 'treats one changed token of a real body as an unknown function, unsupported only when called (lab)' do
      path = lab.lab_path('js_arrays.js')
      skip(lab.lab_missing('js_arrays.js')) unless path
      declarations, = Lich::Genie::JsSource.split(lab.include_source(path).sub('list.length()', 'list.length'))
      changed = declarations.reject { |d| described_class::FUNCTION_BODIES.key?(d.fingerprint) }
      expect(changed.map(&:name)).to eq(['doSort'])
      expect { described_class.callable_for(changed.first).call(runtime, []) }
        .to raise_error(unsupported, /\AdoSort\(\) -- a function body this port does not recognise/)
    end

    it 'replays a body only under its own name' do
      fingerprint, body = described_class::FUNCTION_BODIES.first
      expect(described_class.callable_for(Lich::Genie::JsSource::Declaration.new(body.name, fingerprint, 1))).to equal(body.callable)
      renamed = described_class.callable_for(Lich::Genie::JsSource::Declaration.new('other', fingerprint, 1))
      expect { renamed.call(runtime, []) }.to raise_error(unsupported, /\Aother\(\)/)
    end
  end

  describe 'the functions that always throw (5e08eba, t227)' do
    ['findIndex("t","a")', 'checkExists("t","%a")', 'doInsert("t","x",1)', 'doRemove("t","a",1)', 'doXCompare("t","t","$roomid")',
     'doPop("t")', 'doShift("t")', 'buildArrayStr("b","a foo, a bar","foo")', 'findMax("t")', 'findMin("t")', 'findMaxIndex("t")',
     'findMinIndex("t")', 'findMaxGlobal("t")', 'findMinGlobal("t")', 'zipArrays("t","arr")'].each do |call|
      it "#{call} throws the length TypeError and writes nothing" do
        locals['t'] = 'b|a'
        fault(call)
        expect(locals).to eq('t' => 'b|a')
        expect(reads.map(&:first)).not_to include(:set)
      end
    end

    it 'reads a %name / $name search before throwing, as the JavaScript does' do
      fault('findIndex("t", "%s")')
      fault('doXCompare("t", "u", "$roomid")')
      expect(reads).to eq([[:local, 't'], [:local, 's'], [:local, 't'], [:local, 'u'], [:global, 'roomid']])
    end

    it 'leaves i (0, or 1 for findMax..findMinIndex) and j (zipArrays) behind' do
      fault('findIndex("t", "a")')
      expect(js('i')).to eq(0.0)
      fault('findMinIndex("t")')
      expect(js('i')).to eq(1.0)
      fault('doPop("t")') # `if (list.length() > 0` assigns nothing
      expect(js('i')).to eq(1.0)
      expect { js('j') }.to raise_error(js_error, 'j is not defined')
      fault('zipArrays("t", "u")')
      expect(js('j')).to eq(0.0)
    end
  end

  describe 'doRemove: `findIndex(arrayname, srch)` -- whatever findIndex the engine holds' do
    it 'throws through the version\'s findIndex, reading what it reads' do
      fault('doRemove("t", "%s", 1)')
      expect(reads).to eq([[:local, 't'], [:local, 's']])
    end

    it 'is a ReferenceError without a findIndex, unsupported with an unknown one' do
      bare = Lich::Genie::JsRuntime.new(Lich::Genie::JsRuntime::Host.new(local: ->(_) {}, global: ->(_) {}))
      bare.define('doRemove' => described_class.functions_of(copy)['doRemove'])
      expect { bare.evaluate('doRemove("t", "a")') }.to raise_error(js_error, 'findIndex is not defined')
      bare.define('findIndex' => described_class.callable_for(Lich::Genie::JsSource::Declaration.new('findIndex', '0' * 64, 1)))
      expect { bare.evaluate('doRemove("t", "a")') }.to raise_error(unsupported, /findIndex\(\)/)
    end

    it 'is unsupported should its findIndex ever return' do
      runtime.define('findIndex' => ->(*) { 0.0 })
      expect { js('doRemove("t", "a")') }.to raise_error(unsupported, /findIndex that returned/)
    end
  end

  describe 'missing / null arguments (t227)' do
    {
      'doPush("arr")' => "Cannot read property '0' of undefined", 'doPush("arr", null)' => "Cannot read property '0' of null",
      'doConcat("arr")' => "Cannot read property 'toString' of undefined",
      'buildArray("ba")' => "Cannot read property 'toString' of undefined",
      'buildArrayStr("ba", "x")' => "Cannot read property '0' of undefined", 'buildArrayStr("ba", "x", "$y")' => 'srch is not defined',
      'findIndex("t")' => "Cannot read property '0' of undefined", 'doInsert("t")' => "Cannot read property 'toString' of undefined",
      'doReplace("t", "1")' => "Cannot read property '0' of undefined", 'doReplace("t")' => "Cannot read property '0' of undefined",
      'doRemove("t")' => "Cannot read property '0' of undefined", 'doXCompare("t", "t")' => "Cannot read property '0' of undefined"
    }.each do |call, message|
      it "#{call} -> #{message}" do
        fault(call, message)
        expect(reads.map(&:first)).not_to include(:set)
      end
    end
  end

  describe 'doPush / doUnshift' do
    it 'start an unset array, then append / prepend (t227)' do
      js('doPush("arr", "One")')
      js('doPush("arr", "Two")')
      js('doUnshift("u", "Three")')
      js('doUnshift("u", "Two")')
      expect(locals).to eq('arr' => 'One|Two', 'u' => 'Two|Three')
    end

    it 'resolve %name (unset: "undefined") and $name (the global "$name": empty); numbers and booleans join with ToString' do
      locals.merge!('arr' => 'One', 'a' => 'x|y')
      %w[doPush("arr","%a") doPush("arr","%nosuch") doPush("arr","$roomid") doPush("arr",5) doPush("arr",true) doPush("arr",1.5e3)]
        .each { |call| js(call) }
      expect(locals['arr']).to eq('One|x|y|undefined||5|true|1500')
      expect(reads).to include([:global, '$roomid'])
    end

    it 'replace an empty array element (doPush) but grow one (doUnshift) (t227 pushempty/unshiftempty)' do
      locals.merge!('e' => '', 'f' => '')
      js('doPush("e", "w")')
      js('doUnshift("f", "q")')
      js('doPush("g", "")')
      expect(locals).to eq('e' => 'w', 'f' => 'q|', 'g' => '')
    end

    it 'do not read a %name value that starts with "$" as a global (else if)' do
      locals.merge!('arr' => 'a', 'pv' => '$foo')
      js('doPush("arr", "%pv")')
      js('doUnshift("arr", "%pv")')
      expect(locals['arr']).to eq('$foo|a|$foo')
      expect(reads.map(&:first)).not_to include(:global)
    end
  end

  describe 'the older versions (t239-t242: what differs)' do
    context 'with the 2019-01 copies (%name only)' do
      let(:copy) { :b249849 }

      it 'push / unshift a $name literally and treat only "undefined" as empty' do
        locals.merge!('a' => 'x', 'e' => '')
        js('doPush("a", "$roomid")')
        js('doUnshift("a", "$x")')
        js('doPush("e", "q")')
        expect(locals).to eq('a' => '$x|x|$roomid', 'e' => '|q')
        expect(reads.map(&:first)).not_to include(:global)
      end

      it 'search for a $name literally (but findIndex reads it), and buildArrayStr takes a $name pattern (no `srch` typo)' do
        fault('checkExists("a", "$x")')
        fault('doXCompare("a", "b", "$y")')
        fault('buildArrayStr("bs", "a foo", "$z")')
        fault('findIndex("a", "$w")')
        expect(reads.select { |kind, _| kind == :global }).to eq([[:global, 'w']])
      end

      it 'have no doReplace or zipArrays' do
        expect { js('doReplace("a", "0", "z")') }.to raise_error(js_error, 'doReplace is not defined')
        expect { js('zipArrays("a", "b")') }.to raise_error(js_error, 'zipArrays is not defined')
      end
    end

    context 'with the Miner/mm_train 2019-01 copy' do
      let(:copy) { :'0ad2095' }

      it 'does not join " and some " in buildArray' do
        js('buildArray("ba", "a foo, an bar and some baz, an apple and a pie")')
        expect(locals['ba']).to eq('foo|bar and some baz|apple|pie')
      end
    end

    context 'with the 2019-02 and 2022 copies (`if` for `else if`)' do
      let(:copy) { :'1bfe9a2' }

      it 'read a %name value that starts with "$" as a global too' do
        locals.merge!('a' => 'x', 'pv' => '$foo')
        js('doPush("a", "%pv")')
        js('doUnshift("a", "%pv")')
        fault('findIndex("a", "%pv")')
        expect(locals['a']).to eq('|x|')
        expect(reads.select { |kind, _| kind == :global }).to eq([[:global, '$foo'], [:global, '$foo'], [:global, 'foo']])
      end

      it 'treat only "undefined" as an empty doPush array' do
        locals['e'] = ''
        js('doPush("e", "q")')
        expect(locals['e']).to eq('|q')
      end
    end

    context 'with the first 2025 copy' do
      let(:copy) { :c878a96 }

      it 'does not resolve %name in doReplace' do
        locals.merge!('h' => 'a|b', 'idx' => '0', 'v' => 'z')
        js('doReplace("h", "0", "%v")')
        js('doReplace("h", "%idx", "w")')
        expect(locals['h']).to eq('%v|b')
        expect(reads).not_to include([:local, 'v'])
      end
    end
  end

  describe 'doConcat' do
    it 'appends a | list or a number, writing "undefined" for an unset array (t227)' do
      locals['arr'] = 'a'
      js('doConcat("arr", "p|q")')
      js('doConcat("nov", 12)')
      expect(locals).to eq('arr' => 'a|p|q', 'nov' => 'undefined|12')
    end
  end

  describe 'doReplace (the 2025-08-31 e9794af copy)' do
    before { locals['h'] = 'a|b|c' }

    it 'sets an index, padding holes past the end (t227 rep1)' do
      js('doReplace("h", "5", "z")')
      expect(locals['h']).to eq('a|b|c|||z')
    end

    it 'leaves the array alone for a key that is not an array index (t227 rep2)' do
      %w[doReplace("h","-1","z") doReplace("h","01","z") doReplace("h","foo","z") doReplace("h","%idx","z")
         doReplace("h","4294967295","z")].each { |call| js(call) }
      expect(locals['h']).to eq('a|b|c')
    end

    it 'takes number keys and items, and %name for either (t227 rep3/rep4)' do
      locals.merge!('a' => 'x|y', 'idx' => '0')
      js('doReplace("h", 1, 7)')
      js('doReplace("h", 2.0, 0.5)')
      js('doReplace("h", "%idx", "%a")')
      expect(locals['h']).to eq('x|y|7|0.5')
    end

    it 'truncates or pads through "length", RangeError (empty message) for a non-uint32 (t227 rep5-rep7)' do
      js('doReplace("h", "length", "2")')
      expect(locals['h']).to eq('a|b')
      js('doReplace("h", "length", "4")')
      expect(locals['h']).to eq('a|b||')
      fault('doReplace("h", "length", "x")', '')
      fault('doReplace("h", "length", "-1")', '')
      fault('doReplace("h", "length", 1.5)', '')
      expect(locals['h']).to eq('a|b||')
    end

    it 'refuses to build an array larger than MAX_LENGTH' do
      expect { js('doReplace("h", "4294967294", "z")') }.to raise_error(unsupported)
    end
  end

  describe 'doSort' do
    it 'throws for the NUMBERS 0 and 1 (and -0), leaving i = 0 (t227)' do
      locals['t'] = 'b|a'
      %w[doSort("t",0) doSort("t",1) doSort("t",-0)].each { |call| fault(call) }
      expect(locals['t']).to eq('b|a')
      expect(js('i')).to eq(0.0)
    end

    it 'writes the array back unchanged for any other order ("undefined" when unset; raises "%name") (t227)' do
      locals['t'] = 'b|a'
      js('doSort("t", "0")')
      js('doSort("s", "1")')
      js('doSort("n", 2)')
      expect(locals).to eq('t' => 'b|a', 's' => 'undefined', 'n' => 'undefined')
      expect(reads.count { |r| r.first == :set }).to eq(3)
    end
  end

  describe 'buildArray' do
    it 'turns prose into a | list with ASCII word boundaries (t227 ba)' do
      js('buildArray("ba", "a foo, an bar and some baz, an apple and a pie")')
      js('buildArray("ba2", "")')
      js('buildArray("ba3", 42)')
      expect(locals).to eq('ba' => 'foo|bar|baz|apple and pie', 'ba2' => '', 'ba3' => '42')
    end

    it 'treats a non-ASCII letter as a word boundary like JavaScript' do
      js(%(buildArray("x", "#{[0xE9].pack('U')}a b, a c")))
      expect(locals['x']).to eq("#{[0xE9].pack('U')}b|c")
    end
  end

  describe 'buildArrayStr' do
    it 'throws the length TypeError after a valid pattern, leaving i = 0' do
      fault('buildArrayStr("b", "a foo", "foo")')
      expect(js('i')).to eq(0.0)
    end

    it 'reads a %name pattern first' do
      locals['p'] = 'foo'
      fault('buildArrayStr("b", "a foo", "%p")')
      expect(reads).to include([:local, 'p'])
    end

    it 'reports an invalid pattern before the length fault (text not Jint\'s: tracked divergence)' do
      fault('buildArrayStr("b", "a foo", "(")', 'Invalid regular expression: /(/i')
      expect { js('i') }.to raise_error(js_error, 'i is not defined')
    end
  end

  describe 'SOURCES (whole `<% %>` blocks of the corpus)' do
    def block_source(cmd_path)
      program = Lich::Genie::Lexer.compile(File.read(cmd_path), file_name: 'x.cmd')
      program.instructions.select { |i| i.function == :jsblock }.map { |i| "#{i.content}\n" }.join
    end

    it 'holds the SkillData sort and ubercombat TEXT_TO_NUMBER blocks by their real fingerprints (lab)' do
      paths = %w[t233_js_skilldata.cmd t238_js_uber_text_to_number.cmd].map { |name| lab.lab_path(name) }
      skip(lab.lab_missing('t233_js_skilldata.cmd / t238_js_uber_text_to_number.cmd')) unless paths.all?
      expect(described_class::SOURCES.keys).to contain_exactly(*paths.map { |p| Lich::Genie::JsSource.fingerprint(block_source(p)) })
    end

    it 'is keyed by the tokens: one changed character is not the block, trailing spaces and indentation are (lab)' do
      path = lab.lab_path('t238_js_uber_text_to_number.cmd')
      skip(lab.lab_missing('t238_js_uber_text_to_number.cmd')) unless path
      source = block_source(path)
      expect(described_class::SOURCES).not_to have_key(Lich::Genie::JsSource.fingerprint(source.sub('100;', '1000;')))
      reflowed = source.sub('var map = {', "var map = { \t").gsub(/^/, '  ')
      expect(described_class.source_for(reflowed)).to equal(described_class::UBER_TEXT_TO_NUMBER)
    end

    it 'runs the SkillData sort into the length TypeError, leaving list (opaque) and i (t233)' do
      skilldata = described_class::SOURCES.values.find { |s| s.name.include?('SkillData') }
      locals['skills'] = 'b|a'
      expect { skilldata.run(runtime) }.to raise_error(js_error, described_class::LENGTH_FAULT)
      expect(js('i')).to eq(0.0)
      expect { js('list') }.to raise_error(unsupported)
      expect(locals).to eq('skills' => 'b|a')
    end
  end

  describe 'ubercombat TEXT_TO_NUMBER (t238)' do
    let(:block) { described_class::SOURCES.values.find { |s| s.name.include?('TEXT_TO_NUMBER') } }

    def number_of(text)
      locals['number_as_string'] = text
      block.run(runtime)
      locals['text_to_number']
    end

    {
      'twenty-three' => '23', 'one hundred five' => '105', 'two thousand three hundred forty-five' => '2345',
      'five million six' => '5000006', 'one decillion' => '1E+33', 'nine hundred ninety-nine quintillion' => '9.99E+20',
      'twelve thousand thirty-four million' => '34012000', 'seven--eight  thousand' => '15000', 'thousand million' => '0',
      'Twenty' => '0', 'hundred' => '0', '-five-' => '5', '' => '0', 'zero' => '0', 'nineteen ninety' => '109'
    }.each do |text, value|
      it "#{text.inspect} -> #{value}" do
        expect(number_of(text)).to eq(value)
      end
    end

    it 'splits on every JavaScript \s character and "-" (NBSP, BOM, U+2028 yes; NEL, ZWSP no)' do
      expect([0xA0, 0xFEFF, 0x2028, 0x3000, 0x0B].map { |cp| number_of("twenty#{[cp].pack('U')}three") }).to all(eq('23'))
      expect([0x85, 0x200B, 0x180E].map { |cp| number_of("twenty#{[cp].pack('U')}three") }).to all(eq('0'))
    end

    it 'keeps the empty word after a trailing "-" (JS split has no limit), so magnitude ends undefined (probe m5)' do
      expect(number_of('one thousand twenty-')).to eq('1020')
      expect(js('magnitude')).to be_nil
      expect(number_of('-two thousand')).to eq('2000')
      expect(js('magnitude')).to eq(1000.0)
    end

    it 'splits "" into one empty word, so magnitude is assigned (undefined), not left undeclared' do
      expect(number_of('')).to eq('0')
      expect(js('magnitude')).to be_nil
    end

    it 'reads an unset number_as_string as "undefined" (0)' do
      block.run(runtime)
      expect(locals['text_to_number']).to eq('0')
    end

    it 'leaves magnitude (the last magnitude_map lookup, undefined when not found), map/magnitude_map (opaque) and textToNumber' do
      expect { js('magnitude') }.to raise_error(js_error, 'magnitude is not defined')
      number_of('one')
      expect { js('magnitude') }.to raise_error(js_error, 'magnitude is not defined') # never assigned
      number_of('two thousand')
      expect(js('magnitude')).to eq(1000.0)
      number_of('two thousand some')
      expect(js('magnitude')).to be_nil
      expect { js('map') }.to raise_error(unsupported)
      expect { js('magnitude_map') }.to raise_error(unsupported)
      locals['number_as_string'] = 'forty two'
      expect(js('textToNumber()')).to be_nil
      expect(locals['text_to_number']).to eq('42')
    end

    %w[constructor toString __proto__ hasOwnProperty valueOf].each do |key|
      it "does not model #{key} (an Object.prototype key: Jint concatenates its function text)" do
        locals['text_to_number'] = 'before'
        expect { number_of("one #{key}") }.to raise_error(unsupported, /Object\.prototype/)
        expect(locals['text_to_number']).to eq('before')
      end
    end
  end
end
