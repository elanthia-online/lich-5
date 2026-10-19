# frozen_string_literal: true

require 'tmpdir'
require_relative 'spec_helper'
require_relative 'support/global_defs_spec_source'

RSpec.describe GlobalDefsSpecSource do
  # Writes lines to a throwaway file and yields its path, so the failure
  # cases can be shown on source shapes lib/global_defs.rb does not have.
  def with_source(*lines)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'global_defs.rb')
      File.write(path, lines.join)
      yield path
    end
  end

  describe '.define' do
    it 'defines the shipped method, located at its def line in lib/global_defs.rb' do
      target = Class.new
      described_class.define(target, 'waitrt?')

      expect(target.instance_method(:waitrt?).source_location).to eq([described_class::PATH, described_class.line_of('waitrt?')])
      expect(File.readlines(described_class::PATH)[described_class.line_of('waitrt?') - 1]).to start_with('def waitrt?(')
    end

    it 'defines only the methods it is asked for' do
      target = Class.new
      described_class.define(target, 'get', 'get?')

      expect(target.instance_methods(false)).to contain_exactly(:get, :get?)
    end

    it 'loads a one-line def without taking in the defs after it' do
      target = Class.new
      described_class.define(target, 'n')

      expect(target.instance_methods(false)).to eq([:n])
      expect(target.new.n).to eq('north')
    end

    it 'loads an endless def on its own line' do
      with_source("def doubled(x) = x * 2\n", "def other\n", "  1\n", "end\n") do |path|
        target = Class.new
        described_class.define(target, 'doubled', path: path)

        expect(target.instance_methods(false)).to eq([:doubled])
        expect(target.new.doubled(4)).to eq(8)
      end
    end

    it 'does not treat a default argument as an endless def' do
      with_source("def defaulted(x = 2)\n", "  x * 3\n", "end\n", "def other; end\n") do |path|
        target = Class.new
        described_class.define(target, 'defaulted', path: path)

        expect(target.instance_methods(false)).to eq([:defaulted])
        expect(target.new.defaulted).to eq(6)
      end
    end

    it 'raises when the def is missing' do
      expect { described_class.define(Class.new, 'no_such_global') }
        .to raise_error(RuntimeError, /global_defs\.rb: def no_such_global missing/)
    end

    it 'raises on a duplicate def rather than loading one of them' do
      with_source("def twice\n", "  1\n", "end\n", "def twice\n", "  2\n", "end\n") do |path|
        expect { described_class.define(Class.new, 'twice', path: path) }
          .to raise_error(RuntimeError, /def twice defined 2 times/)
      end
    end

    it 'does not match a longer name that starts with the one asked for' do
      with_source("def fputs_like(x)\n", "end\n", "def fput?\n", "end\n") do |path|
        expect { described_class.define(Class.new, 'fput', path: path) }
          .to raise_error(RuntimeError, /def fput missing/)
      end
    end

    it 'does not match a setter of the same name' do
      with_source("def probe=(value)\n", "  value\n", "end\n") do |path|
        expect { described_class.define(Class.new, 'probe', path: path) }
          .to raise_error(RuntimeError, /def probe missing/)
      end
    end

    it 'does not match an indented def' do
      with_source("module M\n", "  def nested\n", "  end\n", "end\n") do |path|
        expect { described_class.define(Class.new, 'nested', path: path) }
          .to raise_error(RuntimeError, /def nested missing/)
      end
    end

    it 'raises when the def has no column-0 end' do
      with_source("def open_ended\n", "  1\n", "  end\n") do |path|
        expect { described_class.define(Class.new, 'open_ended', path: path) }
          .to raise_error(RuntimeError, /def open_ended terminator missing/)
      end
    end

    it 'leaves Script calls alone by default' do
      code, = described_class.method_source('wait_until')

      expect(code).to include('Script.')
      expect(code).not_to include('Lich::Common::Script.')
    end

    it 'qualifies bare Script calls only, when asked' do
      with_source("def scripted\n",
                  "  [Script.current, SubScript.current, Lich::Common::Script.self, ::Script.current]\n",
                  "end\n") do |path|
        code, line = described_class.method_source('scripted', qualify_script: true, path: path)

        expect(line).to eq(1)
        expect(code).to include('[Lich::Common::Script.current, SubScript.current, Lich::Common::Script.self, ::Script.current]')
      end
    end
  end

  describe '.define_toplevel' do
    after do
      Object.send(:remove_method, :global_defs_spec_source_probe) if Object.private_method_defined?(:global_defs_spec_source_probe, false)
    end

    it 'defines the method the way a top-level def does: private, on Object' do
      with_source("def global_defs_spec_source_probe\n", "  :probed\n", "end\n") do |path|
        described_class.define_toplevel('global_defs_spec_source_probe', path: path)

        expect(Object.private_method_defined?(:global_defs_spec_source_probe, false)).to be(true)
        expect(Object.new.send(:global_defs_spec_source_probe)).to eq(:probed)
        expect(Object.instance_method(:global_defs_spec_source_probe).source_location).to eq([path, 1])
      end
    end
  end

  describe '.eval_toplevel_block' do
    after do
      Object.send(:remove_const, :GlobalDefsSpecSourceProbe) if Object.const_defined?(:GlobalDefsSpecSourceProbe, false)
    end

    it 'evaluates from the marker line to the next column-0 end, and no further' do
      with_source("# probe marker\n", "module GlobalDefsSpecSourceProbe\n", "  VALUE = 1\n", "end\n",
                  "raise 'read past the block'\n") do |path|
        described_class.eval_toplevel_block('probe marker', path: path)

        expect(GlobalDefsSpecSourceProbe::VALUE).to eq(1)
      end
    end

    it 'raises when the marker is missing' do
      with_source("module GlobalDefsSpecSourceProbe\n", "end\n") do |path|
        expect { described_class.eval_toplevel_block('probe marker', path: path) }
          .to raise_error(RuntimeError, /block marker "probe marker" missing/)
      end
    end

    it 'raises when the marker appears more than once' do
      with_source("# probe marker\n", "# probe marker again\n", "module GlobalDefsSpecSourceProbe\n", "end\n") do |path|
        expect { described_class.eval_toplevel_block('probe marker', path: path) }
          .to raise_error(RuntimeError, /block marker "probe marker" found 2 times/)
      end
    end

    it 'raises when the block has no column-0 end' do
      with_source("# probe marker\n", "module GlobalDefsSpecSourceProbe\n", "  end\n") do |path|
        expect { described_class.eval_toplevel_block('probe marker', path: path) }
          .to raise_error(RuntimeError, /block "probe marker" terminator missing/)
      end
    end
  end
end
