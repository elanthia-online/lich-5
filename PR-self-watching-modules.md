# RFC: Self-Watching Module Pattern for Game Initialization

## TL;DR for Reviewers

**What**: Moves game initialization from `games.rb` into game-specific modules using self-watching background threads
**Why**: Better architecture (SOLID compliance), easier to maintain and extend
**Risk**: Moving initialization code always carries risk of timing issues
**Status**: ✅ Code complete, ❌ Testing incomplete
**Next**: **Need GS and DR players to test before merge**

**This PR does NOT change what happens, only WHERE the code lives.**

---

## ⚠️ Community Testing Required Before Merge

**This PR requires validation from both GemStone and DragonRealms players.**

### Why Testing is Critical

This is a significant architectural refactor that touches core initialization logic. While it's designed as a pure refactor with zero behavioral changes, we're moving initialization code that runs on every login. The code paths are different even though the behavior should be identical.

**We need community validation that:**
- ✅ All initialization still happens at the correct time
- ✅ No character state is missing after login
- ✅ Scripts that depend on initialized data still work correctly
- ✅ Both games initialize properly on first login and reconnect
- ✅ No errors appear in console during login
- ✅ Performance is unchanged

### How You Can Help

1. **Test in a safe environment** (separate Lich install or backup first)
2. **Test your normal workflow** (login, run scripts, check character data)
3. **Report results** (both successes and failures help!)
4. **Check the detailed testing plan below**

### Current Test Status

- [ ] **GemStone**: No testing completed yet
- [ ] **DragonRealms**: No testing completed yet

**This PR should not be merged until both games have been validated by the community.**

## Summary

This PR refactors game-specific initialization to follow a self-watching module pattern, making `games.rb` completely game-agnostic and improving SOLID compliance across the codebase.

**Before**: Game initialization was split between `GameLoader` (module loading) and `games.rb` (runtime initialization with game-specific flags and conditionals)

**After**: Each game module owns its complete lifecycle through self-watching threads that monitor conditions and trigger initialization automatically

**Result**: Same behavior, better architecture

## Motivation

The previous architecture violated several SOLID principles:

- **Single Responsibility**: `games.rb` knew about GS/DR initialization details
- **Open/Closed**: Adding a new game required modifying `games.rb`
- **Dependency Inversion**: `games.rb` depended on concrete implementations (DRInfomon, Infomon)

This made the codebase harder to maintain and prune. Removing DR support, for example, required changes across multiple files.

## What Actually Changed in the Code

### The Core Change

**Before** (in `games.rb`):
```ruby
# GS initialization
if !@infomon_loaded && ... && !XMLData.dialogs.empty?
  ExecScript.start("Infomon.redo!", ...) if XMLData.game !~ /^DR/ && Infomon.db_refresh_needed?
  @infomon_loaded = true
end

# DR initialization
if !@dr_startup_done && @autostarted && XMLData.game =~ /^DR/ && ...
  Lich::DragonRealms::DRInfomon.startup
  @dr_startup_done = true
end
```

**After** (in game modules):
```ruby
# In lib/dragonrealms/drinfomon/startup.rb
def self.watch!
  @startup_thread ||= Thread.new do
    sleep 0.1 until $autostarted && XMLData.name && !XMLData.name.empty?
    startup  # Calls the exact same startup method
  end
end

# In lib/gemstone/infomon.rb
def self.watch!
  @init_thread ||= Thread.new do
    sleep 0.1 until $autostarted && XMLData.name && !XMLData.name.empty? &&
                    !XMLData.dialogs.empty?
    ExecScript.start("Infomon.redo!", ...) if XMLData.game !~ /^DR/ && db_refresh_needed?
  end
end
```

**Result**: Same checks, same timing, same method calls - just moved into modules and run by background threads instead of polling in the main loop.

## File Changes

### New Files

#### `lib/common/watchable.rb`
Defines the `Watchable` module interface for self-watching modules:
- Provides a common contract that modules can extend
- Documents the pattern with examples
- Makes the architecture explicit and discoverable

#### Spec Files (New)
- `spec/lib/common/watchable_spec.rb` - Tests for Watchable module interface
- `spec/lib/common/gameloader_spec.rb` - Tests for GameLoader watch! calls
- `spec/lib/games_spec.rb` - Tests for Game.autostarted? method
- `spec/lib/dragonrealms/drinfomon/startup_spec.rb` - Tests for DRInfomon.watch! and lifecycle

### Modified Files

#### `lib/dragonrealms/drinfomon/startup.rb`
- Added `watch!` method that spawns a background thread
- Thread waits for `$autostarted` and `XMLData.name` conditions
- Automatically calls `startup` when character is ready
- Extended `Lich::Common::Watchable` to declare the pattern

#### `lib/gemstone/infomon.rb`
- Added `watch!` method with GS-specific conditions (includes `XMLData.dialogs`)
- Automatically calls `Infomon.redo!` when needed
- Extended `Lich::Common::Watchable`

