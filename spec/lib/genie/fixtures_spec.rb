# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Integration regression against synthetic Genie scripts shaped like large real-world ones
# (spec/fixtures/genie: a casting script + its include, a trigger-setup include). Guards two
# things end-to-end: (1) the lexer keeps 100% parse coverage of those constructs, and (2) a
# full standalone script runs to completion through the whole pipeline and emits the expected
# structured hooks. The real scripts are covered locally by corpus_coverage_spec.rb.
RSpec.describe 'Genie script fixtures' do
  fixtures_dir = File.expand_path('../../fixtures/genie', __dir__)

  # Records commands the interpreter would send to the game.
  recording_game = Class.new do
    attr_reader :commands

    def initialize = (@commands = [])
    def send_command(text) = (@commands << text)
  end

  # No downstream input (these fixtures are config/setup scripts, not hunting loops).
  nil_input = Class.new do
    def next_line(**) = nil
  end

  # Resolve `include <name>` from the fixtures dir (parse_coverage.cmd includes
  # parse_coverage_book.cmd). An include the fixtures do not carry (sightcheck.cmd) is a one-row
  # stub: Remix would refuse to load the script without it ("File not found"), but this is a
  # parse-coverage check of the rows we do have.
  include_loader = lambda do |name|
    path = File.join(fixtures_dir, name)
    File.exist?(path) ? File.read(path) : "echo stub for #{name}\n"
  end

  describe 'parse coverage (lexer regression)' do
    %w[trigger_setup.cmd parse_coverage.cmd parse_coverage_book.cmd].each do |file|
      it "compiles #{file} with zero unknown-command warnings" do
        source = File.read(File.join(fixtures_dir, file))
        program = Lich::Genie::Engine.compile(source, include_loader: include_loader, ignore_warnings: true)
        expect(program.warnings).to be_empty
        expect(program.instructions).not_to be_empty
        expect(program.labels).not_to be_empty
      end
    end
  end

  describe 'end-to-end: trigger_setup.cmd' do
    # The file is an include driven by a caller-set return label; drive it into
    # SetTriggers with a terminal return label so it runs once and exits.
    def run_setup(fixtures_dir, game_klass, input_klass)
      source = "var triggerreturn exitsetup\ngoto SetTriggers\n" \
               "#{File.read(File.join(fixtures_dir, 'trigger_setup.cmd'))}\nexitsetup:\nexit\n"
      game = game_klass.new
      hooks = []
      sink = Object.new.tap { |o| o.define_singleton_method(:emit) { |op, pl| hooks << [op, pl] } }
      lists = Lich::Genie::Lists.new
      variables = Lich::Genie::Variables.new(game_state: { 'unixtime' => '1000000', 'preparedspell' => 'None' })
      Lich::Genie::Engine.build(
        source, name: 'setup', variables: variables, ignore_warnings: true,
        game: game, input: input_klass.new, echo: ->(_t) {}, hooks: sink, lists: lists,
        clock: -> { 0.0 }
      ).run
      { commands: game.commands, hooks: hooks, lists: lists }
    end

    it 'runs to completion filling the class list and the trigger registry, the front end hearing only class events' do
      result = run_setup(fixtures_dir, recording_game, nil_input)

      expect(result[:commands]).to be_empty # pure front-end/config script; nothing goes to the game
      expect(result[:hooks].map(&:first).uniq).to eq(%w[class])
      expect(result[:lists].triggers.count).to be >= 30
      expect(result[:lists].classes.entries.length).to be >= 20
    end

    it 'registers self-describing triggers (key, pattern, commands, class)' do
      key, pattern, commands, = run_setup(fixtures_dir, recording_game, nil_input)[:lists].triggers.entries.first
      expect([key, pattern, commands]).to all(be_a(String).and(satisfy { |s| !s.empty? }))
    end

    it 'evaluates config-section conditionals into class states, both on and off' do
      states = run_setup(fixtures_dir, recording_game, nil_input)[:lists].classes.entries.map(&:last)
      expect(states).to include(true).and include(false)
    end
  end

  describe 'end-to-end: the registered triggers actually FIRE on game lines' do
    # A headless stand-in for LichHookSink: routes trigger/class events into a real
    # Triggers registry through the production dispatch (genie_script.rb
    # apply_trigger -> Triggers#dispatch). No triggers.cfg path: save/load are no-ops.
    it 'loads trigger_setup.cmd and a matching line runs the trigger action' do
      store = Lich::Genie::GlobalStore.new(file: nil)
      triggers = Lich::Genie::Triggers.new
      lists = Lich::Genie::Lists.new(triggers: triggers)
      sink = nil
      game_state = { 'unixtime' => '1000000', 'preparedspell' => 'None' }

      # 1) Run the real script; its `put #trigger ...` lines register into the registry.
      source = "var triggerreturn exitsetup\ngoto SetTriggers\n" \
               "#{File.read(File.join(fixtures_dir, 'trigger_setup.cmd'))}\nexitsetup:\nexit\n"
      script_vars = Lich::Genie::Variables.new(game_state: game_state, global_store: store)
      Lich::Genie::Engine.build(
        source, name: 'setup', variables: script_vars, ignore_warnings: true,
        game: recording_game.new, input: nil_input.new, echo: ->(_t) {}, hooks: sink, lists: lists,
        launch: ->(_n, _a) {}, clock: -> { 0.0 }
      ).run
      expect(triggers.count).to be >= 30

      # 2) A runner (shares the global store) executes matched trigger actions.
      runner_vars = Lich::Genie::Variables.new(game_state: game_state, global_store: store)
      globals = Object.new
      globals.define_singleton_method(:key?) { |name| runner_vars.global_key?(name) }
      runner = Lich::Genie::TriggerRunner.new(
        vars: runner_vars, eval: Lich::Genie::Eval.new(globals: globals),
        game: recording_game.new, launch: ->(_n, _a) {}, hooks: sink, echo: ->(_t) {}, lists: lists
      )

      # The ready-again trigger's class ("cooldown") is gated OFF by the script's own
      # setup (if ($cdtimer > $unixtime) ... else #class cooldown off) -- faithful to Genie.
      cooldown_trigger = triggers.list.find { |t| t['class'] == 'cooldown' }
      expect(cooldown_trigger['active']).to be(false)

      ready_again = 'You feel ready to use your ability again.'
      # 3a) While gated off, the trigger does NOT fire.
      fired = 0
      triggers.apply(ready_again) { |_c, _caps| fired += 1 }
      expect(fired).to eq(0)

      # 3b) Turn the class on (as the cooldown-load path would) -> now it fires and its
      #     action runs: {#var cdtimer 0;#class cooldown off}.
      triggers.toggle_class('cooldown', true)
      triggers.apply(ready_again) { |cmds, caps| runner.fire(cmds, caps) }
      expect(store.get('cdtimer')).to eq('0') # #var cdtimer 0 ran
      expect(triggers.list.find { |t| t['class'] == 'cooldown' }['active']).to be(false) # #class cooldown off ran
    end
  end
end
