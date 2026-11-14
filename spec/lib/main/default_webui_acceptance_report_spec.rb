# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../support/default_webui_acceptance_report'
require 'open3'
require 'rbconfig'
require 'tmpdir'

RSpec.describe DefaultWebUIAcceptanceReport do
  around do |example|
    Dir.mktmpdir('lich acceptance report ') do |directory|
      @report_path = File.join(directory, 'report.json')
      example.run
    end
  end

  it 'receives a complete record from a child without inherited report descriptors' do
    helper = File.expand_path('../../support/default_webui_acceptance_report.rb', __dir__)
    code = 'DefaultWebUIAcceptanceReport.publish(ARGV.fetch(0), { "verdict" => "pass", "payload" => "x" * 100_000 })'
    Open3.popen3(RbConfig.ruby, '-r', helper, '-e', code, @report_path) do |stdin, stdout, stderr, waiter|
      stdin.close
      raw = described_class.receive(@report_path, waiter, timeout: 5)
      expect(waiter.join(5)).not_to be_nil
      expect(waiter.value).to be_success, stderr.read
      expect(JSON.parse(raw)).to eq('verdict' => 'pass', 'payload' => 'x' * 100_000)
      expect(stdout.read).to eq('')
      expect(File.exist?("#{@report_path}.pending")).to be false
    ensure
      Process.kill('KILL', waiter.pid) if waiter&.alive?
    end
  end

  it 'ignores an incomplete pending record and bounds a live child wait' do
    File.write("#{@report_path}.pending", '{"verdict":')
    waiter = Thread.new { sleep 5 }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(described_class.receive(@report_path, waiter, timeout: 0.05)).to be_nil
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
    expect(File.exist?(@report_path)).to be false
  ensure
    waiter&.kill&.join
  end

  it 'returns promptly when the child exits without publishing' do
    waiter = Thread.new {}.tap(&:join)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(described_class.receive(@report_path, waiter, timeout: 5)).to be_nil
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
  end

  it 'retains a report published immediately before child exit' do
    described_class.publish(@report_path, 'verdict' => 'fail', 'error' => 'fixture failure')
    waiter = Thread.new {}.tap(&:join)
    expect(JSON.parse(described_class.receive(@report_path, waiter)))
      .to eq('verdict' => 'fail', 'error' => 'fixture failure')
  end

  it 'retains publication between the initial file check and the child exit check' do
    helper = File.expand_path('../../support/default_webui_acceptance_report.rb', __dir__)
    release = "#{@report_path}.release"
    code = <<~RUBY
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      until File.file?(ARGV.fetch(1))
        raise 'publisher release timeout' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 0.01
      end
      DefaultWebUIAcceptanceReport.publish(ARGV.fetch(0), 'verdict' => 'pass')
    RUBY
    Open3.popen3(RbConfig.ruby, '-r', helper, '-e', code, @report_path, release) do |stdin, stdout, stderr, waiter|
      stdin.close
      # Synchronize only the exit observation: both file checks and publication
      # use real files, and super observes the actual exited Open3 child waiter.
      waiter.define_singleton_method(:alive?) do
        File.write(release, 'release publisher')
        raise 'publisher exit timeout' unless join(5)

        super()
      end
      raw = described_class.receive(@report_path, waiter, timeout: 5)
      expect(waiter.value).to be_success, stderr.read
      expect(raw).not_to be_nil
      expect(JSON.parse(raw)).to eq('verdict' => 'pass')
      expect(stdout.read).to eq('')
    ensure
      Process.kill('KILL', waiter.pid) if waiter&.status
    end
  end
end
