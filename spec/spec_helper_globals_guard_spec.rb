# frozen_string_literal: true

require_relative 'spec_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# spec_helper fails any example or top-level group that leaves one of its
# globals holding a different object. These examples run a throwaway spec file
# through a child RSpec process, so the leaks they provoke never reach this
# process, and check what the guard reported and what the next group saw.
RSpec.describe 'spec_helper global leak guard' do
  probe_source = <<~'RUBY'
    # frozen_string_literal: true

    # Defined before spec_helper loads, as a spec file that does not require
    # spec_helper is when parallel_rspec loads it first in a worker.
    RSpec.describe 'early group' do
      before(:context) { $cmd_prefix = '<early>' }
      after(:context) { $SEND_CHARACTER = '?' }

      it('runs') { nil }
    end

    # spec_helper's around hook lands inside this group's own around hook, so
    # it would see the example's change before the outer hook restores it.
    RSpec.describe 'early group with an around' do
      around do |example|
        saved = $frontend
        example.run
      ensure
        $frontend = saved
      end

      it('leaks a global') { $_CLIENT_ = nil }

      context 'nested' do
        it('changes a global the outer around restores') { $frontend = 'wizard' }
      end
    end

    require ENV.fetch('GUARD_SPEC_HELPER')
    RSpec.configure { |config| config.example_status_persistence_file_path = nil }
    ORIGINAL_CLIENT = $_CLIENT_

    RSpec.describe 'after the early group' do
      it('sees the original prefix, send character and client') do
        expect([$cmd_prefix, $SEND_CHARACTER]).to eq(['', '>'])
        expect($_CLIENT_).to equal(ORIGINAL_CLIENT)
      end
    end

    RSpec.describe 'in place' do
      it('mutates the buffers in place') do
        $_SERVERBUFFER_ << 'line'
        $_CLIENTBUFFER_.replace(%w[a b])
      end

      it('swaps a global and restores it inside the example') do
        saved = $_CLIENT_
        $_CLIENT_ = Object.new
      ensure
        $_CLIENT_ = saved
      end
    end

    RSpec.describe 'around swap' do
      around do |example|
        saved = $frontend
        $frontend = 'wizard'
        example.run
      ensure
        $frontend = saved
      end

      it('sees the swapped value') { expect($frontend).to eq('wizard') }
    end

    RSpec.describe 'context swap' do
      before(:context) do
        @saved_prefix = $cmd_prefix
        $cmd_prefix = '<c>'
      end

      after(:context) { $cmd_prefix = @saved_prefix }

      it('sees the swapped value') { expect($cmd_prefix).to eq('<c>') }
    end

    RSpec.describe 'after leak' do
      after { $_CLIENT_ = nil }

      it('leaks') { nil }
    end

    RSpec.describe 'after the after leak' do
      it('sees the original client') { expect($_CLIENT_).to equal(ORIGINAL_CLIENT) }
    end

    RSpec.describe 'before context leak' do
      before(:context) { $cmd_prefix = '<c>' }

      it('runs') { nil }
    end

    RSpec.describe 'after the before context leak' do
      it('sees the original prefix') { expect($cmd_prefix).to eq('') }
    end

    RSpec.describe 'after context leak' do
      after(:context) { $SEND_CHARACTER = '!' }

      it('runs') { nil }
    end

    RSpec.describe 'after the after context leak' do
      it('sees the original send character') { expect($SEND_CHARACTER).to eq('>') }
    end
  RUBY

  # One child run serves every example below.
  cached_result = nil
  define_method(:probe_result) do
    cached_result ||= Dir.mktmpdir('guard-probe') do |dir|
      file = File.join(dir, 'guard_probe_spec.rb')
      File.write(file, probe_source)
      result = File.join(dir, 'result.json')
      # An empty options file stands in for ~/.rspec, .rspec and .rspec-local,
      # and SPEC_OPTS is cleared, so a developer's --fail-fast or extra
      # formatter cannot change what the probe runs or reports.
      options = File.join(dir, 'options')
      File.write(options, '')
      root = File.expand_path('..', __dir__)
      env = { 'GUARD_SPEC_HELPER' => File.expand_path('spec_helper.rb', __dir__), 'SPEC_OPTS' => nil }
      runner = 'require "rspec/core"; exit RSpec::Core::Runner.run(ARGV)'
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, '-e', runner, '--', file, '--options', options,
                                              '--format', 'json', '--out', result, '--order', 'defined', chdir: root)
      raise "guard probe wrote no results (#{status}):\n#{stdout}\n#{stderr}" unless File.exist?(result)

      JSON.parse(File.read(result))
    end
  end

  def status_of(full_description)
    example = probe_result['examples'].find { |e| e['full_description'] == full_description }
    raise "no probe example #{full_description.inspect}: #{Array(probe_result['messages']).join}" unless example

    [example['status'], example.dig('exception', 'message')]
  end

  it 'lets in-place mutation and in-example, around and context swap-and-restore pass' do
    expect(status_of('in place mutates the buffers in place').first).to eq('passed')
    expect(status_of('in place swaps a global and restores it inside the example').first).to eq('passed')
    expect(status_of('around swap sees the swapped value').first).to eq('passed')
    expect(status_of('context swap sees the swapped value').first).to eq('passed')
  end

  it 'fails an example whose after hook reassigns a global, naming it, and restores it for the next group' do
    status, message = status_of('after leak leaks')
    expect(status).to eq('failed')
    expect(message).to include('left $_CLIENT_ holding a different object')
    expect(status_of('after the after leak sees the original client').first).to eq('passed')
  end

  it 'reports a global reassigned in a before(:context) or after(:context) hook and restores it' do
    messages = Array(probe_result['messages']).join("\n")
    expect(probe_result['summary']['errors_outside_of_examples_count']).to eq(4)
    expect(messages).to match(/guard_probe_spec\.rb:\d+.*left \$cmd_prefix holding a different object/)
    expect(messages).to match(/guard_probe_spec\.rb:\d+.*left \$SEND_CHARACTER holding a different object/)
    expect(status_of('after the before context leak sees the original prefix').first).to eq('passed')
    expect(status_of('after the after context leak sees the original send character').first).to eq('passed')
  end

  it 'checks the context hooks of a group defined before spec_helper loaded' do
    messages = Array(probe_result['messages']).join("\n")
    expect(messages).to match(/guard_probe_spec\.rb:\d+.*left \$SEND_CHARACTER, \$cmd_prefix holding a different object/)
    expect(status_of('after the early group sees the original prefix, send character and client').first).to eq('passed')
  end

  it "judges a group defined before spec_helper loaded only after the group's own around hooks have run" do
    expect(status_of('early group with an around nested changes a global the outer around restores').first).to eq('passed')
    expect(status_of('early group with an around leaks a global').first).to eq('passed')
    expect(Array(probe_result['messages']).join("\n")).to match(/guard_probe_spec\.rb:\d+.*left \$_CLIENT_ holding a different object/)
  end
end
