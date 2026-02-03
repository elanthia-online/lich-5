# Plan: Self-Watching Module Pattern for Game Initialization

## Problem Statement

Currently, game-specific initialization is split between two locations:
- **`GameLoader.load!`** in `lib/common/gameloader.rb` - loads Ruby dependencies
- **`games.rb`** - contains game-specific runtime initialization with separate flags (`@infomon_loaded`, `@dr_startup_done`)

This violates SOLID principles:
- **Single Responsibility**: games.rb knows about GS/DR initialization details
- **Open/Closed**: Adding a new game requires modifying games.rb
- **Dependency Inversion**: games.rb depends on concrete implementations (DRInfomon, Infomon)

The original design of `GameLoader` was to own game-specific behavior, but runtime initialization ended up in `games.rb` due to timing requirements (must wait for `@autostarted` and `XMLData.name`).

## Proposed Solution: Self-Watching Modules

Follow the existing `ActiveSpell.watch!` pattern where each game module:
1. Spawns its own background thread during module load
2. Thread waits for required conditions (autostart, character name, etc.)
3. Runs initialization automatically when ready
4. Owns its complete lifecycle - no external coordination needed

**Key principle**: Each module is self-contained and manages its own timing requirements.

This eliminates the need for games.rb or GameLoader to know *when* or *how* each game initializes.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ games.rb                                            │
│  - Generic server loop                              │
│  - NO game-specific conditionals                    │
│  - Just calls GameLoader.load!                      │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│ GameLoader.load!                                    │
│  - Requires game-specific modules                   │
│  - Calls .watch! on self-watching modules           │
│  - No knowledge of what each module needs           │
└─────────────────────────────────────────────────────┘
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
┌──────────────────────┐    ┌──────────────────────┐
│ Gemstone modules     │    │ DragonRealms modules │
│  - ActiveSpell.watch!│    │  - DRInfomon.watch!  │
│  - Infomon.watch!    │    │  - Self-initializes  │
│  - Self-initialize   │    │  - Owns its timing   │
└──────────────────────┘    └──────────────────────┘
```

## Files to Modify

### 1. `lib/dragonrealms/drinfomon/startup.rb`

Add the watcher thread:

```ruby
module Lich
  module DragonRealms
    module DRInfomon
      @@startup_complete = false

      def self.startup_complete?
        @@startup_complete
      end

      # NEW: Self-watching thread that triggers startup when ready
      def self.watch!
        @startup_thread ||= Thread.new do
          begin
            # Wait for character to be ready
            sleep 0.1 until defined?($autostarted) && $autostarted &&
                            XMLData.name && !XMLData.name.empty?

            # Run startup once
            startup
          rescue StandardError => e
            respond 'Error in DRInfomon startup thread'
            respond e.inspect
          end
        end
      end

      def self.startup
        ExecScript.start(startup_script, { quiet: false, name: "drinfomon_startup" })
      end

      def self.startup_script
        <<~SCRIPT
          # Populate stats, race, guild, circle, etc.
          Lich::Util.issue_command("info", /^Name/, /^<output class=""/, quiet: true, timeout: 1) unless dead?

          # Populate account name and subscription level
          Lich::Util.issue_command("played", /^Account Info for/, quiet: true, timeout: 1)

          # Populate all skill ranks and learning rates
          Lich::Util.issue_command("exp all 0", /^Circle: \\d+/, /^EXP HELP/, quiet: true, timeout: 1)

          # Populate known spells/abilities/khri
          Lich::Util.issue_command("ability", /^You (?:know the Berserks|recall the spells you have learned from your training)|^From (?:your apprenticeship you remember practicing|the \\w+ tree)/, /^You (?:recall that you have \\d+ training sessions|can use SPELL STANCE \\[HELP\\]|have \\d+ available slot)/, quiet: true, timeout: 1)

          Lich::DragonRealms::DRInfomon.startup_completed!
        SCRIPT
      end

      def self.startup_completed!
        @@startup_complete = true
      end
    end
  end
