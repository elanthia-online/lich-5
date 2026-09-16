# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../spec_helper'

# Characterization tests for do_client's ;command dispatch chain.
#
# These pin CURRENT behavior, bugs included, so that a later refactor of the
# chain can be checked against them. They deliberately assert on the exact
# strings and call arguments the chain produces today rather than on what it
# arguably ought to produce; where a test pins something that looks wrong, it
# says so.
#
# do_client cannot be exercised in-process: requiring global_defs.rb
# redefines respond/get/put and the rest of the script-facing DSL against
# production game infrastructure, which breaks every example that runs after
# it (see the note at the top of spec/lib/global_defs_spec.rb). So each
# example runs a probe in a child process, the same technique
# global_defs_spec.rb uses for its own do_client tests.
#
# The chain is an ordered if/elsif: the FIRST matching branch wins and the
# final else treats anything unmatched as a script name. Order is therefore
# load-bearing in several places, and the "ordering" section below pins the
# overlaps that matter.

# The six uniform display toggles, as {word => [accessor, message]}. They all
# share one shape -- read the current value, negate it, let an explicit
# true/false argument override, report, write back -- which makes them the
# clearest candidate for collapsing into a table, so each is pinned here with
# its exact message and accessor. Defined at file scope rather than inside the
# example group so before(:context) can reach it.
UNIFORM_DISPLAY_TOGGLES = {
  'lichid'      => ['display_lichid',      'Changing Lich to display Lich ID#s to'],
  'uid'         => ['display_uid',         'Changing Lich to display RealID#s to'],
  'exits'       => ['display_exits',       'Changing Lich to display Room Exits of non-StringProc/Obvious exits to'],
  'stringprocs' => ['display_stringprocs', 'Changing Lich to display Room Exits of StringProcs to'],
  'roomlinks'   => ['display_room_links',  'Changing Lich to display room exits as clickable command links to'],
  'roommono'    => ['display_room_mono',   'Changing Lich to display room information in monospace font to']
}.freeze

