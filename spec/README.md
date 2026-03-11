# lich-5 Test Suite

This directory contains RSpec tests for the lich-5 codebase.

## Quick Start

```bash
# Run all tests
rspec

# Run specific file
rspec spec/lib/dragonrealms/drinfomon/drstats_spec.rb

# Run with verbose output
rspec --format doc

# Run with specific seed (for reproducing failures)
rspec --seed 12345
```

## Directory Structure

Spec files mirror the `lib/` directory structure:

```
spec/
├── spec_helper.rb           # Shared mocks, contexts, and configuration
├── fixtures/                # Test data files (effect-list.xml, etc.)
├── lib/
│   ├── common/              # Tests for lib/common/
│   ├── dragonrealms/
│   │   ├── commons/         # Tests for lib/dragonrealms/commons/
│   │   └── drinfomon/       # Tests for lib/dragonrealms/drinfomon/
│   └── gemstone/            # Tests for lib/gemstone/
└── *.rb                     # Legacy specs (being migrated)
```

## Spec Standards

### 1. Always Require spec_helper

Every spec file must start with:

```ruby
# frozen_string_literal: true

require_relative '../../../spec_helper'  # Adjust path based on depth
```

### 2. Use `described_class` Instead of Hardcoded Class Names

```ruby
# Good
RSpec.describe Lich::DragonRealms::DRStats do
  it 'does something' do
    expect(described_class.guild).to eq('Moon Mage')
  end
end

# Bad - hardcodes the class name
RSpec.describe Lich::DragonRealms::DRStats do
  it 'does something' do
    expect(Lich::DragonRealms::DRStats.guild).to eq('Moon Mage')
  end
end
```

### 3. Use `reset!` Methods Instead of `class_variable_set`

Production classes provide `reset!` methods for test isolation:

```ruby
# Good
before(:each) do
  described_class.reset!
end

# Bad - couples tests to internal implementation
before(:each) do
  described_class.class_variable_set(:@@some_var, [])
end
```

Available `reset!` methods:
- `DRSkill.reset!` - clears skills, gained_skills, start_time
- `DRStats.reset!` - resets all stats to defaults
- `DRSpells.reset!` - clears known spells, feats, parsing state
- `DRRoom.reset!` - clears npcs, pcs, group members
- `Flags.reset!` - clears all flags and matchers
- `DRInfomon.reset!` - clears startup state
- `UserVars.reset!` - clears all user variables

### 4. Use Shared Examples for Repetitive Patterns

When testing similar behavior across multiple cases, use shared examples:

```ruby
# Defined in spec_helper.rb
RSpec.shared_examples 'guild predicate' do |guild_name, method_name|
  describe ".#{method_name}" do
    it "returns true when guild is #{guild_name}" do
      described_class.guild = guild_name
      expect(described_class.send(method_name)).to be true
    end
    # ... more tests
  end
end

# Usage in spec file
describe 'guild predicate methods' do
  include_examples 'guild predicate', 'Barbarian', :barbarian?
  include_examples 'guild predicate', 'Bard', :bard?
  # ...
end
```

### 5. Use Shared Contexts for Common Setup

```ruby
# Defined in spec_helper.rb
RSpec.shared_context 'XMLData stubs' do
  before do
    allow(XMLData).to receive(:name).and_return('TestChar')
    allow(XMLData).to receive(:health).and_return(100)
    # ...
  end
end

# Usage in spec file
RSpec.describe MyClass do
  include_context 'XMLData stubs'
  # Tests can now use XMLData without additional setup
end
```

Available shared contexts:
- `'XMLData stubs'` - common character info (name, health, mana, etc.)
- `'DRSpells XMLData stubs'` - active spells, slivers, stellar percentage

### 6. Use `unless defined?` Guards for Mock Definitions

When defining mocks that might conflict with production code:

```ruby
module MyMock
  def self.some_method
    'mock value'
  end
end unless defined?(MyMock)
```

### 7. Define Mocks at Top Level, Alias into Namespace

To ensure `expect()` and namespaced code reference the same object:

```ruby
# Define at top level first
module DRC
  def self.bput(*args)
    'default'
  end
end unless defined?(DRC)

# Then alias into namespace
Lich::DragonRealms::DRC = DRC unless defined?(Lich::DragonRealms::DRC)
```

### 8. Use `allow()` Stubs, Not Custom Mock Methods

```ruby
# Good - uses RSpec stubs
allow(DRSkill).to receive(:getrank).with('Evasion').and_return(100)

# Bad - defines custom mock methods that may conflict
def DRSkill.getrank(skill)
  100
end
```

### 9. Match Real Type (Class vs Module)

Ruby raises `TypeError` if you define a class where production expects a module:

```ruby
# Production code
module DRStats; end

# Good - matches production type
module DRStats
  def self.guild; 'Moon Mage'; end
end

# Bad - type mismatch will cause errors
class DRStats  # TypeError!
  def self.guild; 'Moon Mage'; end
end
```

Known types:
- **Classes**: `DRSkill`, `DRRoom`, `Room`, `Script`, `Flags`
- **Modules**: `DRStats`, `DRC`, `DRCI`, `DRCA`, `DRCT`, `DRSpells`, `UserVars`

### 10. Reset State in `before(:each)` Hooks

Always reset shared state to ensure test isolation:

```ruby
RSpec.describe MyClass do
  before(:each) do
    described_class.reset!
    XMLData.reset
    Flags.reset!
  end
end
```

The global `config.before` hook in spec_helper.rb handles common resets, but spec-specific state should be reset in the spec file.

## Test Helpers

### Setting Skill Values

```ruby
DRSkill.set_xp('Evasion', 25)
DRSkill.set_rank('Evasion', 500)
```

### Pre-setting Flag Values

```ruby
# Set a flag value that survives Flags.add calls
Flags.set_pending('my_flag', ['matched value'])
```

## Running Tests

### All Tests
```bash
rspec
```

### Specific Directory
```bash
rspec spec/lib/dragonrealms/
```

### With Coverage
```bash
COVERAGE=true rspec
```

### Debug Mode (shows output)
```bash
DEBUG=1 rspec spec/path/to/spec.rb
```

## Common Issues

### Cross-Spec Pollution

**Symptom**: Tests pass individually but fail when run together.

**Cause**: Shared state not reset between tests.

**Fix**: Add `reset!` calls in `before(:each)` or use the global reset hook.

### Mock/Production Mismatch

**Symptom**: `expect(MyModule)` doesn't match calls to `Lich::DragonRealms::MyModule`.

**Cause**: Two different objects with the same name.

**Fix**: Ensure top-level mock is aliased into namespace:
```ruby
Lich::DragonRealms::MyModule = ::MyModule
```

### Undefined Method on Nil

**Symptom**: `NoMethodError: undefined method 'foo' for nil:NilClass`

**Cause**: Production code relies on NilClass `method_missing` monkey-patch.

**Fix**: Mock the specific method or stub the dependency.
