module Lich
  module DragonRealms

module DRCM
  module_function

  # Map of regex abbreviations for coin denominations
  # Supports abbreviations of input like DR
  $DENOMINATION_REGEX_MAP = {
    'platinum' => /\bp(l|la|lat|lati|latin|latinu|latinum)?\b/i,
    'gold'     => /\bg(o|ol|old)?\b/i,
    'silver'   => /\bs(i|il|ilv|ilve|ilver)?\b/i,
    'bronze'   => /\bb(r|ro|ron|ronz|ronze)?\b/i,
    'copper'   => /\bc(o|op|opp|oppe|opper)?\b/i
  }

  # Map of regex abbreviations for currency
  # Supports abbreviations of input like DR
  $CURRENCY_REGEX_MAP = {
    'kronars' => /\bk(r|ro|ron|rona|ronar|ronars)?\b/i,
    'lirums'  => /\bl(i|ir|iru|irum|irums)?\b/i,
    'dokoras' => /\bd(o|ok|oko|okor|okora|okoras)?\b/i
  }

  def minimize_coins(copper)
    denominations = [[10_000, 'platinum'], [1000, 'gold'], [100, 'silver'], [10, 'bronze'], [1, 'copper']]
    denominations.inject([copper, []]) do |result, denomination|
      remaining = result.first
      display = result.last
      if remaining / denomination.first > 0
        display << "#{remaining / denomination.first} #{denomination.last}"
      end
      [remaining % denomination.first, display]
    end.last
  end

  def convert_to_copper(amount, denomination)
    # Convert to copper given denomination (abbreviation permitted)
    # If no denomination specified, return the integer amount (assumed to be coppers)
    denomination = denomination.strip # trim whitespace and also convert nil to empty string
    if !denomination.empty?
      # Convert amount to float to support expressions like '1.5 plat' then truncate to integer.
      # If convert amount to integer first then lose precision and '1.5 plat' becomes 10,000 instead of 15,000.
      return (amount.to_f * 10_000).to_i if 'platinum'.start_with?(denomination.downcase)
      return (amount.to_f * 1000).to_i if 'gold'.start_with?(denomination.downcase)
      return (amount.to_f * 100).to_i if 'silver'.start_with?(denomination.downcase)
      return (amount.to_f * 10).to_i if 'bronze'.start_with?(denomination.downcase)
      return (amount.to_f * 1).to_i if 'copper'.start_with?(denomination.downcase)
    end
    DRC.message("Unknown denomination, assuming coppers: #{denomination}")
    amount.to_i
  end

  # Returns full canonical currency if given an abbreviation
  def get_canonical_currency(currency)
    currencies = [
      'kronars',
      'lirums',
      'dokoras'
    ]
    return currencies.find { |x| x.start_with?(currency) }
  end

  def convert_currency(amount, from, to, fee)
    # When determining how much coin is needed to receive X amount in another currency
    # Use a negative fee percentage
    # When determining how much coin will be received after the exchange
    # Use a positive fee percentage
    exchange_rates = {
      'dokoras' => {
        'dokoras' => 1,
        'kronars' => 1.385808991,
        'lirums'  => 1.108646953
      },
      'kronars' => {
        'dokoras' => 0.7216,
        'kronars' => 1,
        'lirums'  => 0.8
      },
      'lirums'  => {
        'dokoras' => 0.902,
        'kronars' => 1.25,
        'lirums'  => 1
      }
    }
    if fee < 0
      ((amount / exchange_rates[from][to]).ceil / (1 + fee)).ceil
    else
      ((amount * exchange_rates[from][to]).ceil * (1 - fee)).floor
    end
  end

  def hometown_currency(hometown_name)
    get_data('town')[hometown_name]['currency']
  end

  def check_wealth(currency)
    DRC.bput("wealth #{currency}", /\(\d+ copper #{currency}\)/i, /No #{currency}/i).scan(/\d+/).first.to_i
  end

  def wealth(hometown)
    check_wealth(hometown_currency(hometown))
  end

  def get_total_wealth
    # This method captures your current total on-hand wealth
    # and returns a hash representing the numerical value in
    # coppers of each currency.

    # Set up variables to capture the value in coppers of each currency
    # Set to zero so that, if we have, for example, "No Lirums"
    # we simply return the initialized value of 0.
    kronars = 0
    lirums = 0
    dokoras = 0

    # Grab the character's wealth, pausing a bit
    # then grabbing a sufficient number of lines
    # to ensure we get all the output taking into
    # account other random scroll text.
    # Reversing the lines ensures we are processing
    # the most recent output from 'wealth', in case
    # reget were to grab output from back-to-back calls.
    DRC.bput("wealth", "Wealth")
    pause 0.5
    wealth_lines = reget(10).map(&:strip).reverse

    # We've reversed the reget array. Now we'll iterate over it and capture
    # each line after we recognize we've hit the Wealth block.
    wealth_lines.each do |line|
      case line
      when /^Wealth:/i
        # This is the start of our Wealth lines.
        # We don't need to parse this line. Break out of loop.
        break
      when /\(\d+ copper Kronars\)/i
        kronars = line.scan(/\((\d+) copper kronars\)/i).first.first.to_i
      when /\(\d+ copper Lirums\)/i
        lirums = line.scan(/\((\d+) copper lirums\)/i).first.first.to_i
      when /\(\d+ copper Dokoras\)/i
        dokoras = line.scan(/\((\d+) copper dokoras\)/i).first.first.to_i
      end
    end

    # Set up a hash of currency and corresponding value
    # in coppers. Return the hash for future use.
    total_wealth = {
      'kronars' => kronars,
      'lirums'  => lirums,
      'dokoras' => dokoras
    }
    return total_wealth
  end

  def ensure_copper_on_hand(copper, settings, hometown = nil)
    hometown = settings.hometown if hometown == nil

    on_hand = wealth(hometown)
    return true if on_hand >= copper

    withdrawals = minimize_coins(copper - on_hand)

    withdrawals.all? { |amount| withdraw_exact_amount?(amount, settings, hometown) }
  end

  def withdraw_exact_amount?(amount_as_string, settings, hometown = nil)
    hometown = settings.hometown if hometown == nil

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
    hometown = settings.hometown if hometown == nil

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

    hometown = settings.hometown if hometown == nil

    DRCT.walk_to(get_data('town')[hometown]['deposit']['id'])
    DRC.release_invisibility
    DRC.bput('wealth', 'Wealth:')
    case DRC.bput('deposit all', 'you drop all your', 'You hand the clerk some coins', "You don't have any", 'There is no teller here', 'reached the maximum balance I can permit', 'You find your jar with little effort', 'Searching methodically through the shelves')
    when 'There is no teller here'
      return
    end
    minimize_coins(keep_copper).each { |amount| withdraw_exact_amount?(amount, settings) } if settings.hometown == hometown
    case DRC.bput('check balance', /current balance is .*? (?:Kronars?|Dokoras?|Lirums?)\."$/,
                  /If you would like to open one, you need only deposit a few (?:Kronars?|Dokoras?|Lirums?)\."$/,
                  /As expected, there are .*? (?:Kronars?|Dokoras?|Lirums?)\.$/,
                  'Perhaps you should find a new deposit jar for your financial needs.  Be sure to mark it with your name')
    when /current balance is (?<balance>.*?) (?<currency>Kronars?|Dokoras?|Lirums?)\."$/,
         /As expected, there are (?<balance>.*?) (?<currency>Kronars?|Dokoras?|Lirums?)\.$/
      currency = Regexp.last_match(:currency)
      balance = 0
      Regexp.last_match(:balance).gsub(/and /, '').split(', ').each do |amount_as_string|
        amount, denomination = amount_as_string.split()
        balance += convert_to_copper(amount, denomination)
      end
    when /If you would like to open one, you need only deposit a few (?<currency>Kronars?|Dokoras?|Lirums?)\."$/
      balance = 0
      currency = Regexp.last_match(:currency)
    when /Perhaps you should find a new deposit jar/
      balance = 0
      currency = 'Dokoras'
    end
    return balance, currency
  end

  def town_currency(town)
    get_data('town')[town]['currency']
  end
end
end
end
