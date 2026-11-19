# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

RSpec.describe Lich::Genie::TriggerFile do
  fixture = File.expand_path('../../fixtures/genie/persistence/remix_triggers.cfg', __dir__)

  around { |example| Dir.mktmpdir { |dir| @dir = dir; example.run } }

  def path = File.join(@dir, 'triggers.cfg')
  def entry(pattern, commands, klass = '') = { 'pattern' => pattern, 'commands' => commands, 'class' => klass }

  describe '.normalize (Triggers.Add, Globals.cs:1001-1023 R)' do
    {
      '^plain'      => ['^plain', false, false],
      '/^Foo bar/i' => ['^Foo bar', true, false],
      '/^slashed/'  => ['^slashed', false, false],
      '/^open'      => ['^open', false, false],
      'tail/'       => ['tail', false, false],
      'e/$x = 1/'   => ['$x = 1', false, true],
      'eval $y > 2' => ['$y > 2', false, true],
      'EVAL $z'     => ['$z', false, true],
      'e/$w/i'      => ['$w', true, true],
      '//i'         => ['', true, false],
      ''            => ['', false, false]
    }.each do |pattern, (key, ignore_case, eval_trigger)|
      it "#{pattern.inspect} -> key #{key.inspect}, ignore_case=#{ignore_case}, eval=#{eval_trigger}" do
        norm = described_class.normalize(pattern)
        expect([norm.key, norm.ignore_case, norm.eval]).to eq([key, ignore_case, eval_trigger])
      end
    end
  end

  describe '.row (Triggers.Save, Globals.cs:1146-1160 R)' do
    it 'rebuilds e/key/ and /key/i, and appends the class only when non-empty' do
      expect(described_class.row('eval $x = 1', '#echo y', '')).to eq('#trigger {e/$x = 1/} {#echo y}')
      expect(described_class.row('/^Foo/i', '#echo x', 'c')).to eq('#trigger {/^Foo/i} {#echo x} {c}')
      expect(described_class.row('/^Foo/', 'a', nil)).to eq('#trigger {^Foo} {a}')
    end

    it 'writes the eval form even for an ignore-case eval pattern (eval wins, as in Save)' do
      expect(described_class.row('e/$w/i', 'a', '')).to eq('#trigger {e/$w/} {a}')
    end
  end

  describe '.rows' do
    it 'reproduces the Remix-written fixture from the same triggers, in its order' do
      triggers = [
        entry('^You charge the widget|^You prime',
              '#if {($alt = 0)} {#var charges #evalmath ($charges + 1)};#if {($alt = 1)} {#var altcharges #evalmath ($altcharges + 1)};#class charging off',
              'charging'),
        entry('/^Foo bar/i', '#echo x'),
        entry('e/$nosuchvar = 1/', '#echo y'),
        entry('^plain', '#var p 1'),
        entry('^Apple', '#var p 2', 'spaced'),
        entry('^The cold mist around you fades', '#var misty 0;#class mist off', 'mist')
      ]
      described_class.save(path, triggers)
      expect(File.binread(path)).to eq(File.binread(fixture))
    end

    it 'keeps one row per normalized key, the later trigger winning' do
      rows = described_class.rows([entry('/^a/', 'first'), entry('^a', 'second'), entry('^b', 'b')])
      expect(rows).to eq(['#trigger {^a} {second}', '#trigger {^b} {b}'])
    end
  end

  describe '.read (Triggers.Load/LoadRow, Globals.cs:1077-1125 R)' do
    it 'is empty and false for a missing file' do
      expect(described_class.read(path)).to eq([[], false])
    end

    it 'takes rows with more than two args, trims the class, keeps the pattern raw (no $var expansion)' do
      File.binwrite(path, "#trigger {^a $x} {#var y 1}\r\n#trigger {^b} {go}   {  cls  }\r\njunk\r\n#trigger {only}\r\n" \
                          "#trigger {^c} {x} {k} {extra}\r\n")
      rows, ok = described_class.read(path)
      expect(ok).to be(true)
      expect(rows.map(&:to_a)).to eq([['^a $x', '#var y 1', ''], ['^b', 'go', 'cls'], ['^c', 'x', 'k']])
    end

    it 'reads the Remix fixture back into the six triggers it was written from' do
      rows, ok = described_class.read(fixture)
      expect(ok).to be(true)
      expect(rows.map(&:pattern)).to eq(['^Apple', '/^Foo bar/i', '^plain', '^The cold mist around you fades',
                                         '^You charge the widget|^You prime', 'e/$nosuchvar = 1/'])
    end

    it 'is empty and false (never raises) when the file cannot be read (Load is catch (Exception), Globals.cs:1105-1109 R)' do
      File.binwrite(path, "#trigger {^a} {x}\r\n")
      allow(File).to receive(:binread).and_call_original
      allow(File).to receive(:binread).with(path).and_raise(Errno::EACCES, path)
      expect(described_class.read(path)).to eq([[], false])
      allow(File).to receive(:binread).with(path).and_raise(IOError, 'closed stream')
      expect(described_class.read(path)).to eq([[], false])
    end

    it 'is empty and false for a real unreadable file (chmod 000)' do
      skip 'root can read a mode-000 file' if Process.euid.zero?
      File.binwrite(path, "#trigger {^a} {x}\r\n")
      File.chmod(0o000, path)
      expect(described_class.read(path)).to eq([[], false])
    ensure
      File.chmod(0o600, path) if File.exist?(path)
    end

    it 'aborts at a row ParseArgs throws on, keeping earlier rows' do
      File.binwrite(path, "#trigger {^a} {x}\r\n#trigger {'} {y} {z}\r\n#trigger {^b} {x}\r\n")
      rows, ok = described_class.read(path)
      expect([rows.map(&:pattern), ok]).to eq([['^a'], false])
    end
  end
end
