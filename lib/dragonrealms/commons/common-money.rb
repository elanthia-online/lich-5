module Lich
  module DragonRealms
    module DRCM
      module_function

      # Strips XML tags and decodes common HTML entities from game output lines.
      # Returns an array of non-empty, trimmed strings.
      def strip_xml(lines)
        lines.map { |line| line.gsub(/<[^>]+>/, '').gsub('&gt;', '>').gsub('&lt;', '<').strip }
             .reject(&:empty?)
      end

      def minimize_coins(copper)
        DENOMINATIONS.inject([copper, []]) do |result, denomination|
          remaining = result.first
          display = result.last
          if remaining / denomination.first > 0
            display << "#{remaining / denomination.first} #{denomination.last}"
          end
          [remaining % denomination.first, display]
        end.last
      end

      # Convert an amount to copper given a denomination name (abbreviation permitted).
      # If denomination is nil/empty, assumes coppers and logs a warning.
      # Supports fractional amounts (e.g., '1.5 plat' = 15000 copper).
      def convert_to_copper(amount, denomination)
        denomination = denomination.to_s.strip
        unless denomination.empty?
          DENOMINATION_VALUES.each do |name, multiplier|
            return (amount.to_f * multiplier).to_i if name.start_with?(denomination.downcase)
          end
        end
        Lich::Messaging.msg('bold', "Unknown denomination, assuming coppers: #{denomination}")
        amount.to_i
      end

      # Returns full canonical currency name from an abbreviation.
      # e.g., "k" -> "kronars", "li" -> "lirums"
      def get_canonical_currency(currency)
        CURRENCIES.find { |c| c.start_with?(currency) }
      end

      # Converts an amount between DR currencies, accounting for exchange fees.
      # Use a negative fee to calculate how much is needed to receive a target amount.
      # Use a positive fee to calculate how much will be received after the exchange.
      def convert_currency(amount, from, to, fee)
        if fee < 0
          ((amount / EXCHANGE_RATES[from][to]).ceil / (1 + fee)).ceil
        else
          ((amount * EXCHANGE_RATES[from][to]).ceil * (1 - fee)).floor
        end
      end

      def hometown_currency(hometown_name)
        get_data('town')[hometown_name]['currency']
      end

      # Alias for backward compatibility — common-crafting.rb uses this name.
      def town_currency(town)
        hometown_currency(town)
      end

      def check_wealth(currency)
        DRC.bput("wealth #{currency}", /\(\d+ copper #{currency}\)/i, /No #{currency}/i).scan(/\d+/).first.to_i
      end

      def wealth(hometown)
        check_wealth(hometown_currency(hometown))
      end

      # Captures total on-hand wealth across all three currencies.
      # Returns a hash of currency name => copper value.
      # Uses Lich::Util.issue_command for reliable bounded capture.
      def get_total_wealth
        wealth_lines = Lich::Util.issue_command(
          'wealth',
          /^Wealth:/,
          /<prompt/,
          usexml: true,
          quiet: true,
          include_end: false,
          timeout: 5
        )

        result = { 'kronars' => 0, 'lirums' => 0, 'dokoras' => 0 }
        return result if wealth_lines.nil?

        strip_xml(wealth_lines).each do |line|
          match = line.match(WEALTH_COPPER_REGEX)
          next unless match

          result[match[:currency].downcase] = match[:coppers].to_i
        end

        result
      end

      def ensure_copper_on_hand(copper, settings, hometown = nil)
        hometown = settings.hometown if hometown.nil?

        on_hand = wealth(hometown)
        return true if on_hand >= copper

        withdrawals = minimize_coins(copper - on_hand)

        withdrawals.all? { |amount| withdraw_exact_amount?(amount, settings, hometown) }
      end

      def withdraw_exact_amount?(amount_as_string, settings, hometown = nil)
        hometown = settings.hometown if hometown.nil?

        if settings.bankbot_enabled
          DRCT.walk_to(settings.bankbot_room_id)
          DRC.release_invisibility
          if DRRoom.pcs.include?(settings.bankbot_name)
            amount_convert, type = amount_as_string.split
            amount = convert_to_copper(amount_convert, type)
            currency = hometown_currency(settings.hometown)
            case DRC.bput("whisper #{settings.bankbot_name} withdraw #{amount} #{currency}", 'offers you', 'Whisper what to who?')
            when 'offers you'
              DRC.bput('accept tip', 'Your current balance is')
            end
          else
            get_money_from_bank(amount_as_string, settings, hometown)
          end
        else
          get_money_from_bank(amount_as_string, settings, hometown)
        end
      end

      def get_money_from_bank(amount_as_string, settings, hometown = nil)
        hometown = settings.hometown if hometown.nil?

        DRCT.walk_to(get_data('town')[hometown]['deposit']['id'])
        DRC.release_invisibility
        loop do
          case DRC.bput("withdraw #{amount_as_string}", 'The clerk counts', 'The clerk tells',
                        'The clerk glares at you.', 'You count out', 'find a new deposit jar', 'If you value your hands',
                        'Hey!  Slow down!', "You must be at a bank teller's window to withdraw money",
                        "You don't have that much money", 'have an account',
                        /The clerk says, "I'm afraid you can't withdraw that much at once/,
                        /^How much do you wish to withdraw/i)
          when 'The clerk counts', 'You count out'
            break true
          when 'The clerk glares at you.', 'Hey!  Slow down!', "I don't know what you think you're doing"
            pause 15
          when 'The clerk tells', 'If you value your hands', 'find a new deposit jar',
            "You must be at a bank teller's window to withdraw money", "You don't have that much money",
            'have an account', /The clerk says, "I'm afraid you can't withdraw that much at once/,
            /^How much do you wish to withdraw/i
            break false
          else
            break false
          end
        end
      end

      def debt(hometown)
        currency = hometown_currency(hometown)
        DRC.bput('wealth', /\(\d+ copper #{currency}\)/i, /Wealth:/i).scan(/\d+/).first.to_i
      end

      def deposit_coins(keep_copper, settings, hometown = nil)
        return if settings.skip_bank

        hometown = settings.hometown if hometown.nil?

        DRCT.walk_to(get_data('town')[hometown]['deposit']['id'])
        DRC.release_invisibility
        DRC.bput('wealth', 'Wealth:')
        case DRC.bput('deposit all', 'you drop all your', 'You hand the clerk some coins', "You don't have any",
                      'There is no teller here', 'reached the maximum balance I can permit',
                      'You find your jar with little effort', 'Searching methodically through the shelves')
        when 'There is no teller here'
          return
        end
        minimize_coins(keep_copper).each { |amount| withdraw_exact_amount?(amount, settings) } if settings.hometown == hometown
        balance_result = DRC.bput('check balance',
                                  /current balance is .*? (?:Kronars?|Dokoras?|Lirums?)\."$/,
                                  /If you would like to open one, you need only deposit a few (?:Kronars?|Dokoras?|Lirums?)\."$/,
                                  /As expected, there are .*? (?:Kronars?|Dokoras?|Lirums?)\.$/,
                                  'Perhaps you should find a new deposit jar for your financial needs.  Be sure to mark it with your name')
        case balance_result
        when /current balance is (?<bal>.*?) (?<cur>Kronars?|Dokoras?|Lirums?)\."$/,
             /As expected, there are (?<bal>.*?) (?<cur>Kronars?|Dokoras?|Lirums?)\.$/
          match = balance_result.match(/(?:current balance is|As expected, there are) (?<bal>.*?) (?<cur>Kronars?|Dokoras?|Lirums?)/)
          currency = match[:cur]
          balance = 0
          match[:bal].gsub(/and /, '').split(', ').each do |amount_as_string|
            amount, denomination = amount_as_string.split
            balance += convert_to_copper(amount, denomination)
          end
        when /If you would like to open one, you need only deposit a few (?<cur>Kronars?|Dokoras?|Lirums?)\."$/
          match = balance_result.match(/deposit a few (?<cur>Kronars?|Dokoras?|Lirums?)/)
          balance = 0
          currency = match[:cur]
        when /Perhaps you should find a new deposit jar/
          balance = 0
          currency = 'Dokoras'
        end
        [balance, currency]
      end
    end
  end
end
