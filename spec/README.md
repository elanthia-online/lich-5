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

### 3. Reset State via `class_variable_set` or Mock `reset!`

Production code must NOT contain test-only methods. Use `class_variable_set`
for production classes, or `reset!` on spec_helper mock modules:

```ruby
# For specs that load REAL production classes:
before(:each) do
  # NOTE: class_variable_set used because DRStats is a production class with no reset! method
  described_class.class_variable_set(:@@guild, nil)
  described_class.class_variable_set(:@@race, nil)
end

# For specs that use MOCK modules from spec_helper:
before(:each) do
  described_class.reset!  # reset! is defined on the mock, not production
end
```

Mock modules with `reset!` (defined in spec_helper.rb, NOT production):
- `DRC.reset!` - clears hand state
- `DRStats.reset!` - resets stats to defaults
- `DRSkill.reset!` - clears rank/xp hashes
- `DRSpells.reset!` - clears known spells, feats, parsing state
- `DRRoom.reset!` - clears npcs, pcs, group members
- `Flags.reset!` - clears all flags and matchers
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

### Missing Standard Library

**Symptom**: `NameError: uninitialized constant SomeModule::Date` (or `Time`, `JSON`, etc.)

**Cause**: Production code uses a standard library class that isn't loaded in test context.

**Fix**: Add the require to `spec_helper.rb`:
```ruby
require 'date'
require 'json'
require 'time'
```

## Test Design Principles

### DAMP vs DRY

Tests prioritize **DAMP** (Descriptive And Meaningful Phrases) over DRY (Don't Repeat Yourself).

**DAMP is preferred when:**
- Test intent should be immediately obvious
- Each test should be self-contained and readable
- Duplication makes the test easier to understand

```ruby
# Good - DAMP: clear what each test does
it 'returns nil for non-Moon Mage guilds' do
  described_class.guild = 'Barbarian'
  expect(described_class.native_mana).to be_nil
end

it 'returns lunar for Moon Mage guild' do
  described_class.guild = 'Moon Mage'
  expect(described_class.native_mana).to eq('lunar')
end
```

**DRY is preferred when:**
- Multiple tests share identical setup (use `shared_context`)
- Testing the same behavior with different inputs (use `shared_examples`)
- Repetitive assertions follow a clear pattern

```ruby
# Good - DRY: shared example for 12 identical guild predicate tests
RSpec.shared_examples 'guild predicate' do |guild_name, method_name|
  it "returns true when guild is #{guild_name}" do
    described_class.guild = guild_name
    expect(described_class.send(method_name)).to be true
  end
end

# Usage
include_examples 'guild predicate', 'Barbarian', :barbarian?
include_examples 'guild predicate', 'Moon Mage', :moon_mage?
```

### SOLID Principles in Tests

#### Dependency Inversion (DIP)

**Prefer public `reset!` APIs over `class_variable_set`:**

```ruby
# Good - uses public API
before(:each) do
  described_class.reset!
end

# Avoid - couples to internal implementation
before(:each) do
  described_class.class_variable_set(:@@some_var, [])
end
```

**When `class_variable_set` is acceptable:**
1. Testing the class variable implementation itself
2. No `reset!` method exists (add TODO to create one)
3. Document the reason with a comment

```ruby
# NOTE: class_variable_set acceptable here because we're testing
# the class variable refactoring from @ to @@. This tests the
# implementation detail by design.
```

#### Single Responsibility (SRP)

Each test should verify one behavior:

```ruby
# Good - single responsibility
it 'sets the guild' do
  described_class.guild = 'Moon Mage'
  expect(described_class.guild).to eq('Moon Mage')
end

# Bad - tests multiple unrelated things
it 'sets guild and race and age' do
  described_class.guild = 'Moon Mage'
  described_class.race = 'Elf'
  described_class.age = 30
  expect(described_class.guild).to eq('Moon Mage')
  expect(described_class.race).to eq('Elf')
  expect(described_class.age).to eq(30)
end
```

### Documenting Skipped Tests

When using `xit` or `skip`, always document:
1. **Why** it's skipped
2. **What fix** is needed
3. **Severity** of the test gap
4. **Tracking** reference (or TODO to create issue)

```ruby
# ISSUE: Production bug - GameObj.right_hand returns same instance.
# Fix: Add .dup call in the reader method.
# Severity: Low - scripts rarely mutate hand objects.
# Tracking: Create GitHub issue when addressing this.
xit 'returns duplicate hand objects' do
  # test code...
end
```

For environment-dependent skips:

```ruby
it 'requires full game environment' do
  skip 'Requires network connection and game client'
  # integration test code...
end
```

### Test Isolation Checklist

Before submitting a spec file, verify:

- [ ] `before(:each)` calls appropriate `reset!` methods
- [ ] Global variables (`$foo`) are reset if modified
- [ ] Class variables are reset via `reset!` or documented `class_variable_set`
- [ ] Tests pass with `--order random` (run 3+ times)
- [ ] Tests pass in isolation: `rspec path/to/specific_spec.rb`
- [ ] Tests pass when run with full suite: `rspec`

### Production Code Requirements for Testability

When writing production code, include:

1. **`reset!` method** for any class with mutable state
2. **Frozen constants** for immutable data (`FREEZE` pattern constants)
3. **Dependency injection** where practical (pass dependencies as args)

```ruby
module MyModule
  @@some_state = []

  def self.reset!
    @@some_state = []
  end
end
```
