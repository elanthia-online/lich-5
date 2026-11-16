# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/gemcheck'

RSpec.describe 'init.rb late-load dependency recovery' do
  let(:init_path) { File.expand_path('../../lib/init.rb', __dir__) }
  let(:source) { File.read(init_path) }
  let(:loader) { Object.new }

  # Execute the real boot blocks without loading the rest of the application.
  # Only the failed native require, recovery result and native dialog are seams.
  { 'sqlite3' => :default, 'gtk3' => :gtk }.each do |gem_name, group|
    describe "the #{gem_name} recovery path" do
      let(:recovery_block) do
        block = if gem_name == 'sqlite3'
                  source[/^begin\n  require 'sqlite3'\n.*?(?=^unless ARGV.any\?)/m]
                else
                  source[/^unless ARGV.any\?.*?(?=^unless File.exist\?\(LICH_DIR\))/m]
                end
        raise "could not extract the #{gem_name} recovery block" unless block

        block
      end

      before do
        stub_const('RUBY_PLATFORM', 'x64-mingw-ucrt')
        stub_const('ARGV', [])
        allow(loader).to receive(:require).with(gem_name).and_raise(LoadError, 'fixture native extension unavailable')
        allow(Lich::GemCheck).to receive(:self_healing_supported?).and_return(true)
        allow(Lich::GemCheck).to receive(:write_log)
        expect(Lich::GemCheck).to receive(:recover_with_consent!).with([gem_name], force: true, groups: [group]).and_return(result)
      end

      context 'when staging times out' do
        let(:result) { Lich::DependencyRecovery::Result.new(installed_gems: [], error: 'fixture staging timed out', error_kind: :timeout) }

        it 'preserves the timeout diagnostic and suppresses the installer link' do
          expect(Lich::GemCheck).to receive(:write_log).with(
            missing: [gem_name], groups: [group], error: an_instance_of(Lich::DependencyRecovery::StagingTimeoutError)
          )
          expect(Lich::GemCheck).to receive(:alert_windows) do |body, download:|
            expect(body).to include('download timed out', 'Check your connection and retry', result.error, gem_name)
            expect(body).not_to include("You're missing required Ruby gems", 'Ruby4Lich5 installer')
            expect(download).to be(false)
          end
          expect { loader.instance_eval(recovery_block, init_path) }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
        end
      end

      context 'when recovery fails without a timeout' do
        let(:result) { Lich::DependencyRecovery::Result.new(installed_gems: [], error: 'fixture package installation failed') }

        it 'retains ordinary repair guidance and the underlying failure' do
          expect(Lich::GemCheck).to receive(:alert_windows) do |body, download:|
            expect(body).to include("You're missing required Ruby gems", result.error, gem_name)
            expect(download).to be(true)
          end
          expect { loader.instance_eval(recovery_block, init_path) }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
        end
      end

      context 'when recovery schedules a restart' do
        let(:result) { Lich::DependencyRecovery::Result.new(installed_gems: [], restart_required: true) }

        it 'exits successfully without an error alert' do
          expect(Lich::GemCheck).not_to receive(:alert)
          expect { loader.instance_eval(recovery_block, init_path) }.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
        end
      end

      context 'when recovery schedules a restart for a one-shot command' do
        let(:result) { Lich::DependencyRecovery::Result.new(installed_gems: [], restart_required: true) }

        it 'asks for a rerun and exits 1 because the command did not run' do
          stub_const('ARGV', ['--change-master-password', 'old', 'new'])
          expect(Lich::GemCheck).not_to receive(:alert)

          expect { expect { loader.instance_eval(recovery_block, init_path) }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) } }
            .to output(/Your command did not run/).to_stdout
        end
      end

      context 'when recovery is declined' do
        let(:result) { nil }

        it 'stops without adding a second alert' do
          expect(Lich::GemCheck).not_to receive(:alert)
          expect { loader.instance_eval(recovery_block, init_path) }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
        end
      end
    end
  end
end
