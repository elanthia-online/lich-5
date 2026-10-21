# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

# End-to-end persistence in Remix's model (written to disk only on an explicit save) through the
# real interpreter, router, store and trigger registry.
#
# Fixtures (spec/fixtures/genie/persistence): remix_save.cmd was run through the REAL
# Remix v4.2.4 code (genieflow, `GENIE=remix ./genieflow remix_save.cmd --scriptdir
# <tmp>`, 2026-10-19); remix_variables.cfg / remix_triggers.cfg are the files Remix's own
# `#var save` / `#trigger save` wrote into <tmp>/Config, with LF turned into CRLF: genieflow
# runs on macOS where Environment.NewLine is LF, the Windows client writes CRLF
# (the tester's real variables.cfg is CRLF).
RSpec.describe 'Genie persistence (Remix model)' do
  fixture_dir = File.expand_path('../../fixtures/genie/persistence', __dir__)
  setup_path = File.expand_path('../../fixtures/genie/trigger_setup.cmd', __dir__)
  charge_line = 'You prime a large amount of energy.'

  let(:game) do
    Class.new do
      attr_reader :commands

      def initialize = (@commands = [])
      def send_command(text) = (@commands << text)
    end.new
  end
  let(:nil_input) { Class.new { def next_line(**) = nil }.new }
  let(:echoes) { [] }

  around { |example| Dir.mktmpdir('genie-persist') { |dir| @dir = dir; example.run } }

  def vars_path = File.join(@dir, 'Config', 'variables.cfg')
  def triggers_path = File.join(@dir, 'Config', 'triggers.cfg')

  # The production list path: CommandRouter -> Lists (the registry, triggers.cfg under Config).
  def lists_for(triggers) = Lich::Genie::Lists.new(triggers: triggers, config_dir: File.join(@dir, 'Config'))

  def run_script(source, store:, triggers:, game_state: {})
    variables = Lich::Genie::Variables.new(game_state: game_state, global_store: store)
    Lich::Genie::Engine.build(
      source, name: 'persist', variables: variables, ignore_warnings: true,
      game: game, input: nil_input, echo: ->(t) { echoes << t }, hooks: nil, lists: lists_for(triggers),
      launch: ->(_n, _a) {}, clock: -> { 0.0 }
    ).run
  end

  def runner_for(store, triggers, game_state = {})
    vars = Lich::Genie::Variables.new(game_state: game_state, global_store: store)
    globals = Object.new
    globals.define_singleton_method(:key?) { |name| vars.global_key?(name) }
    Lich::Genie::TriggerRunner.new(vars: vars, eval: Lich::Genie::Eval.new(globals: globals), game: game,
                                   launch: ->(_n, _a) {}, hooks: nil, echo: ->(_t) {}, lists: lists_for(triggers))
  end

  it 'writes byte-for-byte the variables.cfg and triggers.cfg Remix writes for the same script' do
    store = Lich::Genie::GlobalStore.new(file: vars_path)
    run_script(File.read(File.join(fixture_dir, 'remix_save.cmd')), store: store, triggers: Lich::Genie::Triggers.new)

    expect(File.binread(vars_path)).to eq(File.binread(File.join(fixture_dir, 'remix_variables.cfg')))
    expect(File.binread(triggers_path)).to eq(File.binread(File.join(fixture_dir, 'remix_triggers.cfg')))
    expect(echoes).to eq(['Variables Saved', 'Triggers Saved']) # Remix: two cmdecho lines
  end

  it 'never touches the disk for a plain #var / #tvar / #math / #unvar' do
    store = Lich::Genie::GlobalStore.new(file: vars_path)
    run_script("put #var a 1\nput #tvar b 2\nput #math c add 3\nput #unvar a\n",
               store: store, triggers: Lich::Genie::Triggers.new)
    expect(File.exist?(vars_path)).to be(false)
    expect(Dir.exist?(File.dirname(vars_path))).to be(false)
    expect(store.get('c')).to eq('3')
  end

  it 'saves nothing when a script ends (Remix saves only on an explicit save)' do
    store = Lich::Genie::GlobalStore.new(file: vars_path)
    run_script("put #var triggersloaded 1\nexit\n", store: store, triggers: Lich::Genie::Triggers.new)
    expect(File.exist?(vars_path)).to be(false)
    expect(Lich::Genie::GlobalStore.new(file: vars_path).key?('triggersloaded')).to be(false)
  end

  # A hunting script that skips its trigger loader when $triggersloaded is 1 stalls forever
  # when the flag was saved without the triggers. The loader sets the flag and installs
  # {charging}; a quit-script-style `#trigger save` + `#var save` persists both, so
  # the NEXT session starts with the
  # flag AND the trigger (the native-Genie startup state), and the stall cannot happen.
  it 'saved setup triggers survive a restart and the charging trigger still fires' do
    session1_store = Lich::Genie::GlobalStore.new(file: vars_path)
    session1_triggers = Lich::Genie::Triggers.new
    source = "var triggerreturn exitsetup\ngoto SetTriggers\n#{File.read(setup_path)}\n" \
             "exitsetup:\nput #trigger save\nput #var save\nexit\n"
    run_script(source, store: session1_store, triggers: session1_triggers,
                       game_state: { 'unixtime' => '1000000', 'preparedspell' => 'None' })
    expect(session1_store.get('triggersloaded')).to eq('1')

    # Next process: engine start reads both files (FormMain.cs:2311, 2339 R).
    store = Lich::Genie::GlobalStore.new(file: vars_path)
    triggers = Lich::Genie::Triggers.new
    expect(triggers.load(triggers_path)).to be(true)
    expect(store.get('triggersloaded')).to eq('1')
    expect(triggers.list.map { |t| t.slice('pattern', 'commands', 'class') })
      .to match_array(session1_triggers.list.map { |t| t.slice('pattern', 'commands', 'class') })

    # Loaded triggers start active (Trigger ctor IsActive = true), whatever their class
    # state was when saved; the charging trigger fires and bumps $charges.
    store.set('alt', '0')
    store.set('charges', '0')
    runner = runner_for(store, triggers)
    triggers.apply(charge_line) { |cmds, caps| runner.fire(cmds, caps) }
    expect(store.get('charges')).to eq('1')
    expect(triggers.list.find { |t| t['class'] == 'charging' }['active']).to be(false) # its own #class charging off
  end

  it 'loads the Remix-written triggers.cfg fixture and fires its rows' do
    triggers = Lich::Genie::Triggers.new
    expect(triggers.load(File.join(fixture_dir, 'remix_triggers.cfg'))).to be(true)
    expect(triggers.count).to eq(6)
    expect(triggers.list.find { |t| t['class'] == 'spaced' }['pattern']).to eq('^Apple')

    store = Lich::Genie::GlobalStore.new(file: nil)
    store.set('misty', '1')
    runner = runner_for(store, triggers)
    triggers.apply('The cold mist around you fades.') { |cmds, caps| runner.fire(cmds, caps) }
    expect(store.get('misty')).to eq('0')
  end

  it '#var load merges, #load vars replaces the persistent set, temp vars survive both' do
    File.write(File.join(@dir, 'seed.cfg'), "#var {fromfile} {disk}\r\n")
    store = Lich::Genie::GlobalStore.new(file: File.join(@dir, 'seed.cfg'))
    run_script("put #var mine 1\nput #tvar scratch 2\nput #var load\n", store: store, triggers: Lich::Genie::Triggers.new)
    expect([store.get('mine'), store.get('scratch'), store.get('fromfile')]).to eq(%w[1 2 disk])

    run_script("put #load vars\n", store: store, triggers: Lich::Genie::Triggers.new)
    expect([store.get('mine'), store.get('scratch'), store.get('fromfile')]).to eq([nil, '2', 'disk'])
    expect(echoes).to eq(['Variables Loaded', 'Variables Loaded'])
  end

  it '#trigger load merges into the registry; #load triggers clears it first' do
    Lich::Genie::ConfigFile.write_lines(triggers_path, ['#trigger {^disk} {#var d 1}'])
    triggers = Lich::Genie::Triggers.new
    store = Lich::Genie::GlobalStore.new(file: nil)
    run_script("put #trigger {^live} {#var l 1}\nput #trigger load\n", store: store, triggers: triggers)
    expect(triggers.list.map { |t| t['pattern'] }).to contain_exactly('^live', '^disk')

    run_script("put #load triggers\n", store: store, triggers: triggers)
    expect(triggers.list.map { |t| t['pattern'] }).to eq(['^disk'])
  end

  describe 'Lich::Genie module wiring (engine start)' do
    # Swap the process-wide config tree for this example and restore it afterwards.
    around do |example|
      saved = %i[@config_dir @global_store @triggers @class_list @alias_list @stream_filters]
              .to_h { |ivar| [ivar, Lich::Genie.instance_variable_get(ivar)] }
      Lich::Genie.config_dir = @dir
      example.run
    ensure
      saved.each { |ivar, value| Lich::Genie.instance_variable_set(ivar, value) }
    end

    it 'reads variables.cfg and triggers.cfg from <config_dir>/Config once, at first use' do
      Lich::Genie::ConfigFile.write_lines(vars_path, ['#var {flag} {1}'])
      Lich::Genie::ConfigFile.write_lines(triggers_path, ['#trigger {^x} {#var y 1} {cls}'])

      expect(Lich::Genie.variables_file).to eq(vars_path)
      expect(Lich::Genie.triggers_file).to eq(triggers_path)
      expect(Lich::Genie.global_store.get('flag')).to eq('1')
      expect(Lich::Genie.triggers.list.map { |t| t['class'] }).to eq(['cls'])

      # No mid-session reload: another process saving the files is not picked up.
      Lich::Genie::ConfigFile.write_lines(vars_path, ['#var {flag} {2}'])
      Lich::Genie::ConfigFile.write_lines(triggers_path, [])
      File.utime(Time.now + 60, Time.now + 60, vars_path)
      expect(Lich::Genie.global_store.get('flag')).to eq('1')
      expect(Lich::Genie.triggers.count).to eq(1)
    end

    it 'builds ONE store and ONE registry when threads race the first access' do
      allow(Lich::Genie::VariableFile).to receive(:read).and_wrap_original do |original, *args|
        sleep 0.02 # widen the window between the memo check and the assignment
        original.call(*args)
      end
      allow(Lich::Genie::TriggerFile).to receive(:read).and_wrap_original do |original, *args|
        sleep 0.02
        original.call(*args)
      end
      stores = Queue.new
      registries = Queue.new
      Array.new(6) do
        Thread.new do
          stores << Lich::Genie.global_store
          registries << Lich::Genie.triggers
        end
      end.each(&:join)
      expect(Array.new(stores.size) { stores.pop }.map(&:object_id).uniq.length).to eq(1)
      expect(Array.new(registries.size) { registries.pop }.map(&:object_id).uniq.length).to eq(1)
    end

    it 'starts empty when the Config dir does not exist yet, and creates it on save' do
      expect(Lich::Genie.global_store.keys).to eq([])
      expect(Lich::Genie.triggers.count).to eq(0)
      Lich::Genie.global_store.set('k', 'v')
      expect(Lich::Genie.global_store.save).to be(true)
      expect(File.binread(vars_path)).to eq("#var {k} {v}\r\n")
    end

    # Load is catch (Exception) -> false (Globals.cs:757-762, 1105-1109 R). The glue
    # builds both at engine start, so a raise here would abort the first script.
    it 'builds an empty store and registry, without raising, when the cfg files cannot be read' do
      Lich::Genie::ConfigFile.write_lines(vars_path, ['#var {flag} {1}'])
      Lich::Genie::ConfigFile.write_lines(triggers_path, ['#trigger {^x} {y}'])
      allow(File).to receive(:binread).and_call_original
      allow(File).to receive(:binread).with(vars_path).and_raise(Errno::EACCES, vars_path)
      allow(File).to receive(:binread).with(triggers_path).and_raise(Errno::EACCES, triggers_path)

      store = Lich::Genie.global_store
      registry = Lich::Genie.triggers
      expect([store.keys, registry.count]).to eq([[], 0])
      expect([Lich::Genie.global_store, Lich::Genie.triggers]).to eq([store, registry]) # memoized, not rebuilt
    end
  end
end
