#!/usr/bin/env ruby
# frozen_string_literal: true

# extract.rb - turn a ;logxml capture into a stream-replay fixture.
#
#   ruby spec/support/stream_replay/extract.rb LOG OUT --game DR --char NAME \
#        [--from N] [--to N] [--keep NAME,...] [--scrub-names FILE] \
#        [--real-login] [--drop-settings-body] [--end-prompt]
#
# Cleaning, in order:
#   1. drop everything up to logxml's "full logging now active" marker (reget
#      replay is out of order and partial), plus logxml's own date header and
#      trailing timestamp lines. A log with no marker (one that starts at a
#      login, or a window already cut from a longer log) is kept whole;
#   2. strip the per-line "YYYY-MM-DD HH:MM:SS TZ: " prefix;
#   3. drop "<!-- CLIENT -->...<!-- ENDCLIENT -->" lines (upstream echoes, not
#      server output);
#   4. keep cleaned lines --from..--to (1-based, inclusive), snapped outward to
#      prompt boundaries;
#   5. pseudonymize: every player name (a negative-exist <a> noun, the logging
#      character, names in "Also here:" lists, whisper/speech speakers, the group
#      stream, and any name listed in --scrub-names) is replaced by a stable fake
#      name, word-bounded, everywhere; account names are replaced by ACCOUNT.
#      Names are collected from the whole cleaned log, not just the window.
#      Names in --keep are left alone unless also listed in --scrub-names.
#
# The fixture gets a synthetic login header (settingsInfo/app char) so Lich
# identifies the game and character and autostarts the replay probe.
#
# Options for a window that starts at a real login:
#   --real-login          keep the login's own lines instead of the synthetic
#                         header. The header then ends one line after the
#                         login's <app char=...> line (Lich starts the probe on
#                         the line after it); a window without one gets a
#                         synthetic <app> line right after <settingsInfo>.
#   --drop-settings-body  reduce <settings ...>...</settings> (the stored
#                         front-end settings: highlights, presets, macros) to
#                         its empty element. No parser code reads it.
#   --end-prompt          append the driver's warm-up prompt when the window
#                         ends without a prompt (a window that runs to the end
#                         of a partial log), so its last lines get a snapshot.
#
# NOTE: logxml records strings after GameInstance#clean_serverstring, so a
# fixture is post-clean input. Re-cleaning is idempotent for the transforms
# clean_serverstring applies today; keep that in mind when changing them.

require 'optparse'