#### `lib/gemstone/infomon/activespell.rb`
- Extended `Lich::Common::Watchable` (already had `watch!` method)
- Formalizes existing pattern with the interface

#### `lib/common/gameloader.rb`
- Added `Infomon.watch!` call in `gemstone` method
- Added `DRInfomon.watch!` call in `dragon_realms` method
- No longer needs to know *when* or *how* initialization happens

#### `lib/games.rb`
**Removed** all game-specific initialization code:
- Deleted `@infomon_loaded` instance variable
- Deleted `@dr_startup_done` instance variable
- Deleted GS-specific conditional block (5 lines)
- Deleted DR-specific conditional block (6 lines)

**Result**: `games.rb` is now completely game-agnostic for initialization

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

## Benefits

### SOLID Compliance

1. **Single Responsibility**: Each module owns its complete lifecycle
   - `DRInfomon` knows when and how to initialize itself
   - `Infomon` knows its own timing requirements
   - `games.rb` only processes server messages

2. **Open/Closed**: Adding a new game requires zero changes to `games.rb`
   - Just add the module and call `.watch!` in `GameLoader`
   - No central dispatch logic to update

3. **Dependency Inversion**: `games.rb` has zero knowledge of game specifics
   - Modules are self-sufficient
   - No coupling between `games.rb` and game implementations

### Maintainability

1. **Consistent Pattern**: Follows existing `ActiveSpell.watch!` precedent
2. **Self-Documenting**: Each module clearly shows its initialization in one place
3. **Easy Testing**: Modules can be tested in isolation
4. **Simple Pruning**: Delete game folder + remove one `require` line

### Code Quality

1. **No polling overhead in main loop**: Background threads handle waiting
2. **Clear separation of concerns**: Module initialization lives with the module
3. **Reduced coupling**: `games.rb` doesn't import or reference game-specific code
4. **Discoverable**: Grep for `extend.*Watchable` to find all self-watching modules

## Technical Details

### Thread Lifecycle

Each watcher thread:
1. Spawns once during module load (called from `GameLoader`)
2. Blocks with `sleep 0.1` until conditions are met
3. Runs initialization once
4. Exits after completion

### Error Handling

All watcher threads include error handling:
```ruby
rescue StandardError => e
  respond "Error in #{ModuleName} initialization thread"
  respond e.inspect
end
```

This prevents silent failures and surfaces issues to users.

### Game-Specific Conditions

Each game module declares exactly what conditions it needs:

**DragonRealms**:
```ruby
sleep 0.1 until defined?($autostarted) && $autostarted &&
                XMLData.name && !XMLData.name.empty?
```

**Gemstone** (requires dialogs):
```ruby
sleep 0.1 until defined?($autostarted) && $autostarted &&
                XMLData.name && !XMLData.name.empty? &&
                !XMLData.dialogs.empty?
```

## Testing Plan - **HELP NEEDED**

### Critical Tests (Both Games)

Both GemStone and DragonRealms players should verify:

#### Basic Functionality
- [ ] **Initial login**: Character name, stats, skills populate correctly
- [ ] **Script compatibility**: Existing scripts that check character state work
- [ ] **Reconnect**: Logging out and back in works correctly
- [ ] **Multiple characters**: Switching characters doesn't cause issues

#### DragonRealms Specific
- [ ] **DRInfomon startup**: `info`, `played`, `exp all 0`, `ability` commands run automatically
- [ ] **Skills populated**: `DRSkill` values are available after login
- [ ] **Stats populated**: `DRStats` values are available after login
- [ ] **Spells populated**: Known spells/abilities are detected
- [ ] **startup_complete flag**: `DRInfomon.startup_complete?` returns true after init
- [ ] **Scripts using DRSkill**: Confirm scripts like `combat-trainer` work normally

#### GemStone Specific
- [ ] **Infomon initialization**: Data loads correctly on login
- [ ] **Dialog population**: Initialization waits for dialogs before proceeding
- [ ] **DB refresh**: `Infomon.redo!` runs when needed (check after DB schema change)
- [ ] **ActiveSpell tracking**: Spell durations update correctly
- [ ] **Status tracking**: Character status (standing/sitting/etc) tracked correctly
- [ ] **Scripts using Infomon**: Confirm scripts that read character state work

### What Should NOT Change

This refactor should have **zero behavioral changes**:
- ✅ Same initialization commands run at the same time
- ✅ Same state gets populated
- ✅ Same APIs available to scripts
- ✅ Same timing for when data becomes available

The **only** difference is where the initialization logic lives (in modules instead of `games.rb`).

### How to Test

1. **Backup your current Lich installation** (or use a separate install)
2. Check out this branch
3. Login to your character
4. Verify all character data populates (skills, stats, spells, etc.)
5. Run your normal scripts and confirm they work
6. Log out and log back in to test reconnect
7. Report any issues in this PR

### Known Issues

