# YARD Documentation Style Guide

This guide defines documentation standards for the lich-5 codebase using
[YARD](https://yardoc.org/). It covers what to document, how to document it,
and what to skip.

## Principles

1. **Document as you touch** — Add YARD docs when creating or modifying code.
   No retroactive documentation sweeps required.
2. **Accuracy over completeness** — A concise, correct doc block is better than
   a comprehensive, stale one.
3. **Examples over prose** — Show usage with `@example` blocks rather than
   explaining behavior in paragraphs.
4. **Types are required** — Every `@param` and `@return` must include a type
   annotation.
5. **Enforce through PR review** — No CI enforcement. Reviewers check that new
   or modified public methods have appropriate documentation.

---

## Documentation Tiers

Methods fall into one of four tiers based on their usage and visibility.

### Consumer-Facing (Full Documentation)

A method is **consumer-facing** if it is called from `.lic` files in
[elanthia-online/scripts](https://github.com/elanthia-online/scripts) or
[elanthia-online/dr-scripts](https://github.com/elanthia-online/dr-scripts).

These methods are the public API that script authors depend on.

**Required tags**: summary line, `@param`, `@return`

**Encouraged tags**: `@example`, `@see`, `@note`

```ruby
# Gets an item from a container or the default storage location.
#
# Issues a GET command and checks for success or failure responses.
# Returns false if the item cannot be retrieved (hands full, item
# not found, etc.).
#
# @param item [String] item noun (e.g., "sword", "bandages")
# @param container [String, nil] container noun or nil for default
# @return [Boolean] true if item was retrieved successfully
#
# @example Get from default storage
#   DRCI.get_item?("sword")
#
# @example Get from specific container
#   DRCI.get_item?("bandages", "backpack")
#
# @see .put_away_item? Inverse operation
def self.get_item?(item, container = nil)
```

### Internal-Public (Standard Documentation)

A method is **internal-public** if it is public but only called by other
commons modules (not by `.lic` scripts directly).

**Required tags**: summary line, `@param`, `@return`

```ruby
# Stows whatever is in the specified hand using the appropriate verb.
#
# @param hand [String] "right" or "left"
# @return [Boolean] true if hand is now empty
def self.stow_hand?(hand)
```

> **Promotion rule**: If an internal-public method starts being called from
> `.lic` scripts, upgrade its documentation to consumer-facing level as part
> of that change.

### Private (Developer Documentation)

Methods marked `private` or documented with `@api private`.

**Required tags**: summary line, `@param`, `@return`, `@api private`

```ruby
# Retries a stow operation with fallback containers.
#
# @param item [String] item noun
# @param containers [Array<String>] ordered list of containers to try
# @return [Boolean] true if stowed successfully
# @api private
def self.stow_with_fallback(item, containers)
```

### Skip (No Documentation Needed)

The following do not require YARD documentation:

- Trivial one-line delegation methods
- `attr_reader` / `attr_accessor` declarations
- Aliases where the target method is already documented
- Constants with self-evident names and values (e.g., `MAX_RETRIES = 3`)

---

## Tag Reference

### Always Use

| Tag | Format | Notes |
|-----|--------|-------|
| `@param` | `@param name [Type] description` | One per parameter. Type is required. |
| `@return` | `@return [Type] description` | What the method returns. Use `[void]` for no return value. |

### Use When Relevant

| Tag | Format | When |
|-----|--------|------|
| `@example` | Code block follows on next line(s) | Encouraged for consumer-facing methods |
| `@see` | `@see .class_method` or `@see #instance_method` or `@see ClassName` | Cross-reference related methods or constants |
| `@note` | `@note text` | Important caveats or gotchas |
| `@raise` | `@raise [ExceptionType] when...` | Only if the method raises exceptions |
| `@deprecated` | `@deprecated Use {.new_method} instead` | Marks superseded code |
| `@api` | `@api private` | Marks methods that are public but internal |
| `@since` | `@since 5.15.0` | Version a new public API was introduced |

### Method Reference Syntax

YARD uses different prefixes for class methods vs instance methods:

- **`.method_name`** — class/module methods (`def self.method_name`)
- **`#method_name`** — instance methods (`def method_name`)

Most methods in the commons modules are `def self.` class methods. Use `.method_name`
in `@see` tags and `{.method_name}` in inline references.

```ruby
# Class method reference (most commons methods)
# @see .put_away_item?

# Instance method reference (e.g., EquipmentManager instances)
# @see #wield_weapon?

# Inline reference in description text
# Works like {.get_item?} but skips error messaging.
```

### Do Not Use

| Tag | Why |
|-----|-----|
| `@author` | Use `git blame` instead |
| `@version` | Redundant with `@since`; hard to maintain |
| `@todo` | Use GitHub issues instead |
| `@abstract` | Ruby does not have abstract methods |

---

## Type Notation

YARD uses a specific syntax for type annotations.

### Common Types

```ruby
@param name [String]              # simple type
@param count [Integer]            # numeric
@param enabled [Boolean]          # true/false
@param name [String, nil]         # nilable
@param id [String, Integer]       # union
@param items [Array<String>]      # typed array
@param opts [Hash{Symbol => String}]  # typed hash
@return [void]                    # no meaningful return
@return [Boolean]                 # predicate method
@return [self]                    # chainable method
```

### Game-Specific Types

```ruby
@param item [String]               # item noun ("sword", "backpack")
@param item [DRC::Item]            # item object from gear configuration
@param container [String, nil]     # container noun or nil for default
@param pattern [Regexp]            # regex for game output matching
@param patterns [Array<Regexp>]    # array of regex patterns
@param settings [OpenStruct, nil]  # user settings from get_settings
```

---

## Documenting Constants

### Pattern Arrays

Pattern constants (arrays of `Regexp`) should document what strings they match.

```ruby
# Success patterns for the SHEATH verb.
#
# @example Matches
#   "You sheathe your sword in your scabbard."
#   "You slip the dagger into your thigh sheath."
#   "With fluid and stealthy movements you slip the sabre into your harness."
#
# @see SHEATH_ITEM_FAILURE_PATTERNS
# @see .sheath_item?
SHEATH_ITEM_SUCCESS_PATTERNS = [
  /^You sheathe/,
  /^You slip/,
  /^With a flick of your wrist,? you stealthily sheath/,
  /^With fluid and stealthy movements you slip/
].freeze
```

**Recommended**: Use `@see` to cross-reference paired constants (e.g., success
and failure pattern pairs) and the methods that use them.

### Simple Constants

A one-line comment is sufficient.

```ruby
# Maximum retry attempts for stow_helper before giving up.
STOW_HELPER_MAX_RETRIES = 10
```

---

## Documenting Modules and Classes

### Module

```ruby
# Common item manipulation operations for DragonRealms.
#
# DRCI provides low-level, stateless methods for interacting with items
# in the game world: getting, putting, wearing, removing, and querying
# hand contents.
#
# ## Method Categories
#
# - **Retrieval**: {.get_item?}, {.get_item_safe?}
# - **Storage**: {.put_away_item?}, {.stow_item?}, {.tie_item?}
# - **Wearing**: {.wear_item?}, {.remove_item?}
# - **Queries**: {.in_hands?}, {.in_left_hand?}, {.in_right_hand?}
#
# @see EquipmentManager Higher-level gear management
module DRCI
```

### Class

```ruby
# Manages character equipment sets and gear swapping.
#
# Handles wearing, removing, wielding, and tracking gear based on user
# configuration. Maintains state about equipment sets and provides
# methods for combat gear rotation.
#
# @see DRCI Low-level item operations
# @since 5.0.0
class EquipmentManager
```

---

## Tag Order

When multiple tags appear on a method, use this order:

1. `@param` (in parameter order)
2. `@return`
3. `@example`
4. `@note`
5. `@raise`
6. `@see`
7. `@since`
8. `@deprecated`
9. `@api`

```ruby
# Sheaths a weapon into a sheath, scabbard, or harness.
#
# @param item [String] weapon noun
# @param sheath [String, nil] target sheath or nil for default
# @return [Boolean] true if sheathed successfully
#
# @example
#   DRCI.sheath_item?("sword")
#
# @note Returns false if hands are injured or character is immobilized.
#
# @see .wield_item? Inverse operation
# @since 5.15.0
def self.sheath_item?(item, sheath = nil)
```

---

## Anti-Patterns

### Do Not Restate the Obvious

```ruby
# BAD: Restates the method name
# This method gets an item from a container.
#
# @param item [String] The item parameter is a string that represents the item
# @return [Boolean] Returns a boolean indicating whether the operation succeeded

# GOOD: Adds context beyond what the signature tells you
# Gets an item from a container or default storage location.
#
# @param item [String] item noun (e.g., "sword", "bandages")
# @return [Boolean] true if item was retrieved successfully
```

### Do Not Use Prose Where Examples Suffice

```ruby
# BAD: Wall of text
# This method accepts a container name which can include dots for
# disambiguation. The dots are treated as spaces by the game engine
# but not by Ruby string methods, so the method normalizes dots to
# spaces before performing comparisons.

# GOOD: Show it
# @example Dotted noun normalization
#   DRCI.get_item?("small.rucksack", "chest")
#   # Game sees: GET SMALL RUCKSACK IN CHEST
```

### Do Not Document Internals That Change Frequently

```ruby
# BAD: Implementation detail that will go stale
# Uses a three-stage retry with exponential backoff (1s, 2s, 4s)
# and falls back to the default container on the 4th attempt.

# GOOD: Document the contract, not the mechanism
# Retries stowing with fallback containers on failure.
```

---

## Generating Documentation

The repository includes a `.yardopts` file with default settings. To generate
documentation locally:

```bash
# Public API docs (default)
yard doc

# Developer docs including private methods
yard doc --private

# Check documentation coverage
yard stats --list-undoc
```

Output goes to `doc/yard/` which is git-ignored.

---

## Summary

| Question | Answer |
|----------|--------|
| When do I add docs? | When creating or modifying code |
| What's required for public methods? | Summary, `@param`, `@return` |
| Are `@example` blocks required? | Encouraged, not required |
| Do I document private methods? | Summary + types + `@api private` |
| What about trivial helpers? | Skip them |
| How is this enforced? | PR review |
| Do I need `@author`? | No |
| What type format? | `[Type]` with YARD notation |