module StreamReplay
  class Extract
    LOGGING_ACTIVE = '<!-- Above contents from reget; full logging now active -->'
    TS_PREFIX = /\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d(?:\.\d+)? [A-Z+\-:\d]+: /
    LOG_DATE_HEADER = /\A\d{4}-\d\d-\d\d \d{1,2}:\d\d[ap]m\s*\z/
    LOG_TRAILER = /\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+ [+\-]\d\d:\d\d\s*\z/
    CLIENT_ECHO = /<!-- CLIENT -->/
    MARKER = '### stream-replay:body-below ###'
    END_PROMPT = '<prompt time="0">&gt;</prompt>'
    SETTINGS_BODY = %r{(<settings\b[^>]*>).*?</settings>}
    PSEUDONYMS = %w[
      Aldric Brenna Corwin Delphine Edric Fiora Gareth Helsa Ivor Jessamy Kael Liora
      Maddoc Nerys Orrin Perrin Quenna Rhosyn Sabine Tamsin Ulric Vesna Wystan Yselde
      Zarek Anwen Bastian Calla Dorian Elowen Faelan Gwyn Haldor Isolde Jory Kerrin
    ].freeze

    def initialize(game:, char:, from: nil, to: nil, keep: [], scrub: [],
                   real_login: false, drop_settings_body: false, end_prompt: false)
      @game = game
      @char = char
      @from = from
      @to = to
      @keep = keep
      @scrub = scrub
      @real_login = real_login
      @drop_settings_body = drop_settings_body
      @end_prompt = end_prompt
    end

    def call(raw)
      cleaned = clean(raw.lines)
      lines = cleaned[window(cleaned)]
      # Names are collected from the whole log, not just the window: a player
      # identified only outside the window (a link, an "Also here:" list) can
      # still be named in plain text inside it. In-window names come first so
      # their pseudonyms don't depend on the rest of the log. --scrub-names
      # always wins over --keep.
      names = (collect_names(lines) | collect_names(cleaned)) - (@keep - @scrub)
      map = names.each_with_index.to_h { |n, i| [n, PSEUDONYMS.fetch(i) { "Player#{i + 1}" }] }
      char_alias = map.fetch(@char, @char)
      body = lines.map { |l| scrub(l, map) }
      body.map! { |l| l.sub(SETTINGS_BODY, '\1</settings>') } if @drop_settings_body
      body << "#{END_PROMPT}\n" if @end_prompt && !body.last.to_s.include?('<prompt')
      return split_real_login(body, char_alias) if @real_login

      header(char_alias) + "#{MARKER}\n" + body.join
    end

    private

    # Snaps --from/--to outward to prompt boundaries: the window starts just
    # after the prompt preceding --from and ends on the first prompt at or after
    # --to, so a fixture never begins or ends inside a server burst.
    #
    # @raise [ArgumentError] if --from is outside the cleaned log or --to
    #   precedes it
    def window(lines)
      from = (@from || 1) - 1
      to = (@to || lines.length) - 1
      unless from.between?(0, lines.length - 1)
        raise ArgumentError, "--from #{from + 1} is outside the #{lines.length} cleaned lines"
      end
      raise ArgumentError, "--to #{to + 1} is before --from #{from + 1}" if to < from

      from -= 1 while from.positive? && !lines[from - 1].include?('<prompt')
      to += 1 while to < lines.length - 1 && !lines[to].include?('<prompt')
      from..to
    end

    def clean(lines)
      start = lines.index { |l| l.include?(LOGGING_ACTIVE) }
      lines = lines.drop(start + 1) if start
      lines.filter_map do |l|
        next if l.match?(LOG_DATE_HEADER) || l.match?(LOG_TRAILER)

        l = l.sub(TS_PREFIX, '')
        next if l.match?(CLIENT_ECHO)

        l
      end
    end

    def collect_names(lines)
      names = [@char]
      lines.each do |l|
        l.scan(/<a exist="-\d+" noun="([A-Z][a-z']+)"/) { |(n)| names << n }
        l.scan(/<preset id=['"](?:whisper|speech)['"]>(?:<a [^>]*>)?([A-Z][a-z']+)/) { |(n)| names << n }
        if (m = l.match(/Also here: (.*?)(?:<\/component>|\.?\s*\z)/))
          # The list ends with a period ("... and X.</component>"); drop it so
          # the last entry is a bare name like the others.
          plain = m[1].gsub(/<[^>]+>/, '').sub(/\.\s*\z/, '')
          plain.split(/, | and /).each do |entry|
            entry = entry.sub(/ who .*\z/, '').sub(/ \(.*\)\z/, '').strip
            last = entry.split.last
            names << last if last&.match?(/\A[A-Z][a-z']+\z/)
          end
        end
        l.scan(%r{<pushStream id="group"/>\s+([A-Z][a-z']+)[ :(]}) { |(n)| names << n }
      end
      text = lines.join
      names += @scrub.select { |n| text.match?(/\b#{Regexp.escape(n)}\b/) }
      names.uniq - %w[You Also Members There]
    end

    def scrub(line, map)
      line = line.gsub(/(Account Info for )[A-Z0-9_]+/, '\1ACCOUNT')
      return line if map.empty?

      line.gsub(/\b(#{map.keys.map { |n| Regexp.escape(n) }.join('|')})\b/) { map[Regexp.last_match(1)] }
    end

    # The header is sent before the probe starts, so it has to run one line
    # past the login's <app char=...> line: Lich starts --start-scripts on the
    # first line after the one that names the character.
    #
    # @raise [ArgumentError] if the window has no <settingsInfo>, or nothing
    #   follows the <app> line
    def split_real_login(body, char)
      info = body.index { |l| l.include?('<settingsInfo') }
      raise ArgumentError, '--real-login: the window has no <settingsInfo>' unless info

      lines = body.dup
      lines.insert(info + 1, "#{app_line(char)}\n") unless lines.any? { |l| l.include?('<app char=') }
      last = lines.index { |l| l.include?('<app char=') } + 1
      raise ArgumentError, '--real-login: nothing follows the <app> line' if last >= lines.length

      lines[0..last].join + "#{MARKER}\n" + lines[(last + 1)..].join
    end

    def app_line(char)
      title = @game == 'DR' ? "[DR: #{char}]" : "GemStone IV: #{char}"
      %(<app char="#{char}" game="#{@game}" title="#{title}"/>)
    end

    def header(char)
      instance = @game == 'DR' ? 'DR' : 'GS4'
      <<~XML
        <mode id="GAME"/>
        <playerID id='700001'/>
        <settingsInfo  client="1.0.1.28" major="32" crc='1009451187' instance='#{instance}'/>
        #{app_line(char)}
        <streamWindow id="main" title="Story" location="center" target="drop" resident="true"/>
        <endSetup/>
      XML
    end
  end
end

if $PROGRAM_NAME == __FILE__
  opts = { keep: [] }
  OptionParser.new do |o|
    o.banner = 'Usage: extract.rb LOG OUT --game DR|GS --char NAME [--from N] [--to N] [--keep A,B] ' \
               '[--scrub-names FILE] [--real-login] [--drop-settings-body] [--end-prompt]'
    o.on('--game G') { |v| opts[:game] = v }
    o.on('--char C') { |v| opts[:char] = v }
    o.on('--from N', Integer) { |v| opts[:from] = v }
    o.on('--to N', Integer) { |v| opts[:to] = v }
    o.on('--keep LIST') { |v| opts[:keep] = v.split(',') }
    # One name per line; always pseudonymized when present. Keep this file out
    # of the repo: it exists so real character names never get committed.
    o.on('--scrub-names FILE') { |v| opts[:scrub] = File.readlines(v, chomp: true).reject(&:empty?) }
    o.on('--real-login') { opts[:real_login] = true }
    o.on('--drop-settings-body') { opts[:drop_settings_body] = true }
    o.on('--end-prompt') { opts[:end_prompt] = true }
  end.parse!
  log, out = ARGV
  abort 'LOG and OUT are required' unless log && out && opts[:game] && opts[:char]
  begin
    File.write(out, StreamReplay::Extract.new(**opts).call(File.read(log)))
  rescue ArgumentError => e
    abort e.message
  end
end
