# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../../../spec_helper'
require_relative '../../../support/drexpmonitor_reporters'

# Load dependencies in correct order
require_relative '../../../../lib/dragonrealms/drinfomon/drvariables'
require_relative '../../../../lib/dragonrealms/drinfomon/drskill'

# Load the module under test
require_relative '../../../../lib/dragonrealms/drinfomon/drexpmonitor'

RSpec.describe Lich::DragonRealms::DRExpMonitor do
  # Reference the real DRSkill class for specs that need it
  let(:drskill_class) { Lich::DragonRealms::DRSkill }

  before(:each) do
    # Reset state before each test
    described_class.stop if described_class.active?
    described_class.reset!
    # NOTE: class_variable_set is acceptable here because drskill_class.reset! also clears
    # @@list (all skill definitions), which would break tests that rely on real DRSkill data.
    # We only need to clear @@gained_skills to isolate the DRExpMonitor tests.
    drskill_class.class_variable_set(:@@gained_skills, [])
    Lich::Messaging.clear_messages!
    Lich.db.reset! if Lich.db.respond_to?(:reset!)
    Lich.reset_display_expgains! if Lich.respond_to?(:reset_display_expgains!)
  end

  after(:each) do
    described_class.stop if described_class.active?
  end

  describe '.start' do
    it 'starts the reporter thread' do
      described_class.start
      expect(described_class.active?).to be true
    end

    it 'does not start if already running' do
      described_class.start
      Lich::Messaging.clear_messages!

      described_class.start

      expect(Lich::Messaging.messages.last[:message]).to include('already active')
    end

    it 'does not start if exp-monitor script is running' do
      allow(Script).to receive(:running?).with('exp-monitor').and_return(true)

      described_class.start

      expect(described_class.active?).to be false
      expect(Lich::Messaging.messages.last[:message]).to include('exp-monitor')
    end
  end

  describe '.stop' do
    it 'stops the reporter thread' do
      described_class.start
      expect(described_class.active?).to be true

      described_class.stop
      expect(described_class.active?).to be false
    end

    it 'handles stop when already stopped' do
      described_class.stop

      expect(Lich::Messaging.messages.last[:message]).to include('already inactive')
    end
  end

  describe '.active?' do
    it 'returns false when not started' do
      expect(described_class.active?).to be false
    end

    it 'returns true when started' do
      described_class.start
      expect(described_class.active?).to be true
    end
  end

  describe '.inline_display?' do
    it 'defaults to false when no DB value exists' do
      expect(described_class.inline_display?).to be false
    end

    it 'returns false when DB value is false' do
      Lich.db.execute("INSERT INTO lich_settings VALUES ('display_inline_exp', ?)", ['false'])
      described_class.reset!

      expect(described_class.inline_display?).to be false
    end

    it 'returns true when DB value is true' do
      Lich.db.execute("INSERT INTO lich_settings VALUES ('display_inline_exp', ?)", ['true'])
      described_class.reset!

      expect(described_class.inline_display?).to be true
    end
  end

  describe '.inline_display=' do
    it 'sets inline display to true' do
      described_class.inline_display = true
      expect(described_class.inline_display?).to be true
    end

    it 'sets inline display to false' do
      described_class.inline_display = false
      expect(described_class.inline_display?).to be false
    end

    it 'accepts string values' do
      described_class.inline_display = 'on'
      expect(described_class.inline_display?).to be true

      described_class.inline_display = 'off'
      expect(described_class.inline_display?).to be false
    end

    it 'persists to database' do
      described_class.inline_display = true
      expect(Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='display_inline_exp'")).to eq('true')
    end
  end

  describe 'constants' do
    describe 'MAX_SQLITE_RETRIES' do
      it 'is defined as 10 (BUG FIX: prevents infinite retry loops)' do
        expect(described_class::MAX_SQLITE_RETRIES).to eq(10)
      end
    end

    describe 'BOOLEAN_TRUE_PATTERN' do
      it 'matches "on" exactly' do
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('on')).to be true
      end

      it 'matches "true" exactly' do
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('true')).to be true
      end

      it 'matches "yes" exactly' do
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('yes')).to be true
      end

      it 'matches case-insensitively' do
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('ON')).to be true
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('TRUE')).to be true
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('YES')).to be true
      end

      it 'does not match partial strings (BUG FIX)' do
        # Before fix, /on|true|yes/ would match "money" or "trust"
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('money')).to be false
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('trust')).to be false
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('yesman')).to be false
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('ongoing')).to be false
      end

      it 'does not match "off", "false", "no"' do
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('off')).to be false
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('false')).to be false
        expect(described_class::BOOLEAN_TRUE_PATTERN.match?('no')).to be false
      end
    end
  end

  describe '.format_briefexp_on' do
    before do
      described_class.inline_display = true
    end

    it 'appends gained exp to BRIEFEXP ON format' do
      allow(drskill_class).to receive(:gained_exp).with('Augmentation').and_return(0.15)
      line = '     Aug:  565 39%  [ 2/34]'

      result = described_class.format_briefexp_on(line, 'Augmentation')

      expect(result).to eq('     Aug:  565 39%  [ 2/34] 0.15')
    end

    it 'shows 0.00 when no gains' do
      allow(drskill_class).to receive(:gained_exp).with('Augmentation').and_return(0.00)
      line = '     Aug:  565 39%  [ 2/34]'

      result = described_class.format_briefexp_on(line, 'Augmentation')

      expect(result).to eq('     Aug:  565 39%  [ 2/34] 0.00')
    end

    it 'returns line unchanged when inline_display is off' do
      described_class.inline_display = false
      line = '     Aug:  565 39%  [ 2/34]'

      result = described_class.format_briefexp_on(line, 'Augmentation')

      expect(result).to eq(line)
    end

    it 'handles various skill mindstates' do
      allow(drskill_class).to receive(:gained_exp).with('Evasion').and_return(1.23)
      line = '    Evas:  800 75%  [34/34]'

      result = described_class.format_briefexp_on(line, 'Evasion')

      expect(result).to eq('    Evas:  800 75%  [34/34] 1.23')
    end
  end

  describe '.format_briefexp_off' do
    before do
      described_class.inline_display = true
    end

    it 'appends gained exp to BRIEFEXP OFF format' do
      allow(drskill_class).to receive(:gained_exp).with('Augmentation').and_return(0.15)
      line = '    Augmentation:  565 39% learning     '

      result = described_class.format_briefexp_off(line, 'Augmentation', 'learning')

      expect(result).to include('0.15')
    end

    it 'pads the learning rate word' do
      allow(drskill_class).to receive(:gained_exp).with('Augmentation').and_return(0.15)
      line = '    Augmentation:  565 39% clear        '

      result = described_class.format_briefexp_off(line, 'Augmentation', 'clear')

      # Should pad 'clear' to match longest rate word length
      expect(result).to include('clear')
      expect(result).to include('0.15')
    end

    it 'returns line unchanged when inline_display is off' do
      described_class.inline_display = false
      line = '    Augmentation:  565 39% learning     '

      result = described_class.format_briefexp_off(line, 'Augmentation', 'learning')

      expect(result).to eq(line)
    end
  end

  describe '.format_gains' do
    it 'formats single skill gain' do
      gains = [{ skill: 'Evasion', change: 2 }]

      result = described_class.format_gains(gains)

      expect(result).to eq(['Evasion(+2)'])
    end

    it 'formats multiple skill gains' do
      gains = [
        { skill: 'Evasion', change: 2 },
        { skill: 'Parry Ability', change: 1 }
      ]

      result = described_class.format_gains(gains)

      expect(result).to contain_exactly('Evasion(+2)', 'Parry Ability(+1)')
    end

    it 'aggregates multiple gains for same skill' do
      gains = [
        { skill: 'Evasion', change: 2 },
        { skill: 'Evasion', change: 3 },
        { skill: 'Parry Ability', change: 1 }
      ]

      result = described_class.format_gains(gains)

      expect(result).to contain_exactly('Evasion(+5)', 'Parry Ability(+1)')
    end

    it 'returns empty array for no gains' do
      result = described_class.format_gains([])

      expect(result).to eq([])
    end

    it 'sorts gains alphabetically by skill name' do
      gains = [
        { skill: 'Parry Ability', change: 1 },
        { skill: 'Evasion', change: 2 },
        { skill: 'Athletics', change: 3 }
      ]

      result = described_class.format_gains(gains)

      expect(result).to eq(['Athletics(+3)', 'Evasion(+2)', 'Parry Ability(+1)'])
    end
  end

  describe '.report_skill_gains' do
    it 'reports gains and clears the queue' do
      drskill_class.gained_skills << { skill: 'Evasion', change: 2 }
      drskill_class.gained_skills << { skill: 'Parry Ability', change: 1 }

      described_class.report_skill_gains

      expect(Lich::Messaging.messages.last[:message]).to include('DRExpMonitor:')
      expect(Lich::Messaging.messages.last[:message]).to include('Evasion(+2)')
      expect(drskill_class.gained_skills).to be_empty
    end

    it 'does not report when no gains' do
      Lich::Messaging.clear_messages!

      described_class.report_skill_gains

      expect(Lich::Messaging.messages).to be_empty
    end
  end

  describe 'thread safety' do
    # Use fully qualified name inside threads since described_class isn't available in thread scope
    let(:expmonitor) { Lich::DragonRealms::DRExpMonitor }

    it 'handles concurrent start calls without error' do
      klass = expmonitor
      threads = 5.times.map do
        Thread.new { klass.start }
      end

      expect { threads.each(&:join) }.not_to raise_error
      expect(described_class.active?).to be true
    end

    it 'handles concurrent stop calls without error' do
      described_class.start
      expect(described_class.active?).to be true

      klass = expmonitor
      threads = 5.times.map do
        Thread.new { klass.stop }
      end

      expect { threads.each(&:join) }.not_to raise_error
      expect(described_class.active?).to be false
    end

    it 'handles concurrent start and stop calls without error' do
      klass = expmonitor
      threads = []

      # Alternate start/stop calls from different threads
      5.times do |i|
        threads << Thread.new do
          if i.even?
            klass.start
          else
            klass.stop
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end

    it 'does not leave mutex locked after exception in start' do
      # Stub Script.running? to raise an exception
      allow(Script).to receive(:running?).and_raise(StandardError.new("test error"))

      expect { described_class.start rescue nil }.not_to raise_error

      # Should be able to call stop without deadlock
      expect { described_class.stop }.not_to raise_error
    end
  end

  # Each start opens a new generation, and a reporter thread only acts while
  # its own generation is current. These pin what that buys: a stopped
  # thread, which dies some time after stop returns, can no longer switch off
  # the reporter that replaced it.
  describe 'reporter generations' do
    let(:repo_root) { File.expand_path('../../../..', __dir__) }

    # The reporter pauses 1 s between passes. A shorter pause lets these
    # examples wait out several full passes without seconds of fixed sleeps.
    # The waits below are multiples of it.
    let(:interval) { 0.05 }

    around do |example|
      original = described_class.class_variable_get(:@@report_interval)
      described_class.class_variable_set(:@@report_interval, interval)
      example.run
    ensure
      described_class.class_variable_set(:@@report_interval, original)
    end

    def reporter_threads
      DRExpMonitorReporters.threads
    end

    def wait_for(seconds = 5)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      until yield
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.02
      end
      true
    end

    def start_and_capture_thread
      described_class.start
      expect(wait_for { reporter_threads.size == 1 }).to be(true)
      reporter_threads.first
    end

    def reported?(text)
      Lich::Messaging.messages.any? { |m| m[:message].include?(text) }
    end

    after(:each) do
      described_class.stop if described_class.active?
      reporter_threads.each(&:kill).each { |t| t.join(2) }
    end

    it 'keeps the replacement running when stop and start run back to back' do
      old = start_and_capture_thread

      described_class.stop
      described_class.start
      expect(old.join(2)).not_to be_nil # the stopped thread and its ensure have run

      expect(described_class.active?).to be(true)
      expect(reporter_threads.size).to eq(1)
      drskill_class.gained_skills << { skill: 'Evasion', change: 1 }
      expect(wait_for { reported?('DRExpMonitor: Evasion(+1)') }).to be(true)
    end

    it 'survives a burst of off/on pairs with exactly one reporter' do
      start_and_capture_thread
      3.times do
        described_class.stop
        described_class.start
      end

      # Let the stopped threads finish dying, then let the survivor pass the
      # loop check a stale ensure would have tripped.
      expect(wait_for { reporter_threads.size <= 1 }).to be(true)
      sleep interval * 4

      expect(described_class.active?).to be(true)
      expect(reporter_threads.size).to eq(1)
      drskill_class.gained_skills << { skill: 'Athletics', change: 2 }
      expect(wait_for { reported?('DRExpMonitor: Athletics(+2)') }).to be(true)
    end

    it 'stops cleanly after an off/on pair' do
      old = start_and_capture_thread
      described_class.stop
      described_class.start
      old.join(2)

      described_class.stop

      expect(described_class.active?).to be(false)
      expect(wait_for { reporter_threads.empty? }).to be(true)
    end

    it 'marks reporting off when the reporter dies on its own' do
      fatal = Class.new(Exception) # rubocop:disable Lint/InheritException
      raised = Queue.new
      allow(described_class).to receive(:report_skill_gains) do
        Thread.current.report_on_exception = false
        raised << true
        raise fatal
      end

      described_class.start
      raised.pop

      expect(wait_for { !described_class.active? }).to be(true)

      # And a later start is not refused as "already active"
      allow(described_class).to receive(:report_skill_gains).and_call_original
      Lich::Messaging.clear_messages!
      described_class.start
      expect(described_class.active?).to be(true)
      expect(reported?('already active')).to be(false)
    end

    # A reporter started by an older copy of this file, before an in-session
    # update and `;hmr`, ends with an unconditional `@@running = false`. That
    # clears the flag without bumping the generation, and active? must still
    # agree with what is actually running.
    it 'stops reporting when reporting is marked off without a generation bump' do
      old = start_and_capture_thread

      described_class.class_variable_set(:@@running, false)

      expect(old.join(interval * 20)).not_to be_nil
      expect(described_class.active?).to be(false)
      drskill_class.gained_skills << { skill: 'Evasion', change: 1 }
      sleep interval * 4
      expect(reported?('Evasion(+1)')).to be(false)

      # And `;display expgains on` brings back exactly one reporter
      described_class.start
      expect(described_class.active?).to be(true)
      expect(wait_for { reported?('DRExpMonitor: Evasion(+1)') }).to be(true)
      expect(reporter_threads.size).to eq(1)
    end

    context 'with the reporter in a long pause' do
      # Long enough that a reporter left to run is still asleep when the join
      # below gives up, so only a kill ends it in time.
      let(:interval) { 30 }

      it 'kills the reporter on reset! instead of leaving it to run' do
        old = start_and_capture_thread

        described_class.reset!

        expect(old.join(2)).not_to be_nil
        expect(described_class.active?).to be(false)
      end
    end

    # `;hmr drinfomon` re-runs drexpmonitor.rb and then drinfomon.rb, whose
    # autostart calls start again. Reloading in this process would leave the
    # reloaded file's constants behind, so each case runs in a child process
    # with the real files.
    describe 'after a hot reload' do
      def run_child(body)
        source = <<~RUBY
          $VERBOSE = nil
          require './spec/spec_helper'
          require 'common/hmr'
          require './spec/support/drexpmonitor_reporters'
          Object.send(:define_method, :respond) { |*| nil }
          # The reload resets @@report_interval to 1 s, so shorten the
          # reporter's pause with a prepend on the module, which survives it.
          module Lich; module DragonRealms; module DRExpMonitor; end; end; end
          Lich::DragonRealms::DRExpMonitor.singleton_class.prepend(Module.new do
            private def sleep(*) = super(#{interval})
          end)
          def reporters = DRExpMonitorReporters.threads.size
          def wait_until(seconds = 5)
            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
            sleep 0.02 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          end
          #{body}
        RUBY
        out = err = nil
        status = nil
        Open3.popen3(RbConfig.ruby, "-I#{File.join(repo_root, 'lib')}", '-e', source, chdir: repo_root) do |stdin, stdout, stderr, wait|
          stdin.close
          reader = Thread.new { [stdout.read, stderr.read] }
          unless wait.join(30)
            Process.kill('KILL', wait.pid)
            raise 'hot reload child timed out'
          end
          out, err = reader.value
          status = wait.value
        end
        raise "hot reload child failed:\n#{err}" unless status.success?

        out
      end

      it 'keeps a single reporter through `;hmr drinfomon`' do
        out = run_child(<<~RUBY)
          Lich.display_expgains = true
          require 'dragonrealms/drinfomon'
          sleep 0.2
          Lich::Messaging.clear_messages!
          Lich::Common::HMR.reload(%r{dragonrealms/drinfomon})
          sleep #{interval * 6} # past one full loop of any orphaned reporter
          puts "REPORTERS=\#{reporters}"
          puts "ACTIVE=\#{Lich::DragonRealms::DRExpMonitor.active?}"
          puts "MESSAGES=\#{Lich::Messaging.messages.map { |m| m[:message] }.inspect}"
          Lich::DragonRealms::DRSkill.gained_skills << { skill: 'Evasion', change: 1 }
          wait_until { Lich::Messaging.messages.any? { |m| m[:message].include?('Evasion(+1)') } }
          sleep #{interval * 6} # a second reporter would have drained and reported by now
          puts "REPORTS=\#{Lich::Messaging.messages.count { |m| m[:message].include?('Evasion(+1)') }}"
        RUBY

        expect(out).to include('REPORTERS=1')
        expect(out).to include('ACTIVE=true')
        expect(out).not_to include('already active')
        expect(out).to include('REPORTS=1')
      end

      it 'leaves reporting off through `;hmr drinfomon` when it was off' do
        out = run_child(<<~RUBY)
          Lich.display_expgains = false
          require 'dragonrealms/drinfomon'
          Lich::Common::HMR.reload(%r{dragonrealms/drinfomon})
          sleep 0.2
          puts "REPORTERS=\#{reporters}"
          puts "ACTIVE=\#{Lich::DragonRealms::DRExpMonitor.active?}"
        RUBY

        expect(out).to include('REPORTERS=0')
        expect(out).to include('ACTIVE=false')
      end

      it 'keeps owning the running reporter after reloading only drexpmonitor.rb' do
        out = run_child(<<~RUBY)
          require 'dragonrealms/drinfomon/drvariables'
          require 'dragonrealms/drinfomon/drskill'
          require 'dragonrealms/drinfomon/drexpmonitor'
          Lich::DragonRealms::DRExpMonitor.start
          sleep 0.2
          Lich::Common::HMR.reload(%r{drinfomon/drexpmonitor})
          puts "ACTIVE=\#{Lich::DragonRealms::DRExpMonitor.active?}"
          Lich::DragonRealms::DRExpMonitor.start # ;display expgains on
          Lich::DragonRealms::DRExpMonitor.stop  # ;display expgains off
          wait_until { reporters.zero? }
          puts "REPORTERS=\#{reporters}"
        RUBY

        expect(out).to include('ACTIVE=true')
        expect(out).to include('REPORTERS=0')
      end

      it 'registers its exit hook once however many times it is reloaded' do
        out = run_child(<<~RUBY)
          $exit_hooks = 0
          Object.prepend(Module.new do
            private def at_exit(&)
              $exit_hooks += 1 if caller_locations(1, 1)[0].path.include?('drinfomon/drexpmonitor.rb')
              super
            end
          end)
          require 'dragonrealms/drinfomon'
          3.times { Lich::Common::HMR.reload(%r{dragonrealms/drinfomon}) }
          puts "EXIT_HOOKS=\#{$exit_hooks}"
        RUBY

        expect(out).to include('EXIT_HOOKS=1')
      end

      it 'stops a running reporter on exit after reloads' do
        # at_exit hooks run last-registered first, so this one, registered
        # before the file loads, reports after the module's own hook has run.
        out = run_child(<<~RUBY)
          at_exit do
            inactive = Lich::Messaging.messages.count { |m| m[:message].include?('already inactive') }
            puts "ACTIVE_AT_END=\#{Lich::DragonRealms::DRExpMonitor.active?} INACTIVE_MSGS=\#{inactive}"
          end
          Lich.display_expgains = true
          require 'dragonrealms/drinfomon'
          3.times { Lich::Common::HMR.reload(%r{dragonrealms/drinfomon}) }
          puts "ACTIVE=\#{Lich::DragonRealms::DRExpMonitor.active?}"
        RUBY

        expect(out).to include('ACTIVE=true')
        expect(out).to include('ACTIVE_AT_END=false INACTIVE_MSGS=0')
      end

      it 'prints nothing on exit after reloads when reporting is off' do
        out = run_child(<<~RUBY)
          at_exit do
            inactive = Lich::Messaging.messages.count { |m| m[:message].include?('already inactive') }
            puts "INACTIVE_MSGS=\#{inactive}"
          end
          Lich.display_expgains = false
          require 'dragonrealms/drinfomon'
          3.times { Lich::Common::HMR.reload(%r{dragonrealms/drinfomon}) }
        RUBY

        expect(out).to include('INACTIVE_MSGS=0')
      end
    end
  end
end
