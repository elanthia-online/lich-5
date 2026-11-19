# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative 'support/timed_input'
require_relative '../../../lib/genie'
require 'tmpdir'

# Provenance across `#trigger save` / `#alias save` and a load (PR #1813 re-review, Minor 1): a
# definition built from game text must stay game text after it is saved and read back, while
# triggers.cfg / aliases.cfg keep Remix's bytes. The real Triggers, AliasList, CommandRouter,
# interpreter and module wiring, on real files in a temp dir.
RSpec.describe Lich::Genie::DefinitionTrust do
  fixture_dir = File.expand_path('../../fixtures/genie/persistence', __dir__)
  let(:evil) { %(,e respond('PWNED')) }
  let(:notices) { [] }
  let(:notice) { ->(text) { notices << text } }
  let(:uni) { [0xE9, 0x65E5, 0x1F600].pack('U*') } # e-acute, a CJK ideograph, an astral emoji

  around { |example| Dir.mktmpdir('genie-trust') { |dir| @dir = dir; example.run } }

  def cfg(name = 'triggers.cfg') = File.join(@dir, 'Config', name)
  def side(name = 'triggers.cfg') = "#{cfg(name)}.untrusted"

  # [pattern, authored] of every trigger a fresh registry loads from +path+.
  def reload_triggers(path = cfg, notice: nil)
    registry = Lich::Genie::Triggers.new
    registry.load(path, notice: notice)
    registry.list.to_h { |t| [t['pattern'], registry.authored?(t['pattern'])] }
  end

  def reload_aliases(path = cfg('aliases.cfg'), notice: nil)
    list = Lich::Genie::AliasList.new
    list.load(path, notice: notice)
    list.entries.to_h { |key, _| [key, list.authored?(key)] }
  end

  describe 'triggers: save and load' do
    let(:registry) { Lich::Genie::Triggers.new }

    it 'keeps an unauthored trigger unauthored and an authored one authored' do
      registry.add('^mine', ',go2 1', authored: true)
      registry.add('^theirs', ',probe laundered')
      expect(registry.save(cfg)).to be(true)
      expect(reload_triggers).to eq('^mine' => true, '^theirs' => false)
      expect(File.binread(side)).to eq(%(lich-genie-untrusted 1\r\n["^theirs",",probe laundered",""]\r\nend 1\r\n))
    end

    it 'writes triggers.cfg byte for byte as Remix does, whatever the provenance (persistence golden)' do
      golden = File.join(fixture_dir, 'remix_triggers.cfg')
      rows, = Lich::Genie::TriggerFile.read(golden)
      [true, false].each do |flag|
        fresh = Lich::Genie::Triggers.new
        rows.each { |row| fresh.add(row.pattern, row.commands, klass: row.klass, authored: flag) }
        expect(fresh.save(cfg)).to be(true)
        expect(File.binread(cfg)).to eq(File.binread(golden))
        expect(File.exist?(side)).to be(!flag)
        expect(reload_triggers.values.uniq).to eq([flag])
      end
    end

    it 'loads a hand-edited row as the user\'s own: its identity is no longer listed' do
      registry.add('^theirs', ',probe x', klass: 'cls')
      registry.save(cfg)
      File.binwrite(cfg, File.binread(cfg).sub(',probe x', ',probe y'))
      expect(reload_triggers).to eq('^theirs' => true)
    end

    it 'takes the class into the identity: the same pattern and body under another class is authored' do
      registry.add('^t', ',probe x', klass: 'a')
      registry.save(cfg)
      expect(reload_triggers).to eq('^t' => false)
      File.binwrite(cfg, File.binread(cfg).sub('{a}', '{b}'))
      expect(reload_triggers).to eq('^t' => true)
    end

    it 'tells duplicate patterns apart by body: the row that lands decides' do
      registry.add('^x', ',probe listed')
      registry.save(cfg)
      listed = File.binread(cfg)
      File.binwrite(cfg, "#{listed}#trigger {^x} {,probe hand}\r\n")
      expect(reload_triggers).to eq('^x' => true) # the later, hand-written row replaces the listed one
      File.binwrite(cfg, "#trigger {^x} {,probe hand}\r\n#{listed}")
      expect(reload_triggers).to eq('^x' => false)
    end

    it 'keeps identities exact with unicode, braces, quotes, backslashes and sigils' do
      body = %(,probe "q;uo" {br {ne}} #{uni} \\ $1 %x @y@ 'a)
      pattern = %(^#{uni} "(.*)" {x})
      registry.add(pattern, body, klass: "c#{uni}")
      registry.add('^plain', body, authored: true)
      registry.save(cfg)
      expect(reload_triggers).to eq(pattern => false, '^plain' => true)
    end

    it 'lists every row a body with a line break reads back as, so it cannot smuggle an authored row in' do
      registry.add('^bait', "x}\r\n#trigger {^smuggled} {,probe smuggled")
      registry.save(cfg)
      expect(File.binread(cfg)).to include("\r\n#trigger {^smuggled} {,probe smuggled}\r\n")
      expect(reload_triggers).to eq('^bait' => false, '^smuggled' => false)
    end

    it 'loads every row authored when there is no side file (nothing unauthored was ever saved)' do
      registry.add('^a', ',go2 1', authored: true)
      registry.save(cfg)
      expect(File.exist?(side)).to be(false)
      expect(reload_triggers).to eq('^a' => true)
    end

    it 'removes a stale side file when nothing saved is unauthored' do
      registry.add('^a', ',probe x')
      registry.save(cfg)
      expect(File.exist?(side)).to be(true)
      registry.add('^a', ',probe x', authored: true)
      expect(registry.save(cfg)).to be(true)
      expect(File.exist?(side)).to be(false)
      expect(reload_triggers).to eq('^a' => true)
    end

    context 'with a side file that cannot be used' do
      before do
        registry.add('^mine', ',go2 1', authored: true)
        registry.add('^theirs', ',probe x')
        registry.save(cfg)
      end

      {
        'garbage'                                 => "nonsense\r\n",
        'another header'                          => %(lich-genie-untrusted 2\r\n["^theirs",",probe x",""]\r\nend 1\r\n),
        'a count that does not match (truncated)' => %(lich-genie-untrusted 1\r\n["^theirs",",probe x",""]\r\nend 2\r\n),
        'no footer'                               => %(lich-genie-untrusted 1\r\n["^theirs",",probe x",""]\r\n),
        'an alias identity (arity 2)'             => %(lich-genie-untrusted 1\r\n["^theirs",",probe x"]\r\nend 1\r\n),
        'a non-string member'                     => %(lich-genie-untrusted 1\r\n["^theirs",1,""]\r\nend 1\r\n),
        'a JSON object'                           => %(lich-genie-untrusted 1\r\n{"a":"b"}\r\nend 1\r\n),
        'broken JSON'                             => %(lich-genie-untrusted 1\r\n["^theirs",\r\nend 1\r\n),
        'an empty file'                           => ''
      }.each do |what, bytes|
        it "fails closed on #{what}: no row authored, one notice" do
          File.binwrite(side, bytes)
          expect(reload_triggers(notice: notice)).to eq('^mine' => false, '^theirs' => false)
          expect(notices).to eq(['triggers.cfg.untrusted is unreadable: no definition loaded from triggers.cfg may run a Lich command'])
        end
      end

      it 'fails closed on a directory in its place and on a dangling link' do
        File.delete(side)
        Dir.mkdir(side)
        expect(reload_triggers(notice: notice).values).to eq([false, false])
        Dir.rmdir(side)
        File.symlink(File.join(@dir, 'nowhere'), side)
        expect(reload_triggers(notice: notice).values).to eq([false, false])
        expect(notices.length).to eq(2)
      end

      it 'fails closed on a file it may not read (chmod 000)' do
        skip 'root can read a mode-000 file' if Process.euid.zero?
        File.chmod(0o000, side)
        expect(reload_triggers(notice: notice).values).to eq([false, false])
        expect(notices.length).to eq(1)
      ensure
        File.chmod(0o600, side) if File.exist?(side)
      end
    end

    # A save (this Lich's or another's on the same config dir) landing between the reads of
    # triggers.cfg and its side file must not pair a new triggers.cfg with the old side file.
    it 'reads again when a save lands while triggers.cfg is read' do
      File.binwrite(cfg.tap { |path| FileUtils.mkdir_p(File.dirname(path)) }, "#trigger {^old} {,go2 1}\r\n")
      other = Lich::Genie::Triggers.new
      other.add('^new', ',probe laundered')
      saved = false
      allow(Lich::Genie::TriggerFile).to receive(:read).and_wrap_original do |original, path|
        unless saved
          saved = true
          other.save(path)
        end
        original.call(path)
      end
      expect(reload_triggers).to eq('^new' => false)
    end

    it 'fails closed when the side file keeps changing while triggers.cfg is read' do
      registry.add('^a', ',go2 1', authored: true)
      registry.save(cfg)
      calls = 0
      allow(Lich::Genie::TriggerFile).to receive(:read).and_wrap_original do |original, path|
        calls += 1
        described_class.update(path, Set[["^x#{calls}", 'y', '']])
        original.call(path)
      end
      expect(reload_triggers(notice: notice)).to eq('^a' => false)
      expect(calls).to eq(described_class::READ_ATTEMPTS + 1)
      expect(notices.length).to eq(1)
    end

    it 'fails the save when the side file cannot be written first: triggers.cfg untouched, one error line' do
      registry.add('^old', ',go2 1', authored: true)
      registry.save(cfg)
      before = File.binread(cfg)
      Dir.mkdir(side) # a rename onto a directory fails
      registry.add('^theirs', ',probe x')
      expect(registry.save(cfg, notice: notice)).to be(false)
      expect(File.binread(cfg)).to eq(before)
      expect(notices.length).to eq(1)
      expect(notices.first).to start_with('triggers.cfg.untrusted could not be written (').and end_with('): triggers.cfg not saved')
      expect(Dir.children(File.dirname(cfg))).to contain_exactly('triggers.cfg', 'triggers.cfg.untrusted') # no temp file left
    end

    it 'writes no triggers.cfg at all when the first side-file write fails on a new config dir' do
      registry.add('^theirs', ',probe x')
      allow(Lich::Genie::ConfigFile).to receive(:write_lines).and_call_original
      allow(Lich::Genie::ConfigFile).to receive(:write_lines).with(side, anything).and_raise(Errno::ENOSPC)
      expect(registry.save(cfg, notice: notice)).to be(false)
      expect(File.exist?(cfg)).to be(false)
      expect(notices.first).to include('No space left on device')
    end

    # The side file written before triggers.cfg also covers what the triggers.cfg on disk holds, so
    # a triggers.cfg write that fails cannot leave an unauthored row of the old file unlisted.
    it 'keeps the old file\'s unauthored rows listed when the triggers.cfg write fails' do
      registry.add('^theirs', ',probe x')
      registry.save(cfg)
      registry.remove('^theirs')
      registry.add('^new', ',probe y')
      allow(Lich::Genie::ConfigFile).to receive(:write_lines).and_call_original
      allow(Lich::Genie::ConfigFile).to receive(:write_lines).with(cfg, anything).and_raise(Errno::EACCES)
      expect(registry.save(cfg)).to be(false)
      expect(reload_triggers).to eq('^theirs' => false)
    end

    it 'lists every row of the old file when its side file was unusable and the triggers.cfg write fails' do
      registry.add('^theirs', ',probe x')
      registry.add('^mine', ',go2 1', authored: true)
      registry.save(cfg)
      File.binwrite(side, 'corrupt')
      registry.clear
      allow(Lich::Genie::ConfigFile).to receive(:write_lines).and_call_original
      allow(Lich::Genie::ConfigFile).to receive(:write_lines).with(cfg, anything).and_raise(Errno::EACCES)
      expect(registry.save(cfg)).to be(false)
      expect(reload_triggers(notice: notice)).to eq('^theirs' => false, '^mine' => false)
      expect(notices).to eq([]) # the side file is valid again, and lists both
    end

    it 'reports a side file it cannot bring down after triggers.cfg is written, and still fails closed' do
      registry.add('^theirs', ',probe x')
      registry.save(cfg)
      registry.add('^theirs', ',probe x', authored: true)
      allow(File).to receive(:delete).and_call_original
      allow(File).to receive(:delete).with(side).and_raise(Errno::EPERM)
      expect(registry.save(cfg, notice: notice)).to be(true)
      expect(notices.length).to eq(1)
      expect(notices.first).to start_with('triggers.cfg.untrusted could not be removed (')
      expect(reload_triggers).to eq('^theirs' => false)
    end
  end

  describe 'aliases: save and load' do
    let(:aliases) { Lich::Genie::AliasList.new }

    it 'keeps an unauthored alias unauthored and an authored one authored, aliases.cfg in Remix\'s format' do
      aliases.add(',mine', ',go2 1', authored: true)
      aliases.add(',zzla', ',probe aliased')
      expect(aliases.save(cfg('aliases.cfg'))).to be(true)
      expect(File.binread(cfg('aliases.cfg'))).to eq("#alias {,mine} {,go2 1}\r\n#alias {,zzla} {,probe aliased}\r\n")
      expect(File.binread(side('aliases.cfg'))).to eq(%(lich-genie-untrusted 1\r\n[",zzla",",probe aliased"]\r\nend 1\r\n))
      expect(reload_aliases).to eq(',mine' => true, ',zzla' => false)
    end

    it 'saves through the remembered path, with its side file beside it' do
      aliases.load(cfg('aliases.cfg'))
      aliases.add(',zzla', ',probe x')
      expect(aliases.save).to be(true)
      expect(reload_aliases).to eq(',zzla' => false)
    end

    it 'loads a hand-edited value, unicode and quotes included, as the user\'s own' do
      aliases.add(",k#{uni}", %(,probe "a;b" {c} #{uni} \\ $1))
      aliases.save(cfg('aliases.cfg'))
      expect(reload_aliases).to eq(",k#{uni}" => false)
      File.binwrite(cfg('aliases.cfg'), File.binread(cfg('aliases.cfg')).sub('{c}', '{d}'))
      expect(reload_aliases).to eq(",k#{uni}" => true)
    end

    it 'lists every row a value with a line break reads back as' do
      aliases.add(',bait', "x}\n#alias {,smuggled} {,probe smuggled")
      aliases.save(cfg('aliases.cfg'))
      expect(reload_aliases).to eq(',bait' => false, ',smuggled' => false)
    end

    it 'loads every row authored with no side file, and removes a stale one' do
      aliases.add(',a', ',probe x')
      aliases.save(cfg('aliases.cfg'))
      aliases.add(',a', ',probe x', authored: true)
      aliases.save(cfg('aliases.cfg'))
      expect(File.exist?(side('aliases.cfg'))).to be(false)
      expect(reload_aliases).to eq(',a' => true)
    end

    it 'fails closed on a corrupt side file, with one notice' do
      aliases.add(',a', ',go2 1', authored: true)
      aliases.add(',b', ',go2 2', authored: true)
      aliases.save(cfg('aliases.cfg'))
      File.binwrite(side('aliases.cfg'), %(lich-genie-untrusted 1\r\n[",a",",go2 1",""]\r\nend 1\r\n)) # a trigger identity
      expect(reload_aliases(notice: notice)).to eq(',a' => false, ',b' => false)
      expect(notices).to eq(['aliases.cfg.untrusted is unreadable: no definition loaded from aliases.cfg may run a Lich command'])
    end

    it 'fails the save when the side file cannot be written: aliases.cfg untouched, one error line' do
      aliases.add(',a', ',go2 1', authored: true)
      aliases.save(cfg('aliases.cfg'))
      before = File.binread(cfg('aliases.cfg'))
      Dir.mkdir(side('aliases.cfg'))
      aliases.add(',zzla', ',probe x')
      expect(aliases.save(cfg('aliases.cfg'), notice: notice)).to be(false)
      expect(File.binread(cfg('aliases.cfg'))).to eq(before)
      expect(notices.length).to eq(1)
      expect(notices.first).to end_with('): aliases.cfg not saved')
    end
  end

  describe 'through the #commands and a real script' do
    let(:game) { Object.new.tap { |g| g.define_singleton_method(:send_command) { |_text| nil } } }
    let(:echoes) { [] }

    def run_script(source, lists, lines: [])
      clock = [0.0]
      input = GenieSpecSupport::TimedInput.new(lines, clock: clock, gap: 0.02)
      Lich::Genie::Engine.run(source, name: 't', variables: Lich::Genie::Variables.new, game: game, input: input,
                                      echo: ->(t) { echoes << t }, hooks: nil, lists: lists, clock: -> { clock[0] })
    end

    def lists = Lich::Genie::Lists.new(config_dir: File.join(@dir, 'Config'))

    it '#trigger save / #trigger load / #load triggers / #alias save / #alias load keep provenance' do
      first = lists
      run_script(<<~GENIE, first, lines: ['Mallory sets ,probe t', 'Mallory aliases ,probe a', 'THE_END'])
        action put #trigger {^GO} {$1} when ^Mallory sets (.*)$
        action put #alias {,zzla} {$1} when ^Mallory aliases (.*)$
        put #trigger {^MINE} {,go2 1}
        waitfor THE_END
        put #trigger save
        put #alias save
      GENIE
      expect([first.triggers.authored?('^GO'), first.triggers.authored?('^MINE'), first.aliases.authored?(',zzla')]).to eq([false, true, false])
      %w[#trigger\ load #load\ triggers].each do |load|
        second = lists
        run_script("put #{load}\nput #alias load\n", second)
        expect([second.triggers.authored?('^GO'), second.triggers.authored?('^MINE'), second.aliases.authored?(',zzla')]).to eq([false, true, false])
      end
    end

    it 'echoes the corrupt-side-file notice on #trigger load and the failed-save line on #alias save' do
      File.write(cfg.tap { |path| FileUtils.mkdir_p(File.dirname(path)) }, "#trigger {^a} {,go2 1}\n")
      File.write(side, 'corrupt')
      Dir.mkdir(side('aliases.cfg'))
      bundle = lists
      run_script("put #trigger load\nput #alias {,x} {,go2 2}\nput #var y 1\nput #alias {,y} {,go2 $y}\nput #alias save\n", bundle)
      expect(bundle.triggers.authored?('^a')).to be(false)
      expect(echoes[0..1]).to eq(['Triggers Loaded', 'triggers.cfg.untrusted is unreadable: no definition loaded from triggers.cfg may run a Lich command'])
      expect(echoes.last).to end_with('): aliases.cfg not saved')
      expect(echoes[-2]).to eq('Aliases Saved') # Remix's line comes first, as it always does
    end
  end

  describe 'engine start (Lich::Genie wiring)' do
    around do |example|
      saved = %i[@config_dir @global_store @triggers @class_list @alias_list @stream_filters @definition_notice_listener @pending_notices]
              .to_h { |ivar| [ivar, Lich::Genie.instance_variable_get(ivar)] }
      Lich::Genie.instance_variable_set(:@definition_notice_listener, nil)
      Lich::Genie.instance_variable_set(:@pending_notices, [])
      Lich::Genie.config_dir = @dir
      example.run
    ensure
      saved.each { |ivar, value| Lich::Genie.instance_variable_set(ivar, value) }
    end

    it 'reads the side files at the first build of the registries' do
      registry = Lich::Genie::Triggers.new
      registry.add('^theirs', ',probe x')
      registry.add('^mine', ',go2 1', authored: true)
      registry.save(cfg)
      aliases = Lich::Genie::AliasList.new
      aliases.add(',zzla', ',probe y')
      aliases.save(cfg('aliases.cfg'))
      expect([Lich::Genie.triggers.authored?('^theirs'), Lich::Genie.triggers.authored?('^mine')]).to eq([false, true])
      expect(Lich::Genie.alias_list.authored?(',zzla')).to be(false)
    end

    it 'holds a notice made before the glue listens and hands it over, once, when it does' do
      File.write(cfg.tap { |path| FileUtils.mkdir_p(File.dirname(path)) }, "#trigger {^a} {,go2 1}\n")
      File.write(side, 'corrupt')
      File.write(cfg('aliases.cfg'), "#alias {,a} {,go2 1}\n")
      File.write(side('aliases.cfg'), 'corrupt')
      expect(Lich::Genie.triggers.authored?('^a')).to be(false)
      expect(Lich::Genie.alias_list.authored?(',a')).to be(false)
      heard = []
      Lich::Genie.definition_notice_listener = ->(text) { heard << text }
      expect(heard).to eq([Lich::Genie::DefinitionTrust.corrupt_notice(cfg), Lich::Genie::DefinitionTrust.corrupt_notice(cfg('aliases.cfg'))])
      Lich::Genie.definition_notice('later')
      expect(heard.last).to eq('later')
      expect(Lich::Genie.instance_variable_get(:@pending_notices)).to eq([])
    end
  end
end
