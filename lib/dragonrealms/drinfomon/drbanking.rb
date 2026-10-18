# frozen_string_literal: true

module Lich
  module DragonRealms
    # DRBanking provides bank account tracking and vault information storage.
    #
    # Bank balances are tracked passively by parsing game output when players
    # deposit, withdraw, or check their balance at banks across Elanthia.
    #
    # Storage: each character's balances live in that character's own row of
    # the shared settings table (script STORE_SCRIPT, scope "<game>:<name>",
    # value { "Town" => copper }). Only that character's session writes its
    # row, every read comes straight from the database, and every write is an
    # atomic read-modify-write. So several sessions on one install can't
    # overwrite each other's balances, and `;banks all` always shows every
    # character's latest recorded balances.
    #
    # Older versions kept every character in one game-wide row (script 'core',
    # scope "<game>", key 'banking'), and each session wrote back its own stale
    # copy of it. The first read or write that finds that row moves it into
    # per-character rows (see migrate_legacy!).
    #
    # Usage:
    #   DRBanking.my_accounts                    # Current character's bank balances
    #   DRBanking.all_accounts                   # All characters' bank balances
    #   DRBanking.update_balance("Crossings", 15000)  # Update a balance
    #   DRBanking.total_wealth                   # Sum of current character's balances
    #   DRBanking.total_wealth_all               # Sum across all characters
    #
    module DRBanking
      # Pattern constants for bank transaction parsing
      module Pattern
        # Deposit a portion of money
        # "The clerk slides a small metal box across the counter into which you drop 5 gold Kronars"
        DEPOSIT_PORTION = /The clerk slides a small metal box across the counter into which you drop (?<amount>\d+) (?<denomination>\w+) (?<currency>Kronars|Lirums|Dokoras)/i.freeze

        # Deposit all money (teller bank)
        # "The clerk slides a small metal box across the counter into which you drop all your Kronars."
        DEPOSIT_ALL_TELLER = /The clerk slides a small metal box across the counter into which you drop all your (?<currency>Kronars|Lirums|Dokoras)\.\s+She counts them carefully and records the deposit in her ledger/i.freeze

        # Deposit all money (jar bank - Hib, etc.)
        # "You cross through the old balance on the label and update it to reflect your new balance"
        DEPOSIT_ALL_JAR = /You cross through the old balance on the label and update it to reflect your new balance/i.freeze

        # Withdraw a portion of money
        # "The clerk counts out 5 gold Kronars and hands them over, making a notation in her ledger"
        # "You count out 5 gold Dokoras and quickly pocket them, updating the notation on your jar"
        WITHDRAW_PORTION = /(?:The clerk counts|You count) out (?<amount>\d+) (?<denomination>platinum|gold|silver|bronze|copper) (?<currency>Kronars|Lirums|Dokoras) (?:and hands them over, making a notation in her ledger|and quickly pocket them, updating the notation on your jar)/i.freeze

        # Withdraw all money
        # "The clerk counts out all your Kronars and hands them over"
        # "You count out all of your Dokoras and quickly pocket them"
        WITHDRAW_ALL = /(?:The clerk counts out all your|You count out all of your) (?<currency>Kronars|Lirums|Dokoras)/i.freeze

        # Balance check
        # "it looks like your current balance is 5 platinum Kronars"
        # "Here we are. Your current balance is 10 gold, 5 silver Lirums"
        # "As expected, there are 100 copper Dokoras"
        BALANCE_CHECK = /(?:it looks like|"Here we are\.)\s*[Yy]our current balance is (?<balance>.*)\s+(?<currency>Kronars|Lirums|Dokoras)|As expected, there are (?<balance>.*)\s+(?<currency>Kronars|Lirums|Dokoras)/i.freeze

        # No account at this bank
        NO_ACCOUNT = /you do not seem to have an account with us|you should find a new deposit jar for your financial needs/i.freeze
      end

      # Denomination multipliers for converting to copper
      DENOMINATION_VALUES = {
        'platinum' => 10_000,
        'gold'     => 1_000,
        'silver'   => 100,
        'bronze'   => 10,
        'copper'   => 1
      }.freeze

      # Currency to bank list mapping
      CURRENCY_BANKS = {
        'Kronars' => KRONAR_BANKS,
        'Lirums'  => LIRUM_BANKS,
        'Dokoras' => DOKORA_BANKS
      }.freeze

      # Key that held every character's balances in the legacy game-wide row
      SETTINGS_KEY = 'banking'

      # Script name of the per-character balance rows in script_auto_settings
      STORE_SCRIPT = 'core.banking'

      # Script name of the legacy game-wide row (InstanceSettings.game)
      LEGACY_SCRIPT = 'core'

      # Pattern for parsing balance amounts from strings
      BALANCE_AMOUNT_PATTERN = /(\d+)\s+(platinum|gold|silver|bronze|copper)/i.freeze

      class << self
        # Returns the bank accounts of every character in this game, read
        # fresh from the database on every call (nothing is cached).
        # Characters with no recorded balance are left out. A database error
        # is reported and gives {}.
        # @return [Hash] { "CharName" => { "Town" => copper_amount } }
        def all_accounts
          game = game_code
          return {} unless game

          db = adapter
          legacy = legacy_entries(read_legacy_row(db, game), present_only: true)
          if legacy
            begin
              db.transaction { migrate_legacy!(db) }
              legacy = nil
            rescue StandardError => e
              report_storage_error('move old bank data to per-character storage', e)
            end
          end

          accounts = stored_accounts(db, game)
          # If the move failed, still show the old entries, read-only.
          legacy&.each { |name, towns| accounts[name] = towns unless accounts.key?(name) }
          # An empty row is a character whose data was cleared.
          accounts.reject { |_name, towns| towns.empty? }
        rescue StandardError => e
          report_storage_error('read bank data', e)
          {}
        end

        # Returns bank accounts for the current character (a fresh copy)
        # @return [Hash] { "Town" => copper_amount }
        def my_accounts
          name = character_name.to_s
          return {} if name.empty?

          all_accounts[name] || {}
        end

        # Updates a bank balance for the current character
        # @param town [String] The town/bank name
        # @param copper [Integer] The balance in copper
        def update_balance(town, copper)
          stored = modify_my_accounts("save the #{town} balance") do |accounts|
            accounts[town] = copper.to_i
            accounts
          end
          return unless stored

          Lich::Messaging.msg('info', "DRBanking: Updated #{town} balance to #{format_currency(copper)}")
        end

        # Clears the balance for a town (no account)
        # @param town [String] The town/bank name
        def clear_balance(town)
          update_balance(town, 0)
        end

        # Calculates total wealth for current character
        # @return [Integer] Total copper across all banks
        def total_wealth
          my_accounts.values.sum
        end

        # Calculates total wealth across all characters
        # @return [Integer] Total copper across all characters and banks
        def total_wealth_all
          all_accounts.values.map { |banks| banks.values.sum }.sum
        end

        # Converts an amount and denomination to copper
        # @param amount [Integer, String] The amount
        # @param denomination [String] The denomination (platinum, gold, silver, bronze, copper)
        # @return [Integer] The value in copper
        def to_copper(amount, denomination)
          multiplier = DENOMINATION_VALUES[denomination.downcase] || 1
          amount.to_i * multiplier
        end

        # Parses a balance string like "5 platinum, 3 gold, 2 silver" into copper
        # @param balance_string [String] The balance text from game output
        # @return [Integer] The total value in copper
        def parse_balance_string(balance_string)
          return 0 if balance_string.nil? || balance_string.empty?

          copper = 0
          balance_string.scan(BALANCE_AMOUNT_PATTERN) do |amount, denom|
            copper += to_copper(amount, denom)
          end
          copper
        end

        # Formats copper amount as a readable currency string
        # @param copper [Integer, String] Amount in copper
        # @return [String] Formatted string like "5 platinum, 3 gold, 2 silver"
        def format_currency(copper)
          copper = copper.to_i
          return 'none' if copper <= 0

          parts = []
          DENOMINATION_VALUES.each do |name, value|
            count = copper / value
            if count > 0
              parts << "#{count} #{name}"
              copper %= value
            end
          end
          parts.empty? ? 'none' : parts.join(', ')
        end

        # Finds the current bank town based on room title
        # @return [String, nil] The town name or nil if not in a bank
        def current_bank_town
          room_title = XMLData.room_title
          return nil if room_title.nil? || room_title.empty?

          BANK_TITLES.each do |town, titles|
            return town if titles.any? { |title| room_title.include?(title.gsub('[[', '').gsub(']]', '')) }
          end
          nil
        end

        # Parses a line of game output for bank transactions
        # Called by DRParser for each line of server output
        # @param line [String] A line of game output
        # @note Uses explicit match variables instead of Regexp.last_match for reliability
        def parse(line)
          return unless line.is_a?(String)

          town = current_bank_town
          return unless town

          # Use explicit match variables instead of Regexp.last_match (more reliable)
          if (match = line.match(Pattern::DEPOSIT_PORTION))
            handle_deposit_portion(town, match)
          elsif line.match?(Pattern::DEPOSIT_ALL_TELLER) || line.match?(Pattern::DEPOSIT_ALL_JAR)
            handle_deposit_all(town)
          elsif (match = line.match(Pattern::WITHDRAW_PORTION))
            handle_withdraw_portion(town, match)
          elsif line.match?(Pattern::WITHDRAW_ALL)
            handle_withdraw_all(town)
          elsif (match = line.match(Pattern::BALANCE_CHECK))
            handle_balance_check(town, match)
          elsif line.match?(Pattern::NO_ACCOUNT)
            handle_no_account(town)
          end
        end

        # Displays bank balances for current character
        def display_banks
          accounts = my_accounts
          if accounts.empty?
            Lich::Messaging.msg('info', 'DRBanking: No bank account info recorded.')
            return
          end

          Lich::Messaging.msg('info', 'DRBanking: Your bank balances:')
          Lich::Messaging.msg('info', '-' * 50)

          # Group by currency
          { 'Kronars' => KRONAR_BANKS, 'Lirums' => LIRUM_BANKS, 'Dokoras' => DOKORA_BANKS }.each do |currency, banks|
            currency_total = 0
            banks.each do |bank_town|
              next unless accounts[bank_town]

              amount = accounts[bank_town]
              currency_total += amount
              Lich::Messaging.msg('info', "  #{bank_town.rjust(25)}: #{format_currency(amount)}")
            end
            Lich::Messaging.msg('info', "  #{currency} Total:".rjust(27) + " #{format_currency(currency_total)}") if currency_total > 0
          end

          Lich::Messaging.msg('info', '-' * 50)
          Lich::Messaging.msg('info', "  #{'Grand Total:'.rjust(25)} #{format_currency(total_wealth)}")
        end

        # Displays bank balances for all characters
        def display_banks_all
          accounts = all_accounts
          if accounts.empty?
            Lich::Messaging.msg('info', 'DRBanking: No bank account info recorded for any character.')
            return
          end

          Lich::Messaging.msg('info', 'DRBanking: Bank balances for all characters:')
          Lich::Messaging.msg('info', '=' * 60)

          grand_total = 0
          accounts.each do |char_name, char_accounts|
            next if char_accounts.empty?

            char_total = char_accounts.values.sum
            grand_total += char_total

            Lich::Messaging.msg('info', "#{char_name}:")
            char_accounts.each do |town, amount|
              Lich::Messaging.msg('info', "    #{town.rjust(23)}: #{format_currency(amount)}")
            end
            Lich::Messaging.msg('info', "    #{'Character Total:'.rjust(23)} #{format_currency(char_total)}")
            Lich::Messaging.msg('info', '')
          end

          Lich::Messaging.msg('info', '=' * 60)
          Lich::Messaging.msg('info', "Grand Total (all characters): #{format_currency(grand_total)}")
        end

        # Balances are no longer cached, so there is nothing to reload.
        # Kept for compatibility; returns a fresh read, like all_accounts.
        def reload!
          all_accounts
        end

        # Reset current character's bank data
        def reset_character!
          return unless modify_my_accounts('clear your bank data') { |_accounts| {} }

          Lich::Messaging.msg('info', "DRBanking: Cleared bank data for #{character_name}.")
        end

        # Reset all bank data for all characters in this game.
        # Empties every character's row (and the legacy row) in one transaction.
        def reset_all!
          game = game_code
          unless game
            Lich::Messaging.msg('info', "DRBanking: Can't clear bank data before the game is known.")
            return
          end

          db = adapter
          db.transaction do
            migrate_legacy!(db)
            db.get_settings_by_scope_prefix(STORE_SCRIPT, "#{game}:").each_key do |scope|
              db.update_settings(STORE_SCRIPT, scope) { |_accounts| {} }
            end
          end
          Lich::Messaging.msg('info', 'DRBanking: Cleared all bank data for all characters.')
        rescue StandardError => e
          report_storage_error('clear all bank data', e)
        end

        private

        def character_name
          XMLData.name
        end

        # @return [String, nil] the game code ("DR", "DRF"...), nil if not known yet
        def game_code
          game = XMLData.game.to_s
          game.empty? ? nil : game
        end

        # @return [String, nil] this character's row scope, nil if not known yet
        def my_scope
          game = game_code
          name = character_name.to_s
          return nil if game.nil? || name.empty?

          "#{game}:#{name}"
        end

        def adapter
          Lich::Common::Settings.db_adapter
        end

        # Reads every character's row for this game.
        # @return [Hash] { "CharName" => { "Town" => copper } }
        def stored_accounts(db, game)
          prefix = "#{game}:"
          db.get_settings_by_scope_prefix(STORE_SCRIPT, prefix).each_with_object({}) do |(scope, towns), accounts|
            name = scope.delete_prefix(prefix)
            next if name.empty? || !towns.is_a?(Hash)

            accounts[name] = towns
          end
        end

        # Atomically changes this character's row, after moving any legacy
        # data in the same transaction. Yields a fresh copy of the row; the
        # block returns the Hash to store, or nil to store nothing.
        # @param action [String] what is being done, for error messages
        # @return [Hash, nil] the stored Hash; nil if nothing was stored
        def modify_my_accounts(action)
          scope = my_scope
          unless scope
            Lich::Messaging.msg('info', "DRBanking: Can't #{action} before the character is known.")
            return nil
          end

          db = adapter
          db.transaction do
            migrate_legacy!(db)
            db.update_settings(STORE_SCRIPT, scope) { |accounts| yield accounts }
          end
        rescue StandardError => e
          report_storage_error(action, e)
          nil
        end

        # Moves the legacy game-wide blob into per-character rows. Must run
        # inside adapter.transaction. Safe to run any number of times, and
        # from several sessions at once:
        # - A character that already has a row keeps it. That row is newer
        #   than the blob, or was cleared on purpose.
        # - The 'banking' key leaves the old row in the same transaction, so
        #   the next run finds nothing to do.
        # @return [Boolean] true if there was legacy data to move
        def migrate_legacy!(db)
          game = game_code
          return false unless game

          entries = legacy_entries(read_legacy_row(db, game), present_only: true)
          return false unless entries

          prefix = "#{game}:"
          existing = db.get_settings_by_scope_prefix(STORE_SCRIPT, prefix)
          entries.each do |name, towns|
            scope = "#{prefix}#{name}"
            next if existing.key?(scope)

            db.update_settings(STORE_SCRIPT, scope) { |_accounts| towns }
          end
          db.update_settings(LEGACY_SCRIPT, game) do |row|
            row.delete(SETTINGS_KEY)
            row
          end
          true
        end

        # Reads the legacy game-wide row. A row that can't be loaded is logged
        # and treated as having no bank data, so it can't block every read
        # and write of balances. Database errors still raise.
        # @return [Hash]
        def read_legacy_row(db, game)
          db.get_settings(LEGACY_SCRIPT, game)
        rescue TypeError, ArgumentError, EncodingError => e
          Lich.log("error: DRBanking ignoring unreadable legacy row #{LEGACY_SCRIPT}/#{game}: #{e.class}: #{e.message}")
          {}
        end

        # Extracts the well-formed character entries from a legacy row.
        # @param row [Hash] the legacy game-wide row
        # @param present_only [Boolean] return nil when the row has no 'banking' key
        # @return [Hash, nil] { "CharName" => { "Town" => copper } }
        def legacy_entries(row, present_only: false)
          return nil if present_only && !(row.is_a?(Hash) && row.key?(SETTINGS_KEY))

          blob = row.is_a?(Hash) ? row[SETTINGS_KEY] : nil
          return {} unless blob.is_a?(Hash)

          blob.each_with_object({}) do |(name, towns), entries|
            next unless name.is_a?(String) && !name.strip.empty? && towns.is_a?(Hash)

            entries[name] = towns.each_with_object({}) do |(town, copper), clean|
              clean[town] = copper.to_i if town.is_a?(String) && copper.is_a?(Numeric)
            end
          end
        end

        def report_storage_error(action, error)
          Lich::Messaging.msg('bold', "DRBanking: could not #{action}: #{error.class}: #{error.message}")
          Lich.log("error: DRBanking could not #{action}: #{error.class}: #{error.message}\n\t#{(error.backtrace || []).first(5).join("\n\t")}")
        end

        # Applies a deposit or withdrawal to the recorded balance, atomically.
        # Without a recorded balance there is nothing to apply it to.
        def change_balance(town, delta, description)
          unknown = false
          stored = modify_my_accounts("save the #{town} balance") do |accounts|
            if accounts[town].nil?
              unknown = true
              nil
            else
              accounts[town] = [accounts[town].to_i + delta, 0].max
              accounts
            end
          end

          if unknown
            Lich::Messaging.msg('info', "DRBanking: #{description}. No prior balance recorded - check BALANCE to sync.")
          elsif stored
            Lich::Messaging.msg('info', "DRBanking: Updated #{town} balance to #{format_currency(stored[town])}")
          end
        end

        def handle_deposit_portion(town, match)
          copper = to_copper(match[:amount].to_i, match[:denomination])
          change_balance(town, copper, "Deposited #{format_currency(copper)} at #{town}")
        end

        def handle_deposit_all(town)
          # After depositing all, we need to check balance
          # The game will show the new balance, so we trigger a balance check
          Lich::Messaging.msg('info', "DRBanking: Deposited all money at #{town}. Checking balance...")
          # The balance will be updated when the balance response comes through
        end

        def handle_withdraw_portion(town, match)
          copper = to_copper(match[:amount].to_i, match[:denomination])
          change_balance(town, -copper, "Withdrew #{format_currency(copper)} from #{town}")
        end

        def handle_withdraw_all(town)
          update_balance(town, 0)
          Lich::Messaging.msg('info', "DRBanking: Withdrew all money from #{town}.")
        end

        def handle_balance_check(town, match)
          balance_str = match[:balance]
          copper = parse_balance_string(balance_str)
          update_balance(town, copper)
        end

        def handle_no_account(town)
          clear_balance(town)
          Lich::Messaging.msg('info', "DRBanking: No account at #{town}.")
        end
      end
    end
  end
end
