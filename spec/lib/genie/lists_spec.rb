# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'
require 'tmpdir'

# Lich::Genie::Lists: the session's global lists and Command_EventClassChange (FormMain.cs:7483-7519 R).
RSpec.describe Lich::Genie::Lists do
  it 'starts headless with default = True and no files' do
    lists = described_class.new
    expect(lists.classes.entries).to eq([['default', true]])
    expect([lists.file('triggers.cfg'), lists.save_file('triggers.cfg')]).to eq([nil, nil])
  end

  it 'reads registries through callables at each use (a rebuilt one is followed)' do
    current = Lich::Genie::Triggers.new
    lists = described_class.new(triggers: -> { current })
    first = lists.triggers
    current = Lich::Genie::Triggers.new
    expect(lists.triggers).not_to equal(first)
  end

  it 'gives load paths always and save paths only when writable' do
    lists = described_class.new(config_dir: '/cfg', writable: false)
    expect([lists.file('gags.cfg'), lists.save_file('gags.cfg'), lists.writable?]).to eq(['/cfg/gags.cfg', nil, false])
  end

  describe '#class_changed (re-apply EVERY entry, in list order, to triggers and gags/subs)' do
    let(:lists) { described_class.new }

    before do
      lists.triggers.add('^a', 'x', klass: 'Combat')
      lists.triggers.add('^b', 'y')
      lists.filters.add_gag('^g', klass: 'Combat')
      lists.filters.add_gag('^h', klass: 'combat')
    end

    it 'switches a trigger re-added while its class is off back off only at the next class event' do
      lists.classes.add('combat', 'off')
      lists.class_changed
      expect(lists.triggers.entries.first[4]).to be(false)
      lists.triggers.add('^a', 'x', klass: 'Combat') # a new Trigger: active
      expect(lists.triggers.entries.first[4]).to be(true)
      lists.classes.add('other', 'on')
      lists.class_changed
      expect(lists.triggers.entries.first[4]).to be(false)
    end

    it 'compares trigger classes lower-cased but gag classes exactly, and `default` drives the class-less ones' do
      lists.classes.add('combat', 'off')
      lists.classes.add('default', 'off')
      lists.class_changed
      expect(lists.triggers.entries.map { |e| e[4] }).to eq([false, false]) # ^a (Combat) and ^b (class-less)
      expect(lists.filters.gags.map(&:active)).to eq([true, false]) # only the exact 'combat' gag
    end

    it 'lets the later of two case-variant keys win for the triggers (list order)' do
      lists.classes.add('combat', 'off')
      lists.classes.add('Combat', 'on') # sorts after 'combat'
      lists.class_changed
      expect(lists.triggers.entries.first[4]).to be(true)
      expect(lists.filters.gags.map(&:active)).to eq([true, false])
    end
  end

  # A class event snapshots the class list and applies it entry by entry; a
  # second event that runs meanwhile must not be overwritten by the first one's stale snapshot.
  it 'applies two concurrent class events one after the other: the later list state wins' do
    entered = Queue.new
    release = Queue.new
    applied = []
    held = false
    triggers = Object.new
    triggers.define_singleton_method(:toggle_class) do |name, state|
      unless held
        held = true
        entered << :in
        release.pop # hold the first event in the middle of its walk
      end
      applied << [name, state]
    end
    lists = described_class.new(triggers: triggers)
    lists.classes.add('combat', 'on')
    first = Thread.new { lists.class_changed }
    entered.pop
    lists.classes.add('combat', 'off')
    second = Thread.new { lists.class_changed }
    expect(second.join(0.2)).to be_nil # waits for the first event
    release << :go
    [first, second].each { |t| expect(t.join(5)).not_to be_nil }
    expect(applied.to_h['combat']).to be(false) # the last applied state of 'combat'
    expect(lists.filters.gags).to eq([])
  ensure
    release << :go
    [first, second].compact.each { |t| t.join(5) }
  end

  describe '#validate_directory' do
    around { |example| Dir.mktmpdir('genie-lists') { |dir| @dir = File.realpath(dir); example.run } }

    it 'is relative to the folder above the config dir and creates only when writable' do
      config = File.join(@dir, 'Config')
      expect(described_class.new(config_dir: config, writable: false).validate_directory('Logs')).to eq("Directory Created: #{@dir}/Logs")
      expect(Dir.exist?(File.join(@dir, 'Logs'))).to be(false)
      expect(described_class.new(config_dir: config).validate_directory('Logs')).to eq("Directory Created: #{@dir}/Logs")
      expect(Dir.exist?(File.join(@dir, 'Logs'))).to be(true)
    end
  end
end
