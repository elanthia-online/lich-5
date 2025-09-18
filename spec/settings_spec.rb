require 'rspec'
require 'ostruct'
DATA_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'spec')
require_relative File.join(DATA_DIR, 'mock_database_adapter.rb')
LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib')
require_relative File.join(LIB_DIR, 'common', 'settings.rb')

module XMLData
  @dialogs = {}
  def self.game
    "GSIV"
  end

  def self.name
    "TestCharacter"
  end

  def self.indicator
    { 'IconSTUNNED' => 'n',
      'IconDEAD'    => 'n',
      'IconWEBBED'  => false }
  end

  def self.save_dialogs(kind, attributes)
    @dialogs[kind] ||= {}
    return @dialogs[kind] = attributes
  end

  def self.dialogs
    @dialogs ||= {}
  end
end

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
      scripts = upd[:scripts] || []
      mapdb   = upd[:mapdb]   || {}

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
      scripts = upd[:scripts] || []
      mapdb   = upd[:mapdb]   || {}

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
      scripts = upd[:scripts] || []
      mapdb   = upd[:mapdb]   || {}

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
end
