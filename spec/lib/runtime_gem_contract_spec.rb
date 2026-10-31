# frozen_string_literal: true

require_relative '../../lib/runtime_gem_contract'

RSpec.describe Lich::RuntimeGemContract do
  let(:gemfile) do
    <<~GEMFILE
      source 'https://rubygems.org'
      plugin 'must-not-run'
      git_source(:github) { |name| "https://github.com/\#{name}" }
      group :development do
        gem 'rspec'
      end
      group :gtk do
        gem 'gtk3'
      end
      group :profanity do
        gem 'curses'
      end
      gem 'redis'
      gem 'json'
      gem 'sqlite3'
    GEMFILE
  end
  let(:lockfile) do
    <<~LOCK
      GEM
        remote: https://rubygems.org/
        specs:
          curses (1.7.0)
          json (3.1.0)
          mini_portile2 (2.8.9)
          redis (6.0.0)
            redis-client (= 0.30.1)
          redis-client (0.30.1)
            json (>= 3.0)
          sqlite3 (2.10.2)
            mini_portile2 (~> 2.8.0)
          sqlite3 (2.10.2-x64-mingw-ucrt)

      PLATFORMS
        x64-mingw-ucrt

      CHECKSUMS
        curses (1.7.0) sha256=#{'a' * 64}
        json (3.1.0) sha256=#{'b' * 64}
        mini_portile2 (2.8.9) sha256=#{'c' * 64}
        redis (6.0.0) sha256=#{'d' * 64}
        redis-client (0.30.1) sha256=#{'e' * 64}
        sqlite3 (2.10.2) sha256=#{'f' * 64}
        sqlite3 (2.10.2-x64-mingw-ucrt) sha256=#{'0' * 64}
    LOCK
  end
  let(:inventory) do
    { 'ruby_version' => '4.0.9', 'ruby_abi' => '4.0', 'platform' => 'x64-mingw-ucrt',
      'gems' => { 'json' => { 'version' => '3.2.0', 'dependencies' => {} } } }
  end
  subject(:reader) { described_class.new(gemfile: gemfile, lockfile: lockfile) }

  it 'selects default and profanity roots without GTK or development tooling' do
    expect(reader.roots.keys).to contain_exactly('curses', 'redis', 'json', 'sqlite3')
  end

  it 'keeps exact transitive versions and native platform checksums' do
    packages = reader.resolve(inventory).fetch('packages')
    expect(packages.transform_values { |spec| spec['version'] }).to eq('curses' => '1.7.0', 'redis' => '6.0.0', 'redis-client' => '0.30.1', 'sqlite3' => '2.10.2')
    expect(packages.fetch('sqlite3')).to include('platform' => 'x64-mingw-ucrt', 'sha256' => '0' * 64, 'dependencies' => {})
    expect(packages).not_to have_key('mini_portile2')
  end

  it 'reports supplied differences without shipping those gems' do
    expect(reader.resolve(inventory).fetch('bundled')).to eq('json' => { 'locked' => '3.1.0', 'supplied' => '3.2.0' })
  end

  it 'rejects a supplied version that fails a runtime dependency requirement' do
    inventory['gems']['json']['version'] = '2.0.0'
    expect { reader.resolve(inventory) }.to raise_error(described_class::Error, /does not satisfy/)
  end

  it 'rejects inventory from a host instead of the target RubyInstaller' do
    inventory['platform'] = 'arm64-darwin'
    expect { reader.resolve(inventory) }.to raise_error(described_class::Error, /target Windows/)
  end

  it 'follows a newly declared runtime root instead of a fixed root list' do
    contract = described_class.new(gemfile: gemfile + "\ngem 'mini_portile2'\n", lockfile: lockfile)
    expect(contract.resolve(inventory).fetch('packages')).to have_key('mini_portile2')
  end

  it 'rejects a newly declared root absent from the lock' do
    contract = described_class.new(gemfile: gemfile + "\ngem 'new-gem'\n", lockfile: lockfile)
    expect { contract.resolve(inventory) }.to raise_error(described_class::Error, /new-gem is absent/)
  end

  it 'projects explicit platform selectors onto Windows' do
    contract = described_class.new(gemfile: "gem 'redis', platforms: [:windows, :mingw]\ngem 'unavailable', platforms: :jruby", lockfile: lockfile)
    expect(contract.roots.keys).to eq(['redis'])
  end

  ["gem ENV.fetch('GEM')", "gem 'redis', force_ruby_platform: true", "if ENV['X']; gem 'redis'; end", "gem 'redis'; gem 'redis'", "eval('gem redis')"].each do |source|
    it "rejects unsupported or dynamic runtime declarations: #{source}" do
      expect { described_class.new(gemfile: source, lockfile: lockfile) }.to raise_error(described_class::Error)
    end
  end

  it 'rejects a lock without package checksums' do
    expect { described_class.new(gemfile: gemfile, lockfile: lockfile.split('CHECKSUMS').first) }.to raise_error(described_class::Error, /checksums/)
  end

  it 'rejects a missing transitive checksum' do
    expect { described_class.new(gemfile: gemfile, lockfile: lockfile.lines.reject { |line| line.include?('redis-client (0.30.1) sha256') }.join) }.to raise_error(described_class::Error, /missing lock checksum/)
  end

  it 'rejects a transitive version violating its parent requirement' do
    contract = described_class.new(gemfile: gemfile, lockfile: lockfile.gsub('redis-client (0.30.1)', 'redis-client (0.30.2)'))
    expect { contract.resolve(inventory) }.to raise_error(described_class::Error, /redis-client.*does not satisfy/)
  end

  it 'rejects missing platform packages instead of silently losing coverage' do
    contract = described_class.new(gemfile: gemfile, lockfile: lockfile.gsub('sqlite3 (2.10.2-x64-mingw-ucrt)', 'sqlite3 (2.10.2-arm64-darwin)').sub('sqlite3 (2.10.2)', 'sqlite3 (2.10.2-x86-linux)'))
    expect { contract.resolve(inventory) }.to raise_error(described_class::Error, /sqlite3 is absent/)
  end

  it 'canonicalizes contract hashes independently of key order' do
    expect(described_class.digest('b' => 2, 'a' => { 'z' => 1, 'y' => 2 })).to eq(described_class.digest('a' => { 'y' => 2, 'z' => 1 }, 'b' => 2))
  end

  it 'reads startup declarations without a lockfile or evaluating plugins' do
    contract = described_class.new(gemfile: gemfile + "\ngroup :gtk do\n gem 'native-ui'\nend\n", groups: %i[default gtk])
    expect(contract.roots.keys).to contain_exactly('redis', 'json', 'sqlite3', 'gtk3', 'native-ui')
    expect(contract.lock_sha256).to be_nil
    expect { contract.resolve(inventory) }.to raise_error(described_class::Error, /lockfile is required/)
  end

  it 'rejects the wrong ABI even with the correct Windows platform' do
    expect { reader.resolve(inventory) }.not_to raise_error
    inventory['ruby_abi'] = '3.4'
    expect { reader.resolve(inventory) }.to raise_error(described_class::Error, /Ruby ABI 4.0/)
  end

  it 'keeps identity stable across comments, dev pins, non-Windows variants and requirement order' do
    source = "gem 'redis', '>= 5', '< 7'\n"
    original = described_class.new(gemfile: source, lockfile: lockfile)
    edited = lockfile.sub('    curses (1.7.0)', "    dev-tool (2.0)\n    redis (6.0.1-arm64-darwin)\n    curses (1.7.0)")
    edited << "  dev-tool (2.0) sha256=#{'a' * 64}\n"
    changed = described_class.new(gemfile: "# comment\ngem 'redis', '< 7', '>= 5'\ngroup :development do\n gem 'dev-tool'\nend\n", lockfile: edited)
    expect(changed.windows_contract_digest(inventory)).to eq(original.windows_contract_digest(inventory))
    expect(changed.gemfile_sha256).not_to eq(original.gemfile_sha256)
    expect(changed.lock_sha256).not_to eq(original.lock_sha256)
  end

  it 'binds Windows package checksums and transitive requirements' do
    baseline = reader.windows_contract_digest(inventory)
    checksum = lockfile.sub("sha256=#{'d' * 64}", "sha256=#{'a' * 64}")
    expect(described_class.new(gemfile: gemfile, lockfile: checksum).windows_contract_digest(inventory)).not_to eq(baseline)
    dependencies = lockfile.sub('redis-client (= 0.30.1)', 'redis-client (>= 0.30.1)')
    expect(described_class.new(gemfile: gemfile, lockfile: dependencies).windows_contract_digest(inventory)).not_to eq(baseline)
  end

  it 'binds advertised GTK-only non-GTK packages without coupling unused dev entries' do
    names = ['mini_portile2']
    baseline = reader.windows_contract_digest(inventory, advertised_members: names)
    changed = described_class.new(gemfile: gemfile, lockfile: lockfile.gsub('mini_portile2 (2.8.9)', 'mini_portile2 (2.8.8)'))
    expect(changed.windows_contract_digest(inventory, advertised_members: names)).not_to eq(baseline)
    expect(changed.windows_contract_digest(inventory)).to eq(reader.windows_contract_digest(inventory))
    role = { 'gtk' => names }
    expect(changed.windows_contract_digest(inventory, build_roles: role, advertised_members: names)).to eq(
      reader.windows_contract_digest(inventory, build_roles: role, advertised_members: names)
    )
  end

  it 'reads all 18 non-GTK Windows packages from the real repository declarations and lock' do
    root = File.expand_path('../..', __dir__)
    contract = described_class.new(gemfile: File.binread(File.join(root, 'Gemfile')), lockfile: File.binread(File.join(root, 'Gemfile.lock')))
    synthetic = JSON.parse(File.read(File.join(root, 'spec/fixtures/r4l5/ruby-inventory-synthetic.json')))
    expected = %w[ascii_charts concurrent-ruby connection_pool curses ffi kramdown os ox redis redis-client sequel sqlite3 terminal-table tzinfo tzinfo-data unicode-display_width unicode-emoji webrick]
    expect(contract.resolve(synthetic).fetch('packages').keys).to match_array(expected)
  end

  it 'does not treat ruby or mri selectors as Windows roots' do
    contract = described_class.new(gemfile: "gem 'redis'\ngem 'missing', platforms: [:ruby, :mri]\n", lockfile: lockfile)
    expect(contract.roots.keys).to eq(['redis'])
  end

  it 'retains either selected enclosing group through nested groups' do
    source = "group :profanity do\n group :test do\n  gem 'redis'\n end\nend\n" \
             "group :test do\n group :profanity do\n  gem 'curses'\n end\nend\n" \
             "group :test do\n gem 'missing'\nend\n"
    contract = described_class.new(gemfile: source, lockfile: lockfile)
    expect(contract.roots.keys).to contain_exactly('redis', 'curses')
  end

  it 'exposes selected Windows lock members without making unused entries roots' do
    expect(reader.locked_packages.fetch('sqlite3')).to include('platform' => 'x64-mingw-ucrt', 'sha256' => '0' * 64)
    expect(reader.locked_packages).to have_key('mini_portile2')
    expect(reader.roots).not_to have_key('mini_portile2')
    expect(reader.resolve(inventory).fetch('packages')).not_to have_key('mini_portile2')
  end
  it 'reports invalid literal version requirements as a reader error' do
    expect { described_class.new(gemfile: "gem 'redis', 'not-a-version'", lockfile: lockfile) }.to raise_error(described_class::Error, /invalid runtime declarations/)
  end

  it 'respects an explicit non-default startup group without implicitly adding default roots' do
    source = "gem 'redis'\ngroup :gtk do\n gem 'gtk3'\nend\n"
    contract = described_class.new(gemfile: source, groups: [:gtk])
    expect(contract.roots.keys).to eq(['gtk3'])
    expect(contract.lock_sha256).to be_nil
    expect { contract.resolve(inventory) }.to raise_error(described_class::Error, /lockfile is required/)
  end
end
