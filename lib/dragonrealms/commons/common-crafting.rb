# frozen_string_literal: true

module Lich
  module DragonRealms
    module DRCC
      module_function

      # Pattern constants for bput responses
      LOOK_CRUCIBLE_NOT_FOUND = '^I could not find'
      LOOK_CRUCIBLE_EMPTY = '^There is nothing in there'
      LOOK_CRUCIBLE_SEE_PATTERN = /^In the .* crucible you see (?<items>.*)\./.freeze
      # Splits the LOOK_CRUCIBLE_SEE_PATTERN items list into entries at ", ",
      # ", and " or " and " followed by an article or a bare "molten ", keeping
      # that word. The " and " must be a whole word, so "a gold wand and ..."
      # is not cut.
      LOOK_CRUCIBLE_ITEM_SEPARATOR = /(?:,\s+(?:and\s+)?|\s+and\s+)(?=(?:some|an?|molten)\s)/.freeze
      # Matches one entry of the LOOK_CRUCIBLE_SEE_PATTERN items list.
      LOOK_CRUCIBLE_MOLTEN = /\A(?:(?:some|an?)\s+)?molten\s/.freeze
      EMPTY_CRUCIBLE_MAX_PASSES = 3

      LOOK_ANVIL_NOT_FOUND = '^I could not find'
      LOOK_ANVIL_CLEAN = 'surface looks clean and ready'
      LOOK_ANVIL_SEE_PATTERN = /anvil you see (?<items>.*)\./.freeze

      CLEAN_ANVIL_DRAG = 'You drag the'
      CLEAN_ANVIL_REMOVE = 'remove them yourself'
      GET_ANVIL_SUCCESS = 'You get'
      GET_ANVIL_NOT_YOURS = 'is not yours'
      PUT_BUCKET_SUCCESS = 'You drop'

      BOOK_CHAPTER_TURN_SUCCESS = 'You turn'
      BOOK_CHAPTER_DISTRACTED = 'You are too distracted to be doing that right now'
      BOOK_CHAPTER_ALREADY = 'The .* is already turned'
      BOOK_CHAPTER2_SUCCESS = /^You turn your .* to chapter/
      BOOK_CHAPTER2_ALREADY = /^The .* is already turned to chapter/
      BOOK_PAGE_SUCCESS = /^You turn your .* to page/
      BOOK_PAGE_ALREADY = /^You are already on page/
      BOOK_DISCIPLINE_SUCCESS = /^You turn the .* to the section on/
      BOOK_STUDY_SUCCESS = /^Roundtime/

      BELT_UNTIE_SUCCESS = /^You (remove|untie)/
      BELT_UNTIE_ALREADY = /^You are already/
      BELT_UNTIE_NOT_FOUND = /^Untie what/
      BELT_UNTIE_WOUNDED = /^Your wounds hinder your ability to do that/

      GET_CRAFTING_SUCCESS = /^You get/
      GET_CRAFTING_ALREADY = /^You are already/
      GET_CRAFTING_NOT_FOUND_WHAT = /^What do you/
      GET_CRAFTING_NOT_FOUND_WERE = /^What were you/
      GET_CRAFTING_PICKUP = /^You pick up/
      GET_CRAFTING_HEAVY = /can't quite lift it/
      GET_CRAFTING_TIED = /^You should untie/
      GET_CRAFTING_NO_FREE_HAND = /^You need a free hand/

      # Replies to a GET by a remembered or feed id ("get #<id>") meaning the
      # id names nothing the game can reach any more: the pins were used up
      # and replaced, a stack was combined under a new id, or another script
      # moved or sold the item. The id is forgotten and the GET is sent again
      # by name. Anchored, so another player's speech can't drop an id.
      CRAFTING_ID_GET_MISSING = [
        /^What were you referring to/,
        /^I could not find what you were referring to/,
        /^What do you/
      ].freeze

      # Most crafting item ids DRCC keeps. A crafting script uses a handful
      # of tools and consumables, so this holds every one of several
      # scripts' sets; the oldest goes first.
      CRAFTING_ITEM_IDS_MAX = 32

      # The timeout {DRCC} gives the one Inventory refresh it may send, only
      # when the feed is known to answer but no snapshot is held (a refresh
      # whose paginated exchange stalled after its first part). This is the
      # refresh's own wait for the feed: {Lich::Common::Inventory.refresh}
      # first waits for a refresh another script is running and for
      # roundtime, and neither counts against it, so the GET can wait longer.
      CRAFTING_FEED_REFRESH_TIMEOUT = 2

      # Fewest seconds between two such refreshes, so a feed that keeps
      # stalling costs one short wait per this many seconds, not one per GET.
      CRAFTING_FEED_REFRESH_INTERVAL = 300

      # The ids of crafting items DRCC moved by id, so the next GET of an
      # item from the same bag can go by id. Each id is kept with the bag it
      # went into (the bag reference, normalized) and the noun and name the
      # item had in hand then. A GET finds the one kept item in its bag that
      # its name means by the {DRCI.held_id} rule ({DRCI.item_named?}), so a
      # GET of "pins" finds the pins stowed as "sepia pins" (the shortened
      # hand name {DRC.right_hand} gives, which most crafting scripts stow
      # by). Two kept items the name means give no id. An id is kept once,
      # with its latest bag, noun and name; an item that changed name since
      # (stock turned into the half-made product) is caught by the GET by
      # id, which checks what it put in hand. Bounded (the oldest item is
      # dropped past +max+) and thread-safe: scripts run in their own threads
      # and share this one per Lich process. Also keeps the last +max+ ids
      # found dead ({#dead?}), so an old feed snapshot can't offer one again,
      # and when DRCC may next send its own Inventory refresh
      # ({#feed_refresh_due?}).
      class ItemIdMemo
        # One kept item: its id (without "#"), its noun and name as the hand
        # showed them, and the bag reference it went into.
        Entry = Struct.new(:id, :noun, :name, :bag)

        # @param max [Integer] most items kept, and most dead ids kept
        def initialize(max)
          @max = max
          @entries = {}
          @dead = []
          @lock = Mutex.new
          @feed_refresh_at = nil
        end

        # @param bag [String] bag reference, normalized
        # @param name [String] the name a GET asks for
        # @return [String, nil] the id of the one kept item in +bag+ that
        #   +name+ means; nil for none or more than one
        def fetch(bag, name)
          ids = matching(bag, name)
          ids.size == 1 ? ids.first : nil
        end

        # @param bag [String] bag reference, normalized
        # @param name [String] item name
        # @return [Array<String>] the ids of every kept item in +bag+ that
        #   +name+ means, oldest first
        def matching(bag, name)
          @lock.synchronize { @entries.each_value.select { |entry| entry.bag == bag && DRCI.item_named?(entry, name) }.map(&:id) }
        end

        # Keeps +id+ as the newest item, in +bag+ with +noun+ and +item_name+,
        # replacing what was kept for +id+. With +as+, the other kept items
        # in +bag+ that +as+ means are dropped (not counted dead): the game
        # just gave or took this one for that name, so they are no better
        # guess, and two of them would leave the name with no id for good.
        # The oldest items past the cap go.
        #
        # @param bag [String] bag reference, normalized
        # @param id [String] item id, without "#"
        # @param noun [String, nil] the item's noun
        # @param item_name [String, nil] the item's name
        # @param as [String, nil] the name the caller moved it by
        # @return [void]
        def remember(bag, id, noun:, item_name:, as: nil)
          @lock.synchronize do
            @entries.delete(id)
            @entries.delete_if { |_id, entry| entry.bag == bag && DRCI.item_named?(entry, as) } if as
            @entries[id] = Entry.new(id, noun, item_name, bag).freeze
            @entries.shift while @entries.size > @max
            @dead.delete(id)
          end
        end

        # Drops +id+ and counts it dead: a GET by it found nothing or a
        # different item, or it was disposed of or combined.
        #
        # @param id [String] item id, without "#"
        # @return [void]
        def forget(id)
          @lock.synchronize do
            @entries.delete(id)
            @dead.delete(id)
            @dead.push(id)
            @dead.shift while @dead.size > @max
          end
        end

        # @param id [String] item id, without "#"
        # @return [Boolean] whether +id+ was forgotten and not remembered since
        def dead?(id)
          @lock.synchronize { @dead.include?(id) }
        end

        # Whether DRCC may send an Inventory refresh now. True at most once
        # per +interval+ seconds; a true answer starts the next interval.
        #
        # @param interval [Numeric] seconds between refreshes
        # @return [Boolean]
        def feed_refresh_due?(interval)
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @lock.synchronize do
            next false if @feed_refresh_at && now < @feed_refresh_at

            @feed_refresh_at = now + interval
            true
          end
        end

        # Forgets every item, every dead id and the refresh interval.
        #
        # @return [void]
        def clear
          @lock.synchronize do
            @entries.clear
            @dead.clear
            @feed_refresh_at = nil
          end
        end

        # @return [Integer] items kept
        def size
          @lock.synchronize { @entries.size }
        end
      end

      # The one memo every DRCC caller in this Lich process shares.
      CRAFTING_ITEM_IDS = ItemIdMemo.new(CRAFTING_ITEM_IDS_MAX)

      UNTIE_SUCCESS = /^You (remove|untie)/
      UNTIE_NOT_FOUND = /^Untie what/
      UNTIE_WOUNDED = /^Your wounds hinder your ability to do that/

      TIE_BELT_WOUNDED = UNTIE_WOUNDED

      # The first study of instructions that wear out asks for a second one,
      # on one line that also gives the uses left before this study:
      #   [These instructions have only 5 uses remaining.  Study them again to proceed.]
      # (2026-10-25 game log:10812). The uses part is optional so that a
      # bare "Study them again" prompt (what forge, sew, shape and tinker
      # wait for) still counts as a prompt. The game says "1 uses" for the
      # last use (2026-10-25 game log:30340); the singular "use" is
      # accepted but has not been seen. bput returns the matched text, from
      # which +uses+ is read with this same pattern. No double quote may come
      # before the prompt, so another player's speech, whisper or ESP that
      # quotes it (e.g. Name says, "These instructions have only 1 uses
      # remaining.  Study them again to proceed.") is not taken as the game
      # asking for another study, with its uses count.
      STUDY_INSTRUCTIONS_AGAIN = /^[^"]*?(?:These instructions have only (?<uses>\d+) uses? remaining\.\s+)?Study them again/
      # Ends a completed study: "Roundtime: 7 sec." (2026-10-25 game log:10825).
      STUDY_INSTRUCTIONS_SUCCESS = /^Roundtime/
      # Code-derived, not seen after a study in the logs: the reply to a
      # `<verb> my <name>` that names nothing on the character, as a GET of
      # missing instructions gets (2026-10-26 game log:60708).
      STUDY_INSTRUCTIONS_NOT_FOUND = /^What were you referring to/
      # A study when the game does not see the instructions in hand. "You
      # must be holding the instructions to study them." is the real reply to
      # `study instruc` in a 2026-11 enchanting log (enchant.lic in
      # elanthia-online/dr-scripts#7891 matches it too). "But you're not
      # holding" is code-derived: the logs show it only as the reply to a book
      # command without the book in hand (2026-10-25 game log:10805).
      STUDY_INSTRUCTIONS_NOT_HOLDING = /^(?:But you're not holding|You must be holding the instructions)/
      # Sent after the Roundtime of the study that used the last use, so bput
      # has already returned when it arrives and a Flag has to catch it
      # (2026-10-25 game log:30349 then 30352; same order at
      # 2026-10-25 game log:32936 and 2026-10-26 game log:49540,
      # 58546). Anchored like DRParser's spoof-guarded patterns (StatLine,
      # TDPValue): only tags or whitespace may come before the text, so
      # another player's speech or ESP that quotes it (e.g.
      # Name says, "The instructions have grown so smudged...") does not
      # count as a toss and skip the stow of instructions still in hand.
      STUDY_INSTRUCTIONS_DISCARDED = /^(?:<[^>]*>|\s)*The instructions have grown so smudged and faded from use that you can no longer make them out/
      # Flag that catches STUDY_INSTRUCTIONS_DISCARDED during one study_instructions call.
      STUDY_INSTRUCTIONS_DISCARDED_FLAG = 'drcc-study-instructions-discarded'
      # The uses count in the prompt before the study that uses the last use.
      # Every "1 uses" prompt in the logs is followed by the toss once that
      # study completes (2026-10-25 game log:30340 then 30352, 32923 then
      # 32936; 2026-10-26 game log:49528 then 49540, 58534 then 58546),
      # and no set is tossed without one. A completed study after this count
      # is a toss even when the Flag missed the line, so the instructions are
      # not put away after they are gone.
      STUDY_INSTRUCTIONS_LAST_USE = 1
      # Most studies sent per study_instructions call. The game asks for one
      # more study, once (31 prompts in 62 studies in the 2026-10-25
      # and 2026-10-26 game logs); the third is headroom, not an expected path.
      STUDY_INSTRUCTIONS_MAX_STUDIES = 3

      PUT_BAG_TUCK = 'You tuck'
      PUT_BAG_PUT = 'You put your'
      # Anchored: it leads to the still-held check, so another player saying
      # it before the real PUT reply must not end the wait.
      PUT_BAG_NOT_FOUND = /^What were you referring to/
      # The other not-found reply in DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS.
      PUT_BAG_COULD_NOT_FIND = /^I could not find what you were referring to/
      # "Perhaps you should be holding that first." The PUT found an item by
      # that name that isn't in a hand, e.g. worn "leathers" for "my leather",
      # so the held one was not put away.
      PUT_BAG_NOT_HELD = /^Perhaps you should be holding that first/
      # Kept off quoted text, like the refusals below.
      PUT_BAG_TOO_BIG = /^[^"]*?is too \w+ to (?:fit|hold)/
      # "You just can't get the small brazier to fit in the leather satchel,
      # no matter how you arrange it." (DR enchanting, 2026-11).
      PUT_BAG_WONT_FIT = /^You just can't get .* to fit/
      PUT_BAG_WEIRD = "Weirdly, you can't manage"
      PUT_BAG_NO_ROOM = "There's no room"
      # Further refusals from DRCI::PUT_AWAY_ITEM_FAILURE_PATTERNS, anchored
      # (or kept off quoted text) so another player's speech can't match.
      PUT_BAG_FULL = /^There isn't any more room in/
      PUT_BAG_TOO_HEAVY = /^(?:The|That).* too heavy to go in there/
      PUT_BAG_STUFFED = /^[^"]*?even after stuffing/
      PUT_BAG_COMPLETELY_FULL = /^[^"]*?completely full/
      PUT_BAG_CANT_DO = /^You can't do that/
      PUT_BAG_CANT_THERE = "You can't put that there"
      PUT_BAG_COMBINE = 'You combine'
      # PUT replies that leave the tool in hand; stow_crafting_item falls back
      # to STOW for each.
      PUT_BAG_STOW_INSTEAD = [
        PUT_BAG_TOO_BIG, PUT_BAG_WONT_FIT, PUT_BAG_WEIRD, PUT_BAG_NO_ROOM, PUT_BAG_FULL,
        PUT_BAG_TOO_HEAVY, PUT_BAG_STUFFED, PUT_BAG_COMPLETELY_FULL, PUT_BAG_CANT_DO
      ].freeze

      # Parts that cannot be purchased from crafting shops
      PARTS_CANNOT_PURCHASE = %w[
        sufil blue\ flower muljin belradi dioica hulnik aloe eghmok
        lujeakave yelith cebi blocil hulij nuloe hisan gem pebble
        ring gwethdesuan brazier burin any ingot mechanism
      ].freeze

      REPAIR_SUCCESS = 'Roundtime'
      REPAIR_NOT_NEEDED = 'not damaged enough'
      REPAIR_ENGAGED = 'You cannot do that while engaged!'
      REPAIR_CONFUSED = 'cannot figure out how'
      REPAIR_POUR_WHAT = 'Pour what'

      # Anchored so another player's speech can't start a trip to the shop.
      # The second form is the GET while invisible, from
      # DRCI::GET_ITEM_SUCCESS_PATTERNS ("You fade in for a moment as you ...").
      CONSUMABLE_GET_SUCCESS = /^(?:You get|You fade in for a moment as you)/
      CONSUMABLE_GET_NOT_FOUND = /^What were you referring to/
      # The other not-found reply to GET; also means none are left.
      CONSUMABLE_GET_COULD_NOT_FIND = /^I could not find what you were referring to/
      # "You need a free hand to pick that up." The consumable may still be in
      # the bag, and an order would fail with both hands full.
      CONSUMABLE_GET_NO_FREE_HAND = /^You need a free hand/

      # Replies to check_consumables' GET by a remembered or feed id that
      # leave the consumable in hand: a remembered id reaches the item
      # wherever it is, so it may be picked up from the floor ("You pick
      # up") or be held already, as well as got from the bag. "You are
      # already ..." counts only while the id is in hand; otherwise
      # (e.g. "You are already wearing that.") the id is forgotten and the
      # by-name GET follows ({crafting_get_by_known_id}). "You should
      # untie" (tied to the belt, not in the bag) is a miss instead: the id
      # is forgotten and the by-name GET from the bag follows, as before.
      CONSUMABLE_ID_GET_IN_HAND = [CONSUMABLE_GET_SUCCESS, GET_CRAFTING_PICKUP, GET_CRAFTING_ALREADY].freeze
      COUNT_USES_PATTERN = /(\d+)/.freeze
      COUNT_USES_MESSAGES = [
        'The .* has (\d+) uses remaining',
        'You count out (\d+) yards of material there'
      ].freeze

      ADJUST_TONGS_SHOVEL = 'You lock the tongs'
      ADJUST_TONGS_TONGS = 'With a yank you fold the shovel'
      ADJUST_TONGS_CANNOT = 'You cannot adjust'
      ADJUST_TONGS_UNKNOWN = 'You have no idea how'

      BUNDLE_SUCCESS = 'You notate the'
      BUNDLE_EXPIRED = 'This work order has expired'
      BUNDLE_QUALITY = 'The work order requires items of a higher quality'
      BUNDLE_WRONG_TYPE = "That isn't the correct type of item for this work order."
      BUNDLE_NOT_HOLDING = 'You need to be holding'

      FOUNT_TAP_IN_BAG = /You tap .* inside your .*/
      FOUNT_TAP_ON_BAG = /You tap .*your .*/
      FOUNT_TAP_NOT_FOUND = /I could not find what you were referring to./
      FOUNT_TAP_ON_BRAZIER = /You tap .* atop a .*brazier./
      FOUNT_ANALYZE_PATTERN = /This appears to be a crafting tool and it has approximately (?<uses>\d+) uses remaining/.freeze

      BRAZIER_NOTHING = 'There is nothing on there'
      BRAZIER_SEE_PATTERN = /On the (?:.*)brazier you see (?<items>.*)\./.freeze
      BRAZIER_CLEAN_PREPARE = 'You prepare to clean off the brazier'
      BRAZIER_CLEAN_NOTHING = 'There is nothing'
      BRAZIER_CLEAN_NOT_LIT = 'The brazier is not currently lit'
      BRAZIER_CLEAN_FLAME = 'a massive ball of flame jets forward and singes everything nearby'
      BRAZIER_GET_SUCCESS = 'You get'

      RUMMAGE_NOTHING = /crafting materials but there is nothing in there like that\.$/
      RUMMAGE_CLOSED = /While it\'s closed/
      RUMMAGE_NOT_FOUND = /I don\'t know what you are referring to/
      RUMMAGE_INVISIBLE = /You feel about/
      RUMMAGE_NOTHING_ACCOMPLISH = /That would accomplish nothing/
      RUMMAGE_SUCCESS_PATTERN = /looking for crafting materials and see (?<materials>.*)\.$/

      TAP_CRUCIBLE_NOT_FOUND = 'I could not'
      TAP_CRUCIBLE_SUCCESS = /You tap.*crucible/
      TAP_ANVIL_NOT_FOUND = 'I could not'
      TAP_ANVIL_SUCCESS = /You tap.*anvil/
      TAP_GRINDSTONE_NOT_FOUND = 'I could not'
      TAP_GRINDSTONE_SUCCESS = 'You tap.*grindstone'
      TAP_GRINDER_NOT_FOUND = 'I could not'
      TAP_GRINDER_SUCCESS = 'You tap.*grinder'

      SIGIL_COUNT_NOTHING = 'but there is nothing in there like that'

      # Tilts out molten metal and clears clutter, then looks again, up to
      # EMPTY_CRUCIBLE_MAX_PASSES times. Returns false if it is still not empty.
      # Molten metal is found wherever it appears in the list. Clutter is only
      # disposed of when it was actually picked up from the crucible, and
      # clutter whose noun matches something already in hand (DRCI.in_hands?
      # matches any held word starting with the noun) is left alone, so a held
      # item cannot stand in for clutter that was not picked up. Each held
      # noun is reported once per call, not once per entry or per pass.
      # pass: and warned: are internal recursion state -- callers should not
      # set them.
      def empty_crucible?(pass: 0, warned: [])
        case result = DRC.bput('look in cruc',
                               LOOK_CRUCIBLE_NOT_FOUND,
                               LOOK_CRUCIBLE_EMPTY,
                               LOOK_CRUCIBLE_SEE_PATTERN)
        when /There is nothing in there/i
          true
        when /I could not find/
          false
        when /crucible you see/
          if pass >= EMPTY_CRUCIBLE_MAX_PASSES
            Lich::Messaging.msg('bold', "DRCC: The crucible is still not empty after #{pass} attempts to tilt or clear it.")
            return false
          end

          match = result.match(LOOK_CRUCIBLE_SEE_PATTERN)
          return false unless match

          contents = match[:items]
                     .split(LOOK_CRUCIBLE_ITEM_SEPARATOR)
                     .map(&:strip)
          if contents.any? { |entry| entry.match?(LOOK_CRUCIBLE_MOLTEN) }
            fput('tilt crucible')
            fput('tilt crucible')
          else
            attempted = false
            contents.each do |junk|
              junk = DRC.get_noun(junk)
              next unless junk

              # get_item_unsafe and dispose_trash only check that the noun is in
              # hand, so a held matching item would be the one thrown away.
              if DRCI.in_hands?(junk)
                unless warned.include?(junk)
                  Lich::Messaging.msg('bold', "DRCC: Not clearing the #{junk} from the crucible while you are holding something that matches it.")
                  warned += [junk]
                end
                next
              end

              attempted = true
              # A failed GET leaves nothing in hand, and dispose_trash would
              # then fetch a same-noun item from the player's own containers.
              DRCI.dispose_trash(junk) if DRCI.get_item_unsafe(junk, 'crucible')
            end
            return false unless attempted
          end
          DRCC.empty_crucible?(pass: pass + 1, warned: warned)
        else
          false
        end
      end

      def find_empty_crucible(hometown)
        return if DRC.bput('tap crucible', TAP_CRUCIBLE_NOT_FOUND, TAP_CRUCIBLE_SUCCESS) =~ TAP_CRUCIBLE_SUCCESS && (DRRoom.pcs - DRRoom.group_members).empty? && empty_crucible?

        crucibles = get_data('crafting')['blacksmithing'][hometown]['crucibles']
        idle_room = get_data('crafting')['blacksmithing'][hometown]['idle-room']
        DRCT.find_sorted_empty_room(crucibles, idle_room, proc { (DRRoom.pcs - DRRoom.group_members).empty? && empty_crucible? })
        DRCC.clean_anvil?
      end

      def clean_anvil?
        case result = DRC.bput('look on anvil', LOOK_ANVIL_NOT_FOUND, LOOK_ANVIL_CLEAN, LOOK_ANVIL_SEE_PATTERN)
        when /surface looks clean and ready/i
          true
        when /I could not find/
          false
        when /anvil you see/
          match = result.match(LOOK_ANVIL_SEE_PATTERN)
          return false unless match

          clutter = match[:items].split.last
          case DRC.bput('clean anvil', CLEAN_ANVIL_DRAG, CLEAN_ANVIL_REMOVE)
          when /drag/
            fput('clean anvil')
            pause
            waitrt?
          else
            case DRC.bput("get #{clutter} from anvil", GET_ANVIL_SUCCESS, GET_ANVIL_NOT_YOURS)
            when GET_ANVIL_NOT_YOURS
              fput('clean anvil')
              fput('clean anvil')
            when GET_ANVIL_SUCCESS
              DRC.bput("put #{clutter} in bucket", PUT_BUCKET_SUCCESS)
            else
              return false
            end
          end
          true
        else
          false
        end
      end

      def find_wheel(hometown)
        wheels = get_data('crafting')['tailoring'][hometown]['spinning-rooms']
        idle_room = get_data('crafting')['tailoring'][hometown]['idle-room']
        DRCT.find_sorted_empty_room(wheels, idle_room)
      end

      def find_anvil(hometown)
        return if DRC.bput('tap anvil', TAP_ANVIL_NOT_FOUND, TAP_ANVIL_SUCCESS) =~ TAP_ANVIL_SUCCESS && (DRRoom.pcs - DRRoom.group_members).empty? && clean_anvil?

        anvils = get_data('crafting')['blacksmithing'][hometown]['anvils']
        idle_room = get_data('crafting')['blacksmithing'][hometown]['idle-room']
        DRCT.find_sorted_empty_room(anvils, idle_room, proc { (DRRoom.pcs - DRRoom.group_members).empty? && clean_anvil? })
        DRCC.empty_crucible?
      end

      def find_grindstone(hometown)
        return unless DRC.bput('tap grindstone', TAP_GRINDSTONE_NOT_FOUND, TAP_GRINDSTONE_SUCCESS) == TAP_GRINDSTONE_NOT_FOUND

        grindstones = get_data('crafting')['blacksmithing'][hometown]['grindstones']
        idle_room = get_data('crafting')['blacksmithing'][hometown]['idle-room']
        DRCT.find_sorted_empty_room(grindstones, idle_room)
      end

      def find_sewing_room(hometown, override = nil)
        if override
          DRCT.walk_to(override)
        else
          sewingrooms = get_data('crafting')['tailoring'][hometown]['sewing-rooms']
          idle_room = get_data('crafting')['tailoring'][hometown]['idle-room']
          DRCT.find_sorted_empty_room(sewingrooms, idle_room)
        end
      end

      def find_loom_room(hometown, override = nil)
        if override
          DRCT.walk_to(override)
        else
          loom_rooms = get_data('crafting')['tailoring'][hometown]['loom-rooms']
          idle_room = get_data('crafting')['tailoring'][hometown]['idle-room']
          DRCT.find_sorted_empty_room(loom_rooms, idle_room)
        end
      end

      def find_shaping_room(hometown, override = nil)
        if override
          DRCT.walk_to(override)
        else
          shapingrooms = get_data('crafting')['shaping'][hometown]['shaping-rooms']
          idle_room = get_data('crafting')['shaping'][hometown]['idle-room']
          DRCT.find_sorted_empty_room(shapingrooms, idle_room)
        end
      end

      def find_press_grinder_room(hometown)
        return unless DRC.bput('tap grinder', TAP_GRINDER_NOT_FOUND, TAP_GRINDER_SUCCESS) == TAP_GRINDER_NOT_FOUND

        pressgrinderrooms = get_data('crafting')['remedies'][hometown]['press-grinder-rooms']
        DRCT.walk_to(pressgrinderrooms[0])
      end

      def find_enchanting_room(hometown, override = nil)
        if override
          DRCT.walk_to(override)
        else
          enchanting_rooms = get_data('crafting')['artificing'][hometown]['brazier-rooms']
          idle_room = get_data('crafting')['artificing'][hometown]['idle-room']
          DRCT.find_sorted_empty_room(enchanting_rooms, idle_room, proc { (DRRoom.pcs - DRRoom.group_members).empty? && clean_brazier? })
        end
      end

      # Finds the recipe whose name matches item_name (a case-insensitive
      # regex). A single match, or a single exact-name match, is returned
      # directly. Otherwise the matches are listed as a numbered menu and the
      # user picks one with ;send #. Lines that are not a bare number are
      # ignored (they may be game output); a number outside the menu
      # re-prompts. The chosen recipe is returned by its menu position, so a
      # pick never resolves to a different recipe with a similar or
      # duplicate name.
      #
      # @param recipes [Array<Hash>] recipe entries with at least 'name'
      # @param item_name [String] full or partial recipe name
      # @return [Hash, nil] the chosen recipe, or nil when nothing matches
      def recipe_lookup(recipes, item_name)
        matches = recipes.select { |x| x['name'] =~ /#{item_name}/i }
        case matches.length
        when 0
          Lich::Messaging.msg('bold', "DRCC: No recipe in base-recipes.yaml matches #{item_name}")
          nil
        when 1
          matches.first
        else
          exact_matches = matches.select { |x| x['name'] == item_name }
          return exact_matches.first if exact_matches.length == 1

          # The full-name hint only helps when the full name was not typed and
          # at least one listed name is unique; a name shared by several
          # recipes shows this menu however it is typed.
          if exact_matches.empty? && matches.map { |x| x['name'] }.tally.value?(1)
            Lich::Messaging.msg('bold', "DRCC: Using the full name of the item you wish to craft will avoid this in the future (e.g. 'a metal pike' vs 'metal pike')")
          end
          Lich::Messaging.msg('plain', "DRCC: Please select desired recipe #{$clean_lich_char}send #")
          recipe_menu_labels(matches).each_with_index { |label, i| respond "    #{i + 1}: #{label}" }
          matches[recipe_menu_choice(matches.length) - 1]
        end
      end

      # Menu labels for recipe_lookup. A name that appears more than once is
      # suffixed with its type and chapter so the entries can be told apart,
      # and with its volume too when the type and chapter are also shared.
      # Entries that are still identical after that (a duplicate in the data)
      # are numbered "entry k of n" so every menu line is distinct.
      def recipe_menu_labels(matches)
        name_counts = matches.map { |x| x['name'] }.tally
        place_counts = matches.map { |x| x.values_at('name', 'type', 'chapter') }.tally
        labels = matches.map do |x|
          next x['name'] if name_counts[x['name']] == 1

          details = [x['type'], "chapter #{x['chapter']}"]
          details << "volume #{x['volume']}" if x['volume'] && place_counts[x.values_at('name', 'type', 'chapter')] > 1
          "#{x['name']} (#{details.join(', ')})"
        end
        label_counts = labels.tally
        seen = Hash.new(0)
        labels.map do |label|
          next label if label_counts[label] == 1

          "#{label.delete_suffix(')')}, entry #{seen[label] += 1} of #{label_counts[label]})"
        end
      end

      # Reads lines until one is a bare number from 1 to count and returns it.
      def recipe_menu_choice(count)
        loop do
          line = get.to_s.strip
          next unless line =~ /\A\d+\z/

          choice = line.to_i
          return choice if choice.between?(1, count)

          Lich::Messaging.msg('bold', "DRCC: #{choice} is not on the list. Enter a number from 1 to #{count} with #{$clean_lich_char}send #")
        end
      end

      private_class_method :recipe_menu_labels, :recipe_menu_choice

      def find_recipe(chapter, match_string, book = 'book')
        case DRC.bput("turn my #{book} to chapter #{chapter}", BOOK_CHAPTER_TURN_SUCCESS, BOOK_CHAPTER_DISTRACTED, BOOK_CHAPTER_ALREADY)
        when BOOK_CHAPTER_DISTRACTED
          Lich::Messaging.msg('bold', 'DRCC: Cannot turn book, assuming engaged in combat.')
          fput('look')
          exit
        end

        recipe = DRC.bput("read my #{book}", "Page \\d+:\\s(?:some|a|an)?\\s*#{match_string}").split('Page').find { |x| x =~ /#{match_string}/i }
        match = recipe&.match(/(?<page>\d+):/)
        match&.[](:page)
      end

      def find_recipe2(chapter, match_string, book = 'book', discipline = nil)
        DRC.bput("turn my #{book} to discipline #{discipline}", BOOK_DISCIPLINE_SUCCESS) unless discipline.nil?
        case DRC.bput("turn my #{book} to chapter #{chapter}", BOOK_CHAPTER2_SUCCESS, BOOK_CHAPTER2_ALREADY, BOOK_CHAPTER_DISTRACTED)
        when BOOK_CHAPTER_DISTRACTED
          Lich::Messaging.msg('bold', 'DRCC: Cannot turn book, assuming engaged in combat.')
          fput('look')
          exit
        end

        recipe = DRC.bput("read my #{book}", "Page \\d+:\\s(?:some|a|an)?\\s*#{match_string}").split('Page').find { |x| x =~ /#{match_string}/i }
        match = recipe&.match(/(?<page>\d+):/)
        page = match&.[](:page)
        DRC.bput("turn my #{book} to page #{page}", BOOK_PAGE_SUCCESS, BOOK_PAGE_ALREADY)
        DRC.bput("study my #{book}", BOOK_STUDY_SUCCESS)
      end

      # Puts a crafting tool or material in hand. A tool listed on the
      # crafting belt is untied from it; anything else is fetched with
      # `get my <name>`, from +bag+ when +bag_items+ lists it.
      #
      # The GET names +bag+ by its id when exactly one worn item matches it
      # ({DRCI.worn_ref}), so a held or stowed item of the same noun can't be
      # searched instead; otherwise it says `my <bag>` as before. The item
      # itself is deliberately not looked up with {DRCI.held_id}: when one of
      # +name+ is already in hand, held_id would name that held one, so a call
      # fetching a second one (stock to combine) would GET the item it
      # already holds. (What the game answers a GET of a held item is not
      # verified.)
      #
      # The GET goes by the item's own id, `get #<id>`, when one is known and
      # not in a hand: the one item DRCC last moved in or out of this bag
      # that the name means by the {DRCI.held_id} rule (a PUT or STOW by id
      # in stow_crafting_item, under any name that means it, or a GET here
      # that put one matching item in hand; see {CRAFTING_ITEM_IDS}), else the one item in
      # +bag+ that matches the name in the Inventory feed's snapshot, when
      # the feed is already answering ({DRCI.stored_id}). So `get my pins
      # from my duffel bag` can no longer find a half-made "duffel bag" in
      # hand, or other pins. "What were you referring to?", "I could not find
      # what you were referring to." or "What do you" forgets that id and
      # sends today's by-name GET: one extra command, never a timeout; so
      # does "You are already ..." while the id is not in hand. No id is
      # used while the feed snapshot shows two or more items in +bag+ that
      # the name means: the game picks, as before. Without a snapshot, a
      # remembered id makes a GET of stock or material ("cotton cloth")
      # take the piece DRCC moved last, e.g. an offcut sew stowed. A GET
      # by id that puts in hand an item the name no longer matches forgets
      # the id and puts the item back before the by-name GET. Otherwise
      # `get my <name>` stays as callers send it today. A "#<id>"
      # +name+ (or an Integer id) goes by id: `get #<id>`, and after "You
      # should untie" `untie #<id>`, never `my #<id>`; it gets no belt untie,
      # and the in-hand checks compare ids.
      #
      # When wounds hinder an untie, visits safe-room once and sends that
      # untie once more. The belt untie and the plain untie each get their
      # own visit, so a call that falls from the belt to a GET that says to
      # untie the item can visit safe-room twice, never more. Four failures
      # are final, and no retry follows them:
      # - the item can't be found and isn't already in hand;
      # - the game says it "can't quite lift it";
      # - the GET says to untie the item, the untie finds nothing, and the
      #   item isn't in hand;
      # - wounds still hinder the untie after the safe-room trip, and the
      #   item isn't in hand.
      # Each one beeps and prints a bold line. The method then returns false
      # when +skip_exit+ is set; otherwise it stops the script. A reply that
      # matches nothing (a bput timeout) is not final. A timed-out GET, or a
      # timed-out untie after "You should untie", returns whether the item is
      # in hand, as a late reply may still deliver it; a timed-out belt untie
      # falls back to the GET.
      #
      # @param name [String, Integer] item to put in hand, or "#<id>"; an
      #   Integer is an id
      # @param bag [String, Integer] container that holds +bag_items+, or
      #   "#<id>" (an Integer is an id)
      # @param bag_items [Array<String>, nil] items kept in +bag+
      # @param belt [Hash, nil] crafting belt settings ('name', 'items')
      # @param skip_exit [Boolean] return false on a final failure instead of
      #   stopping the script
      # @return [Boolean] true when the item is in hand (the untie or get
      #   succeeded, or it was already held); false after a final failure
      #   with +skip_exit+, or when a timed-out reply leaves it out of hand
      def get_crafting_item(name, bag, bag_items, belt, skip_exit = false)
        name = crafting_name(name)
        waitrt?
        if belt && !crafting_id_ref?(name) && belt['items'].find { |item| /\b#{name}/i =~ item || /\b#{item}/i =~ name }
          case untie_crafting_item(name, "untie my #{name} from my #{belt['name']}", BELT_UNTIE_WOUNDED, BELT_UNTIE_SUCCESS, BELT_UNTIE_ALREADY, BELT_UNTIE_NOT_FOUND)
          when BELT_UNTIE_SUCCESS, BELT_UNTIE_ALREADY
            return true
          when BELT_UNTIE_WOUNDED
            return true if DRCI.in_hands?(name)

            return crafting_item_failed("DRCC: Your wounds still hinder untying: #{name}", skip_exit)
          end
        end
        before = DRCI.held_ids
        known = crafting_get_by_known_id(name, bag, [GET_CRAFTING_SUCCESS, GET_CRAFTING_PICKUP],
                                         [GET_CRAFTING_ALREADY, GET_CRAFTING_HEAVY, GET_CRAFTING_TIED, GET_CRAFTING_NO_FREE_HAND])
        if known
          result, item = known
        else
          # What the untie and the in-hand checks name it by.
          item = name
          command = "get #{DRCI.item_ref(name.to_s)}"
          command += " from #{crafting_bag_ref(bag)}" if bag_items && bag_items.include?(name)
          result = DRC.bput(command, GET_CRAFTING_SUCCESS, GET_CRAFTING_ALREADY, GET_CRAFTING_NOT_FOUND_WHAT, GET_CRAFTING_NOT_FOUND_WERE, GET_CRAFTING_PICKUP, GET_CRAFTING_HEAVY, GET_CRAFTING_TIED, GET_CRAFTING_NO_FREE_HAND)
        end
        case result
        when GET_CRAFTING_SUCCESS, GET_CRAFTING_ALREADY, GET_CRAFTING_PICKUP
          remember_got_crafting_item(name, bag, before) unless result.match?(GET_CRAFTING_ALREADY)
          true
        when GET_CRAFTING_NOT_FOUND_WHAT, GET_CRAFTING_NOT_FOUND_WERE
          pause 2
          return true if DRCI.in_hands?(name)

          crafting_item_failed("DRCC: You seem to be missing: #{name}", skip_exit)
        when GET_CRAFTING_HEAVY
          # Final: GETting it again won't make it liftable.
          crafting_item_failed("DRCC: You can't quite lift: #{name}", skip_exit)
        when GET_CRAFTING_NO_FREE_HAND
          # Final: GETting it again won't empty a hand.
          crafting_item_failed("DRCC: No free hand to get: #{name}", skip_exit)
        when GET_CRAFTING_TIED
          case untie_crafting_item(name, "untie #{DRCI.item_ref(item.to_s)}", UNTIE_WOUNDED, UNTIE_SUCCESS, UNTIE_NOT_FOUND)
          when UNTIE_SUCCESS
            true
          when UNTIE_WOUNDED
            return true if DRCI.in_hands?(item)

            crafting_item_failed("DRCC: Your wounds still hinder untying: #{name}", skip_exit)
          when UNTIE_NOT_FOUND
            return true if DRCI.in_hands?(item)

            crafting_item_failed("DRCC: Told to untie it, but found nothing to untie: #{name}", skip_exit)
          else
            DRCI.in_hands?(item)
          end
        else
          DRCI.in_hands?(item)
        end
      end

      # Sends an untie for get_crafting_item. When wounds hinder it, visits
      # safe-room once, walks back and sends the untie once more.
      #
      # @param name [String] item being untied
      # @param command [String] the untie command
      # @param wounded [Regexp] the reply meaning wounds hinder the untie
      # @param patterns [Array<Regexp>] the other replies to wait for
      # @return [String] the matched reply ('' on a timeout)
      def untie_crafting_item(name, command, wounded, *patterns)
        result = DRC.bput(command, *patterns, wounded)
        return result unless result.match?(wounded)

        Lich::Messaging.msg('bold', "DRCC: Wounds hinder untying #{name}. Visiting safe-room, then trying once more.")
        craft_room = Room.current.id
        DRC.wait_for_script_to_complete('safe-room', ['force'])
        DRCT.walk_to(craft_room)
        DRC.bput(command, *patterns, wounded)
      end

      # Reports a final get_crafting_item failure: beeps and prints +message+.
      #
      # @param message [String] bold line naming the failure
      # @param skip_exit [Boolean] return instead of stopping the script
      # @return [false] when +skip_exit+; otherwise stops the script
      def crafting_item_failed(message, skip_exit)
        DRC.beep
        Lich::Messaging.msg('bold', message)
        return false if skip_exit

        Lich::Messaging.msg('bold', 'DRCC: Cannot continue crafting without required item. Stopping script.')
        exit
      end

      # Internal to get_crafting_item; kept off the public DRCC API.
      private_class_method :untie_crafting_item, :crafting_item_failed

      # The item name the crafting methods work with: an Integer id becomes
      # "#<id>", and a "#<id>" String loses surrounding whitespace (so
      # " #123" is the id and never "my  #123"). Other names are returned
      # unchanged, as these methods always sent them.
      #
      # @param name [String, Integer, nil] item name or id
      # @return [String, nil]
      def crafting_name(name)
        return "##{name}" if name.is_a?(Integer)
        return name.strip if name.is_a?(String) && name.strip.start_with?('#')

        name
      end

      # Whether a crafting item name is an id reference ("#<id>"). Such a
      # name is never looked up on the crafting belt, and never gets "my ".
      #
      # @param name [String, nil] item name, already passed through
      #   {crafting_name}
      # @return [Boolean]
      def crafting_id_ref?(name)
        name.is_a?(String) && name.start_with?('#')
      end

      # How a crafting command names +bag+: "#<id>" when exactly one worn
      # item matches it ({DRCI.worn_ref}), otherwise the "my <bag>" these
      # methods always sent (a nil bag still gives "my ").
      #
      # @param bag [String, Integer, nil] container name
      # @return [String]
      def crafting_bag_ref(bag)
        bag.nil? ? 'my ' : DRCI.worn_ref(bag)
      end

      # How a crafting command names an item it expects in hand: "#<id>" when
      # +name+ means exactly one held item ({DRCI.held_id}), otherwise
      # {DRCI.item_ref} ("my <name>"; a "#<id>" name unchanged). Two held
      # matches, none, or a name starting with an ordinal or "other" give
      # the name, as before.
      #
      # @param name [String, nil] item name; nil names no held item (held_id
      #   would take it for "any") and gives "my ", as "my #{nil}" did
      # @return [String] "#<id>", or {DRCI.item_ref}(name)
      def crafting_held_ref(name)
        id = DRCI.held_id(name.to_s)
        id ? "##{id}" : DRCI.item_ref(name.to_s)
      end

      # Whether +bag+ is given as an id ("#<id>" or an Integer) rather than a
      # name. Such a bag has no "other" one to fall back to.
      #
      # @param bag [String, Integer, nil] container name or id
      # @return [Boolean]
      def crafting_id_bag?(bag)
        bag.is_a?(Integer) || bag.to_s.strip.start_with?('#')
      end

      # A name for the held item whose id is +ref+ ("#<id>"), so a worn-out
      # consumable named by id can be replaced by name: the first word of
      # its name before its GameObj noun ("stiff wire brush" gives "stiff
      # brush"), or the noun alone when the name is one word or starts with
      # the noun ("bucket of viscous gloop" gives "bucket"). The adjective
      # keeps the replacing GET off another item with the same noun (a
      # "sanding brush"); a bare noun has no such guard, so that GET can
      # pick up any item with the noun. The noun comes from the GameObj,
      # never from the end of the name, which need not be the noun ("bone
      # saw with a blade edged in audrualm" gives "bone saw"). Reads the
      # GameObj hands only.
      #
      # @param ref [String] "#<id>"
      # @return [String, nil] "<first word> <noun>" or the noun; nil when no
      #   hand holds that id or it has no noun
      def crafting_held_name(ref)
        obj = crafting_hand_obj(ref)
        return nil unless obj

        noun = obj.noun.to_s.strip
        return nil if noun.empty?

        words = obj.name.to_s.split
        words.size < 2 || words.first.casecmp?(noun) ? noun : "#{words.first} #{noun}"
      end
      private_class_method :crafting_name, :crafting_id_ref?, :crafting_bag_ref, :crafting_held_ref, :crafting_id_bag?, :crafting_held_name

      # The memo bag for a GET or PUT of +name+ in +bag+: the bag as the
      # crafting commands name it ({crafting_bag_ref}), stripped and
      # downcased, so a bag named and the same bag given as an id share it.
      # A "#<id>" name (it already goes by id), an ordinal or "other" first
      # word (they pick one of several by the game's ordering), or an empty
      # or non-String name has none.
      #
      # @param name [String, nil] item name, already through {crafting_name}
      # @param bag [String, Integer, nil] crafting container
      # @return [String, nil]
      def crafting_memo_bag(name, bag)
        return nil unless name.is_a?(String)

        words = name.strip.downcase.sub(/\Amy\s+/, '').split
        return nil if words.empty? || words.first.start_with?('#')
        return nil if DRCI::HELD_REF_ORDINAL_WORDS.include?(words.first) || Array($ORDINALS).include?(words.first)

        crafting_bag_ref(bag).to_s.strip.downcase
      end

      # The id a GET of +name+ from +bag+ can go by: the one item DRCC last
      # moved in or out of +bag+ that +name+ means ({CRAFTING_ITEM_IDS}),
      # else the one item in +bag+ the Inventory feed says +name+ means
      # ({crafting_feed_ids}), unless DRCC found that id dead since
      # ({ItemIdMemo#dead?}). An id already in a hand is never given (the
      # caller wants another one, and a GET of a held item stays by name).
      #
      # When the feed snapshot already held shows the game a choice (two or
      # more items in +bag+ that +name+ means, not counting held or dead
      # ids), no id is given, not even a remembered one: the by-name GET
      # lets the game pick, as before. This keeps a material GET ("cotton
      # cloth") from always taking the piece DRCC moved last, such as an
      # offcut. Without a snapshot the memo can't see a choice, and a
      # remembered id is the piece moved last.
      #
      # Sends no game command, except the one feed refresh
      # {crafting_feed_ids} may send when nothing is remembered.
      #
      # @param name [String, nil] item name, already through {crafting_name}
      # @param bag [String, Integer, nil] crafting container
      # @return [String, nil] the id, without "#"
      def crafting_known_id(name, bag)
        memo_bag = crafting_memo_bag(name, bag)
        return nil unless memo_bag

        held = DRCI.held_ids
        usable = ->(ids) { ids.reject { |id| held.include?(id) || CRAFTING_ITEM_IDS.dead?(id) } }
        id = CRAFTING_ITEM_IDS.fetch(memo_bag, name)
        if id && !held.include?(id)
          # A remembered id sends no refresh: only a snapshot already held.
          return usable.call(crafting_feed_ids(name, memo_bag, refresh: false)).size > 1 ? nil : id
        end

        ids = usable.call(crafting_feed_ids(name, memo_bag, refresh: true))
        ids.size == 1 ? ids.first : nil
      end

      # The ids of the items directly in the crafting bag that +name+ means,
      # from the Inventory feed ({DRCI.stored_ids}). Only when the feed is
      # already known to answer ({Lich::Common::Inventory.feed_available?}):
      # it reads the snapshot already held, and with +refresh+ sends one
      # short refresh when there is none, at most once per
      # {CRAFTING_FEED_REFRESH_INTERVAL}. A bag not named by id (no single
      # worn match) has nothing to look in. A script interruption
      # ({Lich::Common::ScriptExecutionGuard::Interrupted}) raised by the
      # refresh is raised on; any other error gives [].
      #
      # @param name [String] item name
      # @param bag_ref [String] the bag as {crafting_bag_ref} names it
      # @param refresh [Boolean] whether a missing snapshot may be refreshed
      # @return [Array<String>] the ids, without "#"; [] when unknown
      def crafting_feed_ids(name, bag_ref, refresh:)
        bag_id = bag_ref[DRCI::ITEM_ID_REF_PATTERN, 1]
        return [] unless bag_id && defined?(Lich::Common::Inventory)

        inventory = Lich::Common::Inventory
        return [] unless inventory.feed_available?

        snapshot = inventory.current
        snapshot = inventory.refresh(timeout: CRAFTING_FEED_REFRESH_TIMEOUT) if snapshot.nil? && refresh && CRAFTING_ITEM_IDS.feed_refresh_due?(CRAFTING_FEED_REFRESH_INTERVAL)
        DRCI.stored_ids(name, bag_id, snapshot: snapshot)
      rescue StandardError => e
        raise if crafting_interrupted?(e)

        Lich.log("DRCC: Inventory feed lookup for #{name} failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
        []
      end

      # Whether +error+ is a script interruption, which must reach the
      # script, not be taken for a failed lookup.
      #
      # @param error [StandardError]
      # @return [Boolean]
      def crafting_interrupted?(error)
        defined?(Lich::Common::ScriptExecutionGuard::Interrupted) ? error.is_a?(Lich::Common::ScriptExecutionGuard::Interrupted) : false
      end

      # GETs +name+ by a known id ({crafting_known_id}) instead of by name.
      # Replies in {CRAFTING_ID_GET_MISSING} or +misses+ forget the id and
      # give nil, so the caller sends its by-name GET: one extra command.
      # So does a "You are already ..." reply ({GET_CRAFTING_ALREADY}) while
      # the id is not in a hand: a known id is never a held one, so the
      # reply can't mean the item is held (e.g. "You are already wearing
      # that.": the id names a worn item, not the one in the bag). A
      # GET that works but puts in hand an item +name+ no longer means (the
      # id now names a different item) forgets the id, puts that item back
      # in +bag+ (STOW without a bag) and gives nil too.
      #
      # @param name [String] item name, already through {crafting_name}
      # @param bag [String, Integer, nil] crafting container
      # @param successes [Array<Regexp>] replies meaning the item is in hand
      # @param others [Array<Regexp>] the caller's other replies to wait for
      # @param misses [Array<Regexp>] more replies meaning the id is no use
      #   to this caller (e.g. "You should untie" for a GET from the bag)
      # @return [Array(String, String), nil] the reply and "#<id>"; nil when
      #   no id is known, or it missed
      def crafting_get_by_known_id(name, bag, successes, others, misses: [])
        id = crafting_known_id(name, bag)
        return nil unless id

        ref = "##{id}"
        missed = CRAFTING_ID_GET_MISSING + misses
        result = DRC.bput("get #{ref}", *successes, *others, *missed)
        if missed.any? { |pattern| result.match?(pattern) } || (result.match?(GET_CRAFTING_ALREADY) && !DRCI.in_hand?(ref))
          CRAFTING_ITEM_IDS.forget(id)
          return nil
        end
        return [result, ref] unless successes.any? { |pattern| result.match?(pattern) } && DRCI.in_hand?(ref)
        return [result, ref] if DRCI.held_id(name, except: DRCI.held_ids - [id]) == id

        CRAFTING_ITEM_IDS.forget(id)
        put_back = bag.nil? ? DRCI.put_away_item?(ref) : DRCI.put_away_item?(ref, crafting_bag_ref(bag))
        Lich::Messaging.msg('bold', "DRCC: #{ref} is no longer #{name}. #{put_back ? 'Put it back' : 'Could not put it back'}; getting #{name} by name.")
        nil
      end

      # Remembers the id of the +name+ a GET just put in hand: the one held
      # item matching +name+ that was not held before.
      #
      # @param name [String] item name, already through {crafting_name}
      # @param bag [String, Integer, nil] crafting container
      # @param before [Array<String>] {DRCI.held_ids} before the GET
      # @return [String, nil] that id, without "#"; nil when no single new
      #   held item matches +name+
      def remember_got_crafting_item(name, bag, before)
        id = DRCI.held_id(name, except: before)
        remember_crafting_id(name, bag, crafting_hand_obj("##{id}")) if id
        id
      end

      # Remembers the item +obj+ (a hand GameObj, read while it was held) as
      # moved by +name+ in or out of +bag+, with the noun and name it had, so
      # any name that means it ({DRCI.item_named?}) finds it: the "pins" a
      # GET asks for find the "sepia pins" a script stowed. Nothing when
      # +name+ has no memo bag ({crafting_memo_bag}) or +obj+ has no id.
      #
      # @param name [String] the name the caller moved it by
      # @param bag [String, Integer, nil] crafting container
      # @param obj [GameObj, nil] the item, as it was in hand
      # @return [void]
      def remember_crafting_id(name, bag, obj)
        memo_bag = crafting_memo_bag(name, bag)
        id = obj&.id.to_s
        return if memo_bag.nil? || id.empty?

        CRAFTING_ITEM_IDS.remember(memo_bag, id, noun: obj.noun.to_s, item_name: obj.name.to_s, as: name)
      end

      # The hand GameObj whose id is +ref+ ("#<id>"). Reads the GameObj
      # hands only.
      #
      # @param ref [String] "#<id>"
      # @return [GameObj, nil] nil when no hand holds that id
      def crafting_hand_obj(ref)
        [GameObj.right_hand, GameObj.left_hand].find { |hand| hand&.id && "##{hand.id}" == ref }
      end

      # Forgets the ids a PUT that answered "You combine" made dead: a
      # combined stack comes back under a new id, neither input's (seen in
      # game, 2026-11-05). So the id put (+item+, when it is "#<id>") and
      # every kept item in +bag+ that +name+ means (the stack it joined is
      # most likely one of them) go.
      #
      # @param name [String] item name
      # @param bag [String, Integer, nil] crafting container
      # @param item [String] how the PUT named the item: "#<id>" or a name
      # @return [void]
      def forget_combined_crafting_ids(name, bag, item)
        CRAFTING_ITEM_IDS.forget(item.delete_prefix('#')) if crafting_id_ref?(item)
        memo_bag = crafting_memo_bag(name, bag)
        CRAFTING_ITEM_IDS.matching(memo_bag, name).each { |id| CRAFTING_ITEM_IDS.forget(id) } if memo_bag
      end
      private_class_method :crafting_memo_bag, :crafting_known_id, :crafting_feed_ids, :crafting_interrupted?, :crafting_get_by_known_id,
                           :remember_got_crafting_item, :remember_crafting_id, :crafting_hand_obj, :forget_combined_crafting_ids

      # Puts a crafting tool away: ties it to the crafting belt when the belt
      # lists it, otherwise (or when the tie fails) puts it in +bag+. A bag
      # that won't take it falls back to STOW.
      #
      # The belt tie goes by name, as before. The PUT, the STOW fallback and
      # the other-bag PUT name the tool by its id when +name+ means exactly
      # one held item ({DRCI.held_id}: noun equal to the name's
      # {DRC.get_noun} noun, so "leather" is a held "rat-pelt leather" and
      # never worn "sinuous leathers"), and +bag+ by its id when exactly one
      # worn item matches it ({DRCI.worn_ref}). No match, two matches, or an
      # ordinal or "other" name sends `put my <name> in my <bag>` as before.
      # A "#<id>" +name+ (or an Integer id) skips the belt and is sent as
      # "#<id>", never "my #<id>". A +bag+ given as an id gets no "my other"
      # fallback.
      #
      # A PUT by id that the bag takes ("You put", "You tuck"), or a STOW
      # fallback by id that works, remembers the id in +bag+ with the noun
      # and name the item had in hand ({CRAFTING_ITEM_IDS}), so the next
      # get_crafting_item or check_consumables of any name that means it
      # GETs it by id: "pins" after a stow of "sepia pins" ({DRC.right_hand}).
      # "You combine" forgets that id and every kept item in +bag+ that
      # +name+ means instead: the combined stack comes back under a new id.
      #
      # @param name [String, Integer, nil] tool noun, or "#<id>"; an Integer
      #   is an id; nil sends nothing
      # @param bag [String, Integer] container noun for tools off the belt,
      #   or "#<id>" (an Integer is an id)
      # @param belt [Hash, nil] crafting belt settings ('name', 'items')
      # @return [Boolean, nil] nil without a +name+. false when the tool is
      #   still in a hand after the PUT and any STOW fallback: the PUT got
      #   "Perhaps you should be holding that first." (it matched an item
      #   that isn't held), a not-found reply, or no reply, or +bag+ refused
      #   the tool and the STOW failed too. Also false when +bag+ answers
      #   "You can't put that there" and the tool goes to the other +bag+
      #   (for a +bag+ given by id: when the tool is still in a hand).
      #   true otherwise, including a not-found reply or a timeout with no
      #   matching item in either hand (nothing left to put away).
      def stow_crafting_item(name, bag, belt)
        return unless name

        name = crafting_name(name)
        waitrt?
        if belt && !crafting_id_ref?(name) && belt['items'].find { |item| /\b#{name}/i =~ item || /\b#{item}/i =~ name }
          return true if tie_to_crafting_belt?(name, belt)

          # Not tied: wounds outlasted the safe-room trip, or the reply was a
          # refusal that retrying won't clear. Put the tool in the bag instead;
          # get_crafting_item's `get my <name>` finds it there.
          Lich::Messaging.msg('bold', "DRCC: Failed to tie #{name} to #{belt['name']}. Stowing it off the belt instead.")
        end

        item = crafting_held_ref(name)
        # What STOW and the still-held check name it by: the id when the PUT
        # went by id, else the plain name, as before.
        tool = crafting_id_ref?(item) ? item : name
        # The item as it is in hand now, for the memo: gone from the hands
        # once the PUT works.
        held_obj = crafting_id_ref?(item) ? crafting_hand_obj(item) : nil
        result = DRC.bput("put #{item} in #{crafting_bag_ref(bag)}", PUT_BAG_TUCK, PUT_BAG_PUT, PUT_BAG_NOT_FOUND, PUT_BAG_COULD_NOT_FIND, PUT_BAG_NOT_HELD,
                          *PUT_BAG_STOW_INSTEAD, PUT_BAG_CANT_THERE, PUT_BAG_COMBINE)
        case result
        when *PUT_BAG_STOW_INSTEAD
          if DRCI.stow_item?(tool)
            # Stowed elsewhere, but the id still names it: a GET by id finds
            # it where a GET from +bag+ by name would not.
            remember_crafting_id(name, bag, held_obj)
            return true
          end

          failure = "#{bag} would not take #{name}, and stowing it failed too."
        when PUT_BAG_CANT_THERE
          # A bag given by id has no "other" one: "my other #<id>" names
          # nothing. The hands then say whether the tool is still out.
          if crafting_id_bag?(bag)
            failure = "#{bag} would not take #{name}."
          else
            # "other" picks the bag by the game's ordering, so it stays a name.
            fput("put #{item} in my other #{bag}")
            return false
          end
        when PUT_BAG_NOT_FOUND, PUT_BAG_COULD_NOT_FIND, PUT_BAG_NOT_HELD, ''
          failure = "Could not put #{name} in #{bag}."
        else
          if result.include?(PUT_BAG_COMBINE)
            forget_combined_crafting_ids(name, bag, item)
          else
            remember_crafting_id(name, bag, held_obj)
          end
          return true
        end
        # A failed PUT or STOW leaves the hands as they were, so they say
        # whether anything is left to put away.
        return true unless DRCI.in_hands?(tool)

        Lich::Messaging.msg('bold', "DRCC: #{failure} It is still in your hands.")
        false
      end

      # Ties a crafting tool to the belt. When wounds hinder the tie, visits
      # safe-room once and tries once more; any other reply is final.
      #
      # @param name [String] tool noun, as passed to stow_crafting_item
      # @param belt [Hash] crafting belt settings ('name' is tied to)
      # @return [Boolean] true if the tool is tied (or was already tied off)
      def tie_to_crafting_belt?(name, belt)
        command = "tie my #{name} to my #{belt['name']}"
        patterns = [DRCI::TIE_ITEM_SUCCESS_PATTERNS, DRCI::TIE_ITEM_EMPTY_PATTERN, DRCI::TIE_ITEM_FAILURE_PATTERNS]
        result = DRC.bput(command, *patterns)
        if result.match?(TIE_BELT_WOUNDED)
          Lich::Messaging.msg('bold', "DRCC: Wounds hinder tying #{name} to #{belt['name']}. Visiting safe-room, then trying once more.")
          craft_room = Room.current.id
          DRC.wait_for_script_to_complete('safe-room', ['force'])
          DRCT.walk_to(craft_room)
          result = DRC.bput(command, *patterns)
        end
        DRCI::TIE_ITEM_SUCCESS_PATTERNS.any? { |pattern| result.match?(pattern) }
      end
      private_class_method :tie_to_crafting_belt?

      # What one study_instructions call did.
      #
      # @!attribute [r] studied
      #   @return [Boolean] true when a study ended in Roundtime, so the
      #     design is learned and crafting can start
      # @!attribute [r] uses_left
      #   @return [Integer, nil] uses the instructions have after this call:
      #     0 when they were tossed; the game's count minus one after a
      #     completed study (its count is taken before the study uses one:
      #     5 at 2026-10-25 game log:10812, 4 on the next set at 11657,
      #     and "1 uses" is followed by the toss at 30340/30352); the game's
      #     count when the study did not complete; nil when the game gave no
      #     count (instructions that do not wear out, or a failure first)
      # @!attribute [r] discarded
      #   @return [Boolean] true when the game tossed the worn-out
      #     instructions away after the study: the Flag caught the toss line,
      #     or the study that completed followed a "1 uses" prompt
      #     (STUDY_INSTRUCTIONS_LAST_USE)
      #
      # There is no stow field: stow_crafting_item answers true for a PUT that
      # timed out or got "What were you referring to?" when no instructions
      # are in a hand, so it cannot tell whether they were put away, and no
      # caller reads it.
      StudyInstructionsResult = Data.define(:studied, :uses_left, :discarded) do
        # @return [Boolean] see #studied
        def studied?
          studied
        end

        # @return [Boolean] see #discarded
        def discarded?
          discarded
        end
      end

      # Gets crafting instructions, studies them until the game is ready to
      # craft, and puts them away again unless the game tossed them.
      #
      # Steps:
      # 1. get_crafting_item(+name+, +bag+, +bag_items+, +belt+, +skip_exit+).
      # 2. `study my <name>`, by full name so a second set of instructions or
      #    another "instructions" item cannot answer it. A "Study them again"
      #    prompt sends it again, up to STUDY_INSTRUCTIONS_MAX_STUDIES studies
      #    in all; the prompt's uses count is kept for +uses_left+.
      # 3. Waits out the study's roundtime, then checks a Flag for
      #    STUDY_INSTRUCTIONS_DISCARDED, which arrives after the Roundtime line
      #    bput returned on. A completed study after a "1 uses" prompt counts
      #    as a toss even if the Flag missed the line.
      # 4. stow_crafting_item(+name+, +bag+, +belt+), unless the instructions
      #    were tossed. A study that says they are not there or not in hand
      #    still comes after a GET that got them, so they are put away too; if
      #    they really are gone, the PUT only gets "What were you referring
      #    to?" (2026-10-25 game log:30361).
      #
      # A study that does not end in Roundtime (not found, not holding, a
      # timeout, or still "Study them again" after the last study) is a final
      # failure: it beeps, prints a bold line and stops the script, or returns
      # with +studied+ false when +skip_exit+ is set. The instructions are put
      # away first, so a stop does not leave them in hand. A GET that fails
      # without stopping (its timeout, or any final failure with +skip_exit+)
      # returns +studied+ false; without +skip_exit+ the timeout also stops the
      # script, since crafting cannot start without the design.
      #
      # @param name [String] the instructions, as `get my`/`study my` take
      #   them, e.g. "liniment instructions"
      # @param bag [String] container that holds +bag_items+ and takes the
      #   instructions back
      # @param bag_items [Array<String>, nil] items kept in +bag+
      # @param belt [Hash, nil] crafting belt settings ('name', 'items')
      # @param skip_exit [Boolean] return a result on a final failure instead
      #   of stopping the script
      # @return [StudyInstructionsResult]
      # @raise [ArgumentError] when +name+ is nil or blank, before any command
      #   is sent (a blank name would GET or untie nothing in particular)
      #
      # @example Prepare a remedy from instructions
      #   result = DRCC.study_instructions('liniment instructions', bag, bag_items, belt)
      #   DRC.message('Last use of these instructions.') if result.discarded?
      def study_instructions(name, bag, bag_items, belt, skip_exit = false)
        raise ArgumentError, 'DRCC.study_instructions needs the name of the instructions' if name.to_s.strip.empty?

        unless get_crafting_item(name, bag, bag_items, belt, skip_exit)
          # A final GET failure has already reported (and without skip_exit
          # stopped); only a timed-out GET is left to report here.
          crafting_item_failed("DRCC: Could not get #{name} to study.", skip_exit) unless skip_exit
          return StudyInstructionsResult.new(studied: false, uses_left: nil, discarded: false)
        end

        outcome, uses, discarded = study_held_instructions(name)
        studied = outcome == :studied
        stow_crafting_item(name, bag, belt) unless discarded
        crafting_item_failed(study_instructions_failure(outcome, name), skip_exit) unless studied
        StudyInstructionsResult.new(
          studied: studied,
          uses_left: discarded ? 0 : instructions_uses_left(uses, studied),
          discarded: discarded
        )
      end

      # Sends `study my <name>` until a reply other than "Study them again",
      # or STUDY_INSTRUCTIONS_MAX_STUDIES studies, then waits out roundtime
      # and reads the discard Flag. The Flag is added before the first study
      # and deleted on the way out, however the method leaves. A completed
      # study after a STUDY_INSTRUCTIONS_LAST_USE count is a toss too, so a
      # toss line that arrives after waitrt? cannot lead to a stow of
      # instructions that are gone.
      #
      # @param name [String] the instructions, as study_instructions got them
      # @return [Array(Symbol, Integer, Boolean)] the outcome (:studied, :again,
      #   :not_found, :not_holding or :timeout), the last uses count the game
      #   gave (nil if none), and whether the instructions were tossed
      def study_held_instructions(name)
        Flags.add(STUDY_INSTRUCTIONS_DISCARDED_FLAG, STUDY_INSTRUCTIONS_DISCARDED)
        outcome = :again
        uses = nil
        STUDY_INSTRUCTIONS_MAX_STUDIES.times do
          reply = DRC.bput("study my #{name}", STUDY_INSTRUCTIONS_AGAIN, STUDY_INSTRUCTIONS_SUCCESS, STUDY_INSTRUCTIONS_NOT_FOUND, STUDY_INSTRUCTIONS_NOT_HOLDING)
          outcome = study_instructions_outcome(reply)
          break unless outcome == :again

          uses = reply[STUDY_INSTRUCTIONS_AGAIN, :uses]&.to_i || uses
        end
        waitrt?
        tossed = Flags[STUDY_INSTRUCTIONS_DISCARDED_FLAG] || (outcome == :studied && uses == STUDY_INSTRUCTIONS_LAST_USE)
        [outcome, uses, tossed ? true : false]
      ensure
        Flags.delete(STUDY_INSTRUCTIONS_DISCARDED_FLAG)
      end

      # Classifies one study reply.
      #
      # @param reply [String] text bput matched ('' on a timeout)
      # @return [Symbol] :again, :studied, :not_found, :not_holding or :timeout
      def study_instructions_outcome(reply)
        case reply
        when STUDY_INSTRUCTIONS_AGAIN then :again
        when STUDY_INSTRUCTIONS_SUCCESS then :studied
        when STUDY_INSTRUCTIONS_NOT_FOUND then :not_found
        when STUDY_INSTRUCTIONS_NOT_HOLDING then :not_holding
        else :timeout
        end
      end

      # The bold line for a study that did not end in Roundtime.
      #
      # @param outcome [Symbol] a study_instructions_outcome other than :studied
      # @param name [String] the instructions
      # @return [String]
      def study_instructions_failure(outcome, name)
        case outcome
        when :again then "DRCC: Still told to study #{name} again after #{STUDY_INSTRUCTIONS_MAX_STUDIES} studies."
        when :not_found then "DRCC: Could not find #{name} to study."
        when :not_holding then "DRCC: Not holding #{name} to study."
        else "DRCC: No reply to studying #{name}."
        end
      end

      # Uses left after a study_instructions call that kept the instructions.
      #
      # @param uses [Integer, nil] the game's count, taken before the study
      # @param studied [Boolean] whether the study completed (and so used one)
      # @return [Integer, nil] nil when the game gave no count
      def instructions_uses_left(uses, studied)
        return nil unless uses

        studied ? uses - 1 : uses
      end

      # Internal to study_instructions; kept off the public DRCC API.
      private_class_method :study_held_instructions, :study_instructions_outcome,
                           :study_instructions_failure, :instructions_uses_left

      def crafting_cost(recipe, hometown, parts, quantity, material)
        # To use this method, you'll need to pass:
        # recipe => This is a hash drawn directly from base-recipes eg {name: 'a metal ring cap', noun: 'cap', volume: 8, type: 'armorsmithing',etc}
        #     This is fetched via get_data('recipes').crafting_recipes('name')[<name of recipe>]
        # hometown => Just a string eg "Crossing"
        # parts => This is an array containing(if any) a list of parts required. Where base-recipes doesn't do this, you will need to format this.
        # quantity => an integer representing how many of each finished craft you intend to make. You can call this once per item, or once for all items.
        # material => This needs to be a hash drawn directly from base-crafting eg {stock-volume: 5, stock-number: 11, stock-name: 'bronze', stock-value: 562}
        #     This is fetched via get_data('crafting')['stock'][<name of material>]
        #     nil or false if not using stock materials

        currency = DRCM.town_currency(hometown)
        data = get_data('crafting')['stock'] # fetch parts data
        total = 0

        if material && %w[alabaster granite marble].any? { |x| material['stock-name'] == x } # stone isn't stackable, so just calculate stock*quantity
          total += material['stock-value'] * quantity
        elsif material # neither alchemy nor artificing have ONE stock material, they take various materials and combine them, so those are handled by parts below
          stock_to_order = ((recipe['volume'] / material['stock-volume'].to_f) * quantity).ceil
          total += (stock_to_order * material['stock-value'])
        end

        if parts
          parts_to_price = parts.reject { |part| PARTS_CANNOT_PURCHASE.include?(part) } # excludes things you cannot purchase, so won't error if you've got these.
          parts_to_price.each { |part| total += data[part]['stock-value'] * quantity } # adds the cost of each purchasable part to the total
        end

        total += 1000 # added to account for consumables, water, coal, etc

        case currency
        when 'kronars'
          total
        when 'lirums'
          (total * 0.800).ceil
        when 'dokoras'
          (total * 0.7216).ceil
        else
          total
        end
      end

      # Repairs each tool with a wire brush and oil, stowing every item it takes out.
      # Stops at the first engaged reply and leaves the remaining tools for later.
      #
      # @return [Symbol, nil] :engaged when repairs stopped because the character is engaged; nil otherwise
      def repair_own_tools(info, tools, bag, bag_items, belt)
        UserVars.immune_list ||= {} # declaring a hash unless hash already
        tools = tools.to_a # Convert single tool string to array
        UserVars.immune_list.reject! { |_k, v| v < Time.now } # removing anything from the immune list that has an expired timer
        tools.reject! { |x| UserVars.immune_list[x] } # removing tools from the list of eligible repairs if they're still on the immune list
        return unless tools.size > 0 # skips the whole method if no tools are eligible for repairs

        DRCC.check_consumables('oil', info['finisher-room'], info['finisher-number'], bag, bag_items, belt, tools.size) # checks intelligently for enough oil uses to repair the number of tools eligible for repair
        DRCC.check_consumables('wire brush', info['finisher-room'], info['wire-brush-number'] || 10, bag, bag_items, belt, tools.size) # checks intelligently for enough brush uses to repair the number of tools eligible for repair
        repair_tool = ['wire brush', 'oil']
        tools.each do |tool_name| # begins repair cycle for each tool
          DRCC.get_crafting_item(tool_name, bag, bag_items, belt, true) # attempts to fetch the next tool, with the option (true) to continue if fetch fails
          next unless DRC.right_hand # if we don't get the next tool for whatever reason, we move on to the next tool.

          stop_repairs = false # set when engaged: no further tool can be repaired right now
          repair_tool.each do |x| # iterates once for each: wire brush, oil
            DRCC.get_crafting_item(x, bag, bag_items, belt)
            command = x == 'wire brush' ? "rub my #{tool_name} with my wire brush" : "pour my oil on my #{tool_name}" # changes the command based on the tool, instead of a second case statement, since it's just one of each

            case DRC.bput(command, REPAIR_SUCCESS, REPAIR_NOT_NEEDED, REPAIR_ENGAGED, REPAIR_CONFUSED, REPAIR_POUR_WHAT)
            when REPAIR_SUCCESS # successful partial repair (one brush or one oil)
              DRCC.stow_crafting_item(x, bag, belt)
              next # move to oil, or move out of loop
            when REPAIR_NOT_NEEDED # doesn't require repair, leaving loop for the next tool
              DRCC.stow_crafting_item(x, bag, belt)
              break # leave brush/oil loop and choose next tool
            when REPAIR_POUR_WHAT
              DRCC.check_consumables('oil', info['finisher-room'], info['finisher-number'], bag, bag_items, belt) # somehow ran out of oil, fetching more
              DRCC.get_crafting_item(x, bag, bag_items, belt)
              retry_result = DRC.bput("pour my oil on my #{tool_name}", REPAIR_SUCCESS, REPAIR_ENGAGED)
              DRCC.stow_crafting_item(x, bag, belt)
              if retry_result == REPAIR_ENGAGED # engaged while fetching more oil: stop like the first reply would
                Lich::Messaging.msg('bold', 'DRCC: Cannot repair in combat.')
                stop_repairs = true
                break
              end
              next # oil done, next tool
            when REPAIR_ENGAGED
              Lich::Messaging.msg('bold', 'DRCC: Cannot repair in combat.')
              DRCC.stow_crafting_item(x, bag, belt) # the tool itself is stowed once, below
              stop_repairs = true
              break
            when REPAIR_CONFUSED # this tool can't be repaired this way; the others may still be
              Lich::Messaging.msg('bold', "DRCC: Cannot repair #{tool_name}, skipping it.")
              DRCC.stow_crafting_item(x, bag, belt) # the tool itself is stowed once, below
              break
            end
          end
          UserVars.immune_list.store(tool_name, Time.now + 7000) if Flags['proper-repair'] # if our flag picks up a Proper Forging Tool Care successful repair, we add that tool and a time of now plus 7000 seconds (just shy of 2 hours) to the list of immune tools
          Flags.reset('proper-repair')
          DRCC.stow_crafting_item(tool_name, bag, belt)
          return :engaged if stop_repairs # skip the remaining tools
        end
        nil
      end

      # Makes sure +bag+ holds a consumable with at least +count+ uses. Gets
      # it from +bag+ and counts it; one with too few uses is disposed of and
      # replaced by a fresh call. Orders one at +room+ only when the GET says
      # there is none ("What were you referring to?" or "I could not find
      # what you were referring to."), puts it away, then walks back to the
      # room it started in.
      #
      # The GET names +bag+ by its id when exactly one worn item matches it
      # ({DRCI.worn_ref}). After a GET, the COUNT and the dispose of a
      # worn-out one name the consumable by its id when +name+ means exactly
      # one held item ({DRCI.held_id}); otherwise `my <name>` (and the plain
      # name to dispose) as before. The puts go through stow_crafting_item,
      # which resolves the held id itself.
      #
      # The GET goes by the consumable's own id when one is known, as in
      # get_crafting_item: the one item DRCC last moved in or out of +bag+
      # that the name means, else the one matching item in +bag+ in the Inventory feed's snapshot.
      # The COUNT then names that id. "You pick up" (the id reached it on the
      # floor) counts as got. A not-found reply, or "You should untie" (on
      # the belt, not in +bag+), forgets the id and
      # sends today's by-name GET before anything is ordered, so pins used up
      # and replaced are never bought again because an old id missed. A
      # disposed id is forgotten.
      #
      # A "#<id>" +name+ (or an Integer id) names that one item, and no shop
      # sells it. So it is never ordered: a GET that finds no such item
      # returns false. A worn-out one is disposed of by id and replaced by a
      # call with the first word of its hand name and its GameObj noun
      # ({crafting_held_name}: "stiff wire brush" gives "stiff brush"; read
      # from the hand before the dispose), which can fetch or order another
      # as for any name. The adjective keeps that GET off a different item
      # with the same noun. A one-word hand name, or one that starts with
      # its noun, gives the bare noun, so that GET has no adjective guard.
      #
      # @param name [String, Integer] consumable noun, e.g. 'oil', 'wire
      #   brush', or "#<id>"; an Integer is an id
      # @param room [Integer, String] shop room id or map tag for the order
      # @param number [Integer, String] the shop's ORDER number
      # @param bag [String, Integer] container noun the consumable is kept
      #   in, or "#<id>" (an Integer is an id)
      # @param bag_items [Array<String>, nil] passed on to the replacing call
      # @param belt [Hash, nil] crafting belt settings for stow_crafting_item
      # @param count [Integer] fewest uses to keep
      # @return [Boolean] false, without walking or ordering, when the GET
      #   gets "You need a free hand to pick that up." or no reply, or when
      #   a "#<id>" +name+ is not found (or, worn out, its name can't be
      #   read from the hand, or the hand has no noun, after it is disposed
      #   of). false,
      #   with nothing put away, when DRCT.order_item returns nil or '' (no
      #   coins, full hands, an unreachable shop or a timeout); it still walks
      #   back. false, after walking back, when stow_crafting_item returns
      #   false for the kept or bought consumable: it is still in a hand, or
      #   +bag+ refused it and it went into the other +bag+ (stow_crafting_item
      #   prints its own line). A worn-out one returns the replacing call's
      #   result. true otherwise.
      def check_consumables(name, room, number, bag, bag_items, belt, count = 3)
        name = crafting_name(name)
        current = Room.current.id
        before = DRCI.held_ids
        known = crafting_get_by_known_id(name, bag, CONSUMABLE_ID_GET_IN_HAND, [CONSUMABLE_GET_NO_FREE_HAND], misses: [GET_CRAFTING_TIED])
        result = known&.first || DRC.bput("get #{DRCI.item_ref(name.to_s)} from #{crafting_bag_ref(bag)}", CONSUMABLE_GET_SUCCESS, CONSUMABLE_GET_NOT_FOUND,
                                          CONSUMABLE_GET_COULD_NOT_FIND, CONSUMABLE_GET_NO_FREE_HAND)
        case result
        when CONSUMABLE_GET_SUCCESS, *(known ? CONSUMABLE_ID_GET_IN_HAND : [])
          got = remember_got_crafting_item(name, bag, before)
          # The id it got, when the GET went by id; else the one held match.
          held = known && DRCI.in_hand?(known.last) ? known.last : crafting_held_ref(name)
          count_result = DRC.bput("count #{held}", *COUNT_USES_MESSAGES)
          match = count_result.match(COUNT_USES_PATTERN)
          if match && match[1].to_i < count
            # The disposed id names nothing any more; replace it by name.
            replacement = crafting_id_ref?(name) ? crafting_held_name(held) : name
            # A dispose by name may throw away the one just got, so its id
            # goes too.
            disposed = crafting_id_ref?(held) ? held.delete_prefix('#') : got
            CRAFTING_ITEM_IDS.forget(disposed) if disposed
            DRCT.dispose(crafting_id_ref?(held) ? held : name)
            unless replacement
              Lich::Messaging.msg('bold', "DRCC: Disposed of worn-out #{name} but could not tell its name. Not buying more.")
              return false
            end
            # The call below gets, buys, stows and walks back on its own.
            return DRCC.check_consumables(replacement, room, number, bag, bag_items, belt, count)
          end
          stowed = DRCC.stow_crafting_item(name, bag, belt)
        when CONSUMABLE_GET_NOT_FOUND, CONSUMABLE_GET_COULD_NOT_FIND
          if crafting_id_ref?(name)
            Lich::Messaging.msg('bold', "DRCC: #{name} is not in #{bag}, and an id can't be ordered. Not buying more.")
            return false
          end
          if DRCT.order_item(room, number).to_s.empty?
            Lich::Messaging.msg('bold', "DRCC: Could not buy #{name} (order #{number} at #{room}). Not putting anything away.")
            DRCT.walk_to(current)
            return false
          end
          stowed = DRCC.stow_crafting_item(name, bag, belt)
        else
          reason = result.match?(CONSUMABLE_GET_NO_FREE_HAND) ? 'no free hand' : 'no reply'
          Lich::Messaging.msg('bold', "DRCC: Could not get #{name} from #{bag} to check it (#{reason}). Not buying more.")
          return false
        end
        DRCT.walk_to(current)
        stowed != false
      end

      def get_adjust_tongs?(usage, bag, bag_items, belt, adjustable_tongs = false)
        case usage
        when 'shovel' # looking for a shovel
          if @tongs_status == 'shovel' # tongs already a shovel
            DRCC.get_crafting_item('tongs', bag, bag_items, belt) unless DRCI.in_hands?('tongs') # get unless already holding
            return true # tongs previously set to shovel, in hands, adjusted to shovel.
          elsif !adjustable_tongs # determines state of tongs, works either nil or tongs
            return false # non-adjustable
          else
            DRCC.get_crafting_item('tongs', bag, bag_items, belt) unless DRCI.in_hands?('tongs') # get unless already holding

            case DRC.bput('adjust my tongs', ADJUST_TONGS_SHOVEL, ADJUST_TONGS_TONGS, ADJUST_TONGS_CANNOT, ADJUST_TONGS_UNKNOWN)
            when ADJUST_TONGS_CANNOT, ADJUST_TONGS_UNKNOWN # holding tongs, not adjustable, settings are wrong.
              Lich::Messaging.msg('bold', 'DRCC: Tongs are not adjustable. Please change yaml to reflect adjustable_tongs: false')
              DRCC.stow_crafting_item('tongs', bag, belt) # stows to make room for shovel
              return false
            when ADJUST_TONGS_TONGS # now tongs, adjust success but in wrong configuration
              DRC.bput('adjust my tongs', ADJUST_TONGS_SHOVEL) # now shovel, ready to work
              @tongs_status = 'shovel' # correcting instance variable
              return true # tongs as shovel
            when ADJUST_TONGS_SHOVEL # now shovel, adjust success
              @tongs_status = 'shovel' # setting instance variable
              return true # tongs as shovel
            end
          end

          # at this point, we either have tongs-in-shovel and a return of true, or tongs stowed(if in left hand) and a return of false

        when 'tongs' # looking for tongs
          DRCC.get_crafting_item('tongs', bag, bag_items, belt) unless DRCI.in_hands?('tongs') # get unless already holding. Here we are always getting tongs, never stowing tongs.
          if @tongs_status == 'tongs' # tongs as tongs already
            return true # tongs previously set to tongs, in hands, adjusted to tongs. this will not catch unscripted adjustments to tongs.
          elsif !adjustable_tongs # determines state of tongs, works either nil or shovel
            return false # have tongs, as tongs, but not adjustable.
          else

            case DRC.bput('adjust my tongs', ADJUST_TONGS_SHOVEL, ADJUST_TONGS_TONGS, ADJUST_TONGS_CANNOT, ADJUST_TONGS_UNKNOWN)
            when ADJUST_TONGS_CANNOT, ADJUST_TONGS_UNKNOWN # holding tongs, not adjustable, settings are wrong.
              Lich::Messaging.msg('bold', 'DRCC: Tongs are not adjustable. Please change yaml to reflect adjustable_tongs: false')
              return false # here we have tongs in hand, as tongs, but they're not adjustable, so this returns false.
            when ADJUST_TONGS_SHOVEL # now in shovel, adjust success but in wrong configuration
              DRC.bput('adjust my tongs', ADJUST_TONGS_TONGS) # now tongs, ready to work
              @tongs_status = 'tongs'
              return true # tongs as tongs AND adjustable
            when ADJUST_TONGS_TONGS # now tongs
              @tongs_status = 'tongs'
              return true # tongs as tongs AND adjustable
            end
          end

        when 'reset shovel', 'reset tongs' # Used at the top of a script, to determine state of tongs.
          @tongs_status = nil
          adjustable_tongs = true
          if usage == 'reset shovel'
            return DRCC.get_adjust_tongs?('shovel', bag, bag_items, belt, adjustable_tongs)
          elsif usage == 'reset tongs'
            return DRCC.get_adjust_tongs?('tongs', bag, bag_items, belt, adjustable_tongs)
          end
        end
      end

      def logbook_item(logbook, noun, container)
        DRCI.get_item?("#{logbook} logbook")
        bundle_result = DRC.bput("bundle my #{noun} with my logbook",
                                 BUNDLE_SUCCESS,
                                 BUNDLE_EXPIRED,
                                 BUNDLE_QUALITY,
                                 BUNDLE_WRONG_TYPE,
                                 BUNDLE_NOT_HOLDING)
        case bundle_result
        when BUNDLE_EXPIRED, BUNDLE_QUALITY, BUNDLE_WRONG_TYPE
          DRCI.dispose_trash(noun)
        when BUNDLE_NOT_HOLDING
          if DRCI.get_item?(noun, container)
            case DRC.bput("bundle my #{noun} with my logbook",
                          BUNDLE_SUCCESS,
                          BUNDLE_EXPIRED,
                          BUNDLE_QUALITY,
                          BUNDLE_WRONG_TYPE)
            when BUNDLE_EXPIRED, BUNDLE_QUALITY, BUNDLE_WRONG_TYPE
              DRCI.dispose_trash(noun)
            end
          end
        end
        DRCI.put_away_item?("#{logbook} logbook", container) || DRCI.put_away_item?("#{logbook} logbook")
      end

      def order_enchant(stock_room, stock_needed, stock_number, bag, belt)
        stock_needed.times do
          DRCT.order_item(stock_room, stock_number)
          stow_crafting_item(DRC.left_hand, bag, belt)
          stow_crafting_item(DRC.right_hand, bag, belt)
          next unless DRC.left_hand && DRC.right_hand
        end
      end

      def fount(stock_room, stock_needed, stock_number, quantity, bag, bag_items, belt)
        case DRC.bput('tap my fount', FOUNT_TAP_IN_BAG, FOUNT_TAP_ON_BAG, FOUNT_TAP_NOT_FOUND)
        when FOUNT_TAP_IN_BAG, FOUNT_TAP_ON_BAG
          analyze_result = DRC.bput('analyze my fount', FOUNT_ANALYZE_PATTERN)
          match = analyze_result.match(FOUNT_ANALYZE_PATTERN)
          if match && match[:uses].to_i < (quantity + 1)
            get_crafting_item('fount', bag, bag_items, belt)
            DRCT.dispose('fount')
            DRCI.stow_hands
            order_enchant(stock_room, stock_needed, stock_number, bag, belt)
          end
        when FOUNT_TAP_NOT_FOUND
          case DRC.bput('tap my fount on my brazier', FOUNT_TAP_ON_BRAZIER, FOUNT_TAP_NOT_FOUND)
          when FOUNT_TAP_ON_BRAZIER
            analyze_result = DRC.bput('analyze my fount on my brazier', FOUNT_ANALYZE_PATTERN)
            match = analyze_result.match(FOUNT_ANALYZE_PATTERN)
            if match && match[:uses].to_i < quantity
              DRCI.stow_hands
              order_enchant(stock_room, stock_needed, stock_number, bag, belt)
            end
          when FOUNT_TAP_NOT_FOUND
            order_enchant(stock_room, stock_needed, stock_number, bag, belt)
          end
        end
      end

      def clean_brazier?
        case DRC.bput('look on brazier', BRAZIER_NOTHING, BRAZIER_SEE_PATTERN)
        when /There is nothing on there/i
          true
        when /On the .* you see/
          case DRC.bput('clean brazier', BRAZIER_CLEAN_PREPARE, BRAZIER_CLEAN_NOTHING, BRAZIER_CLEAN_NOT_LIT)
          when BRAZIER_CLEAN_PREPARE
            DRC.bput('clean brazier', BRAZIER_CLEAN_FLAME)
          end
          empty_brazier
          true
        end
      end

      def empty_brazier
        result = DRC.bput('look on brazier', BRAZIER_SEE_PATTERN, BRAZIER_CLEAN_NOTHING)
        match = result.match(BRAZIER_SEE_PATTERN)
        return unless match

        items = match[:items]
        items = items.split(' and ')
        items.each do |item|
          item = item.split.last
          DRC.bput("get #{item} from brazier", BRAZIER_GET_SUCCESS)
          DRCT.dispose(item)
        end
      end

      def check_for_existing_sigil?(sigil, stock_number, quantity, bag, belt, info)
        merged = Regexp.union($PRIMARY_SIGILS_PATTERN, $SECONDARY_SIGILS_PATTERN)

        more = 0
        tmp_count = DRCI.count_items_in_container("#{sigil} sigil-scroll", bag).to_i

        if tmp_count >= quantity
          return true
        else
          if merged.match?("#{sigil} sigil")
            more = quantity - tmp_count
            # Found a weird challenge that made the temp_part_count equal 1 even though no "sigil" was in container
            # Check if there's really nothing in there - use bput to check for the nothing message
            nothing_result = DRC.bput("look in my #{bag}", SIGIL_COUNT_NOTHING, /.*/)
            more += 1 if nothing_result&.include?(SIGIL_COUNT_NOTHING)
            DRCC.order_enchant(info['stock-room'], more, stock_number, bag, belt)
            return true
          else
            Lich::Messaging.msg('bold', "DRCC: Not enough #{sigil} sigil-scroll(s). You can purchase or harvest #{more} more. We recommend using our sigilhunter script. Run #{$clean_lich_char}sigilhunter help for more information.")
            return false
          end
        end
      end

      def count_raw_metal(container, type = nil)
        result = DRC.bput("rummage /M #{container}", RUMMAGE_NOTHING, RUMMAGE_CLOSED, RUMMAGE_NOT_FOUND, RUMMAGE_INVISIBLE, RUMMAGE_NOTHING_ACCOMPLISH, RUMMAGE_SUCCESS_PATTERN)

        if result&.match?(RUMMAGE_NOTHING)
          Lich::Messaging.msg('bold', 'DRCC: No materials found.')
          return nil
        elsif result&.match?(RUMMAGE_CLOSED)
          return nil unless DRCI.open_container?(container)

          return count_raw_metal(container, type)
        elsif result&.match?(RUMMAGE_NOT_FOUND)
          Lich::Messaging.msg('bold', 'DRCC: Container not found.')
          return nil
        elsif result&.match?(RUMMAGE_INVISIBLE)
          Lich::Messaging.msg('bold', "DRCC: Try again when you're not invisible.")
          return nil
        end

        match = result&.match(RUMMAGE_SUCCESS_PATTERN)
        unless match
          Lich::Messaging.msg('bold', 'DRCC: Please report this error to the dev team on discord. Include a log snippet if possible.')
          return nil
        end

        h = {}
        list = match[:materials].sub(' and ', ', ').split(', ')
        list.each do |e|
          metal = e.split[2]
          volume = $VOL_MAP[e.split[1]]
          if h.key?(metal)
            h[metal][0] += volume
            h[metal][1] += 1
          else
            h[metal] = [volume, 1]
          end
        end
        h.each do |k, v|
          Lich::Messaging.msg('plain', "DRCC: #{k} - #{v[0]} volume - #{v[1]} pieces")
        end

        type.nil? ? h : h[type]
      end

      def create_mechanisms(settings, material, number, speed = 6)
        DRCC.find_shaping_room(settings.hometown)
        case DRC.bput("turn press to #{speed}", /You dial the device to \d+ and ready it for pressing/, /The press cannot be turned to a speed greater than 12/, /The press cannot be turned to a volume less than 1/)
        when /The press cannot be turned to a speed greater than 12/, /The press cannot be turned to a volume less than 1/
          DRC.message("Invalid press speed specified.  Valid values are from 1-12.")
          return
        end
        number.times do
          DRCC.get_crafting_item("#{material} ingot", settings.crafting_container, settings.crafting_items_in_container, settings.forging_belt)
          break unless DRCI.in_hands?("#{material} ingot")
          DRCC.get_crafting_item('shovel', settings.crafting_container, settings.crafting_items_in_container, settings.forging_belt) unless DRCI.in_hands?('shovel')
          DRC.bput("push fuel with my shovel", /^Roundtime/)
          DRCC.stow_crafting_item('shovel', settings.crafting_container, settings.forging_belt)
          DRCC.get_crafting_item('pliers', settings.crafting_container, settings.crafting_items_in_container, settings.forging_belt)
          DRC.bput('push my ingot with press', /Roundtime/)
          DRC.bput('pull my mech with press', /Roundtime/)
          DRCC.stow_crafting_item('pliers', settings.crafting_container, settings.forging_belt)
          DRCC.get_crafting_item('mechanisms', settings.crafting_container, settings.crafting_items_in_container, nil, true)
          fput('combine') if DRC.right_hand && DRC.left_hand
          DRCC.stow_crafting_item('mechanisms', settings.crafting_container, nil)
        end
        DRCC.get_crafting_item("#{material} ingot", nil, nil, nil, true)
        DRCC.stow_crafting_item("#{material} ingot", settings.crafting_container, nil) if DRC.right_hand
      end

      # --- Private forge helpers ---------------------------------------------
      # Shared settings resolution and navigation for the blacksmithing private
      # forge, so smith / forge / makesteel behave identically. Callers should
      # prefer these over inlining the logic.

      # Default copper reserved to rent/enter a private forge when the
      # forge_private_forge_cost setting is unset.
      DEFAULT_PRIVATE_FORGE_COST = 50_000

      # Patterns for entering a private forge through its door/sentry.
      PRIVATE_FORGE_ENTRY_SUCCESS = ['You head through', 'You walk', 'You go', 'Obvious exits'].freeze
      PRIVATE_FORGE_ENTRY_BLOCKED = ["You don't have enough", 'The sentry blocks', 'cannot enter', 'You need to pay'].freeze

      # Resolve the town a crafter should work in: the crafting-specific override
      # if set, otherwise their hometown. Mirrors the convention used by every
      # crafting script.
      #
      # @param settings the character settings object
      # @return [String] the town name
      def crafting_hometown(settings)
        settings.force_crafting_town || settings.hometown
      end

      # Whether the character wants to use a private forge. Accepts the legacy
      # forge-only setting name for backward compatibility.
      #
      # @param settings the character settings object
      # @return [Boolean]
      def use_private_forge?(settings)
        settings.use_private_forge || settings.forge_use_private_forge || false
      end

      # Copper to reserve for private forge rental/entry.
      #
      # @param settings the character settings object
      # @return [Integer]
      def private_forge_cost(settings)
        settings.forge_private_forge_cost || DEFAULT_PRIVATE_FORGE_COST
      end

      # The room id of a town's private forge, or nil when it has none.
      #
      # @param hometown [String]
      # @return [Integer, nil]
      def private_forge_room(hometown)
        get_data('crafting')['blacksmithing'][hometown]['private_forge']
      end

      # Blacksmithing towns that define a private forge.
      #
      # @return [Array<String>]
      def towns_with_private_forge
        get_data('crafting')['blacksmithing'].select { |_town, data| data['private_forge'] }.keys
      end

      # Ensure funds and navigate into the town's private forge.
      #
      # @param hometown [String]
      # @param settings the character settings object
      # @return [Boolean] true if we ended up in the private forge, false when the
      #   town has no private forge, funds could not be secured, or entry was blocked.
      def go_to_private_forge(hometown, settings)
        room = private_forge_room(hometown)
        return false unless room
        return false unless DRCM.ensure_copper_on_hand(private_forge_cost(settings), settings, hometown)

        DRCT.walk_to(room)
        return true if Room.current.id == room

        # Not in the room yet -- try to enter through the door/sentry.
        DRC.bput('go door', *PRIVATE_FORGE_ENTRY_SUCCESS, *PRIVATE_FORGE_ENTRY_BLOCKED, 'What were you')
        Room.current.id == room
      end
    end
  end
end
