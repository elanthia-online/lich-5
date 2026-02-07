module Lich
  module DragonRealms
    module DRCM
      # Coin denominations ordered from highest to lowest value.
      # Each entry is [copper_multiplier, name].
      DENOMINATIONS = [
        [10_000, 'platinum'],
        [1000, 'gold'],
        [100, 'silver'],
        [10, 'bronze'],
        [1, 'copper']
      ].freeze

      # Maps denomination names to their copper multiplier.
      DENOMINATION_VALUES = {
        'platinum' => 10_000,
        'gold'     => 1000,
        'silver'   => 100,
        'bronze'   => 10,
        'copper'   => 1
      }.freeze

      # Regex abbreviations for coin denominations.
      # Supports in-game abbreviations (e.g., "p" for platinum, "g" for gold).
      DENOMINATION_REGEX_MAP = {
        'platinum' => /\bp(l|la|lat|lati|latin|latinu|latinum)?\b/i,
        'gold'     => /\bg(o|ol|old)?\b/i,
        'silver'   => /\bs(i|il|ilv|ilve|ilver)?\b/i,
        'bronze'   => /\bb(r|ro|ron|ronz|ronze)?\b/i,
        'copper'   => /\bc(o|op|opp|oppe|opper)?\b/i
      }.freeze

      # Regex abbreviations for currency types.
      # Supports in-game abbreviations (e.g., "k" for kronars, "l" for lirums).
      CURRENCY_REGEX_MAP = {
        'kronars' => /\bk(r|ro|ron|rona|ronar|ronars)?\b/i,
        'lirums'  => /\bl(i|ir|iru|irum|irums)?\b/i,
        'dokoras' => /\bd(o|ok|oko|okor|okora|okoras)?\b/i
      }.freeze

      # Canonical currency names for abbreviation resolution.
      CURRENCIES = %w[kronars lirums dokoras].freeze

      # Exchange rates between DR currencies.
      # Usage: EXCHANGE_RATES[from_currency][to_currency]
      EXCHANGE_RATES = {
        'dokoras' => {
          'dokoras' => 1,
          'kronars' => 1.385808991,
          'lirums'  => 1.108646953
        }.freeze,
        'kronars' => {
          'dokoras' => 0.7216,
          'kronars' => 1,
          'lirums'  => 0.8
        }.freeze,
        'lirums'  => {
          'dokoras' => 0.902,
          'kronars' => 1.25,
          'lirums'  => 1
        }.freeze
      }.freeze

      # Regex for parsing copper values from wealth output.
      # Named captures: :coppers, :currency
      WEALTH_COPPER_REGEX = /\((?<coppers>\d+) copper (?<currency>kronars|lirums|dokoras)\)/i.freeze
    end
  end

  # Backward compatibility — global variable aliases for third-party scripts
  $DENOMINATION_REGEX_MAP = DragonRealms::DRCM::DENOMINATION_REGEX_MAP
  $CURRENCY_REGEX_MAP = DragonRealms::DRCM::CURRENCY_REGEX_MAP
end
