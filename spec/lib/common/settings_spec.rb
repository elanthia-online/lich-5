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
  end

  # A proxy holds this process's copy of one container. These examples play
  # another session by writing to the adapter directly between the read that
  # made the proxy and the write through it.
  describe "Writes through a proxy when another session changed the row" do
    let(:settings) { Lich::Common::Settings }

    def game_read(key)
      settings.get_scoped_setting("GSIV", key)
    end

    def their_write(row, scope = "GSIV", script = "test_script")
      @mock_db.save_settings(script, row, scope)
    end

    def stored(scope = "GSIV", script = "test_script")
      @mock_db.get_settings(script, scope)
    end

    before do
      settings.instance_variable_set(:@settings_cache, {})
      settings.instance_variable_set(:@cache_versions, {})
      allow(Lich::Messaging).to receive(:msg)
    end

    describe "replaying the operation on the stored container" do
      it "keeps the other session's keys in the container and the row when writing one key" do
        their_write("opts" => { "x" => 0 })
        opts = game_read('opts')
        their_write("opts" => { "x" => 0, "theirs" => 1 }, "top" => true)

        opts['mine'] = 2

        expect(stored).to eq("opts" => { "x" => 0, "theirs" => 1, "mine" => 2 }, "top" => true)
      end

      it "returns the assigned value, not the stored one" do
        their_write("opts" => {})
        expect(game_read('opts').send(:[]=, 'k', 'v')).to eq('v')
      end

      it "replays each in-place Hash method on the stored hash" do
        {
          [:store, 'k', 1]         => { "a" => 1, "b" => 2, "k" => 1 },
          [:delete, 'a']           => { "b" => 2 },
          [:merge!, { "m" => 3 }]  => { "a" => 1, "b" => 2, "m" => 3 },
          [:update, { "a" => 9 }]  => { "a" => 9, "b" => 2 },
          [:replace, { "r" => 1 }] => { "r" => 1 },
          [:clear]                 => {},
          [:shift]                 => { "b" => 2 },
          [:compact!]              => { "a" => 1, "b" => 2 },
          [:transform_values!]     => { "a" => 1, "b" => 2 }
        }.each do |(method, *args), expected|
          their_write("h" => { "a" => 1 })
          proxy = game_read('h')
          their_write("h" => { "a" => 1, "b" => 2 })

          proxy.public_send(method, *args)

          expect(stored["h"]).to eq(expected), "#{method}: #{stored["h"].inspect}"
        end
      end

      it "replays each in-place Array method on the stored array" do
        {
          [:push, 9]      => [1, 2, 3, 9],
          [:<<, 9]        => [1, 2, 3, 9],
          [:append, 9]    => [1, 2, 3, 9],
          [:unshift, 0]   => [0, 1, 2, 3],
          [:prepend, 0]   => [0, 1, 2, 3],
          [:insert, 1, 7] => [1, 7, 2, 3],
          [:concat, [8]]  => [1, 2, 3, 8],
          [:delete, 2]    => [1, 3],
          [:delete_at, 0] => [2, 3],
          [:pop]          => [1, 2],
          [:shift]        => [2, 3],
          [:slice!, 0, 2] => [3],
          [:reverse!]     => [3, 2, 1],
          [:rotate!]      => [2, 3, 1],
          [:fill, 0]      => [0, 0, 0],
          [:clear]        => [],
          [:replace, [5]] => [5],
          [:compact!]     => [1, 2, 3],
          [:flatten!]     => [1, 2, 3],
          [:uniq!]        => [1, 2, 3],
          [:sort!]        => [1, 2, 3]
        }.each do |(method, *args), expected|
          their_write("arr" => [1])
          proxy = game_read('arr')
          their_write("arr" => [1, 2, 3])

          proxy.public_send(method, *args)

          expect(stored["arr"]).to eq(expected), "#{method}: #{stored["arr"].inspect}"
        end
      end

      it "runs a block given to an in-place method on the stored elements too" do
        their_write("arr" => [1, 2])
        arr = game_read('arr')
        their_write("arr" => [1, 2, 3, 4])

        arr.delete_if(&:even?)
        expect(stored["arr"]).to eq([1, 3])

        arr.map! { |n| n * 10 }
        expect(stored["arr"]).to eq([10, 30])

        their_write("h" => { "a" => 1 })
        h = game_read('h')
        their_write("h" => { "a" => 1, "b" => 2 })
        h.select! { |_k, v| v > 1 }
        expect(stored["h"]).to eq("b" => 2)
      end

      it "returns what the operation returned on the stored container" do
        their_write("arr" => ["mine"])
        arr = game_read('arr')
        their_write("arr" => ["mine", "theirs"])

        expect(arr.pop).to eq("theirs")
        expect(stored["arr"]).to eq(["mine"])

        their_write("h" => {})
        h = game_read('h')
        their_write("h" => { "k" => "theirs" })
        expect(h.delete("k")).to eq("theirs")

        their_write("u" => [1])
        u = game_read('u')
        their_write("u" => [1, 2])
        expect(u.uniq!).to be_nil # nothing to remove from the stored array
      end

      it "returns the proxy when the operation returns its container, so chained calls are saved too" do
        their_write("scripts" => ["a"])
        scripts = game_read('scripts')
        their_write("scripts" => ["a", "b"])

        result = scripts.push("b")
        expect(result.proxy_details).to include('path=["scripts"]')
        result.uniq!

        expect(stored["scripts"]).to eq(["a", "b"])
      end

      it "keeps this session's own earlier write when writing through a proxy kept from before it" do
        their_write("list" => [1])
        kept = game_read('list')
        their_write("list" => [1], "other" => true) # any commit: the next read re-reads the row

        game_read('list').push(2)
        kept.push(3)

        expect(stored["list"]).to eq([1, 2, 3])
      end

      it "shows the stored container through the proxy and through a parent proxy's view of it" do
        their_write("outer" => { "inner" => { "x" => 0 } })
        outer = game_read('outer')
        inner = outer['inner']
        their_write("outer" => { "inner" => { "x" => 0, "theirs" => 1 } })

        inner['mine'] = 2

        expect(inner.to_h).to eq("x" => 0, "theirs" => 1, "mine" => 2)
        expect(outer['inner'].to_h).to eq("x" => 0, "theirs" => 1, "mine" => 2)
      end

      it "stores every write made while the same hash is being iterated, and keeps iterating" do
        loops = {
          "each_pair on the kept proxy" => ->(opts) { opts.each_pair { |k, v| opts[k] = v + 10 } },
          "each_key on the kept proxy"  => ->(opts) { opts.each_key { |k| opts[k] = 0 } },
          "each through a fresh read"   => ->(_opts) { game_read('opts').each { |k, v| game_read('opts')[k] = v * 10 } },
          "a second proxy of the hash"  => ->(opts) { other = game_read('opts'); opts.each_pair { |k, _v| other[k] = 7 } }
        }
        expected = {
          "each_pair on the kept proxy" => { "a" => 11, "b" => 12 },
          "each_key on the kept proxy"  => { "a" => 0, "b" => 0 },
          "each through a fresh read"   => { "a" => 10, "b" => 20 },
          "a second proxy of the hash"  => { "a" => 7, "b" => 7 }
        }
        loops.each do |label, loop_body|
          settings.instance_variable_set(:@settings_cache, {})
          their_write("opts" => { "a" => 1, "b" => 2 })
          opts = game_read('opts')

          expect { loop_body.call(opts) }.not_to raise_error, label
          expect(stored["opts"]).to eq(expected[label]), "#{label}: #{stored["opts"].inspect}"
        end
      end

      it "stores a write made in one thread while another thread iterates the same hash" do
        their_write("spells" => { "101" => 1, "102" => 2 })
        spells = game_read('spells')
        iterating = Queue.new
        written = Queue.new
        reader = Thread.new do
          spells.each_pair do |_k, _v|
            iterating << true
            written.pop
          end
        end
        iterating.pop
        writer_error = nil
        begin
          game_read('spells')['102'] = 20
        rescue StandardError => e
          writer_error = e
        end
        2.times { written << true }
        reader.join

        expect(writer_error).to be_nil
        expect(stored["spells"]).to eq("101" => 1, "102" => 20)
      end

      it "keeps every write made through fresh reads inside an iteration of the hash, reverting none of them" do
        loops = {
          "each_pair, fresh writes" => -> { game_read('opts').each_pair { |k, v| game_read('opts')[k] = v * 10 } },
          "each_key, fresh writes"  => -> { game_read('opts').each_key { |k| game_read('opts')[k] = 0 } },
          "each_pair, fresh delete" => -> { game_read('opts').each_pair { |k, _v| k == "a" ? game_read('opts').delete("a") : game_read('opts')[k] = 0 } }
        }
        expected = {
          "each_pair, fresh writes" => { "a" => 10, "b" => 20 },
          "each_key, fresh writes"  => { "a" => 0, "b" => 0 },
          "each_pair, fresh delete" => { "b" => 0 }
        }
        loops.each do |label, loop_body|
          settings.instance_variable_set(:@settings_cache, {})
          their_write("opts" => { "a" => 1, "b" => 2 })

          expect { loop_body.call }.not_to raise_error, label
          expect(stored["opts"]).to eq(expected[label]), "#{label}: #{stored["opts"].inspect}"
        end
      end

      it "keeps another session's entry when a kept proxy writes while iterating the hash" do
        their_write("opts" => { "a" => 1, "b" => 2 })
        opts = game_read('opts')
        their_write("opts" => { "a" => 1, "b" => 2, "c" => 3 })

        opts.each_pair { |k, v| opts[k] = v + 1 }

        expect(stored["opts"]).to eq("a" => 2, "b" => 3, "c" => 3)
        expect(opts.to_h).to eq("a" => 2, "b" => 3, "c" => 3)
      end

      it "keeps another session's entry committed while a kept proxy iterates and writes" do
        their_write("opts" => { "a" => 1, "b" => 2 })
        opts = game_read('opts')

        opts.each_pair do |k, v|
          their_write("opts" => { "a" => 1, "b" => 2, "c" => 3 }) if k == "a"
          opts[k] = v + 1
        end

        expect(stored["opts"]).to eq("a" => 2, "b" => 3, "c" => 3)
      end

      it "stores a change made to a yielded value inside each_pair, keeping another session's entry" do
        their_write("opts" => { "a" => { "x" => 1 } })
        opts = game_read('opts')
        their_write("opts" => { "a" => { "x" => 1 }, "c" => 3 })

        opts.each_pair { |_k, v| v['y'] = 1 }

        expect(stored["opts"]).to eq("a" => { "x" => 1, "y" => 1 }, "c" => 3)
      end

      it "removes from the stored hash a key the method removed from this session's copy, keeping another session's entry" do
        their_write("opts" => { "a" => 1, "b" => 2 })
        opts = game_read('opts')
        their_write("opts" => { "a" => 1, "b" => 2, "c" => 3 })

        opts.each_pair { |k, _v| opts.target.delete(k) if k == "a" }

        expect(stored["opts"]).to eq("b" => 2, "c" => 3)
      end

      it "keeps another session's commit when a thread that only reads finishes iterating the hash another thread wrote" do
        their_write("opts" => { "a" => 1, "b" => 2 })
        game_read('opts').to_h
        iterating = Queue.new
        go_on = Queue.new
        reader = Thread.new do
          game_read('opts').each_pair do |k, _v|
            next unless k == "a"

            iterating << true
            go_on.pop
          end
        end
        iterating.pop
        game_read('opts')['b'] = 20
        their_write(stored.merge("opts" => stored["opts"].merge("c" => 3)))
        go_on << true
        reader.join

        expect(stored["opts"]).to eq("a" => 1, "b" => 20, "c" => 3)
      end

      it "keeps every write made through fresh reads inside an iteration of an array that does not change its size" do
        their_write("l" => [1, 2])

        game_read('l').each_index { |i| game_read('l')[i] = 0 }

        expect(stored["l"]).to eq([0, 0])
      end

      it "keeps another session's element when changes to the yielded elements of a kept array are stored" do
        their_write("l" => [{ "n" => 1 }])
        l = game_read('l')
        their_write("l" => [{ "n" => 1 }, { "n" => 2 }])

        l.reverse_each { |e| e['seen'] = true }

        expect(stored["l"]).to eq([{ "n" => 1, "seen" => true }, { "n" => 2 }])
      end

      it "stores this session's copy of an array whose size the method changed" do
        their_write("l" => [1, 2])

        game_read('l').each_index { |i| game_read('l').push(9) if i.zero? }

        expect(stored["l"]).to eq([1, 2, 9])
      end

      it "stores this session's copy of an array the method shrank, without the removed element" do
        their_write("l" => [1, 2, 3])
        l = game_read('l')

        l.each_index { |i| l.target.pop if i.zero? }

        expect(stored["l"]).to eq([1, 2])
      end

      it "stores every entry the method changed, keeping another session's entry, in one update of the row" do
        their_write("opts" => { "a" => { "x" => 1 }, "b" => { "x" => 2 } })
        opts = game_read('opts')
        their_write("opts" => { "a" => { "x" => 1 }, "b" => { "x" => 2 }, "c" => 3 })
        allow(@mock_db).to receive(:update_settings).and_call_original

        opts.each_pair { |_k, v| v['seen'] = true }

        expect(stored["opts"]).to eq("a" => { "x" => 1, "seen" => true }, "b" => { "x" => 2, "seen" => true }, "c" => 3)
        expect(@mock_db).to have_received(:update_settings).once
      end

      it "stores a value whose only change is its class (1 to 1.0)" do
        their_write("opts" => { "a" => 1 }, "l" => [1])
        opts = game_read('opts')
        l = game_read('l')

        opts.each_pair { |k, v| opts.target[k] = v.to_f }
        l.each_index { |i| l.target[i] = l.target[i].to_f }

        expect(stored["opts"]["a"]).to eql(1.0)
        expect(stored["l"][0]).to eql(1.0)
      end

      it "tells the user once, not once per entry, when the changed entries can't be stored" do
        their_write("h" => { "n" => { "a" => { "x" => 1 }, "b" => { "x" => 2 }, "c" => { "x" => 3 } } })
        n = game_read('h')['n']
        their_write("h" => 5)

        n.each_pair { |_k, v| v['y'] = 1 }

        expect(stored).to eq("h" => 5)
        expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("does not lead to a container")).once
      end

      it "stores copies of the arguments, so later changes to the caller's objects are not saved or cached" do
        their_write("arr" => [])
        jar = { "gem" => "ruby" }
        game_read('arr').push(jar)
        jar["count"] = 5

        expect(stored["arr"]).to eq([{ "gem" => "ruby" }])
        expect(game_read('arr').to_a).to eq([{ "gem" => "ruby" }])
      end

      it "stores copies of String arguments too, so changing the caller's String later is not shown or saved" do
        their_write("arr" => [], "opts" => {})
        arr = game_read('arr')
        opts = game_read('opts')
        name = +"abc"
        arr.push(name)
        opts['name'] = name
        name << "X"

        expect(arr.to_a).to eq(["abc"])
        expect(game_read('arr').to_a).to eq(["abc"])
        expect(game_read('opts')['name']).to eq("abc")
        expect(stored).to eq("arr" => ["abc"], "opts" => { "name" => "abc" })
      end

      it "stores the plain value when the argument is a proxy" do
        their_write("src" => { "x" => [1] }, "arr" => [])

        game_read('arr').push(game_read('src'))

        expect(stored["arr"]).to eq([{ "x" => [1] }])
        expect(stored["arr"].first).to be_an_instance_of(Hash)
      end

      it "creates the containers on the way that the stored row does not have" do
        their_write("outer" => { "inner" => { "x" => 0 } })
        inner = game_read('outer')['inner']
        their_write("other" => 1)

        inner['y'] = 1

        expect(stored).to eq("other" => 1, "outer" => { "inner" => { "x" => 0, "y" => 1 } })
      end

      it "addresses an element found in an array by its position" do
        their_write("jars" => [{ "gem" => "ruby", "count" => 1 }, { "gem" => "onyx", "count" => 1 }])
        jar = game_read('jars').find { |j| j["gem"] == "onyx" }
        their_write("jars" => [{ "gem" => "ruby", "count" => 1 }, { "gem" => "onyx", "count" => 1, "full" => true }])

        jar["count"] = 2

        expect(stored["jars"]).to eq([{ "gem" => "ruby", "count" => 1 }, { "gem" => "onyx", "count" => 2, "full" => true }])
      end

      it "saves a write through an element that dig, fetch, first, last, at, min_by, max_by or sample returned to that element" do
        cases = {
          ->(m) { m.first }                    => [[1, 9], [2], [3]],
          ->(m) { m.last }                     => [[1], [2], [3, 9]],
          ->(m) { m.at(1) }                    => [[1], [2, 9], [3]],
          ->(m) { m.at(-1) }                   => [[1], [2], [3, 9]],
          ->(m) { m.fetch(-2) }                => [[1], [2, 9], [3]],
          ->(m) { m.dig(0) }                   => [[1, 9], [2], [3]],
          ->(m) { m.min_by { |row| -row[0] } } => [[1], [2], [3, 9]],
          ->(m) { m.max_by { |row| -row[0] } } => [[1, 9], [2], [3]]
        }
        cases.each do |pick, expected|
          their_write("m" => [[1], [2], [3]])
          row = pick.call(game_read('m'))

          row.push(9)

          expect(stored["m"]).to eq(expected)
        end

        their_write("m" => [[1]])
        game_read('m').sample.push(9)
        expect(stored["m"]).to eq([[1, 9]])
      end

      it "saves a write through what Hash#dig and Hash#fetch returned to that hash, keeping its siblings" do
        their_write("opts" => { "a" => { "x" => 0 }, "sib" => 1 })
        by_dig = game_read('opts').dig('a')
        by_fetch = game_read('opts').fetch('a')
        their_write("opts" => { "a" => { "x" => 0, "theirs" => 1 }, "sib" => 1 })

        by_dig['k'] = 1
        by_fetch['j'] = 2

        expect(stored).to eq("opts" => { "a" => { "x" => 0, "theirs" => 1, "k" => 1, "j" => 2 }, "sib" => 1 })
        expect(by_dig.to_h).to eq("x" => 0, "theirs" => 1, "k" => 1, "j" => 2)
      end

      it "saves a write through an element taken from a view (select, sort_by), by a method or by [], to where it is in the stored container" do
        cases = {
          ->(m) { m.select { |row| row[0] > 1 }.first }                          => [[1], [2, 9], [3]],
          ->(m) { m.sort_by { |row| -row[0] }.first }                            => [[1], [2], [3, 9]],
          ->(m) { m.sort_by { |row| -row[0] }.find { |row| row[0] == 2 } }       => [[1], [2, 9], [3]],
          ->(m) { m.select { |row| row[0] > 1 }.sort_by { |row| -row[0] }.last } => [[1], [2, 9], [3]],
          ->(m) { m.reject { |row| row[0] == 1 }.sample }                        => nil,
          ->(m) { m.sort_by { |row| -row[0] }[0] }                               => [[1], [2], [3, 9]],
          ->(m) { m.select { |row| row[0] > 1 }.sort_by { |row| -row[0] }[-1] }  => [[1], [2, 9], [3]]
        }
        cases.each do |pick, expected|
          their_write("m" => [[1], [2], [3]])
          row = pick.call(game_read('m'))
          picked = row.to_a.dup
          their_write("m" => [[1], [2], [3]], "theirs" => 1)

          row.push(9)

          expected ||= [[1], [2], [3]].map { |r| r == picked ? r + [9] : r }
          expect(stored).to eq("m" => expected, "theirs" => 1)
        end
      end

      it "saves a write through an element taken from a Hash view to that element" do
        their_write("opts" => { "a" => { "x" => 0 }, "b" => { "x" => 1 } })
        view = game_read('opts').reject { |k, _v| k == "a" }

        view['b']['k'] = 1
        view.values.first['j'] = 2

        expect(stored).to eq("opts" => { "a" => { "x" => 0 }, "b" => { "x" => 1, "k" => 1, "j" => 2 } })
      end

      it "saves a write through an element taken from a Hash view to that element after the hash took the stored row" do
        their_write("h" => { "n" => { "m" => 1 }, "sib" => 1 })
        h = game_read('h')
        view = h.select { true }
        h['new'] = 1

        view['n']['w'] = 1

        expect(stored).to eq("h" => { "n" => { "m" => 1, "w" => 1 }, "sib" => 1, "new" => 1 })
        expect(Lich::Messaging).not_to have_received(:msg)
      end

      it "saves a write through what dig, fetch or at returned from a view, several keys down, to that element" do
        list = [{ "on" => false, "k" => { "x" => 1 } }, { "on" => true, "k" => { "x" => 2 } }]
        cases = {
          ->(l) { l.select { true }.dig(1, 'k') }                  => ->(rows) { rows[1]['k']['y'] = 1 },
          ->(l) { l.select { |e| e['on'] }.dig(0, 'k') }           => ->(rows) { rows[1]['k']['y'] = 1 },
          ->(l) { l.sort_by { |e| e['on'] ? 0 : 1 }.dig(-1, 'k') } => ->(rows) { rows[0]['k']['y'] = 1 },
          ->(l) { l.reject { |e| e['on'] }.fetch(0) }              => ->(rows) { rows[0]['y'] = 1 },
          ->(l) { l.select { true }.at(-1) }                       => ->(rows) { rows[1]['y'] = 1 }
        }
        cases.each_with_index do |(pick, change), i|
          their_write("l" => Marshal.load(Marshal.dump(list)))
          picked = pick.call(game_read('l'))
          their_write("l" => Marshal.load(Marshal.dump(list)), "theirs" => 1)

          picked['y'] = 1

          expected = Marshal.load(Marshal.dump(list)).tap { |rows| change.call(rows) }
          expect(stored).to eq("l" => expected, "theirs" => 1), "case #{i}: #{stored.inspect}"
        end

        their_write("h" => { "n" => { "m" => { "x" => 1 } }, "sib" => 1 })
        game_read('h').select { true }.dig('n', 'm')['y'] = 1
        expect(stored).to eq("h" => { "n" => { "m" => { "x" => 1, "y" => 1 } }, "sib" => 1 })
      end

      it "saves a write through what dig returned several levels down, at a negative index, to that element" do
        their_write("outer" => { "list" => [{ "n" => 1 }, { "n" => 2 }] })
        row = game_read('outer').dig('list', -1)
        their_write("outer" => { "list" => [{ "n" => 1 }, { "n" => 2 }], "theirs" => 1 })

        row['k'] = 1

        expect(stored).to eq("outer" => { "list" => [{ "n" => 1 }, { "n" => 2, "k" => 1 }], "theirs" => 1 })
      end

      it "saves a write through what store returned to the stored element" do
        their_write("opts" => { "x" => 0 })
        opts = game_read('opts')

        added = opts.store('sub', {})
        added['y'] = 1

        expect(stored).to eq("opts" => { "x" => 0, "sub" => { "y" => 1 } })
      end

      it "returns what delete, delete_at, pop, shift or slice! took out as the plain value, so changing it saves nothing" do
        their_write("opts" => { "sub" => { "x" => 0 }, "sib" => 1 }, "list" => [{ "n" => 1 }, { "n" => 2 }, { "n" => 3 }, { "n" => 4 }])
        taken = [
          game_read('opts').delete('sub'),
          game_read('list').pop,
          game_read('list').shift,
          game_read('list').delete_at(0),
          game_read('list').slice!(0, 1),
          game_read('opts').shift # Hash#shift returns a [key, value] pair
        ]

        taken.each do |value|
          expect(Lich::Common::SettingsProxy === value).to be(false), "got a proxy: #{value.inspect}"
        end
        expect(taken[0]).to eq("x" => 0)
        expect(taken[1]).to eq("n" => 4)
        taken[0]['y'] = 1
        taken[1]['k'] = 1
        taken[4].push("z")

        expect(stored).to eq("opts" => {}, "list" => [])
      end

      it "writes through a root proxy (InstanceSettings.game) into the right script's row" do
        root = settings.root_proxy_for("DR", script_name: "core")
        their_write({ "Beta" => 2 }, "DR", "core")

        root["Alpha"] = 1

        expect(stored("DR", "core")).to eq("Beta" => 2, "Alpha" => 1)
        expect(stored("DR", "test_script")).to eq({})
      end

      it "takes the stored row into the cache, then reads the row again once" do
        their_write("opts" => {})
        opts = game_read('opts')
        their_write("opts" => { "theirs" => 1 })
        opts['mine'] = 2
        allow(@mock_db).to receive(:get_settings).and_call_original

        2.times { expect(game_read('opts').to_h).to eq("theirs" => 1, "mine" => 2) }
        expect(@mock_db).to have_received(:get_settings).once
      end

      it "uses the row of the attempt that was stored when the adapter has to start over" do
        their_write("arr" => ["a"])
        arr = game_read('arr')
        attempts = 0
        allow(@mock_db).to receive(:update_settings).and_wrap_original do |original, script, scope, &block|
          block.call({ "arr" => ["stale"] }) # an attempt whose store found the row changed
          attempts += 1
          their_write("arr" => ["a", "theirs"])
          original.call(script, scope) do |row|
            attempts += 1
            block.call(row)
          end
        end

        expect(arr.pop).to eq("theirs")
        expect(attempts).to eq(2)
        expect(stored["arr"]).to eq(["a"])
        expect(arr.to_a).to eq(["a"])
      end

      it "returns this session's own result when an attempt that replayed was not stored and the next one stores the copy" do
        their_write("arr" => ["a"])
        arr = game_read('arr')
        attempts = 0
        allow(@mock_db).to receive(:update_settings).and_wrap_original do |original, script, scope, &block|
          block.call({ "arr" => ["a", "theirs"] }) # replays pop, then its store finds the row changed
          attempts += 1
          their_write("arr" => nil) # another session removed the array meanwhile
          original.call(script, scope) do |row|
            attempts += 1
            block.call(row)
          end
        end

        expect(arr.pop).to eq("a")
        expect(attempts).to eq(2)
        expect(stored["arr"]).to eq([])
        expect(arr.to_a).to eq([])
      end
    end

    describe "storing this session's copy instead" do
      it "stores the proxy's copy when another session removed the container" do
        their_write("opts" => { "x" => 0 })
        opts = game_read('opts')
        their_write("opts" => nil, "other" => 1)

        opts['y'] = 1

        expect(stored).to eq("opts" => { "x" => 0, "y" => 1 }, "other" => 1)
      end

      it "stores a copy that shares no String with the caller when it stores the proxy's copy" do
        their_write("opts" => { "x" => 0 })
        opts = game_read('opts')
        their_write("opts" => nil)
        name = +"abc"

        opts['name'] = name
        name << "X"

        expect(stored).to eq("opts" => { "x" => 0, "name" => "abc" })
        expect(game_read('opts')['name']).to eq("abc")
      end

      it "stores the proxy's copy when another session put a different kind of value there" do
        their_write("opts" => { "x" => 0 })
        opts = game_read('opts')
        their_write("opts" => [1, 2])

        opts['y'] = 1

        expect(stored).to eq("opts" => { "x" => 0, "y" => 1 })
      end

      it "stores the proxy's copy when the operation raises on the stored container" do
        their_write("arr" => [2, 1])
        arr = game_read('arr')
        their_write("arr" => [2, 1, nil]) # sort! raises on nil

        expect { arr.sort! }.not_to raise_error

        expect(stored["arr"]).to eq([1, 2])
      end

      it "stores the view's copy at its path for a detached view, as before" do
        their_write("opts" => { "a" => 1, "b" => 2 })
        view = game_read('opts').select { |_k, v| v > 1 }
        their_write("opts" => { "a" => 1, "b" => 2 }, "other" => 1)

        view['c'] = 3

        expect(stored).to eq("opts" => { "b" => 2, "c" => 3 }, "other" => 1)
      end

      it "places the copy at an Array index past the end of the stored array, padding with nil" do
        their_write("rows" => [{}, {}, { "x" => 0 }])
        row = game_read('rows')[2]
        their_write("rows" => [{}])

        row['y'] = 1

        expect(stored["rows"]).to eq([{}, nil, { "x" => 0, "y" => 1 }])
      end
    end

    describe "not storing" do
      it "stores nothing for an element yielded by each (a detached view without a path)" do
        their_write("rows" => [{ "x" => 0 }])
        allow(@mock_db).to receive(:update_settings).and_call_original

        game_read('rows').each { |row| row['y'] = 1 }

        expect(@mock_db).not_to have_received(:update_settings)
        expect(stored).to eq("rows" => [{ "x" => 0 }])
      end

      it "stores nothing and says so for an element of a view once its container has taken the stored elements" do
        their_write("l" => [{ "on" => false }, { "on" => true }])
        l = game_read('l')
        selected = l.select { |e| e['on'] }
        l.push({ "on" => false })
        element = selected[0]

        element['k2'] = 1
        selected.first['k3'] = 1

        expect(stored).to eq("l" => [{ "on" => false }, { "on" => true }, { "on" => false }])
        expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("not saved", "not found in the settings")).twice
        expect(element).to be_unlocated
      end

      it "stores nothing and says so for a container under an element yielded by each, instead of writing it at the top of the row" do
        their_write("rows" => [{ "sub" => { "x" => 1 } }], "sub" => "top")

        game_read('rows').each { |row| row['sub']['k'] = 1 }
        game_read('rows').each { |row| row.dig('sub')['j'] = 1 }

        expect(stored).to eq("rows" => [{ "sub" => { "x" => 1 } }], "sub" => "top")
        expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("not found in the settings")).twice
      end

      it "stores nothing and says so for an element of a Hash view whose key now holds another kind of value" do
        their_write("h" => { "n" => { "m" => 1 } })
        h = game_read('h')
        view = h.select { true }
        their_write("h" => { "n" => [1] })
        h['new'] = 1

        view['n']['w'] = 1

        expect(stored).to eq("h" => { "n" => [1], "new" => 1 })
        expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("not found in the settings"))
      end

      it "stores nothing for a new container built from a view's element that is not in the settings, instead of writing at the top of the row" do
        their_write("l" => [{ "on" => false }, { "on" => true }], "top" => 1)
        l = game_read('l')
        selected = l.select { |e| e['on'] }
        l.push({ "z" => 1 })
        mapped = game_read('l').map { |e| e.merge("m" => 1) }

        selected[0].except("nope")['k'] = 1
        expect { selected[0].merge({}).delete("top") }.to raise_error(NoMethodError)
        mapped[0].merge({})['k'] = 1
        expect { mapped[0].merge({}).clear }.to raise_error(NoMethodError)

        expect(stored).to eq("l" => [{ "on" => false }, { "on" => true }, { "z" => 1 }], "top" => 1)
        expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("not found in the settings")).twice
      end

      it "stores nothing for a new container built from an element yielded by each, instead of writing at the top of the row" do
        their_write("rows" => [{ "x" => 0 }], "top" => 1)

        game_read('rows').each { |row| row.merge({})['k'] = 1 }
        expect { game_read('rows').each { |row| row.merge({}).clear } }.to raise_error(NoMethodError)

        expect(stored).to eq("rows" => [{ "x" => 0 }], "top" => 1)
      end

      it "writes through an element of a new container built from a view of a root proxy into that element" do
        their_write("a" => { "x" => 1 }, "top" => 1)
        root = settings.root_proxy_for("GSIV", script_name: "test_script")

        root.select { true }.merge({})['a']['k'] = 1

        expect(stored).to eq("a" => { "x" => 1, "k" => 1 }, "top" => 1)
        expect(Lich::Messaging).not_to have_received(:msg).with("error", anything)
      end

      it "does not write for a method that changes nothing, and runs its block once" do
        their_write("opts" => { "x" => 0 })
        opts = game_read('opts')
        their_write("opts" => { "x" => 0, "theirs" => 1 })
        allow(@mock_db).to receive(:update_settings).and_call_original
        seen = []

        expect(opts.key?("x")).to be(true)
        opts.each_pair { |k, _v| seen << k }

        expect(seen).to eq(["x"])
        expect(@mock_db).not_to have_received(:update_settings)
        expect(stored["opts"]).to eq("x" => 0, "theirs" => 1)
      end

      it "stores nothing and says so when the path runs through a value that is not a container" do
        their_write("outer" => { "inner" => { "x" => 0 } })
        inner = game_read('outer')['inner']
        their_write("outer" => "replaced")

        inner['y'] = 1

        expect(stored).to eq("outer" => "replaced")
        expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("not saved", '["outer", "inner"]'))
      end

      it "stores nothing and says so for a negative Array index in the path" do
        their_write("rows" => [{ "x" => 0 }])
        last = game_read('rows')[-1]

        last['y'] = 1

        expect(stored).to eq("rows" => [{ "x" => 0 }])
        expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("not saved"))
      end

      it "stores nothing and says so when the stored row is not a Hash" do
        their_write("opts" => { "x" => 0 })
        opts = game_read('opts')
        their_write([1, 2])

        opts['y'] = 1

        expect(stored).to eq([1, 2])
        expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("stored as Array, not a Hash"))
      end

      it "stores nothing and says so when an argument can't be stored" do
        their_write("opts" => { "x" => 0 })
        opts = game_read('opts')

        expect { opts['callback'] = proc { 1 } }.not_to raise_error

        expect(stored).to eq("opts" => { "x" => 0 })
        expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("not saved", "Proc"))
      end

      it "stores nothing and says so when this session's copy can't be stored" do
        their_write("opts" => { "x" => 0 })
        opts = game_read('opts')
        their_write("opts" => nil)

        expect { opts['callback'] = proc { 1 } }.not_to raise_error

        expect(stored).to eq("opts" => nil)
        expect(Lich::Messaging).to have_received(:msg).with("error", a_string_including("not saved", "Proc"))
      end

      it "stores nothing without a script name" do
        their_write("opts" => { "x" => 0 })
        opts = game_read('opts')
        Lich::Common::MockScript.current_name = nil
        allow(@mock_db).to receive(:update_settings).and_call_original

        opts['y'] = 1

        expect(@mock_db).not_to have_received(:update_settings)
      ensure
        Lich::Common::MockScript.current_name = "test_script"
      end

      it "keeps this session's change in the proxy and returns its own result when the save fails" do
        their_write("arr" => ["a", "b"])
        arr = game_read('arr')
        allow(@mock_db).to receive(:update_settings).and_return(nil)

        expect(arr.pop).to eq("b")
        expect(arr.to_a).to eq(["a"])
        expect(stored["arr"]).to eq(["a", "b"])
      end
    end

    describe "SettingsProxy::MUTATING_METHODS" do
      it "lists every in-place method of Hash and Array" do
        bang = (Hash.public_instance_methods + Array.public_instance_methods).grep(/\w!\z/).uniq
        others = %i[<< []= append clear compare_by_identity concat default= default_proc= delete delete_at
                    delete_if fill insert keep_if pop prepend push rehash replace shift store unshift update]

        expect(Lich::Common::SettingsProxy::MUTATING_METHODS).to include(*bang, *others)
      end

      it "lists only methods that Hash or Array has, none of them treated as non-destructive" do
        Lich::Common::SettingsProxy::MUTATING_METHODS.each do |method|
          expect(Hash.method_defined?(method) || Array.method_defined?(method)).to be(true), method.inspect
        end
        expect(Lich::Common::SettingsProxy::MUTATING_METHODS & Lich::Common::SettingsProxy::NON_DESTRUCTIVE_METHODS).to be_empty
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
      allow(@mock_db).to receive(:update_settings).and_return(nil) # the lock outlasted the busy timeout

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

      it "does not cache the row when a Settings.load dropped the cached one meanwhile" do
        their_write({ k: 1 }, ":")
        expect(settings[:k]).to eq(1)
        their_write({ k: 2 }, ":")
        @reader, release = start_paused_reader { settings[:k] }

        their_write({ k: 3 }, ":")
        settings.load # drops the cached row and reads k=3
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

