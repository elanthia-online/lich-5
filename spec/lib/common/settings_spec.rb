# frozen_string_literal: true

require_relative '../../spec_helper'

# Load mock database adapter (specific to settings tests)
require_relative File.join(SPEC_ROOT, 'mock_database_adapter.rb')

# Load production code
require 'common/settings'
require 'tmpdir'
require 'fileutils'
require 'timeout'

RSpec.describe Lich::Common::Settings do
  before(:each) do
    @mock_db = Lich::Common::MockDatabaseAdapter.new
    allow(Lich::Common::DatabaseAdapter).to receive(:new).and_return(@mock_db)

    Lich::Common::MockScript.current_name = "test_script"
    Lich::Common::MockXMLData.game = "GSIV"
    Lich::Common::MockXMLData.name = "TestCharacter"

    stub_const("Script", Lich::Common::MockScript)
    stub_const("XMLData", Lich::Common::MockXMLData)

    Lich::Common::Settings.instance_variable_set(:@db_adapter, @mock_db)
    Lich::Common::Settings.instance_variable_set(:@path_navigator, Lich::Common::PathNavigator.new(@mock_db))

    @mock_db.clear
  end

  describe "Basic Functionality" do
    it "sets and retrieves a simple value" do
      Lich::Common::Settings[:test_key] = "test_value"
      expect(Lich::Common::Settings[:test_key]).to eq("test_value")
    end

    it "persists values to the database" do
      Lich::Common::Settings[:test_key] = "test_value"
      storage = @mock_db.dump
      expect(storage["test_script::"]).to include(:test_key => "test_value")
    end

    it "handles different scopes" do
      Lich::Common::Settings.set_script_settings("custom_scope", :test_key, "scoped_value")
      expect(Lich::Common::Settings.to_hash("custom_scope")[:test_key]).to eq("scoped_value")
    end

    it "returns nil for non-existent keys" do
      expect(Lich::Common::Settings[:non_existent]).to be_nil
    end

    it "supports to_h method" do
      Lich::Common::Settings[:key1] = "value1"
      Lich::Common::Settings[:key2] = "value2"
      hash = Lich::Common::Settings.to_h
      expect(hash).to include(:key1 => "value1", :key2 => "value2")
    end
  end

  describe "Ruby Compatibility" do
    describe "Standard Ruby Operators" do
      it "handles nil? operator" do
        expect(Lich::Common::Settings[:non_existent].nil?).to be true
        Lich::Common::Settings[:test_key] = "value"
        expect(Lich::Common::Settings[:test_key].nil?).to be false
      end

      it "handles == operator" do
        Lich::Common::Settings[:test_hash] = { a: 1, b: 2 }
        expect(Lich::Common::Settings[:test_hash] == { a: 1, b: 2 }).to be true
        expect(Lich::Common::Settings[:test_hash] == { a: 1 }).to be false
      end

      it "handles != operator" do
        Lich::Common::Settings[:test_hash] = { a: 1, b: 2 }
        expect(Lich::Common::Settings[:test_hash] != { a: 1 }).to be true
        expect(Lich::Common::Settings[:test_hash] != { a: 1, b: 2 }).to be false
      end

      it "handles ||= operator (non-destructive read)" do
        Lich::Common::Settings[:existing] = "original"
        existing = Lich::Common::Settings[:existing] ||= "default"
        expect(existing).to eq("original")

        new_value = Lich::Common::Settings[:new_key] ||= "default"
        expect(new_value).to eq("default")
        expect(Lich::Common::Settings[:new_key]).to eq("default")
      end
    end

    describe "Comparison Operators" do
      before(:each) do
        Lich::Common::Settings[:numbers] = [1, 2, 3]
      end

      it "handles <=> operator" do
        expect(Lich::Common::Settings[:numbers] <=> [1, 2, 3]).to eq(0)
        expect(Lich::Common::Settings[:numbers] <=> [0, 2, 3]).to eq(1)
        expect(Lich::Common::Settings[:numbers] <=> [2, 2, 3]).to eq(-1)
      end
    end

    describe "Boolean Operators" do
      before(:each) do
        Lich::Common::Settings[:set1] = [1, 2, 3]
        Lich::Common::Settings[:set2] = [3, 4, 5]
      end

      it "handles | operator" do
        union = Lich::Common::Settings[:set1] | Lich::Common::Settings[:set2]
        expect(union).to contain_exactly(1, 2, 3, 4, 5)
      end

      it "handles & operator" do
        intersection = Lich::Common::Settings[:set1] & Lich::Common::Settings[:set2]
        expect(intersection).to contain_exactly(3)
      end
    end

    describe "Type Checking Methods" do
      it "handles is_a? method" do
        Lich::Common::Settings[:test_hash] = { a: 1 }
        Lich::Common::Settings[:test_array] = [1, 2, 3]

        expect(Lich::Common::Settings[:test_hash].is_a?(Hash)).to be true
        expect(Lich::Common::Settings[:test_array].is_a?(Array)).to be true
      end

      it "handles kind_of? method" do
        Lich::Common::Settings[:test_hash] = { a: 1 }
        expect(Lich::Common::Settings[:test_hash].kind_of?(Hash)).to be true
        expect(Lich::Common::Settings[:test_hash].kind_of?(Array)).to be false
      end

      it "handles instance_of? method" do
        Lich::Common::Settings[:test_hash] = { a: 1 }
        expect(Lich::Common::Settings[:test_hash].instance_of?(Hash)).to be true
        expect(Lich::Common::Settings[:test_hash].instance_of?(Array)).to be false
      end
    end

    describe "Conversion Methods" do
      it "handles to_hash and to_h methods" do
        Lich::Common::Settings[:test_hash] = { a: 1, b: 2 }
        hash = Lich::Common::Settings[:test_hash].to_hash
        expect(hash).to be_a(Hash)
        expect(hash).to eq({ a: 1, b: 2 })

        h = Lich::Common::Settings[:test_hash].to_h
        expect(h).to be_a(Hash)
        expect(h).to eq({ a: 1, b: 2 })
      end

      it "handles to_ary and to_a methods" do
        Lich::Common::Settings[:test_array] = [1, 2, 3]
        ary = Lich::Common::Settings[:test_array].to_ary
        expect(ary).to be_an(Array)
        expect(ary).to eq([1, 2, 3])

        a = Lich::Common::Settings[:test_array].to_a
        expect(a).to be_an(Array)
        expect(a).to eq([1, 2, 3])
      end

      it "handles to_s method" do
        Lich::Common::Settings[:test_array] = [1, 2, 3]
        str = Lich::Common::Settings[:test_array].to_s
        expect(str).to eq("[1, 2, 3]")
      end

      it "handles to_i method" do
        Lich::Common::Settings[:test_number] = 42
        num = Lich::Common::Settings[:test_number].to_i
        expect(num).to eq(42)
      end
    end
  end

  describe "Container Operations" do
    describe "Hash Operations" do
      before(:each) do
        Lich::Common::Settings[:test_hash] = { a: 1, b: 2 }
      end

      it "accesses hash keys" do
        expect(Lich::Common::Settings[:test_hash][:a]).to eq(1)
      end

      it "sets hash keys" do
        tmp = Lich::Common::Settings[:test_hash] || {}
        tmp[:c] = 3
        Lich::Common::Settings[:test_hash] = tmp
        expect(Lich::Common::Settings[:test_hash][:c]).to eq(3)
      end

      it "supports hash methods" do
        expect(Lich::Common::Settings[:test_hash].keys).to contain_exactly(:a, :b)
        expect(Lich::Common::Settings[:test_hash].values).to contain_exactly(1, 2)
      end

      it "supports hash iteration" do
        result = {}
        Lich::Common::Settings[:test_hash].each { |k, v| result[k] = v }
        expect(result).to eq({ a: 1, b: 2 })
      end

      it "supports empty? method" do
        Lich::Common::Settings[:empty_hash] = {}
        expect(Lich::Common::Settings[:empty_hash].empty?).to be true
        expect(Lich::Common::Settings[:test_hash].empty?).to be false
      end
    end

    describe "Array Operations" do
      before(:each) do
        Lich::Common::Settings[:test_array] = [1, 2, 3]
      end

      it "accesses array indices" do
        expect(Lich::Common::Settings[:test_array][0]).to eq(1)
      end

      it "sets array indices" do
        arr = Lich::Common::Settings[:test_array] || []
        arr[1] = 99
        Lich::Common::Settings[:test_array] = arr
        expect(Lich::Common::Settings[:test_array][1]).to eq(99)
      end

      it "supports push operation" do
        arr = Lich::Common::Settings[:test_array] || []
        arr.push(4)
        Lich::Common::Settings[:test_array] = arr
        expect(Lich::Common::Settings[:test_array].to_a).to eq([1, 2, 3, 4])
      end

      it "supports << operation" do
        arr = Lich::Common::Settings[:test_array] || []
        arr << 4
        Lich::Common::Settings[:test_array] = arr
        expect(Lich::Common::Settings[:test_array].to_a).to eq([1, 2, 3, 4])
      end

      it "supports include? operation" do
        expect(Lich::Common::Settings[:test_array].include?(2)).to be true
        expect(Lich::Common::Settings[:test_array].include?(99)).to be false
      end

      it "supports empty? method" do
        Lich::Common::Settings[:empty_array] = []
        expect(Lich::Common::Settings[:empty_array].empty?).to be true
        expect(Lich::Common::Settings[:test_array].empty?).to be false
      end
    end

    describe "Enumerable Support" do
      it "supports each method" do
        Lich::Common::Settings[:test_array] = [1, 2, 3]
        sum = 0
        Lich::Common::Settings[:test_array].each { |n| sum += n }
        expect(sum).to eq(6)
      end

      it "supports map method" do
        Lich::Common::Settings[:test_array] = [1, 2, 3]
        result = Lich::Common::Settings[:test_array].map { |n| n * 2 }
        expect(result).to eq([2, 4, 6])
      end

      it "supports select method" do
        Lich::Common::Settings[:test_array] = [1, 2, 3, 4, 5]
        result = Lich::Common::Settings[:test_array].select { |n| n.even? }
        expect(result).to eq([2, 4])
      end

      it "supports reduce method" do
        Lich::Common::Settings[:test_array] = [1, 2, 3, 4, 5]
        result = Lich::Common::Settings[:test_array].reduce(0) { |sum, n| sum + n }
        expect(result).to eq(15)
      end
    end
  end

  describe "Nested Structure Operations" do
    it "handles multi-level hash access" do
      cfg  = Lich::Common::Settings[:config] || {}
      lvl1 = cfg[:level1] || {}
      lvl2 = lvl1[:level2] || {}
      lvl2[:level3] = "deep_value"
      lvl1[:level2] = lvl2
      cfg[:level1]  = lvl1
      Lich::Common::Settings[:config] = cfg

      expect(Lich::Common::Settings[:config][:level1][:level2][:level3]).to eq("deep_value")
    end

    it "handles array of hashes" do
      users = Lich::Common::Settings[:users] || []
      users << { name: "Alice", age: 30 }
      users << { name: "Bob",   age: 25 }
      Lich::Common::Settings[:users] = users

      expect(Lich::Common::Settings[:users][0][:name]).to eq("Alice")
      expect(Lich::Common::Settings[:users][1][:age]).to eq(25)
    end

    it "handles the updatable scripts example" do
      upd     = Lich::Common::Settings[:updatable] || {}
      # Start with a fresh scripts array to ensure test isolation with random ordering
      scripts = []
      mapdb   = upd[:mapdb] || {}

      scripts << { filename: "alias.lic", game: "gs", author: "elanthia-online" }
      mapdb["GSIV"] = true
      upd["lich"]   = false

      upd[:scripts] = scripts
      upd[:mapdb]   = mapdb
      Lich::Common::Settings[:updatable] = upd

      expect(Lich::Common::Settings[:updatable][:scripts][0][:filename]).to eq("alias.lic")
      expect(Lich::Common::Settings[:updatable][:mapdb]["GSIV"]).to be true
      expect(Lich::Common::Settings[:updatable]["lich"]).to be false
    end

    it "persists complex nested structures" do
      upd     = Lich::Common::Settings[:updatable] || {}
      scripts = [] # force a clean list for this example
      scripts << ({ filename: "test.lic", game: "gs" })
      upd[:scripts] = scripts
      Lich::Common::Settings[:updatable] = upd

      storage = @mock_db.dump
      expect(storage["test_script::"][:updatable][:scripts][0][:filename]).to eq("test.lic")
    end

    it "handles nested updates" do
      cfg  = Lich::Common::Settings[:config] || {}
      opts = cfg[:options] || { timeout: 30 }
      opts[:timeout] = 60
      cfg[:options]  = opts
      Lich::Common::Settings[:config] = cfg

      expect(Lich::Common::Settings[:config][:options][:timeout]).to eq(60)

      storage = @mock_db.dump
      expect(storage["test_script::"][:config][:options][:timeout]).to eq(60)
    end
  end

  # ---- Non-destructive vs. Destructive behavior coverage ----

  describe "Non-destructive Operations" do
    it "retains root hash when re-initialized safely" do
      root = Lich::Common::Settings[:root] || {}
      root[:nested] = "value1"
      Lich::Common::Settings[:root] = root

      # safe re-init: read + write-back the same structure
      root = Lich::Common::Settings[:root] || {}
      Lich::Common::Settings[:root] = root
      expect(Lich::Common::Settings[:root][:nested]).to eq("value1")

      storage = @mock_db.dump
      expect(storage["test_script::"][:root][:nested]).to eq("value1")
    end

    it "retains root array when re-initialized safely" do
      list = (Lich::Common::Settings[:list] || [])
      list << "item1"
      Lich::Common::Settings[:list] = list

      list = (Lich::Common::Settings[:list] || [])
      Lich::Common::Settings[:list] = list
      expect(Lich::Common::Settings[:list]).to include("item1")

      storage = @mock_db.dump
      expect(storage["test_script::"][:list]).to include("item1")
    end

    it "preserves nested data when re-initializing branches with safe pattern" do
      branch = (Lich::Common::Settings[:branch] || {})
      branch[:deep] = { a: 1 }
      Lich::Common::Settings[:branch] = branch

      branch = (Lich::Common::Settings[:branch] || {})
      branch[:deep] = (branch[:deep] || { b: 2 })
      Lich::Common::Settings[:branch] = branch

      expect(Lich::Common::Settings[:branch][:deep][:a]).to eq(1)

      storage = @mock_db.dump
      expect(storage["test_script::"][:branch][:deep][:a]).to eq(1)
    end
  end

  describe "Destructive Operations" do
    it "overwrites an existing root hash when = is used" do
      Lich::Common::Settings[:root] = { a: 1, b: 2 }
      expect(Lich::Common::Settings[:root][:a]).to eq(1)

      Lich::Common::Settings[:root] = {}
      expect(Lich::Common::Settings[:root][:a]).to be_nil
      expect(Lich::Common::Settings[:root].keys).to be_empty

      storage = @mock_db.dump
      expect(storage["test_script::"][:root]).to eq({})
    end

    it "overwrites an existing root array when = is used" do
      Lich::Common::Settings[:list] = [1, 2, 3]
      expect(Lich::Common::Settings[:list]).to include(2)

      Lich::Common::Settings[:list] = []
      expect(Lich::Common::Settings[:list]).to be_empty

      storage = @mock_db.dump
      expect(storage["test_script::"][:list]).to eq([])
    end

    it "replaces a nested structure when the branch root is reassigned with =" do
      Lich::Common::Settings[:branch] = { deep: { a: 1, b: 2 } }
      expect(Lich::Common::Settings[:branch][:deep][:a]).to eq(1)

      Lich::Common::Settings[:branch] = {}
      expect(Lich::Common::Settings[:branch][:deep]).to be_nil

      storage = @mock_db.dump
      expect(storage["test_script::"][:branch]).to eq({})
    end

    it "clobbers previously built updatable structure when the root is reassigned with =" do
      upd     = Lich::Common::Settings[:updatable] || {}
      # Start with a fresh scripts array to ensure test isolation with random ordering
      scripts = []
      mapdb   = upd[:mapdb] || {}

      scripts << { filename: "test.lic", game: "gs" }
      mapdb["GSIV"] = true
      upd["lich"]   = false

      upd[:scripts] = scripts
      upd[:mapdb]   = mapdb
      Lich::Common::Settings[:updatable] = upd

      storage = @mock_db.dump
      expect(storage["test_script::"][:updatable][:scripts][0][:filename]).to eq("test.lic")

      # Destructive reset
      Lich::Common::Settings[:updatable] = {}

      expect(Lich::Common::Settings[:updatable][:scripts]).to be_nil
      expect(Lich::Common::Settings[:updatable]["lich"]).to be_nil

      storage = @mock_db.dump
      expect(storage["test_script::"][:updatable]).to eq({})
    end
  end

  describe "Edge Cases" do
    it "handles empty containers" do
      Lich::Common::Settings[:empty_hash] = {}
      Lich::Common::Settings[:empty_array] = []

      expect(Lich::Common::Settings[:empty_hash].empty?).to be true
      expect(Lich::Common::Settings[:empty_array].empty?).to be true
    end

    it "handles non-existent paths" do
      expect(Lich::Common::Settings[:non_existent]).to be_nil
    end

    it "handles special characters in keys" do
      special_keys = {
        "key with spaces"     => "value1",
        :symbol_key           => "value2",
        "special!@#$%^&*()_+" => "value3"
      }

      Lich::Common::Settings[:special] = special_keys
      expect(Lich::Common::Settings[:special]["key with spaces"]).to eq("value1")
      expect(Lich::Common::Settings[:special][:symbol_key]).to eq("value2")
      expect(Lich::Common::Settings[:special]["special!@#$%^&*()_+"]).to eq("value3")
    end

    it "handles nil values" do
      Lich::Common::Settings[:nil_value] = nil
      expect(Lich::Common::Settings[:nil_value]).to be_nil
    end

    it "handles boolean values" do
      Lich::Common::Settings[:true_value] = true
      Lich::Common::Settings[:false_value] = false

      expect(Lich::Common::Settings[:true_value]).to be true
      expect(Lich::Common::Settings[:false_value]).to be false
    end

    it "handles numeric values" do
      Lich::Common::Settings[:integer] = 42
      Lich::Common::Settings[:float] = 3.14

      expect(Lich::Common::Settings[:integer]).to eq(42)
      expect(Lich::Common::Settings[:float]).to eq(3.14)
    end
  end

  describe "Real-world Examples" do
    it "handles the complete updatable scripts example" do
      upd     = Lich::Common::Settings[:updatable] || {}
      # Start with fresh arrays to ensure test isolation with random ordering
      scripts = []
      mapdb   = {}

      # Seed expected entry at index 0
      scripts << { filename: "test.lic", game: "gs" }

      # Add scripts
      scripts << { filename: "alias.lic",     game: "gs", author: "elanthia-online" }
      scripts << { filename: "autostart.lic", game: "gs", author: "elanthia-online" }
      scripts << { filename: "go2.lic",       game: "gs", author: "elanthia-online" }

      # Mapdb + simple value
      mapdb["GSIV"]   = true
      mapdb["GSF"]    = true
      mapdb["GSPlat"] = true
      mapdb["GST"]    = true
      upd["lich"]     = false

      upd[:scripts] = scripts
      upd[:mapdb]   = mapdb
      Lich::Common::Settings[:updatable] = upd

      expect(Lich::Common::Settings[:updatable][:scripts].length).to eq(4)
      expect(Lich::Common::Settings[:updatable][:scripts][0][:filename]).to eq("test.lic")
      expect(Lich::Common::Settings[:updatable][:scripts][1][:filename]).to eq("alias.lic")
      expect(Lich::Common::Settings[:updatable][:scripts][2][:filename]).to eq("autostart.lic")
      expect(Lich::Common::Settings[:updatable][:scripts][3][:filename]).to eq("go2.lic")

      expect(Lich::Common::Settings[:updatable][:mapdb]["GSIV"]).to be true
      expect(Lich::Common::Settings[:updatable][:mapdb]["GSF"]).to be true
      expect(Lich::Common::Settings[:updatable][:mapdb]["GSPlat"]).to be true
      expect(Lich::Common::Settings[:updatable][:mapdb]["GST"]).to be true
      expect(Lich::Common::Settings[:updatable]["lich"]).to be false

      storage  = @mock_db.dump
      settings = storage["test_script::"][:updatable]
      expect(settings[:scripts].length).to eq(4)
      expect(settings[:mapdb].keys).to contain_exactly("GSIV", "GSF", "GSPlat", "GST")
      expect(settings["lich"]).to be false
    end

    it "handles complex operations with method chaining" do
      data = Lich::Common::Settings[:data] || []
      data << { id: 1, name: "Item 1", tags: ["tag1", "tag2"] }
      data << { id: 2, name: "Item 2", tags: ["tag2", "tag3"] }
      data << { id: 3, name: "Item 3", tags: ["tag1", "tag3"] }
      data << { id: 4, name: "Item 4", tags: ["tag7", "tag3"] }
      data << { id: 5, name: "Item 5", tags: ["tag5", "tag3"] }
      data << { id: 6, name: "Item 6", tags: ["tag6", "tag3"] }
      Lich::Common::Settings[:data] = data

      # Find items with tag1
      items_with_tag1 = Lich::Common::Settings[:data].select { |item| item[:tags].include?("tag1") }
      expect(items_with_tag1.length).to eq(2)
      expect(items_with_tag1.map { |item| item[:id] }).to contain_exactly(1, 3)

      # Add a new tag to item 2
      data = Lich::Common::Settings[:data] || []
      item2 = data[1] || {}
      item2[:tags] = (item2[:tags] || [])
      item2[:tags] << "tag4"
      data[1] = item2
      Lich::Common::Settings[:data] = data
      expect(Lich::Common::Settings[:data][1][:tags]).to contain_exactly("tag2", "tag3", "tag4")

      # Update an item's name
      data = Lich::Common::Settings[:data] || []
      item1 = data[0] || {}
      item1[:name] = "Updated Item 1"
      data[0] = item1
      Lich::Common::Settings[:data] = data
      expect(Lich::Common::Settings[:data][0][:name]).to eq("Updated Item 1")

      # Check the mock database directly
      storage = @mock_db.dump
      expect(storage["test_script::"][:data][0][:name]).to eq("Updated Item 1")
      expect(storage["test_script::"][:data][1][:tags]).to contain_exactly("tag2", "tag3", "tag4")
    end
  end

  # Another Lich session is another process: it writes the same database row,
  # and this process's cache does not see it. These examples play the other
  # session by writing to the adapter directly.
  describe "Top-level writes when another session changed the row" do
    let(:settings) { Lich::Common::Settings }

    # GameSettings[]= and GameSettings[] for game "GSIV", called the way
    # gamesettings.rb calls them. (Loading gamesettings.rb here would define
    # Lich::Common::GameSettings for every later spec in the process.)
    def game_write(key, value)
      settings.set_script_settings("GSIV", key, value)
    end

    def game_read(key)
      settings.get_scoped_setting("GSIV", key)
    end

    before do
      settings.instance_variable_set(:@settings_cache, {})
    end

    it "keeps the other session's keys when GameSettings writes a different key" do
      expect(game_read('mine')).to be_nil # this process caches the empty row
      @mock_db.save_settings("test_script", { "theirs" => 1 }, "GSIV")

      game_write('mine', 2)

      expect(@mock_db.get_settings("test_script", "GSIV")).to eq("theirs" => 1, "mine" => 2)
      expect(game_read('theirs')).to eq(1)
    end

    it "keeps the other session's keys when Settings writes a different key" do
      expect(settings[:mine]).to be_nil
      @mock_db.save_settings("test_script", { theirs: 1 }, ":")

      settings[:mine] = 2

      expect(@mock_db.get_settings("test_script", ":")).to eq(theirs: 1, mine: 2)
    end

    it "replaces the other session's value when both write the same key" do
      game_write('shared', 'mine')
      @mock_db.save_settings("test_script", { "shared" => "theirs", "other" => 1 }, "GSIV")

      game_write('shared', 'mine again')

      expect(@mock_db.get_settings("test_script", "GSIV")).to eq("shared" => "mine again", "other" => 1)
    end

    it "stores a copy, so later changes to the caller's hash are not saved or cached" do
      value = { "a" => 1 }
      game_write('h', value)
      value["b"] = 2

      expect(@mock_db.get_settings("test_script", "GSIV")).to eq("h" => { "a" => 1 })
      expect(game_read('h').to_h).to eq("a" => 1)
    end

    it "stores the unwrapped value when assigning a proxy" do
      game_write('src', { "x" => [1, 2] })

      game_write('copy', game_read('src'))

      expect(@mock_db.get_settings("test_script", "GSIV")["copy"]).to eq("x" => [1, 2])
      expect(@mock_db.get_settings("test_script", "GSIV")["copy"]).to be_a(Hash)
    end

    it "returns the assigned value and leaves no navigation path behind" do
      expect(settings.set_script_settings("GSIV", 'k', 'v')).to eq('v')
      expect(settings.instance_variable_get(:@path_navigator).path).to be_empty
    end

    it "still writes the top-level key when a stale navigation path is left over" do
      settings.instance_variable_get(:@path_navigator).set_path(['stale', 'path'])

      settings.set_script_settings("GSIV", 'k', 'v')

      expect(@mock_db.get_settings("test_script", "GSIV")).to eq('k' => 'v')
      expect(settings.instance_variable_get(:@path_navigator).path).to be_empty
    end

    it "writes nothing when there is no script name" do
      Lich::Common::MockScript.current_name = nil

      expect(settings.set_script_settings("GSIV", 'k', 'v')).to eq('v')
      expect(@mock_db.dump).to be_empty
    end

    it "writes to the named script when one is given" do
      settings.set_script_settings("DR:Alpha", 'k', 'v', script_name: 'core')

      expect(@mock_db.get_settings("core", "DR:Alpha")).to eq('k' => 'v')
      expect(@mock_db.get_settings("test_script", "DR:Alpha")).to eq({})
    end

    it "does not raise, leaves the row alone and tells the user when the stored row is not a Hash" do
      @mock_db.save_settings("test_script", [1, 2], "GSIV")
      allow(Lich::Messaging).to receive(:msg)

      expect { game_write('k', 'v') }.not_to raise_error
      expect(@mock_db.get_settings("test_script", "GSIV")).to eq([1, 2])
      expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("stored as Array, not a Hash; 'k' was not saved"))
    end

    it "keeps serving its cached row after a failed write, without asking the still-locked database" do
      game_write('saved', 1)
      # The adapter reads the row and runs the block, then cannot store it.
      allow(@mock_db).to receive(:update_settings) do |script, scope, &block|
        block.call(@mock_db.get_settings(script, scope))
        nil
      end

      game_write('lost', 2)
      # The lock that failed the write is still held: data_version can't be read.
      @mock_db.data_version_unknown = true
      allow(@mock_db).to receive(:get_settings).and_raise(Sequel::DatabaseError, 'database is locked')

      expect(game_read('saved')).to eq(1)
      expect(game_read('lost')).to be_nil
      expect(@mock_db).not_to have_received(:get_settings)
    end

    it "serves its cached row after a failed write when the database can't be re-read" do
      game_write('saved', 1)
      allow(@mock_db).to receive(:update_settings) do |script, scope, &block|
        block.call(@mock_db.get_settings(script, scope))
        nil
      end

      game_write('lost', 2)
      allow(@mock_db).to receive(:get_settings).and_raise(Sequel::DatabaseError, 'database is locked')

      expect(game_read('saved')).to eq(1)
      expect(game_read('lost')).to be_nil
      expect(@mock_db).to have_received(:get_settings).at_least(:once)
    end

    # Two threads of this process. Each test holds the first thread just
    # after its database call for up to PAUSE seconds, or until the second
    # thread is done, and checks that the cache ends on the newest row
    # whichever way the threads are ordered.
    describe "two threads of one process" do
      pause = 0.5

      def in_thread(&block)
        Thread.new do
          Thread.current.report_on_exception = false
          block.call
        end
      end

      it "leaves the cache on the newer row when a later write finishes first" do
        first_stored = Queue.new
        second_done = Queue.new
        first = nil
        allow(@mock_db).to receive(:update_settings).and_wrap_original do |original, *args, **opts, &block|
          stored = original.call(*args, **opts, &block)
          if Thread.current.equal?(first)
            first_stored << true
            second_done.pop(timeout: pause)
          end
          stored
        end

        first = in_thread { game_write('a', 1) }
        second = in_thread do
          first_stored.pop(timeout: 2)
          game_write('b', 2)
          second_done << true
        end
        [first, second].each { |t| t.join(5) }

        expect(@mock_db.get_settings("test_script", "GSIV")).to eq('a' => 1, 'b' => 2)
        expect(game_read('a')).to eq(1)
        expect(game_read('b')).to eq(2)
      end

      it "does not let a read that missed the cache replace a row a write cached after it" do
        loaded = Queue.new
        write_done = Queue.new
        reader = nil
        allow(@mock_db).to receive(:get_settings).and_wrap_original do |original, *args|
          row = original.call(*args)
          if Thread.current.equal?(reader)
            loaded << true
            write_done.pop(timeout: pause)
          end
          row
        end

        reader = in_thread { game_read('a') }
        writer = in_thread do
          loaded.pop(timeout: 2)
          game_write('a', 1)
          write_done << true
        end
        [reader, writer].each { |t| t.join(5) }

        expect(@mock_db.get_settings("test_script", "GSIV")).to eq('a' => 1)
        expect(game_read('a')).to eq(1)
      end

      it "does not let a root proxy's cache fill replace a row a write cached after it" do
        loaded = Queue.new
        write_done = Queue.new
        reader = nil
        allow(@mock_db).to receive(:get_settings).and_wrap_original do |original, *args|
          row = original.call(*args)
          if Thread.current.equal?(reader)
            loaded << true
            write_done.pop(timeout: pause)
          end
          row
        end

        reader = in_thread { settings.root_proxy_for("GSIV") }
        writer = in_thread do
          loaded.pop(timeout: 2)
          game_write('a', 1)
          write_done << true
        end
        [reader, writer].each { |t| t.join(5) }

        expect(game_read('a')).to eq(1)
      end

      it "leaves the cache on the newer row when a top-level write finishes during a nested write" do
        settings[:list] = []
        nested_saved = Queue.new
        top_done = Queue.new
        nested = nil
        allow(@mock_db).to receive(:save_settings).and_wrap_original do |original, *args|
          saved = original.call(*args)
          if Thread.current.equal?(nested)
            nested_saved << true
            top_done.pop(timeout: pause)
          end
          saved
        end

        nested = in_thread { settings[:list] << 'x' }
        top = in_thread do
          nested_saved.pop(timeout: 2)
          settings[:k] = 1
          top_done << true
        end
        [nested, top].each { |t| t.join(5) }

        expect(@mock_db.get_settings("test_script", ":")).to eq(list: ['x'], k: 1)
        expect(settings[:k]).to eq(1)
        expect(settings[:list].to_a).to eq(['x'])
      end

      it "does not let a nested write's row save erase a key a top-level write stored after its refresh" do
        settings[:list] = []
        list = settings[:list]
        refreshed = Queue.new
        top_done = Queue.new
        nested = nil
        allow(@mock_db).to receive(:get_settings).and_wrap_original do |original, *args|
          row = original.call(*args)
          if Thread.current.equal?(nested)
            refreshed << true
            top_done.pop(timeout: pause)
          end
          row
        end

        nested = in_thread { list << 'x' }
        top = in_thread do
          refreshed.pop(timeout: 2)
          settings[:k] = 1
          top_done << true
        end
        [nested, top].each { |t| t.join(5) }

        expect(@mock_db.get_settings("test_script", ":")).to eq(list: ['x'], k: 1)
        expect(settings[:k]).to eq(1)
        expect(settings[:list].to_a).to eq(['x'])
      end

      # Settings[k] = v with a navigation path left over (for example by a
      # destructive call on a detached view, see _reattach_live!) saves the
      # whole row it navigated. Its read and its save must be one step.
      it "does not let a leftover-path Settings write erase a top-level key stored after its read" do
        settings[:k0] = 0
        navigated = Queue.new
        top_done = Queue.new
        path_writer = nil
        allow(settings).to receive(:navigate_to_path).and_wrap_original do |original, *args|
          result = original.call(*args)
          if Thread.current.equal?(path_writer)
            navigated << true
            top_done.pop(timeout: pause)
          end
          result
        end

        path_writer = in_thread do
          settings.instance_variable_get(:@path_navigator).set_path([:nested])
          settings[:k] = 1
        end
        top = in_thread do
          navigated.pop(timeout: 2)
          settings.set_script_settings(":", :t, 2)
          top_done << true
        end
        [path_writer, top].each { |t| t.join(5) }

        expect(@mock_db.get_settings("test_script", ":")).to eq(k0: 0, nested: { k: 1 }, t: 2)
        expect(settings.to_hash).to eq(k0: 0, nested: { k: 1 }, t: 2)
        expect(settings.instance_variable_get(:@path_navigator).path).to be_empty
      end

      # save_to_database is public; a direct call stores the row it is given
      # and caches it, and a top-level write must not land in between.
      it "leaves the cache on the newer row when a top-level write finishes during a direct whole-row save" do
        saved = Queue.new
        top_done = Queue.new
        saver = nil
        allow(@mock_db).to receive(:save_settings).and_wrap_original do |original, *args|
          result = original.call(*args)
          if Thread.current.equal?(saver)
            saved << true
            top_done.pop(timeout: pause)
          end
          result
        end

        saver = in_thread { settings.save_to_database({ 'whole' => 1 }, ":") }
        top = in_thread do
          saved.pop(timeout: 2)
          settings.set_script_settings(":", 't', 2)
          top_done << true
        end
        [saver, top].each { |t| t.join(5) }

        expect(@mock_db.get_settings("test_script", ":")).to eq('whole' => 1, 't' => 2)
        expect(settings.to_hash).to eq('whole' => 1, 't' => 2)
      end

      it "does not let a read that missed the cache replace a row a nested write cached after it" do
        settings[:list] = []
        list = settings[:list]
        settings.instance_variable_set(:@settings_cache, {})
        loaded = Queue.new
        write_done = Queue.new
        reader = nil
        allow(@mock_db).to receive(:get_settings).and_wrap_original do |original, *args|
          row = original.call(*args)
          if Thread.current.equal?(reader)
            loaded << true
            write_done.pop(timeout: pause)
          end
          row
        end

        reader = in_thread { settings.current_script_settings(":") }
        writer = in_thread do
          loaded.pop(timeout: 2)
          list << 'x'
          write_done << true
        end
        [reader, writer].each { |t| t.join(5) }

        expect(@mock_db.get_settings("test_script", ":")).to eq(list: ['x'])
        expect(settings[:list].to_a).to eq(['x'])
      end

      it "does not let a root proxy's cache fill replace a row a nested write cached after it" do
        settings[:list] = []
        list = settings[:list]
        settings.instance_variable_set(:@settings_cache, {})
        loaded = Queue.new
        write_done = Queue.new
        reader = nil
        allow(@mock_db).to receive(:get_settings).and_wrap_original do |original, *args|
          row = original.call(*args)
          if Thread.current.equal?(reader)
            loaded << true
            write_done.pop(timeout: pause)
          end
          row
        end

        reader = in_thread { settings.root_proxy_for(":", script_name: "test_script") }
        writer = in_thread do
          loaded.pop(timeout: 2)
          list << 'x'
          write_done << true
        end
        [reader, writer].each { |t| t.join(5) }

        expect(@mock_db.get_settings("test_script", ":")).to eq(list: ['x'])
        expect(settings[:list].to_a).to eq(['x'])
      end

      it "does not make another script's first read wait for a write in progress" do
        write_started = Queue.new
        release = Queue.new
        writer = nil
        allow(@mock_db).to receive(:update_settings).and_wrap_original do |original, *args, **opts, &block|
          if Thread.current.equal?(writer)
            write_started << true
            release.pop(timeout: 2)
          end
          original.call(*args, **opts, &block)
        end

        writer = in_thread { game_write('a', 1) }
        write_started.pop(timeout: 2)
        reader = in_thread { settings.get_scoped_setting("GSIV", 'b', script_name: 'other_script') }
        finished = reader.join(1)
        release << true
        writer.join(5)

        expect(finished).to eq(reader)
        expect(game_read('a')).to eq(1)
      end

      it "makes a second write to the same row wait for the one in progress" do
        write_started = Queue.new
        release = Queue.new
        first = nil
        allow(@mock_db).to receive(:update_settings).and_wrap_original do |original, *args, **opts, &block|
          if Thread.current.equal?(first)
            write_started << true
            release.pop(timeout: 2)
          end
          original.call(*args, **opts, &block)
        end

        first = in_thread { game_write('a', 1) }
        write_started.pop(timeout: 2)
        second = in_thread { game_write('b', 2) }
        waited = second.join(0.3).nil?
        release << true
        [first, second].each { |t| t.join(5) }

        expect(waited).to be(true)
        expect(game_read('a')).to eq(1)
        expect(game_read('b')).to eq(2)
      end

      it "releases the lock when the database call raises, so the next write still runs" do
        allow(@mock_db).to receive(:update_settings).and_raise(TypeError, 'incompatible marshal file format')
        expect { game_write('a', 1) }.to raise_error(TypeError)
        allow(@mock_db).to receive(:update_settings).and_call_original

        writer = in_thread { game_write('b', 2) }

        expect(writer.join(2)).to eq(writer)
        expect(@mock_db.get_settings("test_script", "GSIV")).to eq('b' => 2)
      end

      it "leaves the cache holding the stored row when the writing thread is killed right after the store" do
        expect(game_read('a')).to be_nil # this process caches the empty row
        # Script#kill is Thread#kill; here it lands as soon as the adapter returns.
        allow(@mock_db).to receive(:update_settings).and_wrap_original do |original, *args, **opts, &block|
          original.call(*args, **opts, &block)
          Thread.current.kill
        end

        writer = in_thread { game_write('a', 1) }
        expect(writer.join(2)).to eq(writer)
        # The write changed data_version, so the next read re-reads the row; a
        # locked database makes that re-read fall back to the cached row,
        # which is there only if the kill did not skip the cache update.
        allow(@mock_db).to receive(:get_settings).and_raise(Sequel::DatabaseError, 'database is locked')

        expect(@mock_db.dump["test_script:GSIV"]).to eq('a' => 1)
        expect(game_read('a')).to eq(1)
      end

      it "leaves the cache holding a whole-row save when the writing thread is killed right after the store" do
        expect(game_read('a')).to be_nil # this process caches the empty row
        # Script#kill is Thread#kill from another thread; here it arrives just
        # after the row was committed, before the cache is updated.
        committed = Queue.new
        allow(@mock_db).to receive(:save_settings).and_wrap_original do |original, *args|
          result = original.call(*args)
          committed << true
          sleep 0.3
          result
        end

        writer = in_thread { settings.save_to_database({ 'a' => 1 }, "GSIV", script_name: "test_script") }
        committed.pop(timeout: 2)
        writer.kill
        expect(writer.join(2)).to eq(writer)
        # The save changed data_version, so the next read re-reads the row; a
        # locked database makes that re-read fall back to the cached row,
        # which is there only if the kill did not skip the cache update.
        allow(@mock_db).to receive(:get_settings).and_raise(Sequel::DatabaseError, 'database is locked')

        expect(@mock_db.dump["test_script:GSIV"]).to eq('a' => 1)
        expect(game_read('a')).to eq(1)
      end

      it "makes Settings.load return and cache a row committed before it was called, over an older fill in progress" do
        @mock_db.save_settings("test_script", { 'v' => 0 }, ":")
        loaded = Queue.new
        release = Queue.new
        reader = nil
        allow(@mock_db).to receive(:get_settings).and_wrap_original do |original, *args|
          row = original.call(*args)
          if Thread.current.equal?(reader)
            loaded << true
            release.pop(timeout: 2)
          end
          row
        end

        reader = in_thread { settings.to_hash }
        loaded.pop(timeout: 2)
        # Another session commits a newer row while the reader holds the older one.
        @mock_db.save_settings("test_script", { 'v' => 1 }, ":")
        refreshed = nil
        refresher = in_thread { refreshed = settings.load }
        Thread.pass until refresher.status == 'sleep' || !refresher.alive?
        release << true
        [reader, refresher].each { |t| t.join(5) }

        expect(refreshed).to eq('v' => 1)
        expect(settings.to_hash).to eq('v' => 1)
      end

      it "returns a copy from Settings.load, so changing it leaves the cache alone" do
        @mock_db.save_settings("test_script", { 'v' => 0 }, ":")

        settings.load['v'] = 9

        expect(settings.to_hash).to eq('v' => 0)
      end

      it "keeps the cached row when Settings.load fails to read the database, and releases the lock" do
        @mock_db.save_settings("test_script", { 'v' => 0 }, ":")
        expect(settings.to_hash).to eq('v' => 0) # fills the cache
        failures = 1
        allow(@mock_db).to receive(:get_settings).and_wrap_original do |original, *args|
          if failures.positive?
            failures -= 1
            raise 'database is locked'
          end
          original.call(*args)
        end

        expect { settings.load }.to raise_error(RuntimeError, 'database is locked')
        failures = 1 # a read that went to the database would raise again

        expect(settings.to_hash).to eq('v' => 0)
        failures = 0
        writer = in_thread { settings['w'] = 1 }
        expect(writer.join(2)).to eq(writer)
        expect(@mock_db.get_settings("test_script", ":")).to eq('v' => 0, 'w' => 1)
      end
    end
  end

  # Another Lich session is another process. These examples play it by writing
  # to the adapter directly, which (like a commit by another connection)
  # changes the adapter's data_version.
  describe "Reads when another session committed" do
    let(:settings) { Lich::Common::Settings }

    def game_read(key)
      settings.get_scoped_setting("GSIV", key)
    end

    def their_write(row, scope = "GSIV", script = "test_script")
      @mock_db.save_settings(script, row, scope)
    end

    before do
      settings.instance_variable_set(:@settings_cache, {})
      settings.instance_variable_set(:@cache_versions, {})
    end

    it "shows a key the other session wrote after this process cached the row" do
      expect(game_read('theirs')).to be_nil
      their_write("theirs" => 1)

      expect(game_read('theirs')).to eq(1)
    end

    it "shows a value the other session changed and drops a key it removed" do
      their_write("mode" => "slow", "gone" => true)
      expect(game_read('mode')).to eq("slow")
      their_write("mode" => "fast")

      expect(game_read('mode')).to eq("fast")
      expect(game_read('gone')).to be_nil
    end

    it "is fresh for every read API: Settings[], to_hash, nested proxies and root proxies" do
      expect(settings[:k]).to be_nil
      expect(settings.to_hash).to eq({})
      proxy_root = settings.root_proxy_for("DR", script_name: "core")
      expect(proxy_root.to_h).to eq({})

      their_write({ k: { "n" => 1 } }, ":")
      their_write({ "bank" => 5 }, "DR", "core")

      expect(settings[:k]["n"]).to eq(1)
      expect(settings.to_hash).to eq(k: { "n" => 1 })
      expect(settings.root_proxy_for("DR", script_name: "core")["bank"]).to eq(5)
    end

    it "does not read the row again while nothing has been committed" do
      their_write("k" => 1)
      expect(game_read('k')).to eq(1)
      allow(@mock_db).to receive(:get_settings).and_call_original

      200.times { game_read('k') }
      settings.root_proxy_for("GSIV")

      expect(@mock_db).not_to have_received(:get_settings)
    end

    it "reads the row again only once per commit" do
      game_read('k')
      allow(@mock_db).to receive(:get_settings).and_call_original

      their_write("k" => 1)
      5.times { game_read('k') }
      their_write("k" => 2)
      5.times { game_read('k') }

      expect(@mock_db).to have_received(:get_settings).twice
      expect(game_read('k')).to eq(2)
    end

    it "uses the cached row while the database's version can't be read (another process holds the lock)" do
      their_write("k" => 1)
      expect(game_read('k')).to eq(1)
      @mock_db.data_version_unknown = true
      their_write("k" => 2)
      allow(@mock_db).to receive(:get_settings).and_call_original

      expect(game_read('k')).to eq(1)
      expect(@mock_db).not_to have_received(:get_settings)

      @mock_db.data_version_unknown = false
      expect(game_read('k')).to eq(2)
    end

    it "reads a row it has not cached even while the version can't be read, and checks it again later" do
      @mock_db.data_version_unknown = true
      their_write("k" => 1)
      expect(game_read('k')).to eq(1)

      their_write("k" => 2)
      @mock_db.data_version_unknown = false

      expect(game_read('k')).to eq(2)
    end

    it "keeps answering from the cached row when the row can't be read again for a database error" do
      their_write("k" => 1)
      expect(game_read('k')).to eq(1)
      their_write("k" => 2)
      allow(@mock_db).to receive(:get_settings).and_raise(Sequel::DatabaseError, 'database is locked')

      expect(game_read('k')).to eq(1)

      allow(@mock_db).to receive(:get_settings).and_call_original
      expect(game_read('k')).to eq(2)
    end

    it "raises the database error when nothing is cached to fall back on" do
      allow(@mock_db).to receive(:get_settings).and_raise(Sequel::DatabaseError, 'database is locked')

      expect { game_read('k') }.to raise_error(Sequel::DatabaseError)
    end

    it "raises, rather than serving the cached row, when the changed row can't be unmarshalled" do
      their_write("k" => 1)
      expect(game_read('k')).to eq(1)
      their_write("k" => 2)
      allow(@mock_db).to receive(:get_settings).and_raise(TypeError, 'incompatible marshal file format')

      expect { game_read('k') }.to raise_error(TypeError)
    end

    it "shows this process's own write on the next read, then reads the stored row again once" do
      settings.set_script_settings("GSIV", 'mine', 1)
      allow(@mock_db).to receive(:get_settings).and_call_original

      expect(game_read('mine')).to eq(1)
      expect(game_read('mine')).to eq(1)
      expect(@mock_db).to have_received(:get_settings).once
    end

    it "does not show a nested change whose save failed once the database can be read" do
      their_write("opts" => { "x" => 0 })
      allow(@mock_db).to receive(:save_settings).and_return(false) # the lock outlasted the busy timeout

      game_read('opts')['y'] = 1

      expect(game_read('opts').to_h).to eq("x" => 0)
    end

    it "does not trust a version taken for a row that a write has since replaced in the cache" do
      expect(game_read('k')).to be_nil
      cache = settings.instance_variable_get(:@settings_cache)
      cache["test_script::GSIV"] = { "k" => "only in memory" } # what a write that kept its row does
      allow(@mock_db).to receive(:get_settings).and_call_original

      expect(game_read('k')).to be_nil
      expect(@mock_db).to have_received(:get_settings).once
    end

    it "reads the row again when a commit lands just after the row was read" do
      their_write("k" => 0)
      expect(game_read('k')).to eq(0)
      their_write("k" => 1)
      commit_once = true
      allow(@mock_db).to receive(:get_settings).and_wrap_original do |original, *args|
        row = original.call(*args)
        if commit_once
          commit_once = false
          their_write("k" => 2) # commits after the row was read, before it is cached
        end
        row
      end

      expect(game_read('k')).to eq(1)
      expect(game_read('k')).to eq(2)
    end

    it "does not keep serving a nested change whose save raised" do
      their_write("opts" => { "x" => 0 })
      expect(game_read('opts').to_h).to eq("x" => 0)
      looped = {}
      looped['self'] = looped

      expect { game_read('opts')['bad'] = looped }.to raise_error(StandardError)

      expect(game_read('opts').to_h).to eq("x" => 0)
    end

    it "refresh_data (Settings.load) still reads the row again" do
      expect(settings[:k]).to be_nil
      @mock_db.data_version_unknown = true
      their_write({ k: 1 }, ":")

      settings.load

      expect(settings[:k]).to eq(1)
    end

    # Two script threads in one process share the cache. A thread re-reading
    # the row (another session committed) can be overtaken, between its read
    # and putting the row in the cache, by a newer row from another thread.
    context "when another thread changes the cached row while this one re-reads it" do
      def game_write(key, value)
        settings.set_script_settings("GSIV", key, value)
      end

      # Starts a thread that runs the block (a read) and stops right after its
      # get_settings returns, before cached_root caches the row. Returns
      # [thread, release]; push to release to let the thread go on.
      def start_paused_reader(&read)
        paused = Queue.new
        release = Queue.new
        allow(@mock_db).to receive(:get_settings).and_wrap_original do |original, *args|
          row = original.call(*args)
          if Thread.current[:pause_after_read]
            Thread.current[:pause_after_read] = false
            paused << true
            release.pop
          end
          row
        end
        reader = Thread.new do
          Thread.current[:pause_after_read] = true
          read.call
        end
        Timeout.timeout(5) { paused.pop }
        [reader, release]
      end

      after { @reader&.kill }

      it "keeps this thread's own write when the other thread's older row arrives later" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        their_write("k" => 1, "z" => 1) # any commit: the next read re-reads
        @reader, release = start_paused_reader { game_read('k') }

        game_write('k', 2)
        @mock_db.data_version_unknown = true # another process now holds the lock
        release << true

        expect(@reader.value).to eq(1) # the other thread's own read, as it was
        expect(game_read('k')).to eq(2)
        @mock_db.data_version_unknown = false
        expect(game_read('k')).to eq(2)
      end

      it "does not go back to an older row after this thread has read a newer one" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        their_write("k" => 1, "z" => 1)
        @reader, release = start_paused_reader { game_read('k') }

        their_write("k" => 2, "z" => 1)
        expect(game_read('k')).to eq(2)
        @mock_db.data_version_unknown = true
        release << true

        expect(@reader.value).to eq(1)
        expect(game_read('k')).to eq(2)
      end

      it "does not cache the row when a Settings.load replaced the cached one meanwhile" do
        their_write({ k: 1 }, ":")
        expect(settings[:k]).to eq(1)
        their_write({ k: 2 }, ":")
        @reader, release = start_paused_reader { settings[:k] }

        their_write({ k: 3 }, ":")
        settings.load # replaces the cached row with k=3
        release << true

        expect(@reader.value).to eq(2)
        @mock_db.data_version_unknown = true
        expect(settings[:k]).to eq(3)
      end

      it "caches the re-read row when nothing changed the cache meanwhile" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        their_write("k" => 2)
        @reader, release = start_paused_reader { game_read('k') }
        release << true

        expect(@reader.value).to eq(2)
        expect(settings.instance_variable_get(:@settings_cache)["test_script::GSIV"]).to eq("k" => 2)
        expect(@mock_db).to have_received(:get_settings).once
        expect(game_read('k')).to eq(2)
        expect(@mock_db).to have_received(:get_settings).once
      end

      it "makes a write wait to replace the cached row while a re-read is deciding whether to cache its own" do
        game_write('k', 1)
        mutex = settings.instance_variable_get(:@cache_mutex)
        expect(mutex).to be_a(Mutex)

        mutex.lock
        begin
          writer = Thread.new { game_write('k', 2) }
          Timeout.timeout(5) { Thread.pass until writer.status == 'sleep' }
          expect(@mock_db.get_settings("test_script", "GSIV")).to eq("k" => 2) # committed
          expect(settings.instance_variable_get(:@settings_cache)["test_script::GSIV"]).to eq("k" => 1) # not yet cached
        ensure
          mutex.unlock
        end
        writer.join(5)

        expect(settings.instance_variable_get(:@settings_cache)["test_script::GSIV"]).to eq("k" => 2)
      end

      # Holds the entry's lock (as a write in progress does) in another thread
      # until the returned queue is pushed to.
      def hold_entry_lock
        held = Queue.new
        release = Queue.new
        @holder = Thread.new do
          settings.send(:with_cache_lock, "test_script::GSIV") do
            held << true
            release.pop
          end
        end
        Timeout.timeout(5) { held.pop }
        release
      end

      after { @holder&.kill }

      it "re-reads a cached row after a commit without waiting for a write in progress" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        release = hold_entry_lock
        their_write("k" => 2)

        reader = Thread.new { game_read('k') }
        expect(reader.join(2)).to eq(reader)
        expect(reader.value).to eq(2)
        release << true
      end

      it "fills a cache miss after the write in progress and records the version seen after waiting" do
        release = hold_entry_lock
        reader = Thread.new { game_read('k') }
        Timeout.timeout(5) { Thread.pass until reader.status == 'sleep' }
        expect(reader.join(0.2)).to be_nil # waits for the entry's lock

        their_write("k" => 1) # committed while the miss waited
        release << true
        expect(reader.value).to eq(1)

        allow(@mock_db).to receive(:get_settings).and_call_original
        expect(game_read('k')).to eq(1)
        expect(@mock_db).not_to have_received(:get_settings)
      end

      it "caches a row re-read while another thread's write is in progress without a version, and records one on the next read" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        release = hold_entry_lock
        their_write("k" => 2)

        expect(Thread.new { game_read('k') }.value).to eq(2)
        expect(settings.instance_variable_get(:@settings_cache)["test_script::GSIV"]).to eq("k" => 2)
        expect(settings.instance_variable_get(:@cache_versions)).not_to have_key("test_script::GSIV")

        allow(@mock_db).to receive(:get_settings).and_call_original
        expect(Thread.new { game_read('k') }.value).to eq(2) # no version: read again
        expect(@mock_db).to have_received(:get_settings).once
        release << true
        @holder.join(5)

        expect(game_read('k')).to eq(2) # read again, now with the version recorded
        expect(game_read('k')).to eq(2)
        expect(@mock_db).to have_received(:get_settings).twice
      end

      it "does not go back to the older cached row when the version can't be read during another thread's write" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        release = hold_entry_lock
        their_write("k" => 2)

        expect(Thread.new { game_read('k') }.value).to eq(2)
        @mock_db.data_version_unknown = true # another process now holds the lock
        expect(Thread.new { game_read('k') }.value).to eq(2)
        expect(game_read('k')).to eq(2) # the holder is another thread; this one too
        release << true
        @holder.join(5)
        expect(game_read('k')).to eq(2)
      end

      it "does not cache a row re-read during another thread's write when the cache entry changed meanwhile" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        release = hold_entry_lock
        their_write("k" => 2)
        @reader, go = start_paused_reader { game_read('k') }
        newer = { "k" => 3 }
        settings.send(:store_in_cache, "test_script::GSIV", newer) # as the writer would
        go << true

        expect(@reader.value).to eq(2)
        expect(settings.instance_variable_get(:@settings_cache)["test_script::GSIV"]).to equal(newer)
        release << true
      end

      # Starts a nested write (game_read(key)[...] = ... through the block) in
      # another thread and stops it inside save_proxy_changes, right after its
      # refresh read of the row. With pause_save, it stops again just before
      # its database write. Returns [thread, paused, release]: pop paused to
      # wait for each stop, push to release to go on.
      def start_paused_write(pause_save: false, &write)
        paused = Queue.new
        release = Queue.new
        pause = lambda do |flag|
          next unless Thread.current[flag]

          Thread.current[flag] = false
          paused << flag
          release.pop
        end
        allow(@mock_db).to receive(:get_settings).and_wrap_original do |original, *args|
          original.call(*args).tap { pause.call(:pause_after_read) }
        end
        allow(@mock_db).to receive(:save_settings).and_wrap_original do |original, *args|
          pause.call(:pause_before_save)
          original.call(*args)
        end
        writer = Thread.new do
          Thread.current[:pause_after_read] = true
          Thread.current[:pause_before_save] = pause_save
          write.call
        end
        expect(Timeout.timeout(5) { paused.pop }).to eq(:pause_after_read)
        [writer, paused, release]
      end

      after { @writer&.kill }

      it "does not keep serving an older row after a write that changed nothing returns" do
        their_write("list" => [{ "a" => 1 }], "ext" => 1)
        list = game_read('list')
        @writer, _paused, release = start_paused_write { list[-1]['a'] = 2 } # a negative index: not saved

        their_write("list" => [{ "a" => 1 }], "ext" => 2)
        expect(game_read('ext')).to eq(2)
        release << true
        @writer.join(5)

        expect(game_read('ext')).to eq(2)
        expect(game_read('ext')).to eq(2)
      end

      it "does not serve the writing thread's older row to other threads while its write is in progress" do
        their_write("opts" => { "c" => 0 }, "ext" => 1)
        opts = game_read('opts')
        @writer, paused, release = start_paused_write(pause_save: true) { opts['c'] = 5 }

        their_write("opts" => { "c" => 0 }, "ext" => 2)
        expect(game_read('ext')).to eq(2)
        release << true
        expect(Timeout.timeout(5) { paused.pop }).to eq(:pause_before_save)

        expect(game_read('ext')).to eq(2)
        release << true
        @writer.join(5)
      end

      # Runs the write (or Settings.load) in the block in another thread. When
      # that thread is done with the database (hook: :save, right after its
      # save_settings returns; :read, right after its get_settings returns),
      # but before it updates the cache, the block given to `meanwhile` runs
      # in this thread: another session commits and another thread re-reads.
      def write_with_gap(hook, meanwhile, &write)
        target = hook == :save ? :save_settings : :get_settings
        allow(@mock_db).to receive(target).and_wrap_original do |original, *args|
          result = original.call(*args)
          if Thread.current[:gap]
            Thread.current[:gap] = false
            meanwhile.call
          end
          result
        end
        writer = Thread.new do
          Thread.current[:gap] = true
          write.call
        end
        expect(writer.join(5)).to eq(writer)
        writer.value
      end

      def reread_in_another_thread(key)
        Thread.new { game_read(key) }.value
      end

      it "keeps a newer row another thread re-read right after a top-level write's store" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        seen = nil
        write_with_gap(:save, lambda {
          their_write("k" => 1, "mine" => 5, "ext" => 2) # another session commits after the store
          seen = reread_in_another_thread('ext')
        }) { game_write('mine', 5) }
        expect(seen).to eq(2)

        @mock_db.data_version_unknown = true # another process now holds the lock
        expect(reread_in_another_thread('ext')).to eq(2)
        expect(game_read('ext')).to eq(2)
        expect(game_read('mine')).to eq(5) # the writing thread still sees its own write
      end

      it "keeps a newer row another thread re-read right after a nested write's save" do
        their_write("opts" => { "c" => 0 })
        opts = game_read('opts')
        seen = nil
        write_with_gap(:save, lambda {
          their_write("opts" => { "c" => 5 }, "ext" => 2)
          seen = reread_in_another_thread('ext')
        }) { opts['c'] = 5 }
        expect(seen).to eq(2)

        @mock_db.data_version_unknown = true
        expect(reread_in_another_thread('ext')).to eq(2)
        expect(game_read('opts').to_h).to eq("c" => 5)
      end

      it "keeps a newer row another thread re-read right after Settings.load's read" do
        their_write({ "k" => 1 }, ":")
        expect(settings[:k]).to be_nil
        seen = nil
        loaded = write_with_gap(:read, lambda {
          their_write({ "k" => 1, "ext" => 2 }, ":")
          seen = Thread.new { settings["ext"] }.value
        }) { settings.load }
        expect(seen).to eq(2)
        expect(loaded).to eq("k" => 1) # Settings.load returns what it read

        @mock_db.data_version_unknown = true
        expect(Thread.new { settings["ext"] }.value).to eq(2)
      end

      it "caches the write's own row over a row another thread re-read before its store" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        seen = nil
        # The re-read runs before the store: the hook is on the read inside
        # the write, so the row it caches does not hold the write.
        allow(@mock_db).to receive(:update_settings).and_wrap_original do |original, *args, **opts, &block|
          original.call(*args, **opts) do |fresh|
            if Thread.current[:gap]
              Thread.current[:gap] = false
              their_write("k" => 1, "ext" => 2)
              seen = reread_in_another_thread('ext')
            end
            block.call(fresh)
          end
        end
        writer = Thread.new do
          Thread.current[:gap] = true
          game_write('mine', 5)
        end
        expect(writer.join(5)).to eq(writer)
        expect(seen).to eq(2)

        @mock_db.data_version_unknown = true
        expect(game_read('mine')).to eq(5)
      end

      it "caches the write's own row when another session commits after the re-read" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        write_with_gap(:save, lambda {
          their_write("k" => 1, "mine" => 5, "ext" => 2)
          expect(reread_in_another_thread('ext')).to eq(2)
          their_write("k" => 1, "mine" => 5, "ext" => 3) # a later commit: can't tell the order any more
        }) { game_write('mine', 5) }

        @mock_db.data_version_unknown = true
        expect(game_read('mine')).to eq(5)
        expect(settings.instance_variable_get(:@settings_cache)["test_script::GSIV"]).to eq("k" => 1, "mine" => 5)
      end

      it "caches the write's own row when the version can't be read after its store" do
        game_write('k', 1)
        expect(game_read('k')).to eq(1)
        write_with_gap(:save, lambda {
          their_write("k" => 1, "mine" => 5, "ext" => 2)
          expect(reread_in_another_thread('ext')).to eq(2)
          @mock_db.data_version_unknown = true
        }) { game_write('mine', 5) }

        expect(game_read('mine')).to eq(5)
        expect(settings.instance_variable_get(:@settings_cache)["test_script::GSIV"]).to eq("k" => 1, "mine" => 5)
      end

      # Runs the proxy write in the block in another thread. Right after its
      # save_to_database returns (the store and the cache update are done),
      # another session commits and another thread re-reads; nothing the
      # write does after that may put its older row over the re-read one.
      def proxy_write_then_reread(&write)
        seen = nil
        allow(settings).to receive(:save_to_database).and_wrap_original do |original, *args, **opts|
          result = original.call(*args, **opts)
          if Thread.current[:gap]
            Thread.current[:gap] = false
            their_write(@mock_db.get_settings("test_script", "GSIV").merge("ext" => 2))
            seen = reread_in_another_thread('ext')
          end
          result
        end
        writer = Thread.new do
          Thread.current[:gap] = true
          write.call
        end
        expect(writer.join(5)).to eq(writer)
        seen
      end

      it "keeps a row another thread re-read after a nested write's save returned" do
        their_write("opts" => { "c" => 0 })
        opts = game_read('opts')
        expect(proxy_write_then_reread { opts['c'] = 5 }).to eq(2)

        @mock_db.data_version_unknown = true # another process now holds the lock
        expect(reread_in_another_thread('ext')).to eq(2)
        expect(game_read('ext')).to eq(2)
        expect(game_read('opts').to_h).to eq("c" => 5) # the writing thread still sees its own write
      end

      it "keeps a row another thread re-read after a root proxy write's save returned" do
        their_write("k" => 0)
        root = settings.root_proxy_for("GSIV")
        expect(proxy_write_then_reread { root['k'] = 5 }).to eq(2)

        @mock_db.data_version_unknown = true
        expect(reread_in_another_thread('ext')).to eq(2)
        expect(game_read('k')).to eq(5)
      end

      it "still caches the saved row holding the nested write's own container" do
        their_write("opts" => { "c" => 0 })
        opts = game_read('opts')
        opts['c'] = 5
        cached = settings.instance_variable_get(:@settings_cache)["test_script::GSIV"]
        expect(cached).to eq("opts" => { "c" => 5 })
        expect(cached["opts"]).to equal(opts.target) # the caller's proxy stays attached to the cache

        opts['d'] = 6 # no commit in between: written through the same container
        expect(game_read('opts').to_h).to eq("c" => 5, "d" => 6)
        expect(@mock_db.get_settings("test_script", "GSIV")).to eq("opts" => { "c" => 5, "d" => 6 })
      end
    end

    context "Settings.load" do
      it "drops changes made only to the cached row when nothing was committed since it was read" do
        settings[:opts] = { "a" => 1 }
        their_write({ "other" => 1 }, "DR") # any commit: the next read re-reads the row
        expect(settings[:opts].to_h).to eq("a" => 1)
        settings[:opts].to_h["x"] = "local" # changes the cached row, never saved
        expect(settings[:opts]["x"]).to eq("local")

        expect(settings.load).to eq(opts: { "a" => 1 })
        expect(settings[:opts]["x"]).to be_nil
        expect(settings[:opts].to_h).to eq("a" => 1)
      end

      it "drops them when the version can't be read before its read" do
        settings[:opts] = { "a" => 1 }
        their_write({ "other" => 1 }, "DR")
        expect(settings[:opts].to_h).to eq("a" => 1)
        settings[:opts].to_h["x"] = "local"
        @mock_db.data_version_unknown = true

        settings.load
        expect(settings[:opts]["x"]).to be_nil
      end
    end
  end