end
```

### 2. `lib/gemstone/infomon.rb`

Add similar watcher for GS (create if doesn't exist, or add to existing):

```ruby
module Lich
  module Gemstone
    module Infomon
      # NEW: Self-watching thread for infomon initialization
      def self.watch!
        @init_thread ||= Thread.new do
          begin
            # Wait for character to be ready and dialogs to load
            sleep 0.1 until defined?($autostarted) && $autostarted &&
                            XMLData.name && !XMLData.name.empty? &&
                            !XMLData.dialogs.empty?

            # Run initial setup if needed
            if db_refresh_needed?
              ExecScript.start("Infomon.redo!", { quiet: true, name: "infomon_reset" })
            end
          rescue StandardError => e
            respond 'Error in Infomon initialization thread'
            respond e.inspect
          end
        end
      end

      # Existing methods...
      def self.db_refresh_needed?
        # existing logic
      end
    end
  end
end
```

### 3. `lib/common/gameloader.rb`

Update to call watch! on modules:

```ruby
def self.gemstone
  common_before
  require File.join(LIB_DIR, 'gemstone', 'sk.rb')
  require File.join(LIB_DIR, 'common', 'map', 'map_gs.rb')
  require File.join(LIB_DIR, 'gemstone', 'effects.rb')
  require File.join(LIB_DIR, 'gemstone', 'bounty.rb')
  require File.join(LIB_DIR, 'gemstone', 'claim.rb')
  require File.join(LIB_DIR, 'gemstone', 'infomon.rb')
  require File.join(LIB_DIR, 'attributes', 'resources.rb')
  require File.join(LIB_DIR, 'attributes', 'stats.rb')
  require File.join(LIB_DIR, 'attributes', 'spells.rb')
  require File.join(LIB_DIR, 'attributes', 'skills.rb')
  require File.join(LIB_DIR, 'gemstone', 'society.rb')
  require File.join(LIB_DIR, 'gemstone', 'infomon', 'status.rb')
  require File.join(LIB_DIR, 'gemstone', 'experience.rb')
  require File.join(LIB_DIR, 'attributes', 'spellsong.rb')
  require File.join(LIB_DIR, 'gemstone', 'infomon', 'activespell.rb')
  require File.join(LIB_DIR, 'gemstone', 'psms.rb')
  require File.join(LIB_DIR, 'attributes', 'char.rb')
  require File.join(LIB_DIR, 'gemstone', 'currency.rb')
  require File.join(LIB_DIR, 'gemstone', 'group.rb')
  require File.join(LIB_DIR, 'gemstone', 'critranks')
  require File.join(LIB_DIR, 'gemstone', 'injured')
  require File.join(LIB_DIR, 'gemstone', 'wounds.rb')
  require File.join(LIB_DIR, 'gemstone', 'scars.rb')
  require File.join(LIB_DIR, 'gemstone', 'gift.rb')
  require File.join(LIB_DIR, 'gemstone', 'combat', 'tracker.rb')
  require File.join(LIB_DIR, 'gemstone', 'readylist.rb')
  require File.join(LIB_DIR, 'gemstone', 'stowlist.rb')
  require File.join(LIB_DIR, 'gemstone', 'armaments.rb')

  # Start watchers
  ActiveSpell.watch!  # Already exists
  Infomon.watch!      # NEW
  common_after
end

def self.dragon_realms
  common_before
  require File.join(LIB_DIR, 'common', 'map', 'map_dr.rb')
  require File.join(LIB_DIR, 'attributes', 'char.rb')
  require File.join(LIB_DIR, 'dragonrealms', 'drinfomon.rb')
  require File.join(LIB_DIR, 'dragonrealms', 'commons.rb')

  # Start watcher (NEW)
  DRInfomon.watch!
  common_after
end
```

### 4. `lib/games.rb`

#### Remove from `initialize_buffers`:
```ruby
# Delete these lines:
@infomon_loaded = false
@dr_startup_done = false
```

#### Remove from `process_server_string`:
```ruby
# Delete this entire GS-specific block (around line 430-433):
if !@infomon_loaded && (defined?(Infomon) || !$DRINFOMON_VERSION.nil?) && !XMLData.name.nil? && !XMLData.name.empty? && !XMLData.dialogs.empty?
  ExecScript.start("Infomon.redo!", { quiet: true, name: "infomon_reset" }) if XMLData.game !~ /^DR/ && Infomon.db_refresh_needed?
  @infomon_loaded = true