RSpec.describe 'do_client command dispatch' do
  # Runs +probe+ after loading global_defs.rb with the game infrastructure
  # stubbed. +game+ sets what XMLData.game reports, which gates 16 of the
  # chain's branches.
  def probe(body, game: 'GSIV')
    root = File.expand_path('../..', __dir__)
    source = <<~RUBY
      require './spec/spec_helper'
      require 'common/detachable_client_registry'
      require './lib/global_defs'

      $lich_char_regex = /;/
      $clean_lich_char = ';'
      $cmd_prefix = '<c>'
      $_CLIENTBUFFER_ = []
      Object.const_set(:LICH_VERSION, 'test') unless Object.const_defined?(:LICH_VERSION)
      Lich.const_set(:MAX_DEBUG_LOGS_DEFAULT, 10) unless Lich.const_defined?(:MAX_DEBUG_LOGS_DEFAULT)
      XMLData.define_singleton_method(:game) { #{game.inspect} }
      UpstreamHook.define_singleton_method(:run) { |line| line }
      Object.send(:define_method, :respond) { |message = nil| puts("R:\#{message}") }
      Object.send(:define_method, :new_upstream) { |_line| nil }
      Script.define_singleton_method(:new_upstream) { |_line| nil }

      #{body}
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, "-I#{File.join(root, 'lib')}", '-e', source, :chdir => root)
    raise "probe failed:\n#{err}" unless status.success?

    out
  end

  # Most branches only need to know that a named script was looked up. This
  # builds a fake script whose every interesting method announces itself.
  def fake_script_helper
    <<~RUBY
      def fake_script(name, paused: false, no_pause_all: false)
        s = Object.new
        s.define_singleton_method(:name) { name }
        s.define_singleton_method(:paused?) { paused }
        s.define_singleton_method(:no_pause_all) { no_pause_all }
        s.define_singleton_method(:kill) { puts "KILL \#{name}" }
        s.define_singleton_method(:pause) { puts "PAUSE \#{name}" }
        s.define_singleton_method(:unpause) { puts "UNPAUSE \#{name}" }
        s.define_singleton_method(:want_downstream) { true }
        s.define_singleton_method(:downstream_buffer) { @buf ||= [] }
        s.define_singleton_method(:unique_buffer) { @ubuf ||= [] }
        s
      end
    RUBY
  end

  describe 'script control' do
    it 'kills the most recent script for ;k, ;kill and ;stop' do
      out = probe(<<~RUBY)
        #{fake_script_helper}
        Script.define_singleton_method(:running) { [fake_script('first'), fake_script('last')] }
        %w[k kill stop].each { |c| do_client(";\#{c}") }
      RUBY
      expect(out.scan(/KILL last/).length).to eq(3)
    end

    it 'reports when there is nothing to kill' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:running) { [] }
        do_client(';k')
      RUBY
      expect(out).to include('R:--- Lich: no scripts to kill')
    end

    it 'pauses the most recent unpaused script and unpauses the most recent paused one' do
      out = probe(<<~RUBY)
        #{fake_script_helper}
        Script.define_singleton_method(:running) { [fake_script('a'), fake_script('b', paused: true)] }
        do_client(';p')
        do_client(';u')
      RUBY
      expect(out).to include('PAUSE a')
      expect(out).to include('UNPAUSE b')
    end

    it 'reports when there is nothing to pause or unpause' do
      out = probe(<<~RUBY)
        #{fake_script_helper}
        Script.define_singleton_method(:running) { [fake_script('a', paused: true)] }
        do_client(';p')
        Script.define_singleton_method(:running) { [fake_script('a')] }
        do_client(';u')
      RUBY
      expect(out).to include('R:--- Lich: no scripts to pause')
      expect(out).to include('R:--- Lich: no scripts to unpause')
    end

    it 'routes ;ka, ;kill all and ;stop all through Script.kill_all' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:kill_all) { |force: false, context: :runtime| puts "KA force=\#{force}"; 1 }
        ['ka', 'kill all', 'killall', 'stop all'].each { |c| do_client(";\#{c}") }
      RUBY
      expect(out.scan(/KA force=false/).length).to eq(4)
    end

    it 'routes ;kd through forced teardown' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:kill_all) { |force: false, context: :runtime| puts "KA force=\#{force}"; 1 }
        do_client(';kd')
      RUBY
      expect(out).to include('KA force=true')
    end

    it 'skips no_pause_all scripts for ;pa and ;ua' do
      out = probe(<<~RUBY)
        #{fake_script_helper}
        Script.define_singleton_method(:running) { [fake_script('normal'), fake_script('protected', no_pause_all: true)] }
        do_client(';pa')
      RUBY
      expect(out).to include('PAUSE normal')
      expect(out).not_to include('PAUSE protected')
    end

    it 'targets a named script for ;kill/;pause/;unpause <name>' do
      out = probe(<<~RUBY)
        #{fake_script_helper}
        Script.define_singleton_method(:running) { [fake_script('alpha')] }
        Script.define_singleton_method(:hidden) { [] }
        do_client(';kill alpha')
        do_client(';pause alpha')
        do_client(';unpause alpha')
      RUBY
      expect(out).to include('KILL alpha')
      expect(out).to include('PAUSE alpha')
      expect(out).to include('UNPAUSE alpha')
    end

    it 'matches a named script by prefix when there is no exact match' do
      out = probe(<<~RUBY)
        #{fake_script_helper}
        Script.define_singleton_method(:running) { [fake_script('alphabet')] }
        Script.define_singleton_method(:hidden) { [] }
        do_client(';kill alpha')
      RUBY
      expect(out).to include('KILL alphabet')
    end

    it 'reports a named script that is not running' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:running) { [] }
        Script.define_singleton_method(:hidden) { [] }
        do_client(';kill nosuch')
      RUBY
      expect(out).to include("R:--- Lich: nosuch does not appear to be running!")
    end
  end

  describe 'listing' do
    it 'lists running scripts for ;list and ;l, marking paused ones' do
      out = probe(<<~RUBY)
        #{fake_script_helper}
        Script.define_singleton_method(:running) { [fake_script('a'), fake_script('b', paused: true)] }
        Script.define_singleton_method(:hidden) { [fake_script('secret')] }
        do_client(';list')
      RUBY
      expect(out).to include('R:--- Lich: a, b (paused)')
      expect(out).not_to include('secret')
    end

    it 'includes hidden scripts for ;listall and ;la' do
      out = probe(<<~RUBY)
        #{fake_script_helper}
        Script.define_singleton_method(:running) { [fake_script('a')] }
        Script.define_singleton_method(:hidden) { [fake_script('secret')] }
        do_client(';la')
      RUBY
      expect(out).to include('secret')
    end

    it 'reports when no scripts are active' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:running) { [] }
        do_client(';list')
      RUBY
      expect(out).to include('R:--- Lich: no active scripts')
    end
  end

  describe 'starting scripts' do
    it 'passes force through for ;force <name> and ;force <name> <args>' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:start) { |*a| puts "START \#{a.inspect}" }
        do_client(';force foo')
        do_client(';force foo bar baz')
      RUBY
      expect(out).to include('START ["foo", {force: true}]').or include('START ["foo", {:force=>true}]')
      expect(out).to include('START ["foo", "bar baz", {force: true}]').or include('START ["foo", "bar baz", {:force=>true}]')
    end

    it 'treats an unmatched command as a script name, with and without args' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:start) { |*a| puts "START \#{a.inspect}" }
        do_client(';someScript')
        do_client(';someScript arg1 arg2')
      RUBY
      expect(out).to include('START ["someScript"]')
      expect(out).to include('START ["someScript", "arg1 arg2"]')
    end

    it 'routes ;exec and ;e through ExecScript, with q marking quiet' do
      out = probe(<<~RUBY)
        ExecScript.define_singleton_method(:start) { |data, opts| puts "EXEC \#{data.inspect} quiet=\#{opts[:quiet].inspect}" }
        do_client(';e puts 1')
        do_client(';eq puts 2')
      RUBY
      expect(out).to include('EXEC "puts 1" quiet=nil')
      expect(out).to include('EXEC "puts 2" quiet="q"')
    end

    it 'routes ;execname and ;en through ExecScript with a name' do
      out = probe(<<~RUBY)
        ExecScript.define_singleton_method(:start) { |data, opts| puts "EXEC \#{data.inspect} name=\#{opts[:name].inspect}" }
        do_client(';en my-job puts 1')
      RUBY
      expect(out).to include('EXEC "puts 1" name="my-job"')
    end
  end

  describe 'sending to scripts' do
    it 'broadcasts for ;send <msg>' do
      out = probe(<<~RUBY)
        #{fake_script_helper}
        Script.define_singleton_method(:running) { [fake_script('a')] }
        Script.define_singleton_method(:hidden) { [] }
        Script.define_singleton_method(:new_downstream) { |msg| puts "DOWNSTREAM \#{msg.inspect}" }
        do_client(';send hello there')
      RUBY
      expect(out).to include('R:--- sent: hello there')
      expect(out).to include('DOWNSTREAM "hello there"')
    end

    it 'targets one script for ;send to <name> <msg>' do
      out = probe(<<~RUBY)
        #{fake_script_helper}
        Script.define_singleton_method(:running) { [fake_script('alpha')] }
        Script.define_singleton_method(:hidden) { [] }
        do_client(';send to alpha hello')
      RUBY
      expect(out).to include("R:--- sent to 'alpha': hello")
    end

    it 'reports an unknown target for ;send to' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:running) { [] }
        Script.define_singleton_method(:hidden) { [] }
        do_client(';send to nosuch hello')
      RUBY
      expect(out).to include("R:--- Lich: 'nosuch' does not match any active script!")
    end

    it 'reports when there is nothing to broadcast to' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:running) { [] }
        Script.define_singleton_method(:hidden) { [] }
        do_client(';send hello')
      RUBY
      expect(out).to include('R:--- Lich: no active scripts to send to.')
    end
  end

  describe 'display toggles' do
    uniform = UNIFORM_DISPLAY_TOGGLES

    # UNIFORM_DISPLAY_TOGGLES is hand-typed on purpose: it characterizes what
    # the original if/elsif chain did, so it has to be written down
    # independently of the table the refactor introduced. Deriving it from
    # DISPLAY_TOGGLES would make this spec agree with the production table by
    # construction and stop testing anything.
    #
    # The cost of that independence is drift -- edit an accessor or message in
    # DISPLAY_TOGGLES, or add a seventh toggle, and this fixture would quietly
    # stop covering it while still passing. So assert the two agree: the
    # characterization stays independent, and a change on either side that
    # isn't mirrored fails loudly here instead of silently narrowing coverage.
    it 'covers exactly the production toggle table' do
      require 'common/client_commands'

      production = Lich::Common::ClientCommands::DISPLAY_TOGGLES.to_h do |word, accessor, description|
        # Patterns carry a trailing "?" for the optional plural ("exits?");
        # the command word the fixture keys on is the pattern without it.
        [word.delete_suffix('?'), [accessor.to_s, "Changing Lich to display #{description} to"]]
      end

      expect(uniform).to eq(production)
    end

    # Driven in one probe rather than one per toggle: each subprocess costs
    # about a second, and six near-identical branches do not need six of them.
    # The per-toggle expectations below still fail individually.
    before(:context) do
      setup = uniform.map { |word, (accessor, _)| <<~RUBY }.join("\n")
        Lich.define_singleton_method(:#{accessor}) { false }
        Lich.define_singleton_method(:#{accessor}=) { |v| puts "SET #{accessor}=\#{v}" }
        do_client(';display #{word}')
        do_client(';display #{word} true')
        do_client(';display #{word} false')
      RUBY
      @toggle_output = probe(setup)
    end

    # The same six, but reading true, so the read-negate path is pinned in
    # both directions rather than only false -> true.
    before(:context) do
      setup = uniform.map { |word, (accessor, _)| <<~RUBY }.join("\n")
        Lich.define_singleton_method(:#{accessor}) { true }
        Lich.define_singleton_method(:#{accessor}=) { |v| puts "SET #{accessor}=\#{v}" }
        do_client(';display #{word}')
      RUBY
      @toggle_from_true = probe(setup)
    end

    def toggle_output = @toggle_output
    def toggle_from_true = @toggle_from_true

    uniform.each do |word, (accessor, message)|
      it "toggles #{word} from its current value and honors an explicit argument" do
        expect(toggle_output).to include("R:#{message} true")
        expect(toggle_output).to include("R:#{message} false")
        # bare toggle (from false) + explicit true, then explicit false
        expect(toggle_output.scan(/SET #{accessor}=true/).length).to eq(2)
        expect(toggle_output.scan(/SET #{accessor}=false/).length).to eq(1)
      end

      it "toggles #{word} back off when it is currently on" do
        expect(toggle_from_true).to include("R:#{message} false")
        expect(toggle_from_true).to include("SET #{accessor}=false")
      end
    end

    it 'accepts plural spellings for exits, stringprocs and roomlinks' do
      out = probe(<<~RUBY)
        %w[display_exits display_stringprocs display_room_links].each do |a|
          Lich.define_singleton_method(a) { false }
          Lich.define_singleton_method("\#{a}=") { |v| puts "SET \#{a}" }
        end
        do_client(';display exit')
        do_client(';display stringproc')
        do_client(';display roomlink')
      RUBY
      expect(out).to include('SET display_exits')
      expect(out).to include('SET display_stringprocs')
      expect(out).to include('SET display_room_links')
    end
  end

  describe 'debug logs' do
    it 'shows current settings for bare ;debuglogs' do
      out = probe(<<~RUBY)
        Lich.define_singleton_method(:max_debug_logs) { 7 }
        do_client(';debuglogs')
      RUBY
      expect(out).to include('R:--- Lich: Debug Log Retention ---')
      expect(out).to include('Current limit:  7 files')
    end

    it 'sets the limit for ;debuglogs <n>' do
      out = probe(<<~RUBY)
        Lich.define_singleton_method(:max_debug_logs) { @l || 0 }
        Lich.define_singleton_method(:max_debug_logs=) { |v| @l = v; puts "SET \#{v}" }
        do_client(';debuglogs 25')
      RUBY
      expect(out).to include('SET 25')
      expect(out).to include('R:--- Lich: debug log retention set to 25 files')
    end

    it 'rejects a non-numeric argument' do
      out = probe(<<~RUBY)
        Lich.define_singleton_method(:max_debug_logs) { 7 }
        do_client(';debuglogs abc')
      RUBY
      expect(out).to include('R:--- Lich: invalid argument. Usage: ;debuglogs [number]')
    end
  end

  describe 'lich5-update' do
    it 'passes arguments through and defaults to --help with none' do
      out = probe(<<~RUBY)
        module Lich; module Util; module Update
          def self.request(arg) = puts("UPDATE \#{arg.inspect}")
        end; end; end
        do_client(';l5u --announce')
        do_client(';lich5-update')
      RUBY
      expect(out).to include('UPDATE "--announce"')
      expect(out).to include('UPDATE "--help"')
    end
  end

  describe 'game gating' do
    it 'runs ;magic only for GemStone' do
      gs = probe(<<~RUBY, game: 'GSIV')
        Object.const_set(:Effects, Module.new)
        Effects.define_singleton_method(:display) { puts 'MAGIC' }
        do_client(';magic')
      RUBY
      expect(gs).to include('MAGIC')

      dr = probe(<<~RUBY, game: 'DR')
        Script.define_singleton_method(:start) { |*a| puts "START \#{a.inspect}" }
        do_client(';magic')
      RUBY
      # Not a GS session, so it falls through to the catch-all as a script name.
      expect(dr).to include('START ["magic"]')
    end

    it 'sends the bank account command for ;banks on GemStone' do
      out = probe(<<~RUBY, game: 'GSIV')
        Object.const_set(:Game, Module.new) unless Object.const_defined?(:Game)
        Game.define_singleton_method(:_puts) { |s| puts "GAME \#{s}" }
        do_client(';banks')
      RUBY
      expect(out).to include('GAME <c>bank account')
    end
  end

  describe 'non-command input' do
    it 'passes ordinary game commands straight upstream' do
      out = probe(<<~RUBY)
        Object.const_set(:Game, Module.new) unless Object.const_defined?(:Game)
        Game.define_singleton_method(:_puts) { |s| puts "GAME \#{s.inspect}" }
        $offline_mode = false
        do_client('look')
      RUBY
      expect(out).to include('GAME "look"')
    end

    it 'refuses to send upstream in offline mode' do
      out = probe(<<~RUBY)
        $offline_mode = true
        do_client('look')
      RUBY
      expect(out).to include('R:--- Lich: offline mode: ignoring look')
    end

    it 'accepts a command wrapped in <c>' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:running) { [] }
        do_client('<c>;k')
      RUBY
      expect(out).to include('R:--- Lich: no scripts to kill')
    end
  end

  # Trust only ever worked under the Ruby 2.0-2.2 $SAFE model. On every
  # supported Ruby all three branches answer with the unavailable message --
  # which IS the current behavior, so that is what gets pinned. These also
  # stand in for the ordering claim that ;lt must precede ;list: it need not
  # (the list pattern cannot match "lt"), so ;lt is pinned by its output.
  describe 'trust' do
    it 'reports trust as unavailable on a modern Ruby' do
      out = probe(<<~RUBY)
        do_client(';trust foo')
        do_client(';distrust foo')
        do_client(';untrust foo')
      RUBY
      expect(out.scan(/R:--- Lich: this feature isn't available in this version of Ruby/).length).to eq(3)
    end

    it 'routes ;lt and ;list trusted to the trusted listing, not the script list' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:running) { [] }
        Script.define_singleton_method(:hidden) { [] }
        do_client(';lt')
        do_client(';list trusted')
      RUBY
      expect(out.scan(/R:--- Lich: this feature isn't available in this version of Ruby/).length).to eq(2)
      expect(out).not_to include('no active scripts')
    end
  end

  describe 'settings' do
    it 'writes a ;set toggle to the settings table' do
      out = probe(<<~RUBY)
        db = Object.new
        db.define_singleton_method(:execute) { |sql, args| puts "DB \#{args.inspect}" }
        Lich.define_singleton_method(:db) { db }
        do_client(';set foo on')
      RUBY
      expect(out).to include('DB ["foo", "on"]')
      expect(out).to include('R:--- Lich: toggle foo set on')
    end

    it 'passes a ;hmr pattern to HMR.reload as a regex' do
      out = probe(<<~RUBY)
        Object.const_set(:HMR, Module.new) unless Object.const_defined?(:HMR)
        HMR.define_singleton_method(:reload) { |rx| puts "RELOAD \#{rx.inspect}" }
        do_client(';hmr foo.*bar')
      RUBY
      expect(out).to include('RELOAD /foo.*bar/')
    end
  end

  describe 'infomon and sk (GemStone)' do
    it 'routes the infomon subcommands' do
      out = probe(<<~RUBY, game: 'GSIV')
        ExecScript.define_singleton_method(:start) { |code, _| puts "EXEC \#{code}" }
        Object.const_set(:Infomon, Module.new) unless Object.const_defined?(:Infomon)
        Infomon.define_singleton_method(:show) { |full| puts "SHOW full=\#{full}" }
        Infomon.define_singleton_method(:get_bool) { |_| false }
        Infomon.define_singleton_method(:set) { |k, v| puts "SET \#{k}=\#{v}" }
        do_client(';infomon sync')
        do_client(';infomon reset')
        do_client(';infomon show')
        do_client(';infomon show full')
        do_client(';infomon show FULL')
        do_client(';infomon effects')
      RUBY
      expect(out).to include('EXEC Infomon.sync')
      expect(out).to include('EXEC Infomon.redo!')
      expect(out).to include('SET infomon.show_durations=true')
      expect(out).to include('SHOW full=false') # bare ;infomon show
      # Both spellings of the argument ask for the complete listing. Before
      # this branch neither did: the capture included the leading space, so
      # " full" never equalled 'full'.
      expect(out.scan(/SHOW full=true/).length).to eq(2)
    end

    it 'passes ;sk arguments through to SK.main' do
      out = probe(<<~RUBY, game: 'GSIV')
        Object.const_set(:SK, Module.new) unless Object.const_defined?(:SK)
        SK.define_singleton_method(:main) { |a, b| puts "SK \#{a.inspect} \#{b.inspect}" }
        do_client(';sk add 1 2')
        do_client(';sk help')
        do_client(';sk')
      RUBY
      expect(out).to include('SK "add" "1 2"')
      expect(out).to include('SK "help" nil')
      expect(out).to include('SK nil nil')
    end
  end

  # DragonRealms-only branches, none of which run under a GS session.
  describe 'DragonRealms-only commands' do
    it 'toggles display flaguid' do
      out = probe(<<~RUBY, game: 'DR')
        Lich.define_singleton_method(:hide_uid_flag) { false }
        Lich.define_singleton_method(:hide_uid_flag=) { |v| puts "SET \#{v}" }
        do_client(';display flaguid')
      RUBY
      expect(out).to include('SET true')
      expect(out).to include('R:Changing Lich to NOT display Room Title RealIDs')
    end

    it 'shows and sets display roomid placement' do
      out = probe(<<~RUBY, game: 'DR')
        Lich.define_singleton_method(:display_roomid_location) { 'title' }
        Lich.define_singleton_method(:display_roomid_location=) { |v| puts "SET \#{v}" }
        do_client(';display roomid')
        do_client(';display roomid both')
      RUBY
      expect(out).to include('R:DragonRealms room id / RealID display placement is currently: title')
      expect(out).to include('SET both')
    end

    it 'routes the banks variants' do
      out = probe(<<~RUBY, game: 'DR')
        module Lich; module DragonRealms; module DRBanking
          %i[display_banks display_banks_all reset_character! reset_all!].each do |m|
            define_singleton_method(m) { puts "BANK \#{m}" }
          end
        end; end; end
        do_client(';banks')
        do_client(';banks all')
        do_client(';banks reset')
        do_client(';banks reset all')
      RUBY
      expect(out).to include('BANK display_banks')
      expect(out).to include('BANK display_banks_all')
      expect(out).to include('BANK reset_character!')
      expect(out).to include('BANK reset_all!')
    end

    it 'refuses display expgains while exp-monitor is running' do
      out = probe(<<~RUBY, game: 'DR')
        Object.send(:define_method, :running?) { |_| true }
        do_client(';display expgains')
      RUBY
      expect(out).to include('R:Error: exp-monitor.lic script is currently running')
    end

    it 'toggles display expgains and inlineexp when free to' do
      out = probe(<<~RUBY, game: 'DR')
        Object.send(:define_method, :running?) { |_| false }
        Lich.define_singleton_method(:display_expgains) { false }
        Lich.define_singleton_method(:display_expgains=) { |v| puts "EXPGAINS=\#{v}" }
        Object.const_set(:DRExpMonitor, Module.new) unless Object.const_defined?(:DRExpMonitor)
        DRExpMonitor.define_singleton_method(:start) { puts 'MON START' }
        DRExpMonitor.define_singleton_method(:stop) { puts 'MON STOP' }
        DRExpMonitor.define_singleton_method(:inline_display?) { false }
        DRExpMonitor.define_singleton_method(:inline_display=) { |v| puts "INLINE=\#{v}" }
        do_client(';display expgains on')
        do_client(';display expgains off')
        do_client(';display inlineexp')
      RUBY
      expect(out).to include('EXPGAINS=true')
      expect(out).to include('MON START')
      expect(out).to include('EXPGAINS=false')
      expect(out).to include('MON STOP')
      expect(out).to include('INLINE=true')
    end

    it 'shows the experience monitor status' do
      out = probe(<<~RUBY, game: 'DR')
        Lich.define_singleton_method(:display_expgains) { true }
        Object.const_set(:DRExpMonitor, Module.new) unless Object.const_defined?(:DRExpMonitor)
        DRExpMonitor.define_singleton_method(:inline_display?) { false }
        DRExpMonitor.define_singleton_method(:active?) { true }
        do_client(';display exp-status')
      RUBY
      expect(out).to include('R:DragonRealms Experience Monitor Status:')
      expect(out).to include('expgains:   ON')
      expect(out).to include('inlineexp:  OFF')
      expect(out).to include('reporter:   RUNNING')
    end
  end

  describe 'help' do
    it 'lists the built-in commands' do
      out = probe("do_client(';help')")
      expect(out).to include('R:Lich vtest')
      expect(out).to include('built-in commands:')
      expect(out).to include(';kd')
    end
  end

  # The chain is first-match-wins. These are the pairs where the patterns
  # GENUINELY overlap -- both match the same input -- so the earlier branch
  # must stay ahead of the later one or the behavior changes. Each was
  # confirmed by checking that both regexes match the test's input.
  #
  # Deliberately NOT here: ;execname vs ;exec and ;lt vs ;list. Those look
  # like ordering constraints and are not. /^(?:exec|e)(q)? (.+)$/ requires a
  # space (or "q" then a space) straight after e/exec, so it cannot match
  # "en job ..." or "execname job ..."; and /^list\s?(?:all)?$|^l(?:a)?$/
  # cannot match "lt" or "list trusted". Those two commands route correctly
  # at any position, so a test asserting the order would be green whatever
  # the order -- false confidence. They are pinned by output instead, in
  # 'starting scripts' and 'trust' below.
  describe 'branch ordering' do
    it 'prefers exact ;debuglogs over the invalid-argument catch' do
      out = probe(<<~RUBY)
        Lich.define_singleton_method(:max_debug_logs) { 7 }
        do_client(';debuglogs')
      RUBY
      expect(out).to include('Debug Log Retention')
      expect(out).not_to include('invalid argument')
    end

    it 'prefers ;l5u with an argument over the bare form' do
      out = probe(<<~RUBY)
        module Lich; module Util; module Update
          def self.request(arg) = puts("UPDATE \#{arg.inspect}")
        end; end; end
        do_client(';l5u --announce')
      RUBY
      expect(out).to include('UPDATE "--announce"')
      expect(out).not_to include('UPDATE "--help"')
    end

    it 'prefers ;force <name> <args> over ;force <name>' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:start) { |*a| puts "START \#{a.inspect}" }
        do_client(';force foo bar')
      RUBY
      expect(out).to include('"foo", "bar"')
    end

    it 'keeps every built-in ahead of the script-name catch-all' do
      out = probe(<<~RUBY)
        Script.define_singleton_method(:start) { |*a| puts "START \#{a.inspect}" }
        Script.define_singleton_method(:running) { [] }
        do_client(';list')
      RUBY
      expect(out).not_to include('START')
    end
  end
end
