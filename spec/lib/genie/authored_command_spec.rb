# frozen_string_literal: true

require 'pp'
require 'tmpdir'
require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative '../../../lib/genie'

# A decided divergence from Remix, for security (PR #1813 review item 1): a send reaches Lich's
# command path (do_client: `,go2`, `;kill`) only when the author WROTE its leading `,`/`;` -- in a
# .cmd put/send row, or in the body of a #trigger, alias or action whose DEFINITION was authored
# (the provenance layer); a code-running one (`,e <ruby>`, `,exec`, `,l5u`, ...) only from a
# literal .cmd `put` row (the code layer). Anything else goes to the game as text.
# The glue's LichGamePort hands a {Lich::Genie::LichCommand} to do_client and puts any other String
# to the game; here every send's CLASS is recorded, on the real interpreter, ParseCommand,
# TriggerRunner, Triggers/AliasList/ActionList and CommandQueue.
RSpec.describe 'Genie: Lich commands only from author-written text' do
  let(:authored) { Lich::Genie::AuthoredCommand }
  let(:mark) { Lich::Genie::AuthoredCommand::MARK }
  let(:code_mark) { Lich::Genie::AuthoredCommand::CODE_MARK }
  let(:evil) { %(,e respond('PWNED_' + (6*7).to_s)) }

  # [text, lich_command?] for each send.
  def classify(sends)
    sends.map { |text| [text.to_s, text.is_a?(Lich::Genie::LichCommand)] }
  end

  # Real Engine.run on a virtual clock; then each of +game_lines+ goes to the global #triggers
  # (through the production ParseDispatch.fire_triggers and a real global-scope TriggerRunner, as
  # the glue's trigger worker does); then the queued sends are released through that runner, as
  # the glue's queue worker does (RunQueueCommand). +triggers+ and +aliases+ are added as
  # triggers.cfg / aliases.cfg rows are (authored); +lists+ may bring a bundle of its own.
  def run(source, lines: [], triggers: nil, aliases: {}, vars: {}, game_lines: [], debug: nil, lists: nil)
    lines += ['THE_END'] if source.include?('waitfor THE_END')
    clock = [0.0]
    sends = []
    echoes = []
    prints = []
    game = Object.new.tap { |g| g.define_singleton_method(:send_command) { |t| sends << t } }
    hooks = Object.new.tap { |h| h.define_singleton_method(:emit) { |op, payload| prints << [op, payload].inspect } }
    queue = Lich::Genie::CommandQueue.new(clock: -> { Time.at(clock[0]) })
    lists ||= Lich::Genie::Lists.new
    triggers&.each { |pattern, body| lists.triggers.add(pattern, body, authored: true) }
    aliases.each { |key, value| lists.aliases.add(key, value, authored: true) }
    globals = Lich::Genie::Variables.new
    vars.each { |name, value| globals.global_set(name, value) }
    source = "debuglevel #{debug}\n#{source}" if debug
    Lich::Genie::Engine.run(source, name: 't', variables: globals, game: game, input: GenieSpecSupport::TimedInput.new(lines, clock: clock, gap: 0.02),
                                    hooks: hooks, lists: lists, queue: queue, echo: ->(t) { echoes << t }, clock: -> { clock[0] })
    runner = Lich::Genie::TriggerRunner.new(vars: globals, eval: Lich::Genie::Eval.new, game: game, launch: ->(*) {},
                                            queue: queue, lists: lists, hooks: hooks, echo: ->(t) { echoes << t })
    game_lines.each do |text|
      Lich::Genie::ParseDispatch.fire_triggers(text, triggers: lists.triggers, runner: runner, on_error: ->(e) { raise e })
    end
    50.times do
      break if queue.empty?

      queue.drain(-> { Lich::Genie::CommandQueue::FREE }) { |action| runner.run_command(action) }
      clock[0] += 1.0
    end
    { sends: classify(sends), echoes: echoes, prints: prints, queue: queue, globals: globals, lists: lists }
  end

  # The sends that went to Lich's command path.
  def lich(result)
    result[:sends].select(&:last)
  end

  describe Lich::Genie::AuthoredCommand do
    it 'marks the leading , or ; of every SafeSplit piece, after white space and <c>, and nothing else' do
      expect(authored.mark(',go2 1;look; ,kill x;<c>,e 1;a,b', ';'))
        .to eq(",#{mark}go2 1;look; ,#{mark}kill x;<c>,#{mark}e 1;a,b")
    end

    it 'marks a ; that opens the text or a folded empty piece (SafeSplit keeps it in the piece)' do
      expect(authored.mark(';e x;;e y', ';')).to eq(";#{mark}e x;;#{mark}e y")
    end

    it 'never marks inside quotes or braces (one piece there) nor a , after the first character' do
      expect(authored.mark('say "a;,b";x {c;,d}', ';')).to eq('say "a;,b";x {c;,d}')
    end

    it 'skips a send delay (digits and dots) only in the first piece, and only at the very start' do
      expect(authored.mark('1 ,go2 x;2 ,kill', ';', delay: true)).to eq("1 ,#{mark}go2 x;2 ,kill")
      expect(authored.mark('1.5,e 1', ';', delay: true)).to eq("1.5,#{mark}e 1")
      expect(authored.mark(' 1 ,go2', ';', delay: true)).to eq(' 1 ,go2') # send_delay reads no delay here either
      expect(authored.mark('1 ,go2', ';')).to eq('1 ,go2') # put: "1 ,go2" is not a Lich command
    end

    it 'returns the very text when it holds no , or ;' do
      text = +'look at the %thing'
      expect(authored.mark(text, ';')).to equal(text)
    end

    it 'follows the live separator char' do
      expect(authored.mark('look|,go2 1', '|')).to eq("look|,#{mark}go2 1")
      expect(authored.mark('look;,go2 1', '|')).to eq('look;,go2 1')
    end

    # The mark must never change how SafeSplit cuts the text: random texts over the characters
    # that matter (separator, quote, braces, backslash, white space, , and <c>).
    it 'leaves the SafeSplit of every text unchanged (seeded fuzz)' do
      rng = Random.new(1813)
      alphabet = [',', ';', ' ', '\\', '"', '{', '}', 'a', '<c>', ';;', ',,']
      2000.times do
        text = Array.new(rng.rand(1..9)) { alphabet[rng.rand(alphabet.length)] }.join
        [false, true].each do |delay|
          marked = authored.mark(text, ';', delay: delay)
          pieces = Lich::Genie::Text.remix_safe_split(marked, ';').map { |piece| authored.strip(piece) }
          expect(pieces).to eq(Lich::Genie::Text.remix_safe_split(text, ';')), "text #{text.inspect} delay #{delay}"
        end
      end
    end

    it 'cannot be forged: the mark carries a per-process random part, and a look-alike is not it' do
      expect(mark).to match(/\A\x05\h{16}\x05\z/)
      expect(authored.leads?(",\x05#{'0' * 16}\x05e 1")).to be(false)
    end

    it 'reads a mark only right after the leading , or ; of the row' do
      expect(authored.leads?(" <c>,#{mark}go2")).to be(true)
      expect(authored.leads?("x ,#{mark}go2")).to be(false)
      expect(authored.leads?("#{mark},go2")).to be(false)
    end

    # The command name must be literal (PR #1813 re-review): a sigil anywhere in it -- whether or not
    # such a variable exists -- leaves the , or ; unmarked; the arguments may hold any.
    it 'leaves the , or ; unmarked when the command name holds a $, % or @, and marks a literal name with any arguments' do
      [',$1', ',%x', ', $1', ";\t%x args", ',$gname', ',pro%x', ',probe$1', ',@scriptdir@', '<c>,%x', ',go2;,%x'].each do |text|
        expect(authored.mark(text, '|')).to eq(text), text.inspect
      end
      expect(authored.mark('1 ,%x', ';', delay: true)).to eq('1 ,%x')
      expect(authored.mark(',go2 $home', ';')).to eq(",#{mark}go2 $home")
      expect(authored.mark(',  go2 %x@y$z', ';')).to eq(",#{mark}  go2 %x@y$z")
      expect(authored.mark(",probe\tx%y;,%x;,go2 1", ';')).to eq(",#{mark}probe\tx%y;,%x;,#{mark}go2 1")
    end

    it 'marks the argument of a put or send row only' do
      expect(authored.mark_argument('  put ,go2 %d', :put, ';')).to eq("  put ,#{mark}go2 %d")
      expect(authored.mark_argument('send 2 ,go2', :send, ';')).to eq("send 2 ,#{mark}go2")
      %i[move do_func echo].each { |verb| expect(authored.mark_argument('x ,go2', verb, ';')).to eq('x ,go2') }
      expect(authored.mark_argument('put', :put, ';')).to eq('put')
    end
  end

  describe Lich::Genie::ParseCommand do
    let(:sent) { [] }
    let(:routed) { [] }
    let(:aliases) { {} }
    let(:parser) do
      out = sent
      rows = routed
      table = aliases
      Lich::Genie::ParseCommand.new(
        router: Object.new.tap { |r| r.define_singleton_method(:command) { |row| rows << row && '' } },
        game: ->(text) { out << text }, launch: ->(name, args) { rows << [name, args] },
        globals: ->(text) { text.gsub('$evil', ',e 1') }, input_box: ->(text) { rows << [:box, text] },
        chars: -> { Lich::Genie::GameState::DEFAULT_CONFIG }, aliases: -> { table }
      )
    end

    it 'sends a marked row as a LichCommand, without its mark; an unmarked , row as plain text' do
      parser.call("look;,#{mark}go2 1;,e 2", send_to_game: true)
      expect(classify(sent)).to eq([['look', false], [',go2 1', true], [',e 2', false]])
    end

    it 'routes a marked ; text whole (the bypass) as a LichCommand; an unmarked one as text' do
      parser.call(";#{mark}kill x;look", send_to_game: true)
      parser.call(';kill x;look', send_to_game: true)
      expect(classify(sent)).to eq([[';kill x;look', true], [';kill x;look', false]])
    end

    # Code layer: only the code mark lets a code-running command through, on the bypass as on a row.
    it 'sends a code-running command as a LichCommand only with the code mark' do
      parser.call(";#{mark}e 1;look", send_to_game: true)
      parser.call(";#{code_mark}e 1;look", send_to_game: true)
      parser.call("look;,#{mark}eq 2;,#{code_mark}exec 3", send_to_game: true)
      expect(classify(sent)).to eq([[';e 1;look', false], [';e 1;look', true], ['look', false], [',eq 2', false], [',exec 3', true]])
    end

    it 'takes the code mark back when ParseGlobalVars changes the row (it needed expansion after all)' do
      parser.call(",#{code_mark}e $evil", send_to_game: true)
      parser.call(";#{code_mark}e $evil", send_to_game: true)
      parser.call(",#{code_mark}go2 $evil", send_to_game: true) # provenance holds: the , is the author's
      expect(classify(sent)).to eq([[',e ,e 1', false], [';e ,e 1', false], [',go2 ,e 1', true]])
    end

    it 'never lets a global put in by ParseGlobalVars carry the mark' do
      parser.call('$evil', send_to_game: true)
      expect(classify(sent)).to eq([[',e 1', false]])
    end

    it 'hands #commands, launches and input-box texts their rows without marks' do
      text = "#echo ,#{mark}x;.scr ,#{mark}a;say @,#{mark}b"
      parser.call(text, send_to_game: true)
      expect(routed.flatten.join).not_to include(mark)
      expect(sent).to eq([])
    end

    context 'with the engine\'s AliasList' do
      let(:aliases) { Lich::Genie::AliasList.new }

      it 'expands an authored lich-key alias the author wrote with its value marked; its $n args stay unmarked' do
        aliases.add(',ev', ',go2 $1;,kill $2', authored: true)
        parser.call(",#{mark}ev 1 ,e", send_to_game: true)
        expect(classify(sent)).to eq([[',go2 1', true], [',kill ,e', true]])
        sent.clear
        aliases.add('fwd', '$1', authored: true)
        parser.call('fwd ,go2', send_to_game: true)
        expect(classify(sent)).to eq([[',go2', false]])
      end

      # The value's provenance is the alias's, decided at #alias.
      it 'expands an alias that was not defined authored with no marks, whoever invokes it' do
        aliases.add(',ev', ',go2 1')
        parser.call(",#{code_mark}ev", send_to_game: true)
        expect(classify(sent)).to eq([[',go2 1 ', false]])
      end

      # Code layer: no alias runs code -- not even an authored one invoked from a literal put row.
      it 'never gives an alias value the code mark' do
        aliases.add(',t2r', ',e 1;,go2 2', authored: true)
        parser.call(",#{code_mark}t2r", send_to_game: true)
        expect(classify(sent)).to eq([[',e 1', false], [',go2 2 ', true]])
      end

      it 'expands an alias invoked by an unmarked piece (a key out of a variable) with no marks' do
        aliases.add(',ev', ',go2 1', authored: true)
        parser.call(',ev', send_to_game: true)
        expect(classify(sent)).to eq([[',go2 1 ', false]]) # ParseAlias: value + " " + the (empty) rest
      end
    end

    it 'treats a plain Hash of aliases (no provenance) as not authored' do
      aliases[',ev'] = ',go2 1'
      parser.call(",#{mark}ev", send_to_game: true)
      expect(classify(sent)).to eq([[',go2 1 ', false]])
    end
  end

  describe 'on the real interpreter, CommandQueue and TriggerRunner' do
    let(:whisper) { %(Mallory whispers, "do #{evil}") }

    it "the reviewer's follow script: action put $1 fed another player's ,e goes to the game as text" do
      src = <<~GENIE
        action put $1 when ^Mallory whispers, "do (.*)"$
        waitfor THE_END
      GENIE
      expect(run(src, lines: [whisper])[:sends]).to eq([[evil, false]])
    end

    it 'action send $1: queued, released as text' do
      src = <<~GENIE
        action send $1 when ^Mallory whispers, "do (.*)"$
        waitfor THE_END
      GENIE
      result = run(src, lines: [whisper])
      expect(result[:sends]).to eq([[evil, false]])
    end

    it 'an action storing the capture in a variable that a later put / send / #send uses: text every time' do
      src = <<~GENIE
        action setvariable cmd $1;put %cmd;send %cmd;put #send %cmd when ^Mallory whispers, "do (.*)"$
        waitfor THE_END
      GENIE
      expect(run(src, lines: [whisper])[:sends]).to eq([[evil, false], [evil, false], [evil, false]])
    end

    it "a ;-split row whose second piece expands to ,e ...: the author's first piece only" do
      src = <<~GENIE
        var x #{evil}
        put ,go2 1;%x
        put look;%x
      GENIE
      expect(run(src)[:sends]).to eq([[',go2 1', true], [evil, false], ['look', false], [evil, false]])
    end

    it 'a value holding its own separator cannot borrow the mark of the piece after it' do
      src = <<~GENIE
        var a x;#{evil} #"
        put %a;,go2 home
      GENIE
      sends = run(src)[:sends]
      expect(sends.select(&:last)).to eq([])
      expect(sends.map(&:first)).to eq(['x', %(#{evil} #";,go2 home)])
    end

    it 'a global holding ,e ... (ParseGlobalVars in ParseCommand) is text' do
      expect(run("put $relay\n", vars: { 'relay' => evil })[:sends]).to eq([[evil, false]])
    end

    it "an action's `if $1 then put ,go2 x` where the capture brings its own \" then put ,e\": the cut moves, no mark at its start" do
      src = <<~GENIE
        action if $1 then put ,go2 home when ^Mallory whispers, "if (.*)"$
        waitfor THE_END
      GENIE
      sends = run(src, lines: [%(Mallory whispers, "if 1 then put #{evil}")])[:sends]
      expect(sends.select(&:last)).to eq([])
    end

    it 'a #trigger body {$2} and a body that queues the capture with #send: text' do
      triggers = { '^(\w+) whispers, "BARE (.*)"$' => '$2', '^(\w+) whispers, "Q (.*)"$' => '#send $2' }
      lines = [%(Mallory whispers, "BARE #{evil}"), %(Mallory whispers, "Q #{evil}")]
      expect(run("echo go\n", game_lines: lines, triggers: triggers)[:sends]).to eq([[evil, false], [evil, false]])
    end

    it 'keeps every author-written Lich command working: put ,go2 %dest, send N ,go2, action and #trigger bodies' do
      src = <<~GENIE
        var dest 123
        put ,go2 %dest
        put <c>,kill x
        send 1 ,go2 2
        if 1 = 1 then put ,go2 4
        action put ,go2 5;send ,go2 6 when ^Bob bows
        action if 1 = 1 then put ,go2 8 when ^Bob nods
        waitfor THE_END
      GENIE
      result = run(src, lines: ['Bob bows', 'Bob nods'], triggers: { '^Bob bows' => ',go2 7' }, game_lines: ['Bob bows'])
      expect(result[:sends]).to contain_exactly([',go2 123', true], ['<c>,kill x', true], [',go2 2', true],
                                                [',go2 4', true], [',go2 5', true], [',go2 6', true], [',go2 7', true],
                                                [',go2 8', true])
    end

    # Game text must not choose WHICH Lich script runs: an author-written , or ; whose command name
    # comes (even partly) from a capture, a variable, a global or an alias argument is game text.
    it 'sends a command whose name is expanded as game text: ,$1 in an action, a #trigger and an alias; ,%x; ,$g; ,pro%x' do
      src = <<~'GENIE'
        var x probe
        var half be
        put ,%x a
        put , %x b
        put ;%x c
        put ,$gname d
        put ,pro%half e
        put ,fw probe f
        action put ,$1 when ^Mallory bows (.*)$
        action put , $1 when ^Mallory nods (.*)$
        waitfor THE_END
      GENIE
      result = run(src, lines: ['Mallory bows probe bowarg', 'Mallory nods probe nodarg'], vars: { 'gname' => 'probe' },
                        aliases: { ',fw' => ',$1' }, triggers: { '^Mallory waves (.*)$' => ',$1' }, game_lines: ['Mallory waves probe wavearg'])
      expect(result[:sends]).to contain_exactly([',probe a', false], [', probe b', false], [';probe c', false], [',probe d', false],
                                                [',probe e', false], [',probe', false], [',probe bowarg', false],
                                                [', probe nodarg', false], [',probe wavearg', false])
    end

    it 'keeps a literal command name working with expanded arguments: put ,go2 $home, %x, an alias $1, a #trigger $1' do
      src = <<~'GENIE'
        var dest 7
        put ,go2 $home
        put ,go2 %dest
        put ,probe x
        send ,probe y
        put ,gh 9
        action put ,probe $1 when ^Mallory points (.*)$
        waitfor THE_END
      GENIE
      result = run(src, lines: ['Mallory points ok'], vars: { 'home' => '123' }, aliases: { ',gh' => ',go2 $1' },
                        triggers: { '^Mallory waves (.*)$' => ',probe $1' }, game_lines: ['Mallory waves hi'])
      expect(result[:sends]).to contain_exactly([',go2 123', true], [',go2 7', true], [',probe x', true], [',probe y', true],
                                                [',go2 9', true], [',probe ok', true], [',probe hi', true])
    end

    it "keeps the mark out of $lastcommand, the echo and the #queue listing" do
      src = <<~GENIE
        put ,go2 1
        echo LAST=%lastcommand
        send 5 ,e 2
        put #queue
      GENIE
      result = run(src)
      expect(result[:echoes].join("\n")).not_to include(mark)
      expect(result[:echoes]).to include('LAST=,go2 1', '(5) ,e 2')
    end
  end

  describe 'code layer, unit: code-running commands and the code mark' do
    it 'tells the code-running built-ins apart as do_client would see them (any case, any line, after strip and <c>)' do
      code = [',e 1', ';eq x', ',exec x', ',execq x', ',execname n x', ',en n x', ',E 1', ',Exec x', '<c>,e 1', "  ,e 1\n",
              ',e', ',e  1', ",e\t1", ',l5u', ',L5U --branch=a:b', ',lich5-update --snapshot', "look\n,e 1", ', e 1',
              ",go2 1\n,e 2"] # Lich acts on the first Lich command line; every one is checked
      other = [',go2 1', ',echo x', ',eval x', ',ending', ',execs x', ',kill e', 'e 1', 'say ,e 1', ',', ';', ',l5', ' <c> ,e 1',
               ",go2 1\nlook"]
      expect(code.reject { |text| authored.code_command?(text) }).to eq([])
      expect(other.select { |text| authored.code_command?(text) }).to eq([])
    end

    it 'makes a LichCommand of a code-running command only when it may run code; any other shape always' do
      expect(authored.lich_command(',e 1', code: false)).to be_an_instance_of(String)
      expect(authored.lich_command(',e 1', code: true)).to be_a(Lich::Genie::LichCommand)
      expect(authored.lich_command(',go2 1', code: false)).to be_a(Lich::Genie::LichCommand)
      expect(authored.lich_command(',e 1', code: false)).to eq(',e 1')
    end

    it 'marks with the code mark on request; reads, downgrades and strips both marks' do
      text = authored.mark(',e 1;,go2 2', ';', code: true)
      expect(text).to eq(",#{code_mark}e 1;,#{code_mark}go2 2")
      expect([authored.leads?(text), authored.leads_code?(text), authored.marked?(text)]).to eq([true, true, true])
      down = authored.downgrade(text)
      expect(down).to eq(",#{mark}e 1;,#{mark}go2 2")
      expect([authored.leads?(down), authored.leads_code?(down)]).to eq([true, false])
      expect([authored.strip(text), authored.strip(down), authored.strip(",#{mark}a #{code_mark}b")]).to eq([',e 1;,go2 2', ',e 1;,go2 2', ',a b'])
      expect(authored.mark_argument('put ,e 1', :put, ';', code: true)).to eq("put ,#{code_mark}e 1")
    end

    it 'cannot be forged either: a distinct per-process random part' do
      expect(code_mark).to match(/\A\x06\h{16}\x06\z/)
      expect(code_mark[1..-2]).not_to eq(mark[1..-2])
      expect(authored.leads_code?(",\x06#{'0' * 16}\x06e 1")).to be(false)
    end

    it 'sets the definition context for the block only, restoring the outer one even on an exception' do
      expect(authored.authored_definitions?).to be(false)
      authored.defining(true) do
        authored.defining(false) { expect(authored.authored_definitions?).to be(false) }
        expect(authored.authored_definitions?).to be(true)
        expect { authored.defining(false) { raise 'boom' } }.to raise_error('boom')
        expect(authored.authored_definitions?).to be(true)
      end
      expect(authored.authored_definitions?).to be(false)
    end
  end

  describe 'code layer on the real engine: code-running Lich commands only from a literal .cmd put row' do
    it "dispatches them from a literal put row -- the corpus's put ,e $T2.reload_settings while no global T2 exists" do
      src = <<~'GENIE'
        put ,e 1
        put ,eq 2
        put ,exec 3
        put ,execq 4
        put ,execname n 5
        put ,l5u --branch=a:b
        put ,e $T2.reload_settings
        if 1 = 1 then put ,e 6
        put look;,e 7;,go2 8
      GENIE
      expect(run(src)[:sends]).to eq([[',e 1', true], [',eq 2', true], [',exec 3', true], [',execq 4', true], [',execname n 5', true],
                                      [',l5u --branch=a:b', true], [',e $T2.reload_settings', true], [',e 6', true],
                                      ['look', false], [',e 7', true], [',go2 8', true]])
    end

    it 'sends the corpus row as game text once a global T2 expands in it (the row was not literal)' do
      expect(run("put ,e $T2.reload_settings\n", vars: { 'T2' => 'x' })[:sends]).to eq([[',e x.reload_settings', false]])
    end

    it 'sends them as game text from every other place: expanded rows, send, #send/#put, JS, gosub args, aliases, actions, #trigger bodies' do
      src = <<~'GENIE'
        var x e 1
        var d 1
        put ,%x
        put ,e %d
        send ,e 2
        put #send ,e 3
        put #put ,e 4
        put #if {1} {#put ,e 5}
        js put(",e 6")
        put ,t2r
        put #trigger {^ping} {,e 11}
        action put ,e 9 when ^Bob bows
        gosub g ,e 7
        waitfor THE_END
        exit
        g:
        put $1 $2
        return
      GENIE
      result = run(src, lines: ['Bob bows'], aliases: { ',t2r' => ',e 8' }, triggers: { '^Bob bows' => ',e 10' },
                        game_lines: ['Bob bows', 'ping'])
      expect(result[:sends]).to contain_exactly([',e 1', false], [',e 1', false], [',e 2', false], [',e 3', false], [',e 4', false],
                                                [',e 5', false], [',e 6', false], [',e 7', false], [',e 8 ', false],
                                                [',e 9', false], [',e 10', false], [',e 11', false])
    end
  end

  # A stored definition must not launder another player's words into author text. Each attack
  # runs with a code-running payload (the code layer alone stops it) AND a plain Lich command
  # (only provenance stops it), and the payload must still reach the game as text.
  describe 'provenance: definitions made from captured or expanded text never author Lich commands' do
    [%(,e respond('PWNED_' + (6*7).to_s)), ',go2 666'].each do |payload|
      context "with the payload #{payload[0, 8]}..." do
        let(:payload) { payload }

        it 'a single-line if / else running put %x' do
          result = run("var x #{payload}\nif 1 = 1 then put %x\nif 0 = 1 then put a\nelse put %x\n")
          expect(result[:sends]).to eq([[payload, false], [payload, false]])
        end

        it 'a #trigger body (triggers.cfg) defining a #trigger from its capture' do
          triggers = { '^Mallory whispers, "learn (.*)"$' => '#trigger {^ping} {$1}' }
          result = run("echo go\n", triggers: triggers, game_lines: [%(Mallory whispers, "learn #{payload}"), 'ping'])
          expect(result[:sends]).to eq([[payload, false]])
        end

        it 'a script action defining a #trigger from its capture' do
          src = %(action put #trigger {^ping} {$1} when ^Mallory whispers, "learn (.*)"$\nwaitfor THE_END\n)
          result = run(src, lines: [%(Mallory whispers, "learn #{payload}")], game_lines: ['ping'])
          expect(result[:sends]).to eq([[payload, false]])
        end

        it 'an action defining an action from its capture (action action $1 when ...)' do
          src = %(action action $1 when ^Mallory whispers, "learn (.*)"$\nwaitfor THE_END\n)
          result = run(src, lines: [%(Mallory whispers, "learn put #{payload} when ^ping"), 'ping'])
          expect(result[:sends]).to eq([[payload, false]])
        end

        it 'an action defining a lich-key alias from its capture, invoked by the author-written put ,x' do
          src = %(action put #alias {,x} {$1} when ^Mallory whispers, "learn (.*)"$\nwaitfor GO\nput ,x\n)
          result = run(src, lines: [%(Mallory whispers, "learn #{payload}"), 'GO'])
          expect(result[:sends]).to eq([["#{payload} ", false]])
        end

        it 'a script #trigger whose body is a variable (expanded when it is defined)' do
          result = run("var cmd #{payload}\nput #trigger {^ping} {%cmd}\n", game_lines: ['ping'])
          expect(result[:sends]).to eq([[payload, false]])
        end
      end
    end
  end

  describe 'provenance: which definitions are authored' do
    it 'a literal .cmd put row defines an authored #trigger and #alias; an authored #trigger body without captures too' do
      src = <<~GENIE
        put #trigger {^ping} {,go2 1}
        put #alias {,h} {,go2 2}
        put ,h
      GENIE
      result = run(src, triggers: { '^a' => '#trigger {^b} {,go2 3}' }, game_lines: %w[ping a b])
      expect(result[:sends]).to eq([[',go2 2 ', true], [',go2 1', true], [',go2 3', true]])
    end

    it 'an expanded row, a queued send, JS put and an action body define non-authored ones' do
      src = <<~'GENIE'
        var d 1
        put #trigger {^p1} {,go2 %d}
        put #trigger {^p2} {,go2 2};#nop %d
        send #trigger {^p3} {,go2 3}
        js put("#trigger {^p5} {,go2 5}")
        action put #trigger {^p6} {,go2 6} when ^Bob bows
        waitfor THE_END
      GENIE
      result = run(src, lines: ['Bob bows'], game_lines: %w[p1 p2 p5 p6]) # ^p3 is defined later, by the queue's release
      expect(result[:sends]).to eq([[',go2 1', false], [',go2 2', false], [',go2 5', false], [',go2 6', false]])
      expect(%w[^p1 ^p2 ^p3 ^p5 ^p6].map { |key| result[:lists].triggers.authored?(key) }).to eq([false] * 5)
    end

    it 'an action defined by an action body is not authored; one defined by a .cmd row is' do
      # an `action` row takes its text raw (no %var), so the nested " when " comes from the capture
      src = <<~'GENIE'
        action put ,go2 1 when ^ping
        action action put ,go2 2 $1 ^pong when ^Bob says (\w+)$
        waitfor THE_END
      GENIE
      expect(run(src, lines: ['Bob says when', 'ping', 'pong'])[:sends]).to eq([[',go2 1', true], [',go2 2', false]])
    end

    it 'triggers.cfg and aliases.cfg rows are authored -- and still run no code' do
      Dir.mktmpdir('genie-d10') do |dir|
        File.write(File.join(dir, 'triggers.cfg'), "#trigger {^ping} {,go2 1;,e 2}\n")
        File.write(File.join(dir, 'aliases.cfg'), "#alias {,t2r} {,go2 3;,e 4}\n")
        lists = Lich::Genie::Lists.new(config_dir: dir)
        lists.triggers.load(lists.file('triggers.cfg'))
        lists.aliases.load(lists.file('aliases.cfg'))
        result = run("put ,t2r\n", lists: lists, game_lines: ['ping'])
        expect(result[:sends]).to eq([[',go2 3', true], [',e 4 ', false], [',go2 1', true], [',e 2', false]])
      end
    end

    # Provenance is saved beside triggers.cfg (DefinitionTrust): a #trigger made from a capture that
    # the user saves and loads back is still not authored, and the code layer holds as before.
    it 'a #trigger made from a capture, saved and loaded back: still game text, and no code runs' do
      Dir.mktmpdir('genie-d10') do |dir|
        src = <<~GENIE
          action put #trigger {^ping} {$1} when ^Mallory whispers, "learn (.*)"$
          action put #trigger {^pong} {$1} when ^Mallory whispers, "teach (.*)"$
          waitfor GO
          put #trigger save
          put #load triggers
        GENIE
        lines = [%(Mallory whispers, "learn #{evil}"), 'Mallory whispers, "teach ,go2 666"', 'GO']
        result = run(src, lines: lines, lists: Lich::Genie::Lists.new(config_dir: dir), game_lines: %w[ping pong])
        expect(result[:sends]).to eq([[evil, false], [',go2 666', false]])
        expect(File.binread(File.join(dir, 'triggers.cfg'))).to eq("#trigger {^ping} {#{evil}}\r\n#trigger {^pong} {,go2 666}\r\n")
      end
    end
  end

  # The forms that were Lich commands before the author-text rule and are game text now.
  it 'sends the forms the author-text rule flipped as game text (#put/#send, send %d, gosub args, JS, \\, and a repeated %lastcommand)' do
    src = <<~'GENIE'
      put #if {1} {#put ,go2 1}
      put #put ,go2 2
      put #send ,go2 3
      var d 1
      send %d ,go2 4
      js put(",go2 6")
      put \,go2 7
      put ,go2 8
      put %lastcommand
      gosub g ,go2 5
      exit
      g:
      put $1 $2
      return
    GENIE
    result = run(src, triggers: { '^ping' => '#if {1} {#put ,go2 9}' }, game_lines: ['ping'])
    expect(result[:sends]).to contain_exactly([',go2 1', false], [',go2 2', false], [',go2 3', false], [',go2 4', false],
                                              [',go2 5', false], [',go2 6', false], [',go2 7', false], [',go2 8', true],
                                              [',go2 8', false], [',go2 9', false])
  end

  describe 'the marks are never printable' do
    it 'never shows a mark in an echo, a debug line, a front-end effect or a send, at any debug level' do
      src = <<~GENIE
        put ,go2 1;,e 2
        put ,e 3
        send 1 ,go2 3
        action put ,e 5;send ,e 6 when ^Bob bows
        action if 1 = 1 then put ,e 8 when ^Bob nods
        put ,go2 "unclosed
        waitfor THE_END
      GENIE
      leaks = [1, 2, 3, 4, 5, 10, 15, 20, 30, 40, 50].select do |level|
        result = run(src, debug: level, lines: ['Bob bows', 'Bob nods'], triggers: { '^Bob bows' => ',e 7' }, game_lines: ['Bob bows'])
        (result[:echoes] + result[:prints] + result[:sends].map(&:first)).join("\n").match?(/[\x05\x06]/)
      end
      expect(leaks).to eq([])
    end

    it 'never lets a mark land in a variable' do
      src = <<~GENIE
        put ,go2 1
        put ,e 1
        send ,go2 2
        action put ,e 5 when ^Bob bows
        waitfor THE_END
      GENIE
      globals = run(src, lines: ['Bob bows'])[:globals]
      expect([globals.inspect, globals.local_get('lastcommand').to_s]).to all(satisfy { |text| !text.match?(/[\x05\x06]/) })
    end

    it "shows a queued item without its route's marks (inspect, to_s, pp)" do
      queue = Lich::Genie::CommandQueue.new
      queue.add(1, ',go2 1', route: ",#{mark}go2 1", wait_rt: true)
      item = queue.items.first
      expect([item.inspect, item.to_s, PP.pp(item, +'')]).to all(include('route=",go2 1"'))
      expect(item.release_text).to eq(",#{mark}go2 1")
    end

    it "names an action body's row in an error line without its marks" do
      src = <<~GENIE
        action put ,go2 1;goto nowhere when ^Bob bows
        waitfor THE_END
      GENIE
      result = run(src, debug: 10, lines: ['Bob bows'])
      expect(result[:echoes].join("\n")).to include('nowhere').and(satisfy { |text| !text.match?(/[\x05\x06]/) })
    end

    it 'labels a nesting-cap overflow of an authored #trigger body re-parsing its own line without marks' do
      echoes = []
      lists = Lich::Genie::Lists.new
      lists.triggers.add('^ping', ',go2 1;#parse ping', authored: true)
      runner = nil
      runner = Lich::Genie::TriggerRunner.new(
        vars: Lich::Genie::Variables.new, eval: Lich::Genie::Eval.new, game: Object.new.tap { |g| g.define_singleton_method(:send_command) { |_t| nil } },
        launch: ->(*) {}, lists: lists, echo: ->(text) { echoes << text },
        parse: ->(text) { Lich::Genie::ParseDispatch.fire_triggers(text, triggers: lists.triggers, runner: runner, on_error: ->(e) { raise e }) }
      )
      Lich::Genie::ParseDispatch.fire_triggers('ping', triggers: lists.triggers, runner: runner, on_error: ->(e) { raise e })
      expect(echoes).to eq(['[Script error: maximum nested dispatch depth (20) exceeded on: #parse ping]'])
    end
  end
end
