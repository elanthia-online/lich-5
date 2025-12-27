# frozen_string_literal: true

require 'rspec'

LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib')

require File.join(LIB_DIR, 'util', 'opts.rb')

RSpec.describe Lich::Util::Opts do
  describe '.parse' do
    context 'with boolean options' do
      it 'parses --flag as true' do
        argv = ['--gui']
        opts = Lich::Util::Opts.parse(argv, { gui: { type: :boolean, default: false } })
        expect(opts.gui).to be true
      end

      it 'respects default value when option not provided' do
        argv = []
        opts = Lich::Util::Opts.parse(argv, { gui: { type: :boolean, default: true } })
        expect(opts.gui).to be true
      end

      it 'parses --option=true' do
        argv = ['--dark-mode=true']
        opts = Lich::Util::Opts.parse(argv, { dark_mode: { type: :boolean } })
        expect(opts.dark_mode).to be true
      end

      it 'parses --option=false' do
        argv = ['--dark-mode=false']
        opts = Lich::Util::Opts.parse(argv, { dark_mode: { type: :boolean } })
        expect(opts.dark_mode).to be false
      end

      it 'parses --option=on as true' do
        argv = ['--dark-mode=on']
        opts = Lich::Util::Opts.parse(argv, { dark_mode: { type: :boolean } })
        expect(opts.dark_mode).to be true
      end

      it 'parses --option=off as false' do
        argv = ['--dark-mode=off']
        opts = Lich::Util::Opts.parse(argv, { dark_mode: { type: :boolean } })
        expect(opts.dark_mode).to be false
      end
    end

    context 'with string options' do
      it 'parses --option=value' do
        argv = ['--account=DOUG']
        opts = Lich::Util::Opts.parse(argv, { account: { type: :string } })
        expect(opts.account).to eq('DOUG')
      end

      it 'parses --option value (with space)' do
        argv = ['--account', 'DOUG']
        opts = Lich::Util::Opts.parse(argv, { account: { type: :string } })
        expect(opts.account).to eq('DOUG')
      end

      it 'respects default value for missing string option' do
        argv = []
        opts = Lich::Util::Opts.parse(argv, { account: { type: :string, default: 'DEFAULT' } })
        expect(opts.account).to eq('DEFAULT')
      end

      it 'overrides default value when option provided' do
        argv = ['--account=DOUG']
        opts = Lich::Util::Opts.parse(argv, { account: { type: :string, default: 'DEFAULT' } })
        expect(opts.account).to eq('DOUG')
      end
    end

    context 'with integer options' do
      it 'parses --option=123 as integer' do
        argv = ['--port=4000']
        opts = Lich::Util::Opts.parse(argv, { port: { type: :integer } })
        expect(opts.port).to eq(4000)
        expect(opts.port).to be_a(Integer)
      end

      it 'respects default integer value' do
        argv = []
        opts = Lich::Util::Opts.parse(argv, { port: { type: :integer, default: 3000 } })
        expect(opts.port).to eq(3000)
      end
    end

    context 'with array options' do
      it 'collects multiple values until next flag' do
        argv = ['--scripts', 'script1', 'script2', 'script3']
        opts = Lich::Util::Opts.parse(argv, { scripts: { type: :array } })
        expect(opts.scripts).to eq(['script1', 'script2', 'script3'])
      end

      it 'stops collecting at next flag' do
        argv = ['--scripts', 'script1', 'script2', '--gui']
        opts = Lich::Util::Opts.parse(argv, {
          scripts: { type: :array },
          gui: { type: :boolean }
        })
        expect(opts.scripts).to eq(['script1', 'script2'])
        expect(opts.gui).to be true
      end

      it 'returns empty array when no values provided' do
        argv = ['--scripts']
        opts = Lich::Util::Opts.parse(argv, { scripts: { type: :array } })
        expect(opts.scripts).to eq([])
      end
    end

    context 'with custom parser' do
      it 'uses custom parser function' do
        custom_parser = ->(value) { value.upcase }
        argv = ['--account=doug']
        opts = Lich::Util::Opts.parse(argv, {
          account: { type: :string, parser: custom_parser }
        })
        expect(opts.account).to eq('DOUG')
      end

      it 'parses key:value pairs with custom parser' do
        custom_parser = ->(value) do
          host, port = value.split(':')
          { host: host, port: port.to_i }
        end
        argv = ['--connection=localhost:4000']
        opts = Lich::Util::Opts.parse(argv, {
          connection: { parser: custom_parser }
        })
        expect(opts.connection).to eq({ host: 'localhost', port: 4000 })
      end
    end

    context 'with multiple options' do
      it 'parses multiple different option types' do
        argv = ['--account=DOUG', '--port=4000', '--gui', '--dark-mode=false']
        opts = Lich::Util::Opts.parse(argv, {
          account: { type: :string },
          port: { type: :integer },
          gui: { type: :boolean },
          dark_mode: { type: :boolean }
        })
        expect(opts.account).to eq('DOUG')
        expect(opts.port).to eq(4000)
        expect(opts.gui).to be true
        expect(opts.dark_mode).to be false
      end

      it 'includes all schema keys in result even if not provided' do
        argv = ['--account=DOUG']
        opts = Lich::Util::Opts.parse(argv, {
          account: { type: :string },
          port: { type: :integer, default: 3000 },
          gui: { type: :boolean, default: true }
        })
        expect(opts.respond_to?(:account)).to be true
        expect(opts.respond_to?(:port)).to be true
        expect(opts.respond_to?(:gui)).to be true
      end
    end

    context 'returns frozen OpenStruct' do
      it 'returns an OpenStruct' do
        opts = Lich::Util::Opts.parse([], {})
        expect(opts).to be_a(OpenStruct)
      end

      it 'returns a frozen object' do
        opts = Lich::Util::Opts.parse([], { account: { type: :string } })
        expect(opts.frozen?).to be true
      end

      it 'prevents modification of returned options' do
        opts = Lich::Util::Opts.parse([], { account: { type: :string, default: 'DOUG' } })
        expect { opts.account = 'NEWNAME' }.to raise_error(FrozenError)
      end
    end

    context 'edge cases' do
      it 'handles empty ARGV' do
        argv = []
        opts = Lich::Util::Opts.parse(argv, { gui: { type: :boolean, default: true } })
        expect(opts.gui).to be true
      end

      it 'ignores unknown options' do
        argv = ['--unknown=value', '--account=DOUG']
        opts = Lich::Util::Opts.parse(argv, { account: { type: :string } })
        expect(opts.account).to eq('DOUG')
      end

      it 'handles option names with underscores and hyphens interchangeably' do
        argv = ['--dark-mode=true']
        opts = Lich::Util::Opts.parse(argv, { dark_mode: { type: :boolean } })
        expect(opts.dark_mode).to be true
      end

      it 'returns nil for missing string option without default' do
        argv = []
        opts = Lich::Util::Opts.parse(argv, { account: { type: :string } })
        expect(opts.account).to be_nil
      end

      it 'handles whitespace in values' do
        argv = ['--message=hello world']
        opts = Lich::Util::Opts.parse(argv, { message: { type: :string } })
        expect(opts.message).to eq('hello world')
      end
    end
  end
end
