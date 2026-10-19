# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative File.join(SPEC_ROOT, 'mock_database_adapter.rb')

require 'common/settings'
require 'common/settings/instance_settings'
require 'tmpdir'
require 'fileutils'

# Writes made while iterating a Settings container, and destructive calls
# through what sort or select returned, through the public API and the real
# DatabaseAdapter (Sequel on a throwaway SQLite file). "Stored" is the row as
# a second connection reads it from the file; "reloaded" is what Settings
# reads after Settings.load.
RSpec.describe Lich::Common::Settings, "writes made while iterating, through the real DatabaseAdapter" do
  let(:settings) { Lich::Common::Settings }
  let(:tmp_dir) { Dir.mktmpdir('settings-iteration-spec') }
  let(:db_file) { File.join(tmp_dir, 'lich.db3') }

  before do
    stub_const("Script", Lich::Common::MockScript)
    stub_const("XMLData", Lich::Common::MockXMLData)
    Lich::Common::MockScript.current_name = "test_script"
    Lich::Common::MockXMLData.game = "GSIV"
    Lich::Common::MockXMLData.name = "TestCharacter"
    allow(Lich).to receive(:log)
    @errors = []
    allow(Lich::Messaging).to receive(:msg) { |kind, text| @errors << text if kind == "error" }
    SQLite3::Database.new(db_file).tap do |db|
      db.execute('CREATE TABLE script_auto_settings (script TEXT NOT NULL, scope TEXT, hash BLOB, PRIMARY KEY(script, scope));')
    end.close
    @saved_adapter = settings.instance_variable_get(:@db_adapter)
    @saved_navigator = settings.instance_variable_get(:@path_navigator)
    @adapter = Lich::Common::DatabaseAdapter.new(tmp_dir, :script_auto_settings)
    settings.instance_variable_set(:@db_adapter, @adapter)
    settings.instance_variable_set(:@path_navigator, Lich::Common::PathNavigator.new(@adapter))
    settings.instance_variable_set(:@settings_cache, {})
    settings.instance_variable_set(:@cache_versions, {})
  end

  after do
    settings.instance_variable_set(:@db_adapter, @saved_adapter)
    settings.instance_variable_set(:@path_navigator, @saved_navigator)
    settings.instance_variable_set(:@settings_cache, {})
    settings.instance_variable_set(:@cache_versions, {})
    @adapter.instance_variable_get(:@db)&.disconnect
    @adapter.instance_variable_get(:@version_db)&.close
    FileUtils.remove_entry(tmp_dir)
  end

  # The row another process would read, straight from the file.
  def stored(script = 'test_script', scope = ':')
    db = SQLite3::Database.new(db_file)
    blob = db.get_first_value('SELECT hash FROM script_auto_settings WHERE script = ? AND scope = ?', [script, scope])
    blob ? Marshal.load(blob) : nil
  ensure
    db&.close
  end

  # Another session's commit, made on a connection of its own.
  def their_write(row, script = 'test_script', scope = ':')
    db = SQLite3::Database.new(db_file)
    db.execute('INSERT OR REPLACE INTO script_auto_settings (script, scope, hash) VALUES (?, ?, ?)',
               [script, scope, SQLite3::Blob.new(Marshal.dump(row))])
  ensure
    db&.close
  end

  # +value+ with every proxy in it replaced by its target.
  def plain(value)
    case value
    when Lich::Common::SettingsProxy then plain(value.target)
    when Array then value.map { |v| plain(v) }
    when Hash then value.transform_values { |v| plain(v) }
    else value
    end
  end

  # What Settings shows for +key+ after dropping this session's cached row.
  def reloaded(key)
    settings.load
    plain(settings[key])
  end

  # The error messages the user was shown.
  def error_messages
    @errors
  end

  describe "an Array of Hashes" do
    before { settings[:rows] = [{ name: "a", count: 0 }, { name: "b", count: 0 }] }

    it "stores a write to each element each yields" do
      settings[:rows].each { |row| row[:count] = 1 }

      expect(stored[:rows]).to eq([{ name: "a", count: 1 }, { name: "b", count: 1 }])
      expect(reloaded(:rows)).to eq([{ name: "a", count: 1 }, { name: "b", count: 1 }])
      expect(error_messages).to be_empty
    end

    it "stores a write to each element each_with_index yields, at that element" do
      settings[:rows].each_with_index { |row, i| row[:count] = i + 10 }

      expect(stored[:rows]).to eq([{ name: "a", count: 10 }, { name: "b", count: 11 }])
      expect(reloaded(:rows)).to eq(stored[:rows])
    end

    it "stores a write to each element each.with_index and each_with_object yield" do
      settings[:rows].each.with_index { |row, i| row[:i] = i }
      memo = settings[:rows].each_with_object([]) { |row, seen| row[:seen] = true; seen << row[:name] }

      expect(memo).to eq(["a", "b"])
      expect(stored[:rows]).to eq([{ name: "a", count: 0, i: 0, seen: true }, { name: "b", count: 0, i: 1, seen: true }])
    end

    it "stores a write to a container inside each element, at its own path" do
      settings[:rows] = [{ tags: [] }, { tags: ["old"] }]

      settings[:rows].each { |row| row[:tags] << "new" }
      settings[:rows].each { |row| row.dig(:tags).push("dug") }

      expect(stored[:rows]).to eq([{ tags: ["new", "dug"] }, { tags: ["old", "new", "dug"] }])
      expect(reloaded(:rows)).to eq(stored[:rows])
    end

    it "keeps what another session changed in an element the loop writes to, and the elements it appended" do
      rows = settings[:rows]
      their_write({ rows: [{ name: "a", count: 0, theirs: 1 }, { name: "b", count: 0 }, { name: "c", count: 0 }] })

      rows.each { |row| row[:count] = 1 }

      expect(stored[:rows]).to eq([{ name: "a", count: 1, theirs: 1 }, { name: "b", count: 1 }, { name: "c", count: 0 }])
    end

    it "stores what in-place map! and select! do, including a write their block makes to an element" do
      settings[:rows].map! { |row| row[:count] = 2; row }
      settings[:rows].select! { |row| row[:name] == "b" }

      expect(stored[:rows]).to eq([{ name: "b", count: 2 }])
      expect(reloaded(:rows)).to eq([{ name: "b", count: 2 }])
    end

    it "stores a write each yields for a nested Array of Hashes, and for a loop inside a loop" do
      settings[:groups] = { list: [{ members: [{ n: 1 }, { n: 2 }] }, { members: [{ n: 3 }] }] }

      settings[:groups][:list].each { |group| group[:members].each { |member| member[:on] = member[:n].odd? } }

      expect(stored[:groups]).to eq(list: [{ members: [{ n: 1, on: true }, { n: 2, on: false }] }, { members: [{ n: 3, on: true }] }])
      expect(reloaded(:groups)).to eq(stored[:groups])
    end

    it "yields plain values as they are, and returns the proxy" do
      settings[:nums] = [1, 2, 3]
      seen = []

      result = settings[:nums].each { |n| seen << n }

      expect(seen).to eq([1, 2, 3])
      expect(result.target).to eq([1, 2, 3])
      expect(settings[:nums].each).to be_a(Enumerator)
    end
  end

  describe "a Hash of Hashes" do
    before { settings[:by_name] = { "a" => { count: 0 }, "b" => { count: 0 }, "n" => 5 } }

    it "stores a write to the value each yields to a |key, value| block" do
      settings[:by_name].each { |_name, entry| entry[:count] = 1 if entry.is_a?(Hash) }

      expect(stored[:by_name]).to eq("a" => { count: 1 }, "b" => { count: 1 }, "n" => 5)
      expect(reloaded(:by_name)).to eq(stored[:by_name])
    end

    it "yields one [key, value] pair to a one-argument block, whose value writes are stored" do
      pairs = []
      settings[:by_name].each do |pair|
        pairs << [pair.class, pair.first]
        pair.last[:count] = 2 if pair.last.is_a?(Hash)
      end

      expect(pairs).to eq([[Array, "a"], [Array, "b"], [Array, "n"]])
      expect(stored[:by_name]).to eq("a" => { count: 2 }, "b" => { count: 2 }, "n" => 5)
    end

    it "yields what a plain Hash yields for each block arity" do
      plain = { "a" => { count: 0 }, "n" => 5 }
      settings[:shape] = plain
      blocks = {
        "|k, v|"      => proc { |k, v| [k, v] },
        "|pair|"      => proc { |pair| pair },
        "|*all|"      => proc { |*all| all },
        "|k, *rest|"  => proc { |k, *rest| [k, rest] },
        "|k, (a, b)|" => proc { |k, (a, b)| [k, a, b] }
      }
      blocks.each do |how, block|
        mine = []
        settings[:shape].each { |*args| mine << plain(block.call(*args)) }
        theirs = []
        plain.each { |*args| theirs << block.call(*args) }
        expect(mine).to eq(theirs), how
      end
      expect { settings[:shape].each(&->(k, v) { [k, v] }) }.to raise_error(ArgumentError)
      expect { plain.each(&->(k, v) { [k, v] }) }.to raise_error(ArgumentError)
    end

    it "lets Ruby take a Hash value apart only as it would take the Hash apart" do
      entry = settings[:by_name]["a"]

      first, second = entry

      expect([first.target, second]).to eq([{ count: 0 }, nil])
      expect(Array(entry)).to eq([[:count, 0]])
      expect([entry].flatten.map(&:target)).to eq([{ count: 0 }])
      expect({ n: 1 }.merge(entry)).to eq(n: 1, count: 0)
      settings[:list_for_plus] = [1]
      expect([0] + settings[:list_for_plus]).to eq([0, 1])
    end

    it "stores the writes made before a break, and returns what break gave" do
      result = settings[:by_name].each { |name, entry| break name if name == "b"; entry[:count] = 5 }

      expect(result).to eq("b")
      expect(stored[:by_name]).to eq("a" => { count: 5 }, "b" => { count: 0 }, "n" => 5)
    end

    it "stores a write to each value each_with_index yields with its pair" do
      settings[:by_name].each_with_index { |(_name, entry), i| entry[:i] = i if entry.is_a?(Hash) }

      expect(stored[:by_name]).to eq("a" => { count: 0, i: 0 }, "b" => { count: 0, i: 1 }, "n" => 5)
    end
  end

  describe "a view (what sort, select or map returned)" do
    before { settings[:rows] = [{ n: 3 }, { n: 1, on: true }, { n: 2, on: true }] }

    it "stores a write to an element each yields for a sort_by or select view, where that element is in the settings" do
      settings[:rows].sort_by { |row| row[:n] }.each { |row| row[:rank] = row[:n] }
      settings[:rows].select { |row| row[:on] }.each { |row| row[:picked] = true }

      expect(stored[:rows]).to eq([{ n: 3, rank: 3 }, { n: 1, on: true, rank: 1, picked: true }, { n: 2, on: true, rank: 2, picked: true }])
      expect(error_messages).to be_empty
    end

    it "stores nothing, and says so once per loop, for the new containers a map view holds" do
      before_write = stored

      settings[:rows].map { |row| row.merge(m: 1) }.each { |row| row[:k] = 1 }

      expect(stored).to eq(before_write)
      expect(error_messages.size).to eq(1)
      expect(error_messages.first).to include("not saved", "not found in the settings", "later writes through what this each loop yields are not saved either")
    end
  end

  describe "a destructive call on a sort or select view" do
    before { settings[:items] = [3, 1, 2] }

    it "stores the call on the container at the view's path, and a later top-level write as well" do
      view = settings[:items].sort
      expect { view.push(4) }.not_to raise_error

      settings[:other] = 1

      expect(stored).to eq(items: [3, 1, 2, 4], other: 1)
      expect(view.to_a).to eq([3, 1, 2, 4])
      expect(reloaded(:items)).to eq([3, 1, 2, 4])
      expect(reloaded(:other)).to eq(1)
    end

    it "stores a select view's call on the container at a nested path, not at the top of the row" do
      settings[:cfg] = { items: [1, 2, 3] }

      settings[:cfg][:items].select(&:odd?).push(5)
      settings[:top] = true

      expect(stored).to eq(items: [3, 1, 2], cfg: { items: [1, 2, 3, 5] }, top: true)
    end

    it "stores the call on the stored container, keeping what another session saved there" do
      view = settings[:items].sort
      their_write({ items: [3, 1, 2, 9], theirs: 1 })

      view.push(4)

      expect(stored).to eq(items: [3, 1, 2, 9, 4], theirs: 1)
    end

    it "stores nothing, and says so, when the container at the view's path is not of the view's kind" do
      settings[:opts] = { "a" => 1 }

      expect { settings[:opts].values.push(2) }.not_to raise_error
      settings[:after] = 1

      expect(stored).to eq(items: [3, 1, 2], opts: { "a" => 1 }, after: 1)
      expect(error_messages).to include(a_string_including("not saved", "push on a view", "[:opts]", "hold Hash there, and the view is Array"))
    end

    it "stores the call in the row of the proxy's own script (InstanceSettings)" do
      Lich::Common::InstanceSettings[:list] = [2, 1]

      Lich::Common::InstanceSettings[:list].sort.push(3)
      Lich::Common::InstanceSettings[:other] = 1

      expect(stored('core', 'GSIV:TestCharacter')).to eq(list: [2, 1, 3], other: 1)
      expect(stored).to eq(items: [3, 1, 2])
    end
  end
end
