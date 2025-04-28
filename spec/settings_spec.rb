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
    # shimming together a hash to test 'muckled?' results
    { 'IconSTUNNED' => 'n',
      'IconDEAD'    => 'n',
      'IconWEBBED'  => false }
  end

  def self.save_dialogs(kind, attributes)
    # shimming together response for testing status checks
    @dialogs[kind] ||= {}
    return @dialogs[kind] = attributes
  end

  def self.dialogs
    @dialogs ||= {}
  end
end

RSpec.describe Lich::Common::Settings do
  before(:each) do
    # Set up mock objects
    @mock_db = Lich::Common::MockDatabaseAdapter.new

    # Replace the real database adapter with our mock
    allow(Lich::Common::DatabaseAdapter).to receive(:new).and_return(@mock_db)

    # Set up test environment
    Lich::Common::MockScript.current_name = "test_script"
    Lich::Common::MockXMLData.game = "GSIV"
    Lich::Common::MockXMLData.name = "TestCharacter"

    # Replace constants with our mocks
    stub_const("Script", Lich::Common::MockScript)
    stub_const("XMLData", Lich::Common::MockXMLData)

    # Reset Settings module state
    Lich::Common::Settings.instance_variable_set(:@db_adapter, @mock_db)
    Lich::Common::Settings.instance_variable_set(:@path_navigator, Lich::Common::PathNavigator.new(@mock_db))

    # Clear any existing settings
    @mock_db.clear
  end

  describe "Basic Functionality" do
    it "sets and retrieves a simple value" do
      Lich::Common::Settings[:test_key] = "test_value"
      expect(Lich::Common::Settings[:test_key]).to eq("test_value")
    end

    it "persists values to the database" do
      Lich::Common::Settings[:test_key] = "test_value"
      # Check the mock database directly
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

    # Settings.char method is not used and has been removed.  No test validation required
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

      it "handles ||= operator" do
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

      # the following operators do not work with arrays; may need to improve exception handling

      # it "handles < operator" do
      #  expect(Lich::Common::Settings[:numbers] < [2, 3, 4]).to raise_error(an_instance_of(NoMethodError))
      #  expect(Lich::Common::Settings[:numbers] < [1, 2, 3]).to raise_error(NoMethodErro, "undefined method '<' for an instance of Array")
      # end

      # it "handles <= operator" do
      #  expect(Lich::Common::Settings[:numbers] <= [1, 2, 3]).to be true
      #  expect(Lich::Common::Settings[:numbers] <= [1, 2, 2]).to be false
      # end

      # it "handles > operator" do
      #  expect(Lich::Common::Settings[:numbers] > [0, 1, 2]).to be true
      #  expect(Lich::Common::Settings[:numbers] > [1, 2, 3]).to be false
      # end

      # it "handles >= operator" do
      #  expect(Lich::Common::Settings[:numbers] >= [1, 2, 3]).to be true
      #  expect(Lich::Common::Settings[:numbers] >= [1, 2, 4]).to be false
      # end
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
        Lich::Common::Settings[:test_hash][:c] = 3
        expect(Lich::Common::Settings[:test_hash][:c]).to eq(3)
      end

      it "supports hash methods" do
        expect(Lich::Common::Settings[:test_hash].keys).to contain_exactly(:a, :b)
        expect(Lich::Common::Settings[:test_hash].values).to contain_exactly(1, 2)
      end

      it "supports hash iteration" do
        result = {}
        Lich::Common::Settings[:test_hash].each do |k, v|
          result[k] = v
        end
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
        Lich::Common::Settings[:test_array][1] = 99
        expect(Lich::Common::Settings[:test_array][1]).to eq(99)
      end

      it "supports push operation" do
        Lich::Common::Settings[:test_array].push(4)
        expect(Lich::Common::Settings[:test_array].to_a).to eq([1, 2, 3, 4])
      end

      it "supports << operation" do
        Lich::Common::Settings[:test_array] << 4
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
      Lich::Common::Settings[:config] = { level1: { level2: { level3: "deep_value" } } }
      expect(Lich::Common::Settings[:config][:level1][:level2][:level3]).to eq("deep_value")
    end

    it "handles array of hashes" do
      Lich::Common::Settings[:users] = [
        { name: "Alice", age: 30 },
        { name: "Bob", age: 25 }
      ]
      expect(Lich::Common::Settings[:users][0][:name]).to eq("Alice")
      expect(Lich::Common::Settings[:users][1][:age]).to eq(25)
    end

    it "handles the updatable scripts example" do
      Lich::Common::Settings[:updatable] = {}
      Lich::Common::Settings[:updatable][:scripts] = []
      Lich::Common::Settings[:updatable][:mapdb] = {}

      Lich::Common::Settings[:updatable][:scripts].push({ filename: "alias.lic", game: "gs",
                                                          author: "elanthia-online" })
      Lich::Common::Settings[:updatable][:mapdb]["GSIV"] = true
      Lich::Common::Settings[:updatable]["lich"] = false

      expect(Lich::Common::Settings[:updatable][:scripts][0][:filename]).to eq("alias.lic")
      expect(Lich::Common::Settings[:updatable][:mapdb]["GSIV"]).to be true
      expect(Lich::Common::Settings[:updatable]["lich"]).to be false
    end

    it "persists complex nested structures" do
      Lich::Common::Settings[:updatable] = {}
      Lich::Common::Settings[:updatable][:scripts] = []
      Lich::Common::Settings[:updatable][:scripts].push({ filename: "test.lic", game: "gs" })

      # Check the mock database directly
      storage = @mock_db.dump
      expect(storage["test_script::"][:updatable][:scripts][0][:filename]).to eq("test.lic")
    end

    it "handles nested updates" do
      Lich::Common::Settings[:config] = { options: { timeout: 30 } }
      Lich::Common::Settings[:config][:options][:timeout] = 60

      expect(Lich::Common::Settings[:config][:options][:timeout]).to eq(60)

      # Check the mock database directly
      storage = @mock_db.dump
      expect(storage["test_script::"][:config][:options][:timeout]).to eq(60)
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
      # tests successfully accessing a non-existent path
      expect(Lich::Common::Settings[:non_existent]).to be_nil
      # evaluate why nested paths are not handled gracefully if the root is nil
      # fails test for accessing a non-existent path with a non-existent key or root
      # expect(Lich::Common::Settings[:non_existent][:deeper]).to be_nil
      # expect(Lich::Common::Settings[:non_existent][:deeper][:path]).to be_nil
    end

    # Type mismatches are not handled gracefully in settings - FIXME
    # it "handles type mismatches gracefully" do
    # Lich::Common::Settings[:string_value] = "not_a_container"
    # expect { Lich::Common::Settings[:string_value][:key] }.not_to raise_error
    # expect(Lich::Common::Settings[:string_value][:key]).not_to raise_error
    # expect(Lich::Common::Settings[:string_value][:key]).to be_nil
    # end

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
      # Initialize with ||= operator - expected that this will retain prior values (filename: "test.lic")
      Lich::Common::Settings[:updatable] ||= {}
      Lich::Common::Settings[:updatable][:scripts] ||= []
      Lich::Common::Settings[:updatable][:mapdb] ||= {}

      # Add scripts
      Lich::Common::Settings[:updatable][:scripts].push({ filename: "alias.lic", game: "gs",
                                                          author: "elanthia-online" })
      Lich::Common::Settings[:updatable][:scripts].push({ filename: "autostart.lic", game: "gs",
                                                          author: "elanthia-online" })
      Lich::Common::Settings[:updatable][:scripts].push({ filename: "go2.lic", game: "gs", author: "elanthia-online" })

      # Set mapdb values
      Lich::Common::Settings[:updatable][:mapdb]["GSIV"] = true
      Lich::Common::Settings[:updatable][:mapdb]["GSF"] = true
      Lich::Common::Settings[:updatable][:mapdb]["GSPlat"] = true
      Lich::Common::Settings[:updatable][:mapdb]["GST"] = true

      # Set a simple value
      Lich::Common::Settings[:updatable]["lich"] = false

      # Verify the structure
      expect(Lich::Common::Settings[:updatable][:scripts].length).to eq(3)
      expect(Lich::Common::Settings[:updatable][:scripts][0][:filename]).to eq("alias.lic")
      expect(Lich::Common::Settings[:updatable][:scripts][1][:filename]).to eq("autostart.lic")
      expect(Lich::Common::Settings[:updatable][:scripts][2][:filename]).to eq("go2.lic")

      expect(Lich::Common::Settings[:updatable][:mapdb]["GSIV"]).to be true
      expect(Lich::Common::Settings[:updatable][:mapdb]["GSF"]).to be true
      expect(Lich::Common::Settings[:updatable][:mapdb]["GSPlat"]).to be true
      expect(Lich::Common::Settings[:updatable][:mapdb]["GST"]).to be true

      expect(Lich::Common::Settings[:updatable]["lich"]).to be false

      # Check the mock database directly
      storage = @mock_db.dump
      settings = storage["test_script::"][:updatable]

      expect(settings[:scripts].length).to eq(3)
      expect(settings[:mapdb].keys).to contain_exactly("GSIV", "GSF", "GSPlat", "GST")
      expect(settings["lich"]).to be false
    end

    it "handles complex operations with method chaining" do
      Lich::Common::Settings[:data] = Array.new
      Lich::Common::Settings[:data].push({ id: 1, name: "Item 1", tags: ["tag1", "tag2"] })
      Lich::Common::Settings[:data].push({ id: 2, name: "Item 2", tags: ["tag2", "tag3"] })
      Lich::Common::Settings[:data].push({ id: 3, name: "Item 3", tags: ["tag1", "tag3"] })
      Lich::Common::Settings[:data].push({ id: 4, name: "Item 4", tags: ["tag7", "tag3"] })
      Lich::Common::Settings[:data].push({ id: 5, name: "Item 5", tags: ["tag5", "tag3"] })
      Lich::Common::Settings[:data].push({ id: 6, name: "Item 6", tags: ["tag6", "tag3"] })

      # Find items with tag1
      items_with_tag1 = Lich::Common::Settings[:data].select { |item| item[:tags].include?("tag1") }
      expect(items_with_tag1.length).to eq(2)
      expect(items_with_tag1.map { |item| item[:id] }).to contain_exactly(1, 3)

      # Add a new tag to item 2
      Lich::Common::Settings[:data][1][:tags].push("tag4")
      expect(Lich::Common::Settings[:data][1][:tags]).to contain_exactly("tag2", "tag3", "tag4")

      # Update an item's name
      Lich::Common::Settings[:data][0][:name] = "Updated Item 1"
      expect(Lich::Common::Settings[:data][0][:name]).to eq("Updated Item 1")

      # Check the mock database directly
      storage = @mock_db.dump
      expect(storage["test_script::"][:data][0][:name]).to eq("Updated Item 1")
      expect(storage["test_script::"][:data][1][:tags]).to contain_exactly("tag2", "tag3", "tag4")
    end
  end
end