If you encounter:
- **Missing character data**: The watcher thread may not have triggered
- **Startup commands not running**: Check for errors in console
- **Script errors about nil values**: Data may not be initialized yet

Please report any issues with:
- Game (GS or DR)
- Character name (if comfortable sharing)
- Error messages from console
- What data is missing or incorrect

### Running Unit Tests

The unit tests have been successfully run and all pass:

```bash
# Run all PR-related specs
rspec spec/lib/common/watchable_spec.rb \
      spec/lib/common/gameloader_spec.rb \
      spec/lib/games_spec.rb \
      spec/lib/dragonrealms/drinfomon/startup_spec.rb \
      --format documentation

# Results: 27 examples, 0 failures, 3 pending
# All pending tests are expected (require full Lich environment)
```

**Test Coverage**:
- ✅ Watchable interface contract (4 examples)
- ✅ GameLoader watch! calls for both games (8 examples)
- ✅ Game autostarted? class method accessor (6 examples)
- ✅ DRInfomon thread lifecycle and startup (9 examples)
- ✅ Error handling in watcher threads
- ✅ Thread idempotency (single thread per module)
- ✅ Condition checking before initialization

**Unit Test Status**: ✅ All passing

## Breaking Changes

**None intended**. This is designed as a pure refactor with no API changes:
- All public methods remain the same
- Initialization timing should be identical
- `DRInfomon.startup_complete?` still works
- Scripts that depend on initialized state should see no difference

**However**, since we're moving initialization logic, unforeseen issues may occur. **Testing is critical.**

## Rollback Plan

If issues are discovered after merging, the changes can be reverted quickly:

### Quick Rollback (if needed)
1. Revert the entire PR - this restores everything to previous state
2. The old code path in `games.rb` will work immediately

### Partial Rollback (if one game has issues)
1. Revert just the game-specific changes (e.g., `lib/dragonrealms/` or `lib/gemstone/`)
2. Restore the corresponding conditional block in `games.rb`
3. Other game can keep the new architecture

### Files to Revert
- `lib/games.rb` (restore `@infomon_loaded`, `@dr_startup_done`, conditionals)
- `lib/common/gameloader.rb` (remove `watch!` calls)
- `lib/dragonrealms/drinfomon/startup.rb` (remove `watch!` method)
- `lib/gemstone/infomon.rb` (remove `watch!` method)
- `lib/gemstone/infomon/activespell.rb` (remove Watchable extension)
- `lib/common/watchable.rb` (delete new file)

The old architecture is well-tested and can be restored at any time.

## Future Enhancements

This pattern makes future improvements easier:

1. **New games**: Just implement `watch!` pattern, no `games.rb` changes needed
2. **Better logging**: Add debug output to watcher threads without touching `games.rb`
3. **Retry logic**: Modules can implement their own retry strategies
4. **Conditional loading**: Modules can decide whether to initialize based on settings

## References

- Design document: `PLAN-self-watching-modules.md`
- Existing pattern: `ActiveSpell.watch!` in `lib/gemstone/infomon/activespell.rb`
- Discussion: [Link to issue or discussion about GameLoader design]

## Implementation Checklist

### Code Complete
- [x] Code follows existing patterns (`ActiveSpell.watch!`)
- [x] All game-specific logic removed from `games.rb`
- [x] Modules extend `Watchable` interface
- [x] Error handling included in all watcher threads
- [x] Comments document the pattern and usage
- [x] No intended breaking changes to public APIs
- [x] Syntax errors fixed

### Unit Tests - ✅ **COMPLETE AND PASSING**
- [x] **Watchable module spec** - Tests interface contract (4 examples passing)
- [x] **DRInfomon.watch! spec** - Tests thread creation and lifecycle (9 examples passing)
- [x] **GameBase::Game.autostarted? spec** - Tests class variable accessor (6 examples passing)
- [x] **GameLoader specs** - Tests watch! calls for both games (8 examples passing)
- [x] **Error handling specs** - Tests rescue blocks in watchers (included in above)
- [x] **All specs run successfully** - 27 examples, 0 failures, 3 pending (expected)

### Integration Testing Required - **BLOCKING MERGE**
- [ ] **GemStone login tested** (primary blocker)
- [ ] **GemStone scripts verified** (primary blocker)
- [ ] **GemStone dialogs condition verified** (GS-specific)
- [ ] **DragonRealms login tested** (primary blocker)
- [ ] **DragonRealms scripts verified** (primary blocker)
- [ ] **DragonRealms startup commands verified** (DR-specific)
- [ ] **Multiple characters tested** (both games)
- [ ] **Reconnect scenarios tested** (both games)
- [ ] **No console errors during login** (both games)
- [ ] **Community sign-off received** (both games)

### Post-Merge Monitoring
- [ ] Monitor for issues in the first week after merge
- [ ] Be ready to rollback if critical issues found
- [ ] Document any edge cases discovered
- [ ] Update testing documentation based on findings

---

**Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>**
