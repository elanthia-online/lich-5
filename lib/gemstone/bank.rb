# frozen_string_literal: true

# Bank: the GemStone bank verbs, sent and confirmed once.
#
# eloot, eherbs and ebounty each carry the same deposit / withdraw / note
# sequences with the same reply lines, plus the Pinefar depository's different
# wording and the free-to-play balance cap. This is that set, in one place.
# Getting to the bank is a script's job (see libeo's EO.go2); these assume the
# character is already standing at one.
#
#   Bank.here?                 # standing at a bank
#   Bank.account               # { balance: 12345, max: nil } from BANK ACCOUNT, nil without access
#   Bank.deposit               # everything carried; f2p accounts respect the cap and take notes
#   Bank.deposit(5000)
#   Bank.deposit_note          # the note in hand
#   Bank.withdraw(8000)        # silver; the f2p path drains notes from the stow container first
#   Bank.withdraw(8000, note: true)
module Lich
  module Gemstone
    module Bank
      module Pattern
        DEPOSIT = Regexp.union(
          /^You deposit (?<silver>[\d,]+) silvers? into your account/,
          /^That's a total of (?<silver>[\d,]+) silver/,
          /^You deposit your note worth (?<silver>[\d,]+) into your account/,
          /They add up to (?<silver>[\d,]+) (?:silver|silvers)/,
          /^You have no coins to deposit/,
          /takes your silvers?/,
          /^You hand your notes to the teller/,
        ).freeze

        # The teller's answer to a withdrawal, without the debt notice: that
        # comes first and the real answer follows it.
        WITHDRAW_RESULT = Regexp.union(
          /^Very well, a withdrawal of (?<silver>[\d,]+) silver/,
          /teller scribbles the transaction into a book and hands you (?<silver>[\d,]+) silver/,
          /teller carefully records the transaction, (?:and then )?hands you (?<silver>[\d,]+) silver/,
          /^The banker nods and says, "Alright, here ye go/,
          /^The teller (?:carefully|hands you|makes|taps her quill|purses her lips)/,
          /seem to have that much/,
          /debt collector/,
          /looks at you suspiciously/,
          /chuckles at you/,
        ).freeze

        DEBT     = /I have a bill of (?<debt>[\d,]+) silvers?/.freeze
        WITHDRAW = Regexp.union(WITHDRAW_RESULT, DEBT).freeze

        # Replies that mean the withdrawal did not happen.
        WITHDRAW_REFUSED = /seem to have that much|looks at you suspiciously|chuckles at you|taps her quill|purses her lips/.freeze
        NOTE_HANDED      = /hands you a (?:bank )?note/.freeze
        PINEFAR_HANDED   = /Alright, here ye go/.freeze

        ACCOUNT_START   = /You currently have the following amounts on deposit|You currently have an account|you don't have access/i.freeze
        ACCOUNT_LINE    = /^\s+(?<bank>.+?) Bank: (?<silver>[\d,]+)$/.freeze
        ACCOUNT_TOTAL   = /^\s+Total: (?<silver>[\d,]+)$/.freeze
        ACCOUNT_BALANCE = /in the amount of (?<silver>[\d,]+) silver/.freeze
        ACCOUNT_MAX     = /a maximum of (?<silver>[\d,]+) silvers/.freeze
        ACCOUNT_END     = /urchin bank runner uses remaining|a maximum of|you don't have access|<prompt/i.freeze
        NO_ACCESS       = /you don't have access/i.freeze
        NOTE_VALUE      = /has a value of (?<silver>[\d,]+) silver and reads/.freeze
        NOTE_READ       = /Hold in right hand to use|has a value of/.freeze
      end

      PINEFAR_TITLE = '[Pinefar, Depository]'
      NOTE_NOUN = /^(?:note|scrip|chit)$/.freeze

      # Silver kept on hand when the f2p deposit loop sizes a note, so the next
      # pass can still deposit something. eloot's number.
      F2P_NOTE_BUFFER = 10_000

      # @return [Boolean] standing at a bank (a tagged room or the Pinefar depository)
      def self.here?
        pinefar? || Room.current&.tags.to_a.include?('bank') ? true : false
      end

      # @return [Boolean] the Pinefar depository, which has a banker NPC and its own verbs
      def self.pinefar?
        XMLData.room_title == PINEFAR_TITLE
      end

      # @return [Boolean] free-to-play account: capped balance, notes for the overflow
      def self.f2p?
        Lich::Common::Account.type.to_s == 'FREE'
      end

      # BANK ACCOUNT, parsed. The listing covers every town's account, so
      # +balance+ is the one for the town the character is standing in, picked
      # by matching the bank's name against the room's location.
      #
      # @return [Hash, nil] +{ balance:, max:, banks:, total: }+ where +banks+ maps
      #   town name to silver, +max+ is the f2p cap (nil without one), or nil
      #   when this town's bank refuses access
      def self.account
        lines = Lich::Util.issue_command('bank account', Pattern::ACCOUNT_START, Pattern::ACCOUNT_END, silent: true, quiet: true)
        return nil if lines.any? { |l| l =~ Pattern::NO_ACCESS }
        banks = {}
        total = nil
        max = nil
        balance = nil
        lines.each do |line|
          if line =~ Pattern::ACCOUNT_LINE
            banks[Regexp.last_match[:bank]] = Regexp.last_match[:silver].delete(',').to_i
          elsif line =~ Pattern::ACCOUNT_TOTAL
            total = Regexp.last_match[:silver].delete(',').to_i
          elsif line =~ Pattern::ACCOUNT_BALANCE
            balance = Regexp.last_match[:silver].delete(',').to_i
          elsif line =~ Pattern::ACCOUNT_MAX
            max = Regexp.last_match[:silver].delete(',').to_i
          end
        end
        balance ||= banks[local_bank(banks.keys)] || 0
        { balance: balance, max: max, banks: banks, total: total || banks.values.sum }
      end

      # @return [Integer, nil] balance at this town's bank, nil without access
      def self.balance
        account&.fetch(:balance)
      end

      # The bank named for the town the character is in ("Four Winds" for a room
      # located on Four Winds Isle).
      #
      # @param names [Array<String>] bank names from BANK ACCOUNT
      # @return [String, nil]
      def self.local_bank(names)
        location = Room.current&.location.to_s
        return nil if location.empty?
        names.find { |n| location.start_with?(n) } || names.find { |n| location.include?(n) || n.include?(location) }
      end

      # @return [GameObj, nil] a bank note in either hand
      def self.note_in_hand
        [GameObj.right_hand, GameObj.left_hand].compact.find { |i| i.noun =~ NOTE_NOUN }
      end

      # @param container [GameObj, nil] defaults to the STOW default container
      # @return [Array<GameObj>] bank notes Lich knows to be in that container
      def self.notes_in(container = StowList.default)
        container&.contents.to_a.select { |obj| obj.noun =~ NOTE_NOUN }
      end

      # @param note [GameObj] a note in hand
      # @return [Integer] its value, 0 when unreadable
      def self.note_value(note = note_in_hand)
        return 0 if note.nil?
        waitrt?
        line = dothistimeout("read ##{note.id}", 3, Pattern::NOTE_READ)
        line.to_s =~ Pattern::NOTE_VALUE ? Regexp.last_match[:silver].delete(',').to_i : 0
      end

      # Deposit silver.
      #
      # @param amount [Integer, :all]
      # @return [Integer, nil] silver deposited as the bank reported it, 0 when
      #   there was nothing to deposit, nil when the bank refused
      def self.deposit(amount = :all)
        return deposit_f2p(amount) if f2p? && !pinefar?

        waitrt?
        result = if pinefar?
                   silver = amount == :all ? Currency.silver(refresh: true) : amount
                   return 0 unless silver.to_i.positive?
                   wait_for_banker
                   dothistimeout("give banker #{silver} silver", 3, Pattern::DEPOSIT)
                 else
                   dothistimeout("deposit #{amount == :all ? 'all' : amount}", 3, Regexp.union(Pattern::DEPOSIT, Pattern::NO_ACCESS))
                 end
        Currency.refresh
        deposited(result)
      end

      # Deposit the note in hand. Pinefar cannot take notes.
      #
      # @param note [GameObj, nil]
      # @return [Integer, nil] the note's value as the bank reported it, nil when
      #   there is no note or the bank cannot take it
      def self.deposit_note(note = note_in_hand)
        return nil if note.nil? || pinefar?
        waitrt?
        result = dothistimeout("deposit ##{note.id}", 3, Pattern::DEPOSIT)
        20.times { break if note_in_hand.nil?; sleep 0.1 }
        deposited(result)
      end

      # Withdraw silver, or a note for that amount.
      #
      # @param amount [Integer]
      # @param note [Boolean] take a note rather than coins
      # @return [Integer, nil] silver withdrawn (the note's face value for a note),
      #   nil when the bank refused
      def self.withdraw(amount, note: false)
        return withdraw_f2p(amount) if f2p? && !note && !pinefar?

        waitrt?
        result = if pinefar?
                   wait_for_banker
                   withdraw_reply("ask banker for #{amount} silvers", 3)
                 elsif note
                   withdraw_reply("withdraw #{amount} note", 5)
                 else
                   withdraw_reply("withdraw #{amount} silvers", 3)
                 end
        Currency.refresh unless note
        return nil if result.nil? || result =~ Pattern::WITHDRAW_REFUSED
        return (result =~ Pattern::NOTE_HANDED ? amount : nil) if note
        return amount if result =~ Pattern::PINEFAR_HANDED
        result =~ /(?<silver>[\d,]+) silver/ ? Regexp.last_match[:silver].delete(',').to_i : nil
      end

      # Free-to-play deposit: fill the account to its cap, convert the overflow to
      # a note and stow it, repeat until everything carried is put away.
      #
      # @param amount [Integer, :all]
      # @param stow [GameObj, nil] where notes go; the STOW default container
      # @return [Integer, nil] silver put away in total, nil when the bank refused
      #   before anything was deposited
      def self.deposit_f2p(amount = :all, stow: StowList.default)
        total = 0
        refused = false
        remaining = amount == :all ? nil : amount
        loop do
          info = account
          if info.nil?
            refused = true
            break
          end
          carried = Currency.silver(refresh: true).to_i
          carried = [carried, remaining].min if remaining
          break unless carried.positive?

          max = info[:max]
          if max.nil? || info[:balance] + carried < max
            got = deposited(dothistimeout("deposit #{carried}", 3, Pattern::DEPOSIT))
            refused = got.nil?
            total += got.to_i
            break
          end

          room = max - info[:balance]
          if room.positive?
            got = deposited(dothistimeout("deposit #{room}", 3, Pattern::DEPOSIT))
            if got.nil?
              refused = true
              break
            end
            total += got
            remaining -= got if remaining
          end
          carried = Currency.silver(refresh: true).to_i
          break if (remaining && remaining <= 0) || !carried.positive?
          note_size = carried >= F2P_NOTE_BUFFER ? max : max - (F2P_NOTE_BUFFER - carried)
          break if withdraw(note_size, note: true).nil?
          note = note_in_hand
          break if note.nil? || stow.nil?
          Lich::Stash.add_to_bag(stow, note)
        end
        Currency.refresh
        refused && total.zero? ? nil : total
      end

      # Free-to-play withdrawal: the balance may be short of +amount+ while notes
      # in the stow container hold the rest, so deposit notes until it covers.
      #
      # @param amount [Integer]
      # @param stow [GameObj, nil]
      # @return [Integer, nil] silver withdrawn, nil when the bank refused
      def self.withdraw_f2p(amount, stow: StowList.default)
        info = account
        return nil if info.nil?
        bal = info[:balance]
        if bal >= amount
          got = withdraw_silver(amount)
          Currency.refresh
          return got
        end

        taken = 0
        want = amount
        refused = false
        notes_in(stow).each do
          if bal.positive?
            got = withdraw_silver(bal)
            if got.nil?
              refused = true
              break
            end
            taken += got
            want -= got
            bal = 0
          end
          note = notes_in(stow).first
          break if note.nil?
          fput "get ##{note.id}"
          value = deposit_note(note)
          break if value.nil?
          got = withdraw_silver([value, want].min)
          if got.nil?
            refused = true
            break
          end
          taken += got
          want -= got
          break if want <= 0
        end
        Currency.refresh
        refused && taken.zero? ? nil : taken
      end

      # The Pinefar banker wanders; give him a moment to be at the counter.
      #
      # @param timeout [Numeric]
      # @return [Boolean]
      def self.wait_for_banker(timeout: 30)
        deadline = Time.now + timeout
        until GameObj.npcs.to_a.any? { |npc| npc.noun == 'banker' }
          return false if Time.now > deadline
          sleep 1
        end
        true
      end

      # Send a withdrawal and return the teller's answer to it. A debt notice
      # is not an answer: warn about it and keep waiting for the line that is.
      #
      # @api private
      # @return [String, nil]
      def self.withdraw_reply(command, timeout)
        result = dothistimeout(command, timeout, Pattern::WITHDRAW)
        return result unless result =~ Pattern::DEBT
        Lich::Messaging.msg('warn', "Bank: a debt of #{Regexp.last_match[:debt]} silver was collected first")
        matchtimeout(timeout, Pattern::WITHDRAW_RESULT) || nil
      end
      private_class_method :withdraw_reply

      # WITHDRAW N SILVER, confirmed.
      #
      # @api private
      # @return [Integer, nil] silver the teller said was handed over, nil when
      #   refused or unanswered
      def self.withdraw_silver(amount)
        result = withdraw_reply("withdraw #{amount} silver", 3)
        return nil if result.nil? || result =~ Pattern::WITHDRAW_REFUSED
        result =~ /(?<silver>[\d,]+) silver/ ? Regexp.last_match[:silver].delete(',').to_i : nil
      end
      private_class_method :withdraw_silver

      # @api private
      def self.deposited(result)
        return nil if result.nil? || result =~ Pattern::NO_ACCESS
        return 0 if result =~ /no coins to deposit/
        result =~ /(?<silver>[\d,]+)/ ? Regexp.last_match[:silver].delete(',').to_i : 0
      end
      private_class_method :deposited
    end
  end
end
