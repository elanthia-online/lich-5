# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

RSpec.describe 'default WebUI entrypoint acceptance' do
  let(:root) { File.expand_path('../../..', __dir__) }
  let(:script) { File.join(root, 'spec/support/default_webui_acceptance_check.rb') }

  it 'authenticates the real page, exercises it, and shuts down without GTK' do
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, chdir: root)

    expect(status).to be_success, stderr
    result = JSON.parse(stdout)
    expect(result).to include(
      'verdict'                    => 'pass',
      'authenticated_http'         => true,
      'authenticated_websocket'    => true,
      'required_tabs'              => ['Saved Entry', 'Manual Entry', 'Account Management', 'Frontends'],
      'interaction'                => 'GUI Settings changed from hidden to visible',
      'launcher_start_replaced'    => false,
      'launcher_await_replaced'    => false,
      'entrypoint_argv'            => [],
      'clean_shutdown'             => true,
      'exit_status'                => 0,
      'gtk_family_loaded_features' => [],
      'escaped_roots'              => {}
    )
    expect(result.fetch('effective_roots').keys).to include(
      'LICH_DIR', 'DATA_DIR', 'TEMP_DIR', 'SCRIPT_DIR', 'MAP_DIR', 'LOG_DIR', 'BACKUP_DIR', 'working_directory'
    )
    expect(result.fetch('launcher_start_source')).to match(%r{\Alib/common/webui_launcher\.rb:\d+\z})
    expect(result.fetch('launcher_await_source')).to match(%r{\Alib/common/webui_launcher\.rb:\d+\z})
  end

  it 'prints a verdict when the entrypoint exits between the liveness check and the group signal' do
    Dir.mktmpdir('lich-acceptance-race') do |dir|
      # The entrypoint lingers after its report, so the supervisor reaches its
      # signal loop; the stubbed group kill delivers the signal, waits until the
      # group is gone, then raises ESRCH as a lost exit-versus-kill race would.
      linger = File.join(dir, 'linger.rb')
      File.write(linger, "at_exit { sleep 30 }\n")
      race = File.join(dir, 'race.rb')
      File.write(race, <<~RUBY)
        require 'open3'
        module AcceptanceRacePopen
          def popen2e(env, *args, **options)
            super(env.merge('RUBYOPT' => "\#{env['RUBYOPT']} -r#{linger}"), *args, **options)
          end
        end
        Open3.singleton_class.prepend(AcceptanceRacePopen)
        module AcceptanceRaceWait
          def join(limit = nil) = super(limit == 10 ? 1 : limit)
        end
        Process::Waiter.prepend(AcceptanceRaceWait)
        module AcceptanceRaceKill
          def kill(signal, pid)
            return super unless pid.is_a?(Integer) && pid.negative?

            super
            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
            loop do
              super(0, pid)
              raise 'group outlived the race window' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

              sleep 0.05
            end
          rescue Errno::ESRCH
            raise Errno::ESRCH
          end
        end
        Process.singleton_class.prepend(AcceptanceRaceKill)
      RUBY
      stdout, stderr, = Open3.capture3(RbConfig.ruby, '-r', race, script, chdir: root)

      expect(stderr).not_to include('Errno::ESRCH')
      result = JSON.parse(stdout.lines.last.to_s)
      expect(result).to include('verdict', 'exit_status', 'term_signal', 'escaped_roots')
      expect(result.fetch('term_signal')).to eq(Signal.list.fetch('TERM'))
    end
  end
end