describe 'Settings#save_proxy_changes for a detached view without a path' do
  # Use RSpec stubs to ensure Script.current.name works regardless of other specs
  before do
    script_double = double('Script', name: 'test_script')
    allow(Script).to receive(:current).and_return(script_double)
    @saved_adapter = Lich::Common::Settings.instance_variable_get(:@db_adapter)
    @saved_cache = Lich::Common::Settings.instance_variable_get(:@settings_cache)
  end

  after do
    Lich::Common::Settings.instance_variable_set(:@db_adapter, @saved_adapter)
    Lich::Common::Settings.instance_variable_set(:@settings_cache, @saved_cache)
  end

  it 'stores nothing and leaves the cached root alone' do
    settings_module = Lich::Common::Settings
    cache_key = 'test_script::' + ':'

    root = { jars: [] }
    settings_module.instance_variable_set(:@settings_cache, { cache_key => root })
    # A double with no methods: any call to the adapter fails the example.
    settings_module.instance_variable_set(:@db_adapter, double('DBAdapter'))

    detached_proxy = Lich::Common::SettingsProxy.new(settings_module, ':', [], { jars: [{ gem: 'ruby' }] }, detached: true)

    expect(settings_module.save_proxy_changes(detached_proxy)).to be_nil
    expect(settings_module.save_proxy_changes(detached_proxy, :[]=, [:jars, []])).to be_nil

    cache = settings_module.instance_variable_get(:@settings_cache)[cache_key]
    expect(cache).to equal(root)
    expect(cache).to eq(jars: [])
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