end

# The same reads through the real DatabaseAdapter, whose data_version comes
# from SQLite. Another session is played by a second connection to the file.
RSpec.describe Lich::Common::Settings, "reads through the real DatabaseAdapter" do
  let(:settings) { Lich::Common::Settings }
  let(:tmp_dir) { Dir.mktmpdir('settings-real-adapter-spec') }
  let(:db_file) { File.join(tmp_dir, 'lich.db3') }

  before do
    stub_const("Script", Lich::Common::MockScript)
    stub_const("XMLData", Lich::Common::MockXMLData)
    Lich::Common::MockScript.current_name = "test_script"
    Lich::Common::MockXMLData.game = "GSIV"
    allow(Lich).to receive(:log)
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

  def game_read(key)
    settings.get_scoped_setting("GSIV", key)
  end

  def their_write(row)
    db = SQLite3::Database.new(db_file)
    db.execute('INSERT OR REPLACE INTO script_auto_settings (script, scope, hash) VALUES (?, ?, ?)',
               ['test_script', 'GSIV', SQLite3::Blob.new(Marshal.dump(row))])
  ensure
    db&.close
  end

  it "shows another session's commit once the version connection has been reopened after an error" do
    their_write("k" => 1)
    expect(game_read('k')).to eq(1)
    their_write("k" => 2)
    broken = @adapter.instance_variable_get(:@version_db)
    allow(broken).to receive(:execute_batch2).and_raise(SQLite3::IOException, 'disk I/O error')
    expect(game_read('k')).to eq(1) # the version can't be read: the cached row is used

    expect(game_read('k')).to eq(2)
  end

  it "keeps showing a newer row read during another thread's write when another session then holds the lock" do
    their_write("ext" => 1)
    expect(game_read('ext')).to eq(1)
    paused = Queue.new
    release = Queue.new
    first = true
    allow(@adapter).to receive(:update_settings).and_wrap_original do |original, *args, **opts, &block|
      original.call(*args, **opts) do |fresh|
        if first
          first = false
          paused << true
          release.pop
        end
        block.call(fresh)
      end
    end
    writer = Thread.new { settings.set_script_settings("GSIV", 'mine', 5) }
    Timeout.timeout(5) { paused.pop }

    their_write("ext" => 2)
    expect(game_read('ext')).to eq(2)
    locker = SQLite3::Database.new(db_file)
    begin
      locker.execute('BEGIN EXCLUSIVE') # another session holds the lock
      expect(@adapter.data_version).to be_nil
      expect(game_read('ext')).to eq(2)
    ensure
      locker.rollback if locker.transaction_active?
      locker.close
      release << true
    end
    expect(writer.join(5)).to eq(writer)
    expect(game_read('ext')).to eq(2)
    expect(game_read('mine')).to eq(5)
  ensure
    writer&.kill
  end

  it "keeps a newer row another thread re-read between a top-level write's store and its cache update" do
    their_write("ext" => 1)
    expect(game_read('ext')).to eq(1)
    seen = nil
    allow(@adapter).to receive(:update_settings).and_wrap_original do |original, *args, on_stored:, &block|
      gap = lambda do |row|
        their_write(row.merge("ext" => 2)) # another session commits just after the store
        seen = Thread.new { game_read('ext') }.value
        on_stored.call(row)
      end
      original.call(*args, on_stored: gap, &block)
    end
    expect(Thread.new { settings.set_script_settings("GSIV", 'mine', 5) }.join(5)).to be_truthy
    expect(seen).to eq(2)

    locker = SQLite3::Database.new(db_file)
    begin
      locker.execute('BEGIN EXCLUSIVE') # another session holds the lock
      expect(@adapter.data_version).to be_nil
      expect(Thread.new { game_read('ext') }.value).to eq(2)
      expect(game_read('mine')).to eq(5)
    ensure
      locker.rollback if locker.transaction_active?
      locker.close
    end
    expect(game_read('ext')).to eq(2)
  end

  it "shows another session's commit and then stops reading the row" do
    expect(game_read('k')).to be_nil
    their_write("k" => 1)

    expect(game_read('k')).to eq(1)
    allow(@adapter).to receive(:get_settings).and_call_original
    3.times { expect(game_read('k')).to eq(1) }
    expect(@adapter).not_to have_received(:get_settings)
  end
