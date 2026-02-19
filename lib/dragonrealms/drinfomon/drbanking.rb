# frozen_string_literal: true

module Lich
  module DragonRealms
    # DRBanking provides bank account tracking and vault information storage.
    #
    # Bank balances are tracked passively by parsing game output when players
    # deposit, withdraw, or check their balance at banks across Elanthia.
    #
    # Data is persisted using GameSettings (game-scoped) so that the `;banks all`
    # command can aggregate balances across all characters.
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

      class << self
        # Returns all bank accounts for all characters (game-scoped)
        # @return [Hash] { "CharName" => { "Town" => copper_amount } }
        def all_accounts
          ensure_initialized
          GameSettings['drbanking_accounts']
        end

        # Returns bank accounts for the current character
        # @return [Hash] { "Town" => copper_amount }
        def my_accounts
          ensure_initialized
          all_accounts[character_name] ||= {}
        end

        # Updates a bank balance for the current character
        # @param town [String] The town/bank name
        # @param copper [Integer] The balance in copper
        def update_balance(town, copper)
          ensure_initialized
          all_accounts[character_name] ||= {}
          all_accounts[character_name][town] = copper.to_i
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
          balance_string.scan(/(\d+)\s+(platinum|gold|silver|bronze|copper)/i) do |amount, denom|
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
        def parse(line)
          return unless line.is_a?(String)

          town = current_bank_town
          return unless town

          case line
          when Pattern::DEPOSIT_PORTION
            handle_deposit_portion(town, Regexp.last_match)
          when Pattern::DEPOSIT_ALL_TELLER, Pattern::DEPOSIT_ALL_JAR
            handle_deposit_all(town)
          when Pattern::WITHDRAW_PORTION
            handle_withdraw_portion(town, Regexp.last_match)
          when Pattern::WITHDRAW_ALL
            handle_withdraw_all(town)
          when Pattern::BALANCE_CHECK
            handle_balance_check(town, Regexp.last_match)
          when Pattern::NO_ACCOUNT
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

        private

        def character_name
          XMLData.name
        end

        def ensure_initialized
          GameSettings['drbanking_accounts'] ||= {}
        end

        def handle_deposit_portion(town, match)
          amount = match[:amount].to_i
          denomination = match[:denomination]
          copper = to_copper(amount, denomination)

          current = my_accounts[town].to_i
          update_balance(town, current + copper)
        end

        def handle_deposit_all(town)
          # After depositing all, we need to check balance
          # The game will show the new balance, so we trigger a balance check
          Lich::Messaging.msg('info', "DRBanking: Deposited all money at #{town}. Checking balance...")
          # The balance will be updated when the balance response comes through
        end

        def handle_withdraw_portion(town, match)
          amount = match[:amount].to_i
          denomination = match[:denomination]
          copper = to_copper(amount, denomination)

          current = my_accounts[town].to_i
          new_balance = [current - copper, 0].max
          update_balance(town, new_balance)
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
