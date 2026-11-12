# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Lich::Genie::ParseCommand: Remix Command.ParseCommand's row pipeline (Command.cs:219-2558 R) and
# SendTextToGame / ClassCommand_SendText (Command.cs:2826-2839 R, FormMain.cs:4391-4422 R), run
# on the real CommandRouter (its #command arm) with recording ports. Every expectation below is
# Remix behaviour pinned by a genieflow golden (flow t127-t130, t134-t138; genieflow probes
# p01-p05).
RSpec.describe Lich::Genie::ParseCommand do
  let(:vars) { Lich::Genie::Variables.new }
  let(:sends) { [] }
  let(:boxes) { [] }
  let(:launches) { [] }
  let(:echoes) { [] }
  let(:queue) { Lich::Genie::CommandQueue.new(clock: -> { Time.at(0) }) }
  let(:aliases) { {} }
  let(:config) { Lich::Genie::GameState::DEFAULT_CONFIG }
  let(:globals_adapter) { Object.new.tap { |o| o.define_singleton_method(:key?) { |name| vars.global_key?(name) } } }
  let(:router) do
    Lich::Genie::CommandRouter.new(
      vars: vars, eval: Lich::Genie::Eval.new(globals: globals_adapter), echo: ->(t) { echoes << t },
      send: ->(t) { sends << t }, hooks: nil, launch: ->(n, a) { launches << [n, a] }, queue: queue,
      input_box: ->(t) { boxes << t }, aliases: -> { aliases }
    )
  end

  def parse(text, send: true, quick: true) = router.parse_command(text, send_to_game: send, parse_quick_send: quick)

  describe 'the bug / sing / ; bypass (Command.cs:223-233 R)' do
    it 'sends the whole text unsplit, $-expanded and unescaped, case-insensitively, and returns it raw' do
      vars.global_set('who', 'Al')
      expect(parse('SING la;la $who')).to eq('SING la;la $who')
      parse('bug report;x')
      parse(';lich cmd;x')
      parse('sing a\\;b')
      expect(sends).to eq(['SING la;la Al', 'bug report;x', ';lich cmd;x', 'sing a;b'])
    end

    it 'needs the space after bug/sing, and only a LEADING ; bypasses' do
      parse('singer x;y')
      parse('bugs;z')
      parse('a;;b')
      expect(sends).to eq(['singer x', 'y', 'bugs', 'z', 'a', ';b']) # ";b" is a folded piece, not a bypass
    end

    it 'without bSendToGame sends nothing and still returns the text' do
      expect(parse(';x', send: false)).to eq(';x')
      expect(sends).to be_empty
    end
  end

  describe 'the split and the rows (Command.cs:235-2551 R)' do
    it 'splits on ; with SafeSplit quirks, never trims a row, and returns the LAST row' do
      expect(parse('x;  y ;z')).to eq('z')
      expect(sends).to eq(['x', '  y ', 'z'])
    end

    it 'runs every # row (the trimmed test) and returns its result; a later plain row resets it' do
      expect(parse('  #evalmath 2+3', send: false)).to eq('5')
      expect(parse('#var a 1;look', send: false)).to eq('look')
      expect(parse('look;#var b 2', send: false)).to eq('') # sResult reset per row
      expect(sends).to be_empty
      expect([vars.global_get('a'), vars.global_get('b')]).to eq(%w[1 2])
    end

    it 'launches a RAW leading-. row with the ParseArgs name, and sends " .x" as text' do
      parse('.helper a b;  .no')
      expect(launches).to eq([['helper', 'a b']])
      expect(sends).to eq(['  .no'])
    end

    # Remix launches ".cmd" and prints "File not found: .cmd" (flow t162; ScriptLaunch).
    it 'still launches an empty or dot-only name (`.`, `. x`, `..h`)' do
      parse('.;. x;..h')
      expect(launches).to eq([['', ''], ['', 'x'], ['.h', '']])
      expect(sends).to be_empty
    end

    it 'turns a raw leading - into #send (quick send) unless parse_quick_send is off' do
      parse('-1 nod; -2 grin')
      expect(queue.items.map { |i| [i.delay, i.action] }).to eq([[1.0, 'nod']])
      expect(sends).to eq([' -2 grin'])
      parse('-3 x', quick: false)
      expect(sends.last).to eq('-3 x')
    end

    it 'keeps an escaped separator in its row (\\; is not a split point) and the backslash until the send' do
      expect(parse('#var esc a\\;b', send: false)).to eq('')
      expect(vars.global_get('esc')).to eq('a\\;b') # ParseArgs and ParseAllArgs keep it (flow t128)
      parse('e\\;f')
      expect(sends).to eq(['e;f'])
    end

    it 'expands $globals (not %locals, not $1) on a plain row before sending' do
      vars.global_set('t', 'goblin')
      parse('attack $t %t $1 \\$t')
      expect(sends).to eq(['attack goblin %t $1 $t'])
    end

    it 'returns "" for an empty or separator-only text without sending' do
      expect(parse('')).to eq('')
      expect(parse(';', send: false)).to eq(';') # a leading ; is the bypass
      expect(sends).to be_empty
    end
  end

  describe 'SendTextToGame + ClassCommand_SendText (Command.cs:2826-2839 R; FormMain.cs:4391-4422 R)' do
    it 'turns \\\\ into \\, keeps \\x and \\@, drops every other backslash' do
      parse('k\\\\l')
      parse('m\\n\\\\\\o')
      parse('i\\@j')
      expect(sends).to eq(['k\\l', 'mn\\o', 'i@j'])
    end

    it 'puts a text holding @ or \\x in the input box instead of sending it' do
      parse('say hello@there')
      parse('g\\\\h\\x')
      expect(sends).to be_empty
      expect(boxes).to eq(['say hello@there', 'g\\h\\x'])
    end

    it 'shows an escaped \\@ in the input box as Remix\'s marker when the text also holds a bare @' do
      parse('a\\@b@c')
      expect(boxes).to eq(["a#{[0xA4].pack('U')}b@c"])
    end

    it 'never sends an empty text after unescaping' do
      parse('\\')
      expect(sends).to be_empty
    end
  end

  describe 'faults (Command.cs:219 R is async; top-level callers never await it)' do
    it 'propagates a fault from call and ends the remaining rows' do
      expect { parse("#var {'} {2};#var later 1") }.to raise_error(Lich::Genie::Error, /Invalid string in Parse Arguments/)
      expect(vars.global_get('later')).to be_nil
    end

    it 'swallows it at the top level (run), after running the rows before it' do
      expect { router.run("#var ok 1;#var {'} {2};#var later 1", send_to_game: true) }.not_to raise_error
      expect([vars.global_get('ok'), vars.global_get('later')]).to eq(['1', nil])
    end

    it 'never swallows a nesting-cap overflow' do
      boom = Lich::Genie::DispatchDepth::Exceeded.new('cap')
      exploding = Lich::Genie::CommandRouter.new(vars: vars, eval: Lich::Genie::Eval.new(globals: globals_adapter),
                                                 echo: ->(_t) {}, send: ->(_t) { raise boom }, hooks: nil)
      expect { exploding.run('look', send_to_game: true) }.to raise_error(boom)
    end

    it 'lets an engine bug (not a Genie::Error) through' do
      broken = Lich::Genie::CommandRouter.new(vars: vars, eval: Lich::Genie::Eval.new(globals: globals_adapter),
                                              echo: ->(_t) {}, send: ->(_t) { raise TypeError, 'bug' }, hooks: nil)
      expect { broken.run('look', send_to_game: true) }.to raise_error(TypeError, 'bug')
    end
  end

  describe 'the configured characters (Config.cs:579-636 R; flow t138)' do
    let(:capture) do
      Lich::Genie::GameState.new.tap do |state|
        state.apply_setting('separatorchar', '|')
        state.apply_setting('commandchar', '!')
        state.apply_setting('scriptchar', ',')
      end
    end
    let(:vars) { Lich::Genie::Variables.new(game_state: Lich::Genie::ReservedState.new(game_state: capture)) }

    it 'splits on the separator char, dispatches on the command char and launches on the script char' do
      parse('x;y|!var a 1|,helper q')
      expect(sends).to eq(['x;y'])
      expect(vars.global_get('a')).to eq('1')
      expect(launches).to eq([['helper', 'q']])
    end

    it 'still writes the quick send as "#send", which is then plain text under another command char' do
      parse('-1 nod')
      expect(sends).to eq(['#send 1 nod'])
      expect(queue).to be_empty
    end
  end

  # Command.ParseAlias (Command.cs:238-241, 2746-2780 R). The engine owns no AliasList in
  # Lich, so production passes none; the port is exercised here.
  describe 'aliases' do
    it 'expands a piece whose first word is a key: $0/$n replaced, else the rest appended; then splits again' do
      aliases.merge!('aa' => 'say $1-$2 [$0];look', 'bb' => 'wave')
      parse('aa "one" two three;bb at me')
      expect(sends).to eq(['say one-two [one two three]', 'look', 'wave at me'])
    end

    it 'matches the key lower-cased but looks it up as typed: an upper-case use runs nothing' do
      aliases['aa'] = 'say hi'
      expect(parse('AA x', send: false)).to eq('')
      parse('AA x')
      expect(sends).to be_empty
    end

    it 'does not expand an alias inside the expansion again (no recursion on this path)' do
      aliases['loop'] = 'loop again'
      parse('loop')
      expect(sends).to eq(['loop again '])
    end
  end
end