end

# Delete this entire DR-specific block (around line 437-440):
if !@dr_startup_done && @autostarted && XMLData.game =~ /^DR/ && !XMLData.name.nil? && !XMLData.name.empty?
  Lich::DragonRealms::DRInfomon.startup
  @dr_startup_done = true
end
```

**That's it for games.rb - no replacements needed.** The watcher threads handle everything.

## Before/After Comparison

| Aspect | Before | After |
|--------|--------|-------|
| GS init flag | `@infomon_loaded` in games.rb | Thread-local in `Infomon.watch!` |
| DR init flag | `@dr_startup_done` in games.rb | Thread-local in `DRInfomon.watch!` |
| GS init logic | Inline conditional in games.rb | `Infomon.watch!` background thread |
| DR init logic | Inline conditional in games.rb | `DRInfomon.watch!` background thread |
| Timing control | games.rb polls every server message | Each module waits for its own conditions |
| Code paths | 2 separate game-specific blocks in games.rb | 0 game-specific code in games.rb |
| games.rb role | Knows about GS vs DR initialization | Completely game-agnostic |

## Benefits

### SOLID Compliance

1. **Single Responsibility**: Each module owns its complete lifecycle
   - `DRInfomon` knows when and how to initialize itself
   - `Infomon` knows its own timing requirements
   - games.rb only processes server messages

2. **Open/Closed**: Adding a new game = add module + call `.watch!`
   - No modifications to games.rb
   - No central dispatch logic to update

3. **Dependency Inversion**: games.rb has zero knowledge of game specifics
   - Modules are self-sufficient
   - No coupling between games.rb and game implementations

### Maintainability

1. **Consistent Pattern**: Follows existing `ActiveSpell.watch!` precedent
2. **Self-Documenting**: Each module clearly shows its initialization in one place
3. **Easy Testing**: Modules can be tested in isolation
4. **Simple Pruning**: Delete game folder + remove one `require` line

### Code Quality

1. **No polling overhead in main loop**: Background threads handle waiting
2. **Clear separation of concerns**: Module initialization lives with the module
3. **Reduced coupling**: games.rb doesn't import or reference game-specific code

## Implementation Considerations

### Thread Lifecycle

Each watcher thread:
- Spawns once during module load
- Waits for conditions (blocks with `sleep 0.1`)
- Runs initialization once
- Exits after completion

Thread management is simple since each thread is fire-and-forget.

### Error Handling

Each watcher should wrap its logic in rescue blocks:

```ruby
def self.watch!
  @thread ||= Thread.new do
    begin
      sleep 0.1 until conditions_met?
      startup
    rescue StandardError => e
      respond "Error in #{self.name} initialization"
      respond e.inspect
    end
  end
end
```

This prevents silent failures and surfaces issues to the user.

### Polling Overhead

`sleep 0.1` creates minimal CPU overhead (wakes 10x/sec). If this becomes an issue:

**Option 1: ConditionVariable** (more complex, no polling)
```ruby
@mutex = Mutex.new
@cv = ConditionVariable.new

def self.watch!
  Thread.new do
    @mutex.synchronize do
      @cv.wait(@mutex) until conditions_met?
      startup
    end
  end
end

# Called from games.rb when conditions might be met
def self.signal_ready
  @mutex.synchronize { @cv.signal }
end
```

**Option 2: Increase sleep** (simpler, trades latency for CPU)
```ruby
sleep 0.5 until conditions_met?  # Check every 500ms instead
```

For now, `sleep 0.1` is fine - it's the same pattern used by `GameLoader.load!` today.

### Game-Specific Conditions

Each game may have different readiness requirements:

**DR**: Only needs `$autostarted` and `XMLData.name`
```ruby
sleep 0.1 until $autostarted && XMLData.name && !XMLData.name.empty?
```

**GS**: Also needs `XMLData.dialogs` populated
```ruby
sleep 0.1 until $autostarted && XMLData.name && !XMLData.name.empty? &&
                !XMLData.dialogs.empty?