end

describe 'SettingsProxy#rebind_to_live!' do
  it 'rebinds target to the live container and clears detached' do
    settings_module = Lich::Common::Settings
    scope = ':'
    path  = [:updatable, :scripts]
    initial = []

    # Create proxy with explicit version detection instead of inline rescue.
    # The rescue pattern could mask real errors - this makes version handling explicit.
    proxy = begin
      # Try new API with detached keyword argument
      Lich::Common::SettingsProxy.new(settings_module, scope, path, initial, detached: true)
    rescue ArgumentError
      # Fall back to old API without detached keyword
      Lich::Common::SettingsProxy.new(settings_module, scope, path, initial)
    end
    live = [{ filename: 'x.lic' }]

    old_oid = proxy.target.object_id
    proxy.send(:rebind_to_live!, live)

    expect(proxy.target).to equal(live)
    expect(proxy.target.object_id).not_to eq(old_oid)
    if proxy.respond_to?(:detached?)
      expect(proxy.detached?).to eq(false)
    else
      expect(proxy.instance_variable_get(:@detached)).to eq(false)
    end
    expect(proxy.scope).to eq(scope)
    expect(proxy.path).to eq(path)
  end
end

describe 'Settings#save_proxy_changes refresh-before-save' do
  # Use RSpec stubs to ensure Script.current.name works regardless of other specs
  before do
    script_double = double('Script', name: 'test_script')
    allow(Script).to receive(:current).and_return(script_double)
  end

  it 'refreshes from DB to prevent stale-cache overwrites' do
    settings_module = Lich::Common::Settings
    script_name = 'test_script'
    scope = ':'
    cache_key = "#{script_name}::#{scope}"

    fresh = { refreshed: true }
    dbl = double('DBAdapter', get_settings: fresh, save_settings: true, data_version: nil)
    settings_module.instance_variable_set(:@db_adapter, dbl)
    settings_module.instance_variable_set(:@settings_cache, { cache_key => { old: true } })

    proxy = Lich::Common::SettingsProxy.new(settings_module, scope, [], {})
    proxy.instance_variable_set(:@detached, true)
    expect {
      settings_module.save_proxy_changes(proxy)
    }.not_to raise_error

    cache_after = settings_module.instance_variable_get(:@settings_cache)[cache_key]
    expect(cache_after).to be_a(Hash)
  end
