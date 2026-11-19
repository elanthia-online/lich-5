# frozen_string_literal: true

require_relative 'support/example_timeout'
require 'json'
require_relative '../../../lib/genie'

# Lich::Genie::GameState: the reserved variables Remix's Game.cs keeps from the game stream.
# Goldens come from Remix's own code: genieflow (Remix Game.cs/Globals.cs headless) fed the
# same rows (fixtures below, flow fixtures t86-t88/t92), and its --settings probes.
RSpec.describe Lich::Genie::GameState do
  fixtures = File.expand_path('../../fixtures/genie/game_state', __dir__)
  # genieflow VirtualClock.Epoch as recorded (UTC+13): a fixed offset, never Time.local, so the
  # golden $spellstarttime-style instants and wall-clock fields hold in any spec TZ.
  wall = Time.new(2026, 1, 1, 12, 0, 0, '+13:00')

  let(:write_clock) { Lich::Genie::WriteClock.new }
  let(:state) { described_class.new(clock: -> { wall }, write_clock: write_clock) }

  def feed(*rows)
    rows.each { |row| state.feed("#{row}\r\n") }
  end

  # What a script reads: `[$name]` through the real Substitution over Variables over
  # ReservedState, so undefined names show Remix's prefix fallback too.
  def read(name, game_state: state)
    vars = Lich::Genie::Variables.new(game_state: Lich::Genie::ReservedState.new(game_state: game_state),
                                      global_store: Lich::Genie::GlobalStore.new(write_clock: write_clock))
    Lich::Genie::Substitution.new(variables: vars).expand("[$#{name}]")[1...-1]
  end

  describe 'a DragonRealms session (synthetic capture in real row shapes, 654 rows)' do
    golden = JSON.parse(File.read(File.join(fixtures, 'session_capture_expected.json')))['values']

    it 'leaves every reserved variable where Remix leaves it after the same rows' do
      File.foreach(File.join(fixtures, 'session_capture_rows.txt')) { |row| state.feed(row.chomp + "\r\n") }
      actual = golden.keys.to_h { |name| [name, read(name)] }
      expect(actual).to eq(golden)
    end
  end

  describe 'settings.cfg (Config.Load + SetSetting, Config.cs:531-565, 803-922 R)' do
    it "reads a tester's monstercountignorelist, prompt and roundtimeoffset rows" do
      config = described_class::Config.from_settings(Lich::Genie::SettingsFile.read(File.join(fixtures, 'tester_settings_excerpt.cfg')))
      expect(config.to_h).to eq(prompt: '> ', prompt_force: true, rt_offset: 0.0, separator_char: ';', command_char: '#', script_char: '.',
                                ignore_monster_list: 'appears dead|(dead)|tabby cat|ferret|stone golem|hound|badger|owl|clay soldier|shadow helper',
                                condensed: false, parse_game_only: false, show_links: false, trigger_on_input: true,
                                script_timeout: 5000, max_gosub_depth: 50, ignore_script_warnings: false, abort_dupe_script: true, my_command_char: '/')
    end

    # Config.cs:579-586, 618-636 R: the first char of a non-empty value; an empty one changes
    # nothing (genieflow t138_separatorchar runs ParseCommand and ParseAction on `|`).
    it 'reads separatorchar / commandchar / scriptchar as their first character, skipping empty values' do
      pairs = [%w[separatorchar |x], %w[CommandChar !], %w[scriptchar ,,], ['separatorchar', ''], ['commandchar', '']]
      config = described_class::Config.from_settings(pairs)
      expect([config.separator_char, config.command_char, config.script_char]).to eq(['|', '!', ','])
      expect(described_class::DEFAULT_CONFIG.separator_char).to eq(';')
    end

    # Config.cs:17 R (cMyCommandChar = '/'), 638-645 R (the first char of a non-empty value).
    it 'reads mycommandchar as its first character, default "/", skipping an empty value' do
      expect(described_class::DEFAULT_CONFIG.my_command_char).to eq('/')
      expect(described_class::Config.from_settings([%w[MyCommandChar !x], ['mycommandchar', '']]).my_command_char).to eq('!')
    end

    it 'counts only the monsters no ignore entry is contained in (genieflow --settings probe p1: mc=1)' do
      config = described_class::Config.from_settings(Lich::Genie::SettingsFile.read(File.join(fixtures, 'tester_settings_excerpt.cfg')))
      tester = described_class.new(config: config, write_clock: write_clock)
      tester.feed("<component id='room objs'>You also see <pushBold/>a tabby cat<popBold/>, <pushBold/>a goblin<popBold/> and " \
                  "<pushBold/>a large hound<popBold/> that is sleeping.</component>\r\n")
      expect([tester['monstercount'], tester['monsterlist']]).to eq(['1', 'a goblin'])
    end

    it 'applies the SetSetting rules: on/off words for prompt, empty values skipped, later rows win' do
      pairs = [%w[prompt off], %w[promptforce no], %w[monstercountignorelist ghost], ['monstercountignorelist', ''],
               %w[roundtimeoffset 2], ['roundtimeoffset', ''], %w[PROMPT TRUE]]
      expect(described_class::Config.from_settings(pairs).to_h)
        .to eq(prompt: '> ', prompt_force: false, ignore_monster_list: 'ghost', rt_offset: 2.0, separator_char: ';', command_char: '#',
               script_char: '.', condensed: false, parse_game_only: false, show_links: false, trigger_on_input: true,
               script_timeout: 5000, max_gosub_depth: 50, ignore_script_warnings: false, abort_dupe_script: true, my_command_char: '/')
      expect(described_class::Config.from_settings([%w[prompt >>]]).prompt).to eq('>>')
    end

    # The script engine's keys: Config.cs:743-750 (scripttimeout =
    # Conversions.ToInteger(Utility.StringToDouble(v))), 905-912 (maxgosubdepth =
    # Conversions.ToInteger(v)), 995-1013 / 1113-1131 (on/true/1, else False) R; an empty value is
    # skipped and a value VB cannot convert leaves the old one (Config.Load's per-row catch).
    it 'reads scripttimeout, maxgosubdepth, ignorescriptwarnings and abortdupescript' do
      config = described_class::Config.from_settings([%w[ScriptTimeout 2500.5], %w[maxgosubdepth 7], %w[IgnoreScriptWarnings ON],
                                                      %w[abortdupescript False]])
      expect(config.to_h.values_at(:script_timeout, :max_gosub_depth, :ignore_script_warnings, :abort_dupe_script))
        .to eq([2500, 7, true, false])
      expect(described_class::Config.from_settings([%w[scripttimeout 2501.5]]).script_timeout).to eq(2502) # banker's rounding
      expect(described_class::Config.from_settings([%w[scripttimeout abc]]).script_timeout).to eq(-1) # StringToDouble's -1
      kept = described_class::Config.from_settings([%w[maxgosubdepth 9], %w[maxgosubdepth x], ['maxgosubdepth', ''],
                                                    %w[scripttimeout 1e12]])
      expect([kept.max_gosub_depth, kept.script_timeout]).to eq([9, 5000])
      expect(described_class::Config.from_settings([%w[maxgosubdepth &H10]]).max_gosub_depth).to eq(16)
      expect(described_class::Config.from_settings([%w[ignorescriptwarnings yes], %w[abortdupescript 1]]).to_h
               .values_at(:ignore_script_warnings, :abort_dupe_script)).to eq([false, true])
    end

    it 'counts nothing when the ignore list has an empty entry (String.Contains(""))' do
      empty_entry = described_class.new(config: described_class::DEFAULT_CONFIG.dup.tap { |c| c.ignore_monster_list = 'dead|' })
      empty_entry.feed("<component id='room objs'>You also see <pushBold/>a goblin<popBold/>.</component>\r\n")
      expect([empty_entry['monstercount'], empty_entry['monsterlist']]).to eq(['0', ''])
    end
  end

  describe '<prompt> (Game.cs:2236-2416 R)' do
    it 'snapshots $roundtime from <roundTime> - prompt time, plus the offset rounded half-to-even' do
      offset = described_class.new(config: described_class::DEFAULT_CONFIG.dup.tap { |c| c.rt_offset = 1.5 })
      offset.feed("<roundTime value='1700000003'/>\r\n")
      offset.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
      expect([offset['roundtime'], offset['prompt']]).to eq(['5', 'R> ']) # 3 + ToInt32(1.5) = 3 + 2
      offset.feed(%(<prompt time="1700000001">&gt;</prompt>\r\n)) # m_iRoundTime was reset to 0
      expect(offset['roundtime']).to eq('0')
    end

    # A roundtimeoffset .NET cannot take (0 corpus rows). Script.SetRoundTime / FormMain's
    # RoundTimeEnd = DateTime.Now.AddMilliseconds(rt * 1000 + offset * 1000) (Script.cs:1007,
    # FormMain.cs:6953 R): past MaxMillis it throws, Game_EventRoundtime's catch shows a dialog
    # (FormMain.cs:6739-6742 R) and no end changes; NaN is 0 ticks (the end = now). Then
    # Convert.ToInt32(offset) (Game.cs:2376 R) throws for NaN / infinite / beyond Int32 and the row
    # ends there: $roundtime is not written. On two wall clocks (the GameState clock is a Time,
    # Remix's DateTime.Now) in different fixed offsets, so no result depends on the spec's TZ.
    describe 'a roundtimeoffset .NET rejects' do
      def prompt_events(offset, clock)
        state = described_class.new(config: described_class::DEFAULT_CONFIG.dup.tap { |c| c.rt_offset = offset }, clock: clock)
        events = []
        state.listener = ->(batch) { events.concat(batch.events.grep(Lich::Genie::GameEvents::RoundTime)) if batch.is_a?(described_class::Row) }
        state.feed(%(<prompt time="1699999999">&gt;</prompt>\r\n))
        state.feed("<roundTime value='1700000003'/>\r\n")
        expect { state.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n)) }.not_to raise_error
        [events.map(&:seconds), state['roundtime'], state['gametime'], state.roundtime?(clock.call + 1)]
      end

      [-> { Time.new(2026, 1, 1, 12, 0, 0, '-05:00') }, -> { Time.new(2026, 1, 1, 12, 0, 0, '+13:00') }].each_with_index do |clock, n|
        it "drops the roundtime of an infinite or huge offset and ends the row (clock #{n})" do
          [Float::INFINITY, -Float::INFINITY, 1e300, 4e11, -3e11].each do |offset|
            expect(prompt_events(offset, clock)).to eq([[], '0', '1700000000', false])
          end
        end

        it "raises a NaN offset's roundtime as 0 s (the end = now) and ends the row (clock #{n})" do
          expect(prompt_events(Float::NAN, clock)).to eq([[0.0], '0', '1700000000', false])
        end

        it "keeps an offset past Int32 for the end but ends the row at Convert.ToInt32 (clock #{n})" do
          expect(prompt_events(3e9, clock)).to eq([[3_000_000_003.0], '0', '1700000000', true])
          # in range: rt += Convert.ToInt32(offset) is unchecked Int32 arithmetic (wraps)
          expect(prompt_events(2_147_483_647.4, clock).values_at(1, 3)).to eq(['-2147483646', true])
        end
      end
    end

    # v0.26.2: the AddMilliseconds year bound is checked on the INJECTED clock (Remix's one
    # DateTime.Now), not a Time.now of the engine's own: 3 s of roundtime 2 s before year 10000
    # (wall year, in the clock's own offset) is un-representable, so no end and no event; the
    # same roundtime a minute earlier is kept. $roundtime is still written (the offset is valid).
    it 'checks the roundtime end against the injected clock, in its own offset (year 9999 bound)' do
      ['+00:00', '+13:00', '-09:30'].each do |zone|
        late = Time.new(9999, 12, 31, 23, 59, 58, zone)
        [[late, [], false], [late - 60, [3.0], true]].each do |now, rt_events, in_rt|
          state = described_class.new(clock: -> { now })
          events = []
          state.listener = ->(batch) { events.concat(batch.events.grep(Lich::Genie::GameEvents::RoundTime)) if batch.is_a?(described_class::Row) }
          state.feed(%(<prompt time="1699999999">&gt;</prompt>\r\n))
          state.feed("<roundTime value='1700000003'/>\r\n")
          state.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
          expect([zone, events.map(&:seconds), state['roundtime'], state.roundtime?(now + 1)]).to eq([zone, rt_events, '3', in_rt])
        end
      end
    end

    # FormMain.SetRoundTime / HasRoundTime (FormMain.cs:6918-6954 R): RoundTimeEnd = the clock
    # at the prompt + rt + the DOUBLE offset; never cleared, so it just lies in the past later.
    # The CommandQueue's RT gate (flow t131_queue_rt_trigger).
    describe '#roundtime? (Globals.RoundTimeEnd)' do
      let(:now) { [wall] }
      let(:timed) do
        described_class.new(config: described_class::DEFAULT_CONFIG.dup.tap { |c| c.rt_offset = 0.5 }, clock: -> { now[0] })
      end

      it 'is false before any roundtime and for a prompt without one' do
        expect(timed.roundtime?).to be(false)
        timed.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
        expect(timed.roundtime?).to be(false)
      end

      it 'holds from the prompt for rt + offset seconds (the boundary itself is not in roundtime)' do
        timed.feed("<roundTime value='1700000003'/>\r\n")
        expect(timed.roundtime?).to be(false) # the <roundTime> alone sets nothing: the prompt does
        timed.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
        expect(timed.roundtime?(wall + 3.49)).to be(true)
        expect(timed.roundtime?(wall + 3.5)).to be(false)
        now[0] = wall + 3.4
        expect(timed.roundtime?).to be(true) # default: this capture's own clock
      end

      it 'keeps the last end when a later prompt has none (a stale end is simply in the past)' do
        timed.feed("<roundTime value='1700000002'/>\r\n")
        timed.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
        now[0] = wall + 1
        timed.feed(%(<prompt time="1700000001">&gt;</prompt>\r\n))
        expect(timed.roundtime?(wall + 2.4)).to be(true)
        expect(timed.roundtime?(wall + 10)).to be(false)
      end
    end

    it 'keeps a stale <roundTime> until a prompt makes it positive (m_iRoundTime reset only then)' do
      feed("<roundTime value='1700000002'/>", %(<prompt time="1700000005">&gt;</prompt>), %(<prompt time="1700000001">&gt;</prompt>))
      expect(state['roundtime']).to eq('1')
    end

    it 'sets nothing for a prompt whose time is not an Int32' do
      feed(%(<prompt time="soon">&gt;</prompt>), %(<prompt>&gt;</prompt>), %(<prompt time="2147483648">&gt;</prompt>))
      %w[prompt gametime unixtime roundtime].each { |name| expect(state[name]).to be_nil, name }
    end

    it 'stamps $unixtime with the wall clock at each prompt' do
      clock = [wall]
      ticking = described_class.new(clock: -> { clock.first })
      ticking.feed(%(<prompt time="1">&gt;</prompt>\r\n))
      clock[0] = wall + 7
      expect(ticking['unixtime']).to eq(wall.to_i.to_s)
      ticking.feed(%(<prompt time="2">&gt;</prompt>\r\n))
      expect(ticking['unixtime']).to eq((wall.to_i + 7).to_s)
    end

    it 'appends the letters in Remix order, then moves the ">" to the end as "> "' do
      feed(*%w[KNEELING SITTING PRONE STUNNED HIDDEN INVISIBLE WEBBED BLEEDING JOINED STANDING].map { |id| "<indicator id='Icon#{id}' visible='y'/>" })
      feed(%(<prompt time="1">&gt;</prompt>))
      expect(state['prompt']).to eq('KsPSHIW!J> ')
    end

    it 'shows DEAD instead of the letters while dead' do
      feed("<indicator id='IconDEAD' visible='y'/>", "<indicator id='IconHIDDEN' visible='y'/>", %(<prompt time="1">&gt;</prompt>))
      expect(state['prompt']).to eq('DEAD> ')
    end

    it 'adds no letters without promptforce, and no rewrite with an empty prompt setting' do
      plain = described_class.new(config: described_class::DEFAULT_CONFIG.dup.tap { |c| c.prompt_force = false })
      plain.feed("<indicator id='IconHIDDEN' visible='y'/>\r\n<roundTime value='9'/>\r\n")
      plain.feed(%(<prompt time="1">&gt;</prompt>\r\n))
      expect(plain['prompt']).to eq('> ')
      bare = described_class.new(config: described_class::DEFAULT_CONFIG.dup.tap { |c| c.prompt = '' })
      bare.feed("<indicator id='IconHIDDEN' visible='y'/>\r\n")
      bare.feed(%(<prompt time="1">&gt;</prompt>\r\n))
      expect(bare['prompt']).to eq('>H')
    end

    it 'with a blank prompt setting throws in String.Replace: roundtime set, prompt not (genieflow probe s2.cfg)' do
      blank = described_class.new(config: described_class::DEFAULT_CONFIG.dup.tap { |c| c.prompt = ' ' })
      blank.feed("<roundTime value='4'/>\r\n")
      blank.feed(%(<prompt time="1">&gt;</prompt><indicator id='IconHIDDEN' visible='y'/>\r\n))
      expect([blank['roundtime'], blank['prompt'], blank['hidden']]).to eq(['3', nil, nil]) # rest of the row lost
    end

    it 'switches to the status prompt for good on a non-">" prompt, then only applies the J/! fix' do
      feed("<indicator id='IconJOINED' visible='y'/>", "<indicator id='IconBLEEDING' visible='y'/>", "<indicator id='IconHIDDEN' visible='y'/>")
      feed(%(<prompt time="1">J&gt;</prompt>))
      expect([state['prompt'], state['joined'], state['bleeding']]).to eq(['J> ', '1', '0'])
      # (main text in between: a prompt right after a prompt keeps its raw text, Game.cs:2397 R)
      feed('You wait.', "<roundTime value='9'/>", %(<prompt time="2">&gt;</prompt>))
      expect([state['prompt'], state['joined'], state['roundtime']]).to eq(['> ', '0', '7']) # no letters, no R
    end

    it 'turns the status prompt off again after "set !statusprompt" is sent' do
      feed(%(<prompt time="1">H&gt;</prompt>), "<indicator id='IconHIDDEN' visible='y'/>")
      state.sent('SET !StatusPrompt')
      feed(%(<prompt time="2">&gt;</prompt>))
      expect(state['prompt']).to eq('H> ')
    end
  end

  describe 'the spell timer (Game.cs:1914-1938, 2199-2234 R; FormMain.cs:6697-6707 R)' do
    it 'starts on a non-None <spell>, stamps $spellstarttime with local Unix time, clears on None' do
      feed("<spell exist='spell'>Dragon's Breath</spell><castTime value='1767222006'/>")
      expect([state.spell_time_start, state['spellstarttime'], state['preparedspell'], state['casttime']])
        .to eq([wall, wall.to_i.to_s, "Dragon's Breath", '1767222006'])
      feed('<spell>None</spell>')
      expect([state.spell_time_start, state['spellstarttime'], state['preparedspell']]).to eq([nil, wall.to_i.to_s, 'None'])
    end

    it 'reads ScriptNumber as Unknown' do
      feed('<spell>ScriptNumber</spell>')
      expect(state['preparedspell']).to eq('Unknown')
    end

    it 'takes <spelltime value> as $spellstarttime only while a spell is prepared' do
      feed("<spelltime value='42'/>")
      expect(state['spellstarttime']).to eq('0')
      feed('<spell>Shadows</spell>', "<spelltime value='42'/>")
      expect(state['spellstarttime']).to eq('42')
    end
  end

  describe 'element handling' do
    it 'skips the children of an unknown component (m_bIgnoreXMLDepth) but not of a known one' do
      feed("<component id='exp Athletics'><progressBar id='health' value='5' text='x'/></component>")
      expect(state['health']).to be_nil
      feed("<component id='room exits'>Obvious paths: <d>north</d>.<compass></compass></component>")
      expect([state['roomexits'], state['north']]).to eq(['Obvious paths: north.', '0']) # nested <compass> reset
    end

    it 'ignores a <dir> outside a <compass> and an unknown direction' do
      feed('<dir value="n"/>', '<compass><dir value="nnw"/><dir value="out"/></compass>')
      expect([state['north'], state['out']]).to eq(%w[0 1])
    end

    it 'abandons the rest of a row when int.Parse throws, keeping what came before' do
      feed("<progressBar id='mana' value='50' text='mana 50%'/><progressBar id='health' value='lots'/><progressBar id='spirit' value='7'/>")
      expect([state['mana'], state['manaBarText'], state['health'], state['spirit']]).to eq(['50', 'Mana 50%', nil, nil])
    end

    it 'drops a whole buffer XmlDocument rejects' do
      feed("<component id='room objs'>You also see a box.</component>", "<component id='room objs'>a ghost&nbsp;light</component>")
      expect(state['roomobjs']).to eq('You also see a box.')
    end

    it 'records $lastcommand for every send and $lastinput only for typed input -- in the GLOBALS' do
      store = Lich::Genie::GlobalStore.new(write_clock: write_clock)
      typed = described_class.new(clock: -> { wall }, write_clock: write_clock, globals: store)
      typed.sent('look')
      typed.sent('wave', user_input: true)
      typed.sent('#var x 1')
      expect([typed['lastcommand'], typed['lastinput'], store.get('lastinput')]).to eq(['#var x 1', nil, 'wave'])
    end

    # VariableList["lastinput"] = sText is the indexer (Game.cs:529 R): a NEW key is
    # SaveToFile (Globals.cs:665-690 R) -- listed, saved and cleared like a #var -- and an existing one
    # keeps its type; lastinput is not in SetDefaultGlobalVars' reserved list (Globals.cs:825-919 R).
    it 'makes $lastinput a SaveToFile global unless it exists, keeping an existing type' do
      store = Lich::Genie::GlobalStore.new(write_clock: write_clock)
      typed = described_class.new(write_clock: write_clock, globals: store)
      typed.sent('north', user_input: true)
      expect([store.get('lastinput'), store.kind('lastinput'), store.persistent?('lastinput')]).to eq(['north', :save, true])
      store.set('lastinput', 'x', persist: false) # #tvar lastinput x
      typed.sent('south', user_input: true)
      expect([store.get('lastinput'), store.kind('lastinput')]).to eq(['south', :temporary])
      expect(typed.names).not_to include('lastinput')
    end

    # Game.SendText runs PrintInputText -- the echo AddText and the $lastinput set --
    # only when no gag hid the "[origin]: text" echo (if (bHideOutput == false), Game.cs:515-543 R).
    it 'keeps the prompt flag and sets no $lastinput for a send whose echo a gag hid' do
      store = Lich::Genie::GlobalStore.new(write_clock: write_clock)
      typed = described_class.new(write_clock: write_clock, globals: store)
      typed.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
      typed.sent('look', echoed: false)
      expect([typed.last_row_was_prompt, typed['lastcommand']]).to eq([true, 'look'])
      typed.sent('wave', user_input: true, echoed: false)
      expect(store.get('lastinput')).to be_nil
      typed.sent('look')
      expect(typed.last_row_was_prompt).to be(false)
    end

    # Game.SendText's cMyCommandChar gate (Game.cs:527, 545 R; genieflow flow case t266_mycommandchar):
    # a text starting with it is echoed (PrintInputText, Game.cs:541 R -- the prompt flag clears) but
    # never reaches the socket, so neither $lastcommand nor (typed) $lastinput changes and no variable
    # change is raised. StartsWith on the raw text: a leading space is a game command.
    it 'echoes a mycommandchar text without $lastcommand / $lastinput or any variable change' do
      store = Lich::Genie::GlobalStore.new(write_clock: write_clock)
      changes = []
      typed = described_class.new(write_clock: write_clock, globals: store, listener: ->(names) { changes.concat(names) })
      typed.sent('look')
      typed.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
      changes.clear
      typed.sent('/sort name')
      typed.sent('/spelltimer', user_input: true)
      expect([typed['lastcommand'], store.get('lastinput'), changes, typed.last_row_was_prompt]).to eq(['look', nil, [], false])
      expect([typed.my_command?('/x'), typed.my_command?(' /x'), typed.my_command?(''), typed.my_command?('x/')]).to eq([true, false, false, false])
      typed.sent(' /track clear', user_input: true)
      expect([typed['lastcommand'], store.get('lastinput')]).to eq([' /track clear', ' /track clear'])
    end

    it 'follows a runtime #config mycommandchar: the old char is a game command again' do
      typed = described_class.new(write_clock: write_clock)
      typed.apply_setting('mycommandchar', '!')
      typed.sent('!x')
      expect(typed['lastcommand']).to be_nil
      typed.sent('/sort')
      expect(typed['lastcommand']).to eq('/sort')
    end

    it 'stamps every write from the write clock, later writes higher' do
      feed("<indicator id='IconHIDDEN' visible='y'/>")
      first = state.stamp('hidden')
      feed("<indicator id='IconHIDDEN' visible='n'/>")
      expect(state.stamp('hidden')).to be > first
      expect(state.stamp('invisible')).to be_nil
    end

    # genieflow over the edge1 probe (Remix Game.cs:1825-1830, 2766-2783 R):
    # health stays 90 and every compass dir 0 at MARK2-4.
    it 'keeps an empty unknown component\'s skip-children flag for the next node with children, across rows' do
      feed("<dialogData id='minivitals'><progressBar id='health' value='90' text='health 90%'/></dialogData>")
      feed("<component id='room extra'></component>", # empty: the flag outlives it and the row
           "<dialogData id='minivitals'><progressBar id='health' value='50' text='health 50%'/></dialogData>")
      expect([state['health'], state['healthBarText']]).to eq(['90', 'Health 90%'])
      feed("<component id='exp Athletics'></component>", "<compass><dir value=\"n\"/><dir value=\"s\"/></compass>")
      feed("<component id='exp Athletics'/><compass><dir value=\"e\"/></compass>") # same buffer
      expect(%w[north south east].map { |dir| state[dir] }).to eq(%w[0 0 0])
      # Cleared by the skipped node: the next compass is read in full.
      feed('<compass><dir value="w"/></compass>')
      expect(state['west']).to eq('1')
    end

    it 'lets any buffer clear a pending flag, even one naming no element the capture reads' do
      feed("<component id='exp Athletics'></component>", 'Obvious paths: <d>north</d>.', '<compass><dir value="n"/></compass>')
      expect(state['north']).to eq('1')
    end

    it 'skips the children of an unknown component that has them, and only those' do
      feed("<component id='exp X'><progressBar id='health' value='10' text='h'/></component><progressBar id='mana' value='20' text='m'/>")
      expect([state['health'], state['mana']]).to eq([nil, '20'])
    end
  end

  # The glue's start-up replay (GameStateFeed#install).
  describe '#seed' do
    let(:room_a) { %(<streamWindow id='room' subtitle=" - [Room A] (1)"/>\r\n) }
    let(:room_b) { %(<streamWindow id='room' subtitle=" - [Room B] (2)"/>\r\n) }

    it 'replays the snapshot in order' do
      state.seed { ["<indicator id='IconHIDDEN' visible='y'/>\r\n", "<indicator id='IconHIDDEN' visible='n'/>\r\n"] }
      expect(state['hidden']).to eq('0')
    end

    it 'lands a live row parsed during the snapshot after the replay, not under it' do
      live = nil
      state.seed do
        live = Thread.new { state.feed(room_b) } # Lich's parser thread: a row after the snapshot
        Thread.pass until live.status == 'sleep' || !live.alive? # waiting on the capture's lock
        [room_a]
      end
      live.join
      expect([state['roomname'], state['uid']]).to eq(['Room B', '2'])
    end

    it 'applies the snapshot row still on its way to the live feed once (String#equal?)' do
      rt = "<roundTime value='110'/>\r\n"
      prompt = %(<prompt time="100">&gt;</prompt>\r\n)
      state.seed { [rt, prompt] }
      expect(state['roundtime']).to eq('10')
      state.feed(prompt) # the same String Lich pushed into its buffer: already applied
      expect(state['roundtime']).to eq('10')
      state.feed(prompt.dup) # an equal but new row is a new row (the prompt zeroed the RT)
      expect(state['roundtime']).to eq('0')
    end

    it 'skips the in-flight row by identity even when an earlier snapshot row has the same text' do
      prompt = %(<prompt time="100">&gt;</prompt>\r\n)
      last = prompt.dup
      state.seed { [prompt, "<roundTime value='110'/>\r\n", last] }
      state.feed(last)
      expect(state['roundtime']).to eq('10')
    end

    it 'applies a first live row that only equals a snapshot row (a new String is a new row)' do
      rt = "<roundTime value='110'/>\r\n"
      prompt = %(<prompt time="100">&gt;</prompt>\r\n)
      state.seed { [rt, prompt] }
      state.feed(prompt.dup)
      expect(state['roundtime']).to eq('0')
    end

    it 'forgets the snapshot at the first live row (only the last row can be in flight)' do
      hidden = "<indicator id='IconHIDDEN' visible='y'/>\r\n"
      state.seed { [hidden] }
      feed("<indicator id='IconHIDDEN' visible='n'/>")
      state.feed(hidden)
      expect(state['hidden']).to eq('1')
    end

    it 'ignores non-String entries and a nil snapshot' do
      state.seed { [nil, 5, "<indicator id='IconDEAD' visible='y'/>\r\n"] }
      expect(state['dead']).to eq('1')
      expect { described_class.new.seed { nil } }.not_to raise_error
    end
  end

  # Lich::Genie's two load/launch switches read the live config at each use, so
  # settings.cfg and a later runtime `#config` both reach the next load/launch.
  describe 'Lich::Genie.ignore_script_warnings? / .abort_dupe_script?' do
    it 'follow the live game_state config, including a runtime #config' do
      live = described_class.new(config: described_class::Config.from_settings([%w[ignorescriptwarnings True], %w[abortdupescript off]]))
      allow(Lich::Genie).to receive(:game_state).and_return(live)
      expect([Lich::Genie.ignore_script_warnings?, Lich::Genie.abort_dupe_script?]).to eq([true, false])
      live.apply_setting('ignorescriptwarnings', 'no')
      live.apply_setting('abortdupescript', '1')
      expect([Lich::Genie.ignore_script_warnings?, Lich::Genie.abort_dupe_script?]).to eq([false, true])
    end

    it 'default to Remix\'s False / True with no settings rows' do
      allow(Lich::Genie).to receive(:game_state).and_return(described_class.new)
      expect([Lich::Genie.ignore_script_warnings?, Lich::Genie.abort_dupe_script?]).to eq([false, true])
    end
  end

  describe '#apply_setting (a runtime #config, Config.cs:895-922 R)' do
    let(:objs) { "<component id='room objs'>You also see <pushBold/>a goblin<popBold/> and <pushBold/>a shadowling<popBold/>.</component>" }

    it 'changes the live config at once for the keys the capture reads, from the current config' do
      feed(objs)
      expect(state['monstercount']).to eq('2')
      state.apply_setting('MonsterCountIgnoreList', 'appears dead|shadowling')
      state.apply_setting('roundtimeoffset', '1.6')
      state.apply_setting('scripttimeout', '50000') # the engine's own key
      state.apply_setting('autolog', 'off') # not ours: no change
      feed(objs)
      expect([state['monstercount'], state['monsterlist']]).to eq(['1', 'a goblin'])
      expect(state.config.to_h).to eq(prompt: '> ', prompt_force: true, ignore_monster_list: 'appears dead|shadowling', rt_offset: 1.6,
                                      separator_char: ';', command_char: '#', script_char: '.', condensed: false,
                                      parse_game_only: false, show_links: false, trigger_on_input: true,
                                      script_timeout: 50_000, max_gosub_depth: 50, ignore_script_warnings: false, abort_dupe_script: true, my_command_char: '/')
      expect(described_class::DEFAULT_CONFIG.ignore_monster_list).to eq('appears dead|(dead)')
    end

    it 'keeps the list on an empty value (SetSetting skips it) and rounds the offset into $roundtime' do
      state.apply_setting('monstercountignorelist', '')
      state.apply_setting('roundtimeoffset', '1.6')
      feed("<roundTime value='110'/>", %(<prompt time="100">&gt;</prompt>))
      expect([state.config.ignore_monster_list, state['roundtime']]).to eq(['appears dead|(dead)', '12'])
    end
  end

  describe '#host_stamp (the Remix writer a host value stands for)' do
    def room_update
      feed(%(<streamWindow id='room' subtitle=" - [Room] (1)"/>), %(<prompt time="1">&gt;</prompt>))
    end

    it 'stamps $game at the capture start, after a store built before it' do
      store = Lich::Genie::GlobalStore.new(write_clock: write_clock)
      store.set('game', 'DR')
      later = described_class.new(write_clock: write_clock)
      expect(later.host_stamp('game', :connect)).to be > store.stamp('game')
      expect(later.host_stamp('game', :connect)).to eq(later.host_stamp('game', :connect))
    end

    it 'moves the :room stamp at the first prompt after a room title only (AutoMapper.cs:269-278 R)' do
      start = state.host_stamp('roomid', :room)
      feed(%(<prompt time="1">&gt;</prompt>))
      expect(state.host_stamp('roomid', :room)).to eq(start)
      feed(%(<streamWindow id='room' subtitle=" - [Room] (1)"/>))
      expect(state.host_stamp('roomid', :room)).to eq(start)
      feed(%(<prompt time="2">&gt;</prompt>))
      updated = state.host_stamp('roomid', :room)
      expect(updated).to be > start
      feed(%(<prompt time="3">&gt;</prompt>))
      expect(state.host_stamp('roomid', :room)).to eq(updated)
    end

    it 'moves a :zone stamp only when the reading changes, to the room update that saw it' do
      first = state.host_stamp('zoneid', :zone, '1')
      room_update
      expect(state.host_stamp('zoneid', :zone, '1')).to eq(first)
      changed = state.host_stamp('zoneid', :zone, '7')
      expect(changed).to be > first
      expect(changed).to eq(state.host_stamp('roomid', :room))
      expect(state.host_stamp('zonename', :zone, 'Crossing')).to eq(changed) # its own reading
    end

    it 'gives a :zone reading first seen between a room title and its prompt the stamp of that room update' do
      first = state.host_stamp('zoneid', :zone, '1')
      feed(%(<streamWindow id='room' subtitle=" - [Room] (1)"/>))
      expect(state.host_stamp('zoneid', :zone, '7')).to eq(first) # pending: not written yet
      expect(state.host_stamp('zoneid', :zone, '8')).to eq(first) # a later reading replaces it
      feed(%(<prompt time="2">&gt;</prompt>))
      updated = state.host_stamp('roomid', :room)
      expect(updated).to be > first
      expect(state.host_stamp('zoneid', :zone, '8')).to eq(updated)
      room_update
      expect(state.host_stamp('zoneid', :zone, '8')).to eq(updated)
    end

    it 'forgets a pending :zone reading that reverts to the written one before the prompt' do
      first = state.host_stamp('zoneid', :zone, '1')
      feed(%(<streamWindow id='room' subtitle=" - [Room] (1)"/>))
      state.host_stamp('zoneid', :zone, '7')
      expect(state.host_stamp('zoneid', :zone, '1')).to eq(first)
      feed(%(<prompt time="2">&gt;</prompt>))
      expect(state.host_stamp('zoneid', :zone, '1')).to eq(first)
    end

    it 'has no stamp for an unknown policy' do
      expect(state.host_stamp('x', :nope)).to be_nil
    end
  end

  describe 'the plugin hand-off (ParsePluginText / EventParseXML)' do
    let(:calls) { [] }
    let(:timer) do
      log = calls
      Object.new.tap do |o|
        o.define_singleton_method(:parse_text) { |text, window| log << [:text, text, window] }
        o.define_singleton_method(:parse_xml) { |xml| log << [:xml, xml] }
      end
    end
    let(:state) { described_class.new(write_clock: write_clock, spell_timer: timer) }

    it 'hands each row of an open percWindow stream to the percwindow, CRLF included' do
      feed('<clearStream id="percWindow"/>', '<pushStream id="percWindow"/>Ignite  (11 roisaen)', 'Tailwind  (30 roisaen)',
           '<popStream/><prompt time="1">&gt;</prompt>')
      texts = calls.select { |c| c.first == :text }
      expect(texts).to eq([[:text, "Ignite  (11 roisaen)\r\n", 'percwindow'], [:text, "Tailwind  (30 roisaen)\r\n", 'percwindow']])
      expect(calls.first).to eq([:xml, '<clearStream id="percWindow"/>'])
    end

    it 'flushes text to the stream that was open when a mid-row stream tag changes the target' do
      feed('<pushStream id="percWindow"/>Ignite  (1 roisaen)<popStream/>after')
      expect(calls.select { |c| c.first == :text }).to eq([[:text, 'Ignite  (1 roisaen)', 'percwindow'], [:text, "after\r\n", 'main']])
    end

    it 'names an unknown stream by its lower-cased id' do
      feed('<pushStream id="moonWindow"/>Xibar<popStream/>')
      expect(calls.select { |c| c.first == :text }.first).to eq([:text, 'Xibar', 'moonwindow'])
    end

    it 'disables a plugin that throws, for the rest of the session' do
      bomb = Object.new
      bomb.define_singleton_method(:parse_xml) { |_| raise ArgumentError, 'boom' }
      broken = described_class.new(spell_timer: bomb)
      broken.feed("<indicator id='IconHIDDEN' visible='y'/>\r\n")
      expect(broken['hidden']).to eq('1') # the row itself still parsed
      expect { broken.feed("x\r\n") }.not_to raise_error
    end
  end

  # The VariableChanged names Game.cs raises, as the listener gets them. Goldens:
  # genieflow --verbose (Remix's own Game.cs, src=game var events) over the same rows
  # (fixtures *_events.json).
  describe 'variable changes (Game.cs VariableChanged R)' do
    # genieflow loads no AutoMapper plugin, so its goldens never hold the automapper's "$roomid"
    # (asserted separately below); every other name is Game.cs's.
    events_for = lambda do |rows_file|
      names = []
      listening = described_class.new(clock: -> { wall }, listener: ->(batch) { names.concat(batch) })
      File.foreach(File.join(fixtures, rows_file)) { |row| listening.feed(row.chomp + "\r\n") }
      names
    end

    it 'raises exactly Remix\'s names, in Remix\'s order, over the session capture (815 changes)' do
      golden = JSON.parse(File.read(File.join(fixtures, 'session_capture_events.json')))['events']
      expect(golden.length).to eq(815)
      expect(events_for.call('session_capture_rows.txt') - ['$roomid']).to eq(golden)
    end

    it 'covers every element kind: app, hands, spell, castTime, spelltime, bars, indicators, the J/! fix, prompt, compass, room' do
      golden = JSON.parse(File.read(File.join(fixtures, 'variable_change_events.json')))['events']
      expect(events_for.call('variable_change_rows.txt') - ['$roomid']).to eq(golden)
    end

    # The automapper's SetRoomVariables (AutoMapper.cs:851-888, 2003-2009 R), reached from
    # TriggerVariableChanged("$prompt") -> SafeParsePluginVariable (FormMain.cs:5045-5050 R) ->
    # AutoMapper.VariableChanged("prompt") with m_RoomUpdated (AutoMapper.cs:269-278 R).
    it 'raises "$roomid" right after "$prompt" on every prompt that ends a room update, and only then' do
      names = events_for.call('session_capture_rows.txt')
      roomids = names.each_index.select { |i| names[i] == '$roomid' }
      expect(roomids).not_to be_empty
      expect(roomids.map { |i| names[i - 1] }.uniq).to eq(['$prompt'])
      # one per room title (each title is followed by a prompt in the capture)
      expect(roomids.length).to eq(names.count('$roomname'))
    end

    it 'raises "$roomid" again for the same room (a look), and not on a prompt without a title' do
      batches = []
      mapper = described_class.new(clock: -> { wall }, listener: ->(batch) { batches << batch })
      title = "<streamWindow id='room' title='Room' subtitle=\" - [Crossing, Hodierna Way]\"/>\r\n"
      prompt = "<prompt time=\"1700000000\">&gt;</prompt>\r\n"
      [title, prompt, prompt, title, prompt].each { |row| mapper.feed(row) }
      expect(batches).to eq([%w[$roomname $uid], %w[$gametime $unixtime $roundtime $prompt $roomid],
                             %w[$gametime $unixtime $roundtime $prompt], %w[$roomname $uid],
                             %w[$gametime $unixtime $roundtime $prompt $roomid]])
    end

    it 'hands the listener one batch per row and per send, never an empty one (a text-only row: no change, one text event)' do
      batches = []
      batcher = described_class.new(clock: -> { wall }, listener: ->(batch) { batches << batch })
      batcher.feed("<progressBar id='health' value='42'/><progressBar id='mana' value='7'/>\r\n")
      batcher.feed("plain text\r\n")
      batcher.feed("<progressBar id='health' value='42'/>\r\n")
      batcher.sent('north', user_input: true)
      expect(batches).to eq([%w[$health $mana], [], %w[$health], %w[lastinput lastcommand]])
      expect(batches[1].events.map(&:text)).to eq(['plain text'])
      expect(batches[2].events).to eq([])
    end

    it 'calls the listener after the row, outside the lock: it can read the state (no deadlock)' do
      seen = []
      reader = described_class.new(clock: -> { wall }, write_clock: write_clock)
      reader.listener = ->(batch) { batch.each { |name| seen << [name, reader['health'], reader['healthBarText']] } }
      reader.feed("<progressBar id='health' value='42' text='health 42%'/>\r\n")
      expect(seen).to eq([['$health', '42', 'Health 42%']])
    end

    it 'hands the listener the values of the WHOLE row (Remix: mid-row; tracked timing divergence)' do
      seen = []
      reader = described_class.new(clock: -> { wall }, write_clock: write_clock)
      reader.listener = ->(batch) { batch.each { |name| seen << [name, reader['roomobjs']] if name == '$monstercount' } }
      reader.feed("<component id='room objs'>You also see <pushBold/>a goblin<popBold/>.</component>\r\n")
      expect(seen).to eq([['$monstercount', 'You also see a goblin.']])
    end

    it 'raises "lastinput" (typed only) then "lastcommand" for a send, without "$" (Game.cs:529-551 R)' do
      names = []
      sender = described_class.new(listener: ->(batch) { names.concat(batch) })
      sender.sent('look')
      sender.sent('north', user_input: true)
      expect(names).to eq(%w[lastcommand lastinput lastcommand])
    end

    it 'raises nothing for a replayed snapshot, and nothing for a row the replay already applied' do
      names = []
      seeded = described_class.new(listener: ->(batch) { names.concat(batch) })
      row = "<progressBar id='health' value='42' text='health 42%'/>\r\n"
      seeded.seed { [row] }
      seeded.feed(row) # the in-flight row: skipped by identity
      expect(names).to eq([])
      seeded.feed(row.dup)
      expect(names).to eq(['$health'])
    end

    it 'keeps the changes made before a .NET throw in the row (they were raised in Remix)' do
      names = []
      broken = described_class.new(listener: ->(batch) { names.concat(batch) })
      broken.feed("<indicator id='IconHIDDEN' visible='y'/><progressBar id='health' value='x'/>\r\n")
      expect(names).to eq(['$hidden'])
    end

    it 'raises "compass" for every <dir> in a compass, known or not, and none outside one' do
      names = []
      compass = described_class.new(listener: ->(batch) { names.concat(batch) })
      compass.feed("<compass><dir value='n'/><dir value='zz'/></compass><dir value='s'/>\r\n")
      expect(names).to eq(%w[compass compass compass])
    end

    it 'adds the SpellTimer port\'s `#var`s as "$name" changes of the same row' do
      names = []
      store = Lich::Genie::GlobalStore.new(write_clock: write_clock)
      timed = described_class.new(listener: ->(batch) { names.concat(batch) }, spell_timer: Lich::Genie::SpellTimer.new(store: store))
      timed.feed("<pushStream id=\"percWindow\"/>Ignite  (11 roisaen)\r\n")
      timed.feed("<popStream/>\r\n")
      expect(names).to eq(%w[$SpellTimer.Ignite.active $SpellTimer.Ignite.duration])
    end
  end

  # The script-timing events of a fed row (GameState::Row#events), in Remix's
  # order. Golden: genieflow --verbose over the session capture (move-event, roundtime-event,
  # prompt-event + the prompt's game-print; fixtures session_capture_timing_events.json).
  describe 'script-timing events (Game.cs:1763-1765, 2366-2411 R)' do
    def rows_events(state, rows)
      out = []
      state.listener = ->(batch) { out.concat(batch.events) if batch.is_a?(described_class::Row) }
      rows.each { |row| state.feed(row) }
      out
    end

    def as_golden(events)
      events.grep_v(Lich::Genie::GameEvents::TextLine).map do |event|
        case event
        when Lich::Genie::GameEvents::Move then ['move']
        when Lich::Genie::GameEvents::RoundTime then ['roundtime', event.seconds]
        when Lich::Genie::GameEvents::Prompt then ['prompt', event.text]
        end
      end
    end

    it 'raises Remix\'s move, roundtime and prompt events (with the printed text) over the session capture' do
      golden = JSON.parse(File.read(File.join(fixtures, 'session_capture_timing_events.json')))['events']
      expect(golden.length).to eq(125)
      # 32 of the 85 prompts follow no main-window text since the previous prompt (vitals pulses,
      # percWindow/room-only rows): Remix prints and parses only the other 53 (Game.cs:2397 R).
      prompts = golden.select { |event| event[0] == 'prompt' }
      expect([prompts.length, prompts.count { |event| event[1] }]).to eq([85, 53])
      rows = File.readlines(File.join(fixtures, 'session_capture_rows.txt')).map { |row| row.chomp + "\r\n" }
      expect(as_golden(rows_events(described_class.new(clock: -> { wall }), rows))).to eq(golden)
    end

    # m_bLastRowWasPrompt (Game.cs:2397 R; set/cleared by FormMain.AddText, FormMain.cs:5100-5122 R):
    # while the last row printed to the main window was a prompt, the next prompt prints nothing
    # (no TriggerParse) and $prompt keeps the raw text (no "> " rewrite); TriggerPrompt still fires.
    describe 'the last-row-was-prompt flag' do
      let(:prompt_row) { "<prompt time=\"1700000000\">&gt;</prompt>\r\n" }
      let(:pulse_row) do
        "<dialogData id='minivitals'><progressBar id='health' value='99' text='health 99%' left='0%' top='0%' width='25%' " \
          "height='100%'/></dialogData>\r\n"
      end
      let(:flagged) { described_class.new(clock: -> { wall }) }

      it 'prints a back-to-back prompt (one after a vitals pulse) nowhere and leaves $prompt unrewritten' do
        events = rows_events(flagged, [prompt_row, pulse_row, prompt_row, prompt_row])
        expect(as_golden(events)).to eq([['prompt', '> '], ['prompt', nil], ['prompt', nil]])
        expect(flagged['prompt']).to eq('>')
      end

      it 'keeps "R" (promptforce) in the unrewritten $prompt of a back-to-back prompt with a roundtime' do
        events = rows_events(flagged, [prompt_row, "<roundTime value='1700000004'/>\r\n", prompt_row])
        expect(as_golden(events)).to eq([['prompt', '> '], ['roundtime', 4], ['prompt', nil]])
        expect(flagged['prompt']).to eq('>R')
      end

      it 'is cleared by game text in the main window, not by a blank row or another window\'s text' do
        rows = [prompt_row, "   \r\n", prompt_row, "<pushStream id=\"thoughts\"/>Someone thinks.<popStream/>\r\n", prompt_row,
                "<pushStream id=\"percWindow\"/>Ignite  (11 roisaen)\r\n<popStream/>\r\n", prompt_row, "You feel fine.\r\n", prompt_row]
        expect(as_golden(rows_events(flagged, rows)).map(&:last)).to eq(['> ', nil, nil, nil, '> '])
      end

      it 'is cleared by main text flushed mid-row at a stream change, and by text later in the prompt\'s own row' do
        rows = [prompt_row, "You see.<pushStream id=\"thoughts\"/>x<popStream/>\r\n", prompt_row,
                "<prompt time=\"1700000000\">&gt;</prompt>trailing text\r\n", prompt_row]
        expect(as_golden(rows_events(flagged, rows)).map(&:last)).to eq(['> ', '> ', nil, '> '])
      end

      it 'is cleared by every send (the input echo, Game.cs:541-542 R)' do
        events = rows_events(flagged, [prompt_row])
        flagged.sent('look')
        events += rows_events(flagged, [prompt_row])
        expect(as_golden(events).map(&:last)).to eq(['> ', '> '])
      end

      it 'is cleared by a non-blank line the host prints to the main window (script echo, #echo, errors)' do
        events = rows_events(flagged, [prompt_row])
        flagged.printed(" \r\n")
        events += rows_events(flagged, [prompt_row])
        flagged.printed('[script echo]')
        events += rows_events(flagged, [prompt_row])
        expect(as_golden(events).map(&:last)).to eq(['> ', nil, '> '])
      end

      it 'is not set by a prompt printed into another window (room: printed there unparsed; thoughts: parsed)' do
        rows = ["<pushStream id=\"room\"/>#{prompt_row}", "<popStream/>\r\n", prompt_row, "You feel fine.\r\n",
                "<pushStream id=\"thoughts\"/>#{prompt_row}", "<popStream/>\r\n", prompt_row, prompt_row]
        expect(as_golden(rows_events(flagged, rows)).map(&:last)).to eq([nil, '> ', '> ', '> ', nil])
      end

      it 'is never set while `prompt` is off (nothing printed), so the first prompt after `prompt on` prints' do
        flagged.apply_setting('prompt', 'off')
        events = rows_events(flagged, [prompt_row, prompt_row])
        flagged.apply_setting('prompt', '> ')
        events += rows_events(flagged, [prompt_row, prompt_row])
        expect(as_golden(events).map(&:last)).to eq([nil, nil, '> ', nil])
      end

      it 'skips the String.Replace that throws on a blank prompt setting while the flag is set' do
        flagged.feed(prompt_row)
        flagged.apply_setting('prompt', ' ')
        expect { flagged.feed(prompt_row) }.not_to raise_error
        expect(flagged['prompt']).to eq('>')
      end
    end

    it 'hands a fed row\'s batch over as a Row (with its events) and a send\'s as a plain Array' do
      batches = []
      batcher = described_class.new(clock: -> { wall }, listener: ->(batch) { batches << batch })
      batcher.feed("<prompt time=\"1700000000\">&gt;</prompt>\r\n")
      batcher.sent('look')
      expect(batches.map(&:class)).to eq([described_class::Row, Array])
      expect(batches.first.events.map(&:class)).to eq([Lich::Genie::GameEvents::Prompt])
      expect(batches.first.events).to be_frozen
    end

    it 'raises the roundtime with the double RT offset, before the prompt, whose text then carries "R"' do
      offset = described_class.new(clock: -> { wall }, config: described_class::Config.from_settings([%w[roundtimeoffset 0.5]]))
      events = rows_events(offset, ["<roundTime value='1700000004'/>\r\n", "<prompt time=\"1700000000\">&gt;</prompt>\r\n"])
      expect(as_golden(events)).to eq([['roundtime', 4.5], ['prompt', 'R> ']])
    end

    it 'prints no prompt text with `prompt` off, but still raises TriggerPrompt (Game.cs:2397, 2411 R)' do
      off = described_class.new(clock: -> { wall })
      off.apply_setting('prompt', 'off')
      expect(as_golden(rows_events(off, ["<prompt time=\"1700000000\">&gt;</prompt>\r\n"]))).to eq([['prompt', nil]])
    end

    it 'prints the prompt text into the current stream, so none is parsed inside the room or inv stream' do
      %w[room inv].each do |stream|
        inside = described_class.new(clock: -> { wall })
        events = rows_events(inside, ["<pushStream id=\"#{stream}\"/><prompt time=\"1700000000\">&gt;</prompt>\r\n"])
        expect(as_golden(events)).to eq([['prompt', nil]]), stream
      end
      other = described_class.new(clock: -> { wall })
      events = rows_events(other, ["<pushStream id=\"thoughts\"/><prompt time=\"1700000000\">&gt;</prompt>\r\n"])
      expect(as_golden(events)).to eq([['prompt', '> ']])
    end

    it 'raises nothing for a prompt whose time is not an Int32 (the whole arm is skipped, Game.cs:2357 R)' do
      expect(rows_events(described_class.new(clock: -> { wall }), ["<prompt time=\"soon\">&gt;</prompt>\r\n"])).to eq([])
    end

    it 'raises TriggerMove for each room desc component, and nothing for the other room components' do
      events = rows_events(described_class.new(clock: -> { wall }),
                           ["<component id='room desc'>A road.</component><component id='room objs'>a rock</component>\r\n",
                            "<component id='room exits'>Obvious paths: north.</component>\r\n"])
      expect(as_golden(events)).to eq([['move']])
    end

    it 'raises no event for a replayed snapshot (Remix never re-parses old rows)' do
      seeded = described_class.new(clock: -> { wall })
      batches = []
      seeded.listener = ->(batch) { batches << batch }
      seeded.seed { ["<component id='room desc'>A road.</component>\r\n", "<prompt time=\"1700000000\">&gt;</prompt>\r\n"] }
      seeded.feed("<progressBar id='health' value='42'/>\r\n")
      expect(batches.map(&:events)).to eq([[]])
    end
  end

  # The texts ParseGameRow prints with parse (GameEvents::TextLine), in row
  # order -- what the #triggers and the scripts get as game lines. Expectations are the Remix
  # goldens of flow t52-t55 and t171-t175 (genieflow runs the real Game.cs on the same rows).
  describe 'printed texts (PrintTextWithParse -> TriggerParse, Game.cs:567-889, 2808-3069 R)' do
    def texts(rows, config: described_class::DEFAULT_CONFIG)
      out = []
      capture = described_class.new(config: config, clock: -> { wall }, write_clock: write_clock)
      capture.listener = ->(batch) { out.concat(batch.events.grep(Lich::Genie::GameEvents::TextLine).map(&:text)) if batch.is_a?(described_class::Row) }
      rows.each { |row| capture.feed("#{row}\r\n") }
      out
    end

    it 'trims CR/LF only, keeping spaces and tabs (Utility.Trim) and skipping a Trim()-blank text' do
      expect(texts(['   Last login: x', "tab\tin  ", '   ', "#{[0xA0].pack('U')} "])).to eq(['   Last login: x', "tab\tin  "])
    end

    it 'routes by window: Other streams and combat/thoughts/familiar/logons/death parsed, room and inv not (t52, t172)' do
      rows = ["<pushStream id='talk'/>Bob says, hi.<popStream/>", "<pushStream id='room'/>room text<popStream/>",
              "<pushStream id='inv'/>a sack<popStream/>", "<pushStream id='combat'/>* hit<popStream/>",
              "<pushStream id='logons'/>* Bob joins.<popStream/>"]
      expect(texts(rows)).to eq(['Bob says, hi.', '* hit', '* Bob joins.'])
    end

    it 'prints each row of a stream left open on arrival, main rows too (t53)' do
      expect(texts(["<pushStream id='moonWindow'/>Katamba sets.", 'still in moon', '<popStream/>back'])).to eq(['Katamba sets.', 'still in moon', 'back'])
    end

    it 'splits a row at a roomDesc preset and at a mid-row stream change (t55)' do
      rows = ["<style id=\"\"/><preset id='roomDesc'>A walkway lies west.</preset>  You also see a stair.", "PRE <pushStream id='thoughts'/>MID<popStream/> POST"]
      expect(texts(rows)).to eq(['A walkway lies west.', 'You also see a stair.', 'PRE ', 'MID', ' POST']) # TrimStart: Game.cs:2813-2817 R
    end

    it 'collects a text element nested in another twice, as ProcessXMLData does (t172)' do
      expect(texts(["<preset id='roomDesc'>A path <a exist='2'>runs</a> north.</preset>  Obvious."])).to eq(['A path runs north.runs', '  Obvious.'])
    end

    it 'prints bold text starting "< ", "> " or "* " on its own, never under condensed (t173, t175)' do
      combat = ['< You swing at a <pushBold/>goblin<popBold/>.', '* A goblin <pushBold/>attacks<popBold/> you!']
      expect(texts(combat)).to eq(['< You swing at a ', 'goblin.', '* A goblin ', 'attacks you!'])
      condensed = described_class::Config.from_settings([%w[condensed True]])
      expect(texts(combat, config: condensed)).to eq(['< You swing at a goblin.', '* A goblin attacks you!'])
    end

    # Probe t/bold2 vs genieflow: a combat-split row ends with m_bBold false
    # (Game.cs:856-859, 893-896 R), so the next row's bold text is not split again.
    it 'leaves the bold flag off after a combat-split row (Game.cs:893-896 R)' do
      rows = ['< You swing <pushBold/>at a goblin', "* more <a exist='1' noun='x'>thing</a> end<popBold/>"]
      expect(texts(rows)).to eq(['< You swing ', 'at a goblin', '* more thing end'])
    end

    it 'keeps the bold flag of a row that was not split' do
      rows = ['You see <pushBold/>a goblin', "* hit <a exist='3'>it</a> now<popBold/>"]
      expect(texts(rows)).to eq(['You see a goblin', '* hit ', 'it now'])
    end

    it 'appends a row-end remainder after the text and CRLF with no split (t174)' do
      expect(texts(["PRE <preset id='roomDesc'>open", '</preset> POST'])).to eq(['PRE ', " POST\r\nopen"])
    end

    it 'reads a <d> link outside a component only, as {text:cmd} with showlinks (t172, t175)' do
      rows = ["<component id='room exits'>Obvious paths: <d>north</d>.</component>", "Link <d cmd='look rock'>rock</d> here."]
      expect(texts(rows)).to eq(['Link rock here.'])
      links = described_class::Config.from_settings([%w[showlinks on]])
      expect(texts(rows, config: links)).to eq(['Link {rock:look rock} here.'])
    end

    it 'parses only the main window with parsegameonly (Game.cs:3065 R, t175)' do
      only_main = described_class::Config.from_settings([%w[parsegameonly 1]])
      rows = ["<pushStream id='thoughts'/>[General] thought<popStream/>", "<stream id='thoughts'>streamed</stream>", 'main text']
      expect(texts(rows)).to eq(['[General] thought', 'streamed', 'main text'])
      expect(texts(rows, config: only_main)).to eq(['main text'])
    end

    it 'decodes an invalid UTF-8 row like Remix\'s socket text (U+FFFD), so a regex never raises on it' do
      text = texts([[0x63, 0x61, 0x66, 0xE9, 0x20, 0x61, 0x75].pack('C*')]).first
      expect([text.encoding, text.valid_encoding?, text]).to eq([Encoding::UTF_8, true, "caf#{[0xFFFD].pack('U')} au"])
      expect(text).to match(/caf. au/)
    end
  end

  # A script's `#var roomname` / `#var prompt` reaches the automapper plugin
  # (SafeParsePluginVariable, FormMain.cs:5045-5050 R; AutoMapper.cs:269-278 R).
  describe '#plugin_variable_changed (the automapper\'s VariableChanged)' do
    it 'runs the room update on "prompt" only after a "roomname", raising "$roomid" once' do
      batches = []
      state.listener = ->(batch) { batches << batch }
      state.plugin_variable_changed('$prompt')
      state.plugin_variable_changed('$roomname')
      state.plugin_variable_changed(%w[$prompt lastcommand])
      state.plugin_variable_changed('prompt')
      expect(batches).to eq([%w[$roomid]])
    end

    it 'moves $roomid\'s write stamp to the room update' do
      before = state.host_stamp('roomid', :room)
      state.plugin_variable_changed(%w[roomname prompt])
      expect(state.host_stamp('roomid', :room)).to be > before
    end
  end

  # A gagged main text never reaches AddText and one substituted to blank does
  # not clear m_bLastRowWasPrompt (Game.cs:3075-3103 R; flow t225_prompt_flag_gag).
  describe 'the display port and #last_row_was_prompt' do
    let(:filters) do
      Lich::Genie::StreamFilters.new.tap do |f|
        f.add_gag('^hide')
        f.add_sub('^blank.*', '')
      end
    end
    let(:state) do
      described_class.new(write_clock: Lich::Genie::WriteClock.new, display: ->(text, target) { filters.displayed(text, target) })
    end
    let(:prompt) { %(<prompt time="1700000000">&gt;</prompt>\r\n) }

    it 'keeps the flag across a gagged line and a line substituted to blank, clears it on a shown one' do
      state.feed(prompt)
      expect(state.last_row_was_prompt).to be(true)
      state.feed("hide me\r\n")
      state.feed("blank this\r\n")
      expect(state.last_row_was_prompt).to be(true)
      state.feed("shown line\r\n")
      expect(state.last_row_was_prompt).to be(false)
    end

    it 'still offers the gagged line to the scripts and #triggers (TriggerParse comes first)' do
      events = []
      state.listener = ->(row) { events.concat(row.events.map(&:text)) if row.respond_to?(:events) }
      state.feed("hide me\r\n")
      expect(events).to include('hide me')
    end

    # The display port runs with the state lock released, so a slow gag never
    # stalls a reader (a script's `$roomobjs`, the queue's roundtime test) and the port may read the
    # state back (a substitute's ParseGlobalVars); every other writer still waits for the whole row.
    it 'calls the display port without the state lock: readers run, writers wait for the row' do
      entered = Queue.new
      release = Queue.new
      slow = described_class.new(write_clock: Lich::Genie::WriteClock.new,
                                 display: lambda do |text, _target|
                                   entered << text
                                   release.pop
                                   text
                                 end)
      slow.feed("<progressBar id='health' value='42'/>\r\n")
      feeder = Thread.new { slow.feed("<progressBar id='health' value='7'/>shown text\r\n") }
      expect(entered.pop).to eq("shown text\r\n")
      read = Thread.new { [slow['health'], slow.last_row_was_prompt] }
      expect(read.join(5)&.value).to eq(['7', false]) # not blocked by the port (the row is half applied)
      sender = Thread.new { slow.sent('look') }
      expect(sender.join(0.2)).to be_nil # a writer waits for the row
      release << :go
      expect(feeder.join(5)).not_to be_nil
      expect(sender.join(5)).not_to be_nil
      expect(slow['lastcommand']).to eq('look')
    ensure
      release << :go
      [feeder, sender, read].compact.each { |t| t.join(5) }
    end

    it 'lets the display port read the state back (ParseGlobalVars of a substitute) without deadlocking' do
      reader = nil
      reader = described_class.new(write_clock: Lich::Genie::WriteClock.new,
                                   display: ->(text, _target) { reader['health'] ? text : nil })
      reader.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
      reader.feed("<progressBar id='health' value='9'/>shown\r\n")
      expect(reader.last_row_was_prompt).to be(false)
    end

    # The display port runs host code (ParseGlobalVars) on Lich's parser thread while the
    # row holds the writers' lock; a host line printed by a thread that holds a lock the port waits on
    # (Lich's Map: synchronize_load around `respond map_loaded_message`) must not wait for the row, or
    # the two threads deadlock. #printed takes the state lock only, which the port runs without.
    it 'records a host line printed while the display port waits on a lock the printing thread holds' do
      lock = Mutex.new
      holding = Queue.new
      entered = Queue.new
      waiting = described_class.new(write_clock: Lich::Genie::WriteClock.new,
                                    display: lambda do |text, _target|
                                      entered << true
                                      lock.synchronize { text }
                                    end)
      waiting.feed(prompt)
      host = Thread.new do
        lock.synchronize do
          holding << true
          entered.pop
          waiting.printed('--- Lich: map loaded')
          waiting.last_row_was_prompt
        end
      end
      holding.pop
      parser = Thread.new { waiting.feed("You also see a goblin.\r\n") }
      expect(host.join(5)&.value).to be(false) # printed (it cleared the flag) while the row waited on the lock
      expect(parser.join(5)).not_to be_nil
    ensure
      [host, parser].compact.each { |t| t.join(0.5) || t.kill }
    end

    it 'records a host line printed from inside a writer (a plugin port) without re-locking' do
      printer = nil
      timer = Object.new
      timer.define_singleton_method(:parse_text) { |_text, _window| nil }
      timer.define_singleton_method(:parse_xml) { |buffer| printer.printed('[spell timer]') if buffer.include?('progressBar') }
      printer = described_class.new(write_clock: Lich::Genie::WriteClock.new, spell_timer: timer)
      2.times do # the second round: the plugin is still enabled (no ThreadError disabled it)
        printer.feed(prompt)
        printer.feed("<progressBar id='health' value='9'/>\r\n") # a text-less row: only the plugin's line clears it
        expect(printer.last_row_was_prompt).to be(false)
      end
    end

    it 'falls back to the raw text when the display port raises' do
      broken = described_class.new(write_clock: Lich::Genie::WriteClock.new, display: ->(_t, _w) { raise 'boom' })
      broken.feed(prompt)
      broken.feed("anything\r\n")
      expect(broken.last_row_was_prompt).to be(false)
    end
  end
end