```

This flexibility is a feature - each module declares exactly what it needs.

## Testing Plan

### Manual Testing

1. **DR login**:
   - Start Lich, connect to DR
   - Verify `DRInfomon.watch!` thread starts
   - After autostart, verify `info`, `played`, `exp all 0`, `ability` commands run
   - Check `DRInfomon.startup_complete?` returns true
   - Verify skills/stats/spells are populated

2. **GS login**:
   - Start Lich, connect to GS
   - Verify both `ActiveSpell.watch!` and `Infomon.watch!` threads start
   - Check that `Infomon.redo!` runs if DB refresh needed
   - Verify dialogs condition works correctly

3. **Reconnect scenario**:
   - Login, verify initialization
   - Disconnect and reconnect to same game
   - Verify initialization runs again (or doesn't, depending on desired behavior)

4. **Fast disconnect**:
   - Start connecting but disconnect before autostart
   - Verify watcher threads don't run startup
   - Verify no errors/hangs

### Automated Testing

Unit tests for each module's watch behavior:

```ruby
describe DRInfomon do
  describe '.watch!' do
    it 'waits for autostart and character name' do
      # Mock conditions not met
      allow($autostarted).to receive(:nil?).and_return(true)

      DRInfomon.watch!
      sleep 0.2  # Give thread time to check

      expect(DRInfomon.startup_complete?).to be false
    end

    it 'runs startup when conditions are met' do
      # Mock conditions met
      allow($autostarted).to receive(:nil?).and_return(false)
      stub_const('XMLData', double(name: 'TestChar'))

      expect(DRInfomon).to receive(:startup)
      DRInfomon.watch!
      sleep 0.2
    end
  end
end
```

## Optional: Watchable Interface

To make the pattern explicit and discoverable, consider adding a module interface:

```ruby
# lib/common/watchable.rb
module Lich
  module Common
    module Watchable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Modules including Watchable must implement watch!
        def watch!
          raise NotImplementedError, "#{self.name} must implement .watch!"
        end
      end
    end
  end
end
```

Then each module declares the contract:

```ruby
module Lich
  module DragonRealms
    module DRInfomon
      include Lich::Common::Watchable  # Declares we're self-watching

      def self.watch!
        # Implementation
      end
    end
  end
end
```

This is optional but makes the architecture more explicit.

## Migration Path

### Phase 1: Add DR Watcher (Low Risk)
1. Add `DRInfomon.watch!` method
2. Call it from `GameLoader.dragon_realms`
3. Keep existing games.rb flag as fallback
4. Test thoroughly

### Phase 2: Remove games.rb DR Logic
1. Delete `@dr_startup_done` and conditional
2. Verify DR still works

### Phase 3: Add GS Watcher
1. Create `Infomon.watch!`
2. Call it from `GameLoader.gemstone`
3. Keep existing games.rb flag as fallback

### Phase 4: Remove games.rb GS Logic
1. Delete `@infomon_loaded` and conditional
2. Verify GS still works

This incremental approach allows testing at each step.

## Open Questions

1. **Thread cleanup on disconnect**: Should watcher threads be terminated on disconnect? Or can they safely persist?
   - Likely safe to persist - they check conditions and do nothing if not met
   - Could add `@thread.kill` in disconnect handler if needed

2. **Logging**: Should we add debug logging to watcher threads?
   - Suggest yes: `respond "[#{self.name}] Initialization complete" if $debug_mode`

3. **Error recovery**: If initialization fails, should the thread retry or give up?
   - Current behavior: gives up (thread exits after one attempt)
   - Could add retry logic if needed

## Summary

This refactor moves game-specific initialization from central coordination (games.rb) to self-contained modules that manage their own lifecycle. The benefits:

- **Better SOLID compliance**: Each module owns its complete lifecycle
- **Simpler pruning**: Delete game folder = remove all game-specific code
- **Easier extension**: New games just implement `.watch!` pattern
- **Follows existing patterns**: `ActiveSpell.watch!` already works this way
- **games.rb becomes generic**: No game-specific conditionals or flags

The implementation is straightforward: add a `watch!` method to each game module that spawns a thread, waits for conditions, and runs initialization. This eliminates the need for games.rb to know about game-specific timing requirements.