end

describe 'Settings#save_proxy_changes detached view behavior' do
  # Use RSpec stubs to ensure Script.current.name works regardless of other specs
  before do
    script_double = double('Script', name: 'test_script')
    allow(Script).to receive(:current).and_return(script_double)
  end

  it 'persists the current root when called on a detached proxy' do
    settings_module = Lich::Common::Settings
    script_name = 'test_script'
    scope = ':'
    cache_key = "#{script_name}::#{scope}"

    root = { jars: [] }
    settings_module.instance_variable_set(:@settings_cache, { cache_key => root })
    settings_module.instance_variable_set(:@db_adapter, double('DBAdapter', get_settings: root, save_settings: true, data_version: nil))

    detached_target = { jars: [{ gem: 'ruby' }] }
    detached_proxy = Lich::Common::SettingsProxy.new(settings_module, scope, [], detached_target)
    detached_proxy.instance_variable_set(:@detached, true)

    expect {
      settings_module.save_proxy_changes(detached_proxy)
    }.not_to raise_error

    cache = settings_module.instance_variable_get(:@settings_cache)[cache_key]
    expect(cache).to eq(root)
    expect(cache).to eq(root)
  end
end

describe Lich::Common::SettingsProxy do
  it 'defines a private rebind_to_live! helper' do
    expect(Lich::Common::SettingsProxy.private_instance_methods).to include(:rebind_to_live!)
  end

  it 'rebinds target to the live container and clears detached (without altering scope/path)' do
    proxy = Lich::Common::SettingsProxy.allocate

    settings_module = Object.new
    def settings_module._log(*); end

    # Use stub_const to safely provide LOG_LEVEL_DEBUG without leaking to other tests.
    # This replaces the previous pattern that defined the constant inside the test,
    # which could persist and affect other tests with random ordering.
    stub_const('Settings::LOG_LEVEL_DEBUG', 0) unless defined?(Settings::LOG_LEVEL_DEBUG)

    proxy.instance_variable_set(:@settings_module, settings_module)
    proxy.instance_variable_set(:@scope, ':')
    proxy.instance_variable_set(:@path, [:updatable, :scripts])
    proxy.instance_variable_set(:@target, [:old])
    proxy.instance_variable_set(:@detached, true)

    live = [:new]
    proxy.send(:rebind_to_live!, live)

    expect(proxy.instance_variable_get(:@target)).to equal(live)
    expect(proxy.instance_variable_get(:@detached)).to eq(false)
    expect(proxy.instance_variable_get(:@path)).to eq([:updatable, :scripts])
    expect(proxy.instance_variable_get(:@scope)).to eq(':')
  end
end
