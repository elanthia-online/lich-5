# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../../spec_helper'
# The registry module alone is safe to load in-process: unlike
# global_defs.rb it defines no top-level methods. Loading the built-ins
# table is what needs a subprocess, and that happens inside probe.
require 'common/client_commands'

# The registry itself: registration, ordering, game gating, and -- the part
# with teeth -- what happens when the built-ins file is loaded a second time.
#
# Run in a child process for the same reason spec/lib/do_client_spec.rb is:
# loading global_defs.rb in-process redefines the script-facing DSL against
# production game infrastructure.
RSpec.describe Lich::Common::ClientCommands do
  def probe(body, game: 'GSIV')
    root = File.expand_path('../../..', __dir__)
    source = <<~RUBY
      require './spec/spec_helper'
      require 'common/detachable_client_registry'

      $lich_char_regex = /;/
      $clean_lich_char = ';'
      $cmd_prefix = '<c>'
      $_CLIENTBUFFER_ = []
      Object.const_set(:LICH_VERSION, 'test') unless Object.const_defined?(:LICH_VERSION)
      Lich.const_set(:MAX_DEBUG_LOGS_DEFAULT, 10) unless Lich.const_defined?(:MAX_DEBUG_LOGS_DEFAULT)

      require './lib/global_defs'

      XMLData.define_singleton_method(:game) { #{game.inspect} }
      UpstreamHook.define_singleton_method(:run) { |line| line }
      Object.send(:define_method, :respond) { |message = nil, *| puts("R:\#{message}") }
      Object.send(:define_method, :new_upstream) { |_line| nil }
      Script.define_singleton_method(:new_upstream) { |_line| nil }
      Script.define_singleton_method(:running) { [] }

      REGISTRY = Lich::Common::ClientCommands
      BUILTINS = File.join(Dir.pwd, 'lib', 'common', 'client_commands', 'builtins.rb')

      #{body}
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, "-I#{File.join(root, 'lib')}", '-e', source, :chdir => root)
    raise "probe failed:\n#{err}" unless status.success?

    out
  end

  describe 'reloading the built-ins' do
    # HMR.reload calls load(), and load() re-executes the file body. Before
    # ClientCommands.define existed, every command() call appended, so a
    # reload doubled the table and left the OLD handlers in front -- an
    # edited built-in was loaded and then never ran. Caught in review of the
    # refactor PR; this is the regression guard.
    it 'rebuilds the table rather than appending a second copy' do
      out = probe(<<~RUBY)
        puts "BEFORE=\#{REGISTRY.commands.length}"
        load BUILTINS
        puts "AFTER=\#{REGISTRY.commands.length}"
      RUBY
      before = out[/BEFORE=(\d+)/, 1].to_i
      after  = out[/AFTER=(\d+)/, 1].to_i
      expect(before).to be > 0
      expect(after).to eq(before)
    end

    it 'dispatches to the reloaded handler, not the original' do
      # The edited copy goes to a Tempfile, never over the tracked
      # builtins.rb: writing the real file and restoring it in an ensure
      # leaves it corrupted if the process is killed between the two writes,
      # and races any parallel runner sharing the checkout. load() cares
      # about the body, not the path -- builtins.rb's only require resolves
      # through LIB_DIR -- so a temp copy exercises the same reload path.
      out = probe(<<~RUBY)
        require 'tempfile'

        original = File.read(BUILTINS)
        edited = original.sub(
          "        command(/^k$|^kill$|^stop$/) do\\n",
          "        command(/^k$|^kill$|^stop$/) do\\n          respond 'EDITED HANDLER'\\n"
        )
        raise 'fixture edit did not apply' if edited == original

        Tempfile.create(['builtins', '.rb']) do |f|
          f.write(edited)
          f.flush
          load f.path
          do_client(';k')
        end
      RUBY
      expect(out).to include('R:EDITED HANDLER')
    end

    it 'leaves the previous table in place when registration raises' do
      out = probe(<<~RUBY)
        before = REGISTRY.commands.length
        begin
          REGISTRY.define do
            REGISTRY.command(/^zzz$/) { nil }
            raise 'boom'
          end
        rescue RuntimeError
          nil
        end
        puts "AFTER=\#{REGISTRY.commands.length} SAME=\#{REGISTRY.commands.length == before}"
        do_client(';k')
      RUBY
      expect(out).to include('SAME=true')
      # The old table is not just the right size, it still works.
      expect(out).to include('R:--- Lich: no scripts to kill')
    end

    it 'refuses a registration made outside a define block' do
      out = probe(<<~RUBY)
        begin
          REGISTRY.command(/^zzz$/) { nil }
          puts 'NO RAISE'
        rescue RuntimeError => e
          puts "RAISED=\#{e.message}"
        end
      RUBY
      expect(out).to include('RAISED=ClientCommands.command must be called inside ClientCommands.define')
    end
  end

  describe 'dispatch' do
    it 'reports whether a command claimed the input' do
      out = probe(<<~RUBY)
        puts "known=\#{REGISTRY.dispatch('help')}"
        puts "unknown=\#{REGISTRY.dispatch('no-such-command-here')}"
      RUBY
      expect(out).to include('known=true')
      expect(out).to include('unknown=false')
    end

    it 'runs the first match, so registration order decides' do
      out = probe(<<~RUBY)
        REGISTRY.define do
          REGISTRY.command(/^over/) { puts 'FIRST' }
          REGISTRY.command(/^overlap$/) { puts 'SECOND' }
        end
        REGISTRY.dispatch('overlap')
      RUBY
      expect(out).to include('FIRST')
      expect(out).not_to include('SECOND')
    end

    it 'skips a command whose game gate does not match' do
      gs = probe(<<~RUBY, game: 'GSIV')
        REGISTRY.define do
          REGISTRY.command(/^x$/, game: :dr) { puts 'DR' }
          REGISTRY.command(/^x$/, game: :gs) { puts 'GS' }
        end
        REGISTRY.dispatch('x')
      RUBY
      expect(gs).to include('GS')
      expect(gs).not_to include('DR')
    end

    it 'passes the whole command alongside the match' do
      out = probe(<<~RUBY)
        REGISTRY.define do
          REGISTRY.command(/^pre/) { |m, cmd| puts "match=\#{m[0]} cmd=\#{cmd}" }
        end
        REGISTRY.dispatch('prefix and more')
      RUBY
      # match[0] is the matched span only; the handler needs the rest.
      expect(out).to include('match=pre cmd=prefix and more')
    end
  end

  describe '.toggle_value' do
    it 'negates the current value when no argument is given' do
      expect(described_class.toggle_value(false, nil)).to be(true)
      expect(described_class.toggle_value(true, nil)).to be(false)
    end

    it 'honors an explicit argument in either vocabulary' do
      expect(described_class.toggle_value(true, 'true')).to be(true)
      expect(described_class.toggle_value(false, 'on')).to be(true)
      expect(described_class.toggle_value(true, 'false')).to be(false)
      expect(described_class.toggle_value(true, 'off')).to be(false)
    end

    # Each case passes `current` EQUAL to the value being asked for, so a
    # case-sensitive implementation -- which falls through to !current --
    # returns the opposite and fails. Picking current == !expected instead
    # would pass either way: the negation would coincide with the expected
    # answer and the assertion would prove nothing.
    it 'is case-insensitive' do
      expect(described_class.toggle_value(true, 'TRUE')).to be(true)
      expect(described_class.toggle_value(true, 'On')).to be(true)
      expect(described_class.toggle_value(false, 'FALSE')).to be(false)
      expect(described_class.toggle_value(false, 'Off')).to be(false)
    end
  end
end
