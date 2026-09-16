# frozen_string_literal: true

require File.join(LIB_DIR, 'common', 'xml_entities.rb')

module Lich
  module Common
    # Frontend markup translation for the server stream.
    #
    # Four concerns, all string-in/string-out:
    #
    #   * +fb_to_sf+  - normalizes a client line on the way upstream
    #   * +sf_to_wiz+ - rewrites a StormFront/XML line into the GSL escape
    #                   vocabulary an old Wizard frontend understands
    #   * +strip_xml+ - removes markup entirely, for scripts that want text
    #   * +monsterbold_*+ - the emphasis pair for whatever frontend is attached
    #
    # Lifted out of global_defs.rb, where it could not be unit-tested: that
    # file cannot be required from a spec without redefining the whole
    # script-facing DSL (respond, get, put...) against production game
    # infrastructure. The six global wrappers remain in global_defs.rb and
    # delegate here, because scripts in the wild call them unqualified.
    #
    # State note: sf_to_wiz and strip_xml both carry unterminated markup
    # across calls, because a pushStream element can be split over two reads.
    # Those buffers stay in the process-globals they have always lived in
    # ($sftowiz_multiline, $strip_xml_multiline) rather than becoming module
    # state -- games.rb clears $strip_xml_multiline directly on reconnect
    # (see games.rb:435), and that remains a supported reach-in.
    module Markup
      # Streams whose content is presented elsewhere in the frontend (the
      # spell window, the inventory pane) and so must not be echoed inline.
      SUPPRESSED_STREAMS = /<pushStream id=["'](?:spellfront|inv|bounty|society|reserve|speech|talk)["'][^>]*\/>.*?<popStream[^>]*>/m.freeze
      SPELLS_STREAM      = /<stream id="Spells">.*?<\/stream>/m.freeze
      # Paired elements carrying data for the status bars, not prose.
      DATA_ELEMENTS      = /<(compDef|inv|component|right|left|spell|prompt)[^>]*>.*?<\/\1>/m.freeze
      ANY_TAG            = /<[^>]+>/.freeze

      class << self
        # Normalize a line arriving from the client.
        #
        # @param line [String] one client line
        # @return [String, nil] the line with <c> removed, or nil when
        #   nothing printable remains
        def fb_to_sf(line)
          return line if line == "\r\n"

          line = line.gsub(/<c>/, "")
          return nil if line.gsub("\r\n", '').length < 1

          line
        rescue StandardError
          report_error('fb_to_sf', line)
          nil
        end

        # Rewrite an XML server line into the GSL escapes a Wizard-family
        # frontend understands.
        #
        # @param line [String] one server line
        # @param bypass_multiline [Boolean] skip the split-element buffer.
        #   Callers synthesizing a whole line of their own (messaging.rb)
        #   pass true so a stray unbalanced tag cannot swallow it.
        # @return [String, nil] nil while buffering a split element, or when
        #   nothing printable remains
        def sf_to_wiz(line, bypass_multiline: false)
          return line if line == "\r\n"

          unless bypass_multiline
            line = buffer_sf_multiline(line)
            return nil if line.nil?
          end

          line = translate_launch_url(line)
          line = translate_speech(line)
          line = translate_thoughts(line)
          line = translate_voln(line)
          line = translate_familiar(line)
          line = translate_death(line)
          line = translate_room(line)
          line = translate_bold(line)

          line = line.gsub(SUPPRESSED_STREAMS, '')
          line = line.gsub(SPELLS_STREAM, '')
          line = line.gsub(DATA_ELEMENTS, '')
          line = line.gsub(ANY_TAG, '')
          line = line.gsub('&gt;', '>').gsub('&lt;', '<').gsub('&amp;', '&')
          return nil if line.gsub("\r\n", '').length < 1

          line
        rescue StandardError
          report_error('sf_to_wiz', line)
          nil
        end

        # Strip game markup from a server-stream fragment.
        #
        # @param line [String] one server-stream fragment
        # @param type [String, Symbol, nil] optional multiline buffer key.
        #   When nil the fragment is stripped statelessly. When given,
        #   unfinished pushStream content accumulates in a type-keyed buffer
        #   until a balancing popStream arrives, so an element split across
        #   reads is reassembled before stripping.
        # @return [String, nil] nil when nothing printable remains, or while
        #   a typed fragment is still being accumulated
        def strip_xml(line, type: nil)
          type.nil? ? strip_simple(line) : strip_multiline(line, type)
        end

        # ::Frontend is explicit for readability, not to fix a resolution
        # hazard: Lich::Common owns Frontend directly (frontend.rb:18), so a
        # bare name here would find Lich::Common::Frontend by lexical scope,
        # and frontend.rb:928 aliases the top-level constant to that same
        # object. All three spellings resolve identically. The qualifier just
        # names which one at the call site.

        # @return [String] frontend-appropriate emphasis open
        def monsterbold_start
          if ::Frontend.supports_gsl?    then "\034GSL\r\n"
          elsif ::Frontend.supports_xml? then '<pushBold/>'
          else                                ''
          end
        end

        # @return [String] frontend-appropriate emphasis close
        def monsterbold_end
          if ::Frontend.supports_gsl?    then "\034GSM\r\n"
          elsif ::Frontend.supports_xml? then '<popBold/>'
          else                                ''
          end
        end

        private

        def strip_simple(line)
          return nil if line == "\r\n" # short-circuit empty links

          line = line.gsub(SUPPRESSED_STREAMS, '')
          line = line.gsub(SPELLS_STREAM, '')
          line = line.gsub(DATA_ELEMENTS, '')
          line = line.gsub(ANY_TAG, '')
          line = Lich::Common::XmlEntities.decode(line)

          return nil if line.match?(/\A\s*\z/)

          line
        end

        def strip_multiline(line, type)
          $strip_xml_multiline ||= {}
          line = $strip_xml_multiline[type] + line if $strip_xml_multiline[type]
          if unbalanced_stream?(line)
            $strip_xml_multiline[type] = line
            return nil
          end
          $strip_xml_multiline[type] = nil
          strip_simple(line)
        end

        # Accumulate until both pushStream and style elements balance.
        # Returns nil while still buffering.
        def buffer_sf_multiline(line)
          if $sftowiz_multiline
            $sftowiz_multiline += line
            line = $sftowiz_multiline
          end
          if unbalanced_stream?(line) || unbalanced_style?(line)
            $sftowiz_multiline = line
            return nil
          end
          $sftowiz_multiline = nil
          line
        end

        def unbalanced_stream?(line)
          line.scan(/<pushStream[^>]*\/>/).length > line.scan(/<popStream[^>]*\/>/).length
        end

        def unbalanced_style?(line)
          line.scan(/<style id="\w+"[^>]*\/>/).length > line.scan(/<style id=""[^>]*\/>/).length
        end

        # The frontend cannot render a LaunchURL, so the link is pushed to
        # the client as a plain play.net URL on its own GSL channel.
        def translate_launch_url(line)
          $_CLIENT_.puts "\034GSw00005\r\nhttps://www.play.net#{$1}\r\n" if line =~ /<LaunchURL src="(.*?)" \/>/
          line
        end

        def translate_speech(line)
          return line unless line =~ /<preset id='speech'>(.*?)<\/preset>/m

          line.sub(/<preset id='speech'>.*?<\/preset>/m,
                   "#{$speech_highlight_start}#{$1}#{$speech_highlight_end}")
        end

        def translate_thoughts(line)
          if line =~ /<pushStream id="thoughts"[^>]*>\[([^\\]+?)\]\s*(.*?)<popStream\/>/m
            # Bind both captures before touching either: gsub runs a match of
            # its own, which resets $~ and would blank the capture not yet read.
            channel, msg = $1, $2
            channel = channel.gsub(' ', '-')
            msg = msg.gsub('<pushBold/>', '').gsub('<popBold/>', '')
            line = line.sub(/<pushStream id="thoughts".*<popStream\/>/m,
                            "You hear the faint thoughts of [#{channel}]-ESP echo in your mind:\r\n#{msg}")
          end
          if line =~ /<stream id="thoughts"[^>]*>([^:]+): (.*?)<\/stream>/m
            line = line.sub(/<stream id="thoughts"[^>]*>.*?<\/stream>/m,
                            "You hear the faint thoughts of #{$1} echo in your mind:\r\n#{$2}")
          end
          line
        end

        VOLN = /<pushStream id="voln"[^>]*>\[Voln \- (?:<a[^>]*>)?([A-Z][a-z]+)(?:<\/a>)?\]\s*(".*")[\r\n]*<popStream\/>/m.freeze

        def translate_voln(line)
          return line unless line =~ VOLN

          line.sub(VOLN,
                   "The Symbol of Thought begins to burn in your mind and you hear #{$1} thinking, #{$2}\r\n")
        end

        def translate_familiar(line)
          return line unless line =~ /<pushStream id="familiar"[^>]*>(.*)<popStream\/>/m

          line.sub(/<pushStream id="familiar"[^>]*>.*<popStream\/>/m, "\034GSe\r\n#{$1}\034GSf\r\n")
        end

        def translate_death(line)
          return line unless line =~ /<pushStream id="death"\/>(.*?)<popStream\/>/m

          line.sub(/<pushStream id="death"\/>.*?<popStream\/>/m, "\034GSw00003\r\n#{$1}\034GSw00004\r\n")
        end

        def translate_room(line)
          if line =~ /<style id="roomName" \/>(.*?)<style id=""\/>/m
            line = line.sub(/<style id="roomName" \/>.*?<style id=""\/>/m, "\034GSo\r\n#{$1}\034GSp\r\n")
          end
          line = line.gsub(/<style id="roomDesc"\/><style id=""\/>\r?\n/, '')
          if line =~ /<style id="roomDesc"\/>(.*?)<style id=""\/>/m
            desc = $1.gsub(/<a[^>]*>/, $link_highlight_start).gsub("</a>", $link_highlight_end)
            line = line.sub(/<style id="roomDesc"\/>.*?<style id=""\/>/m, "\034GSH\r\n#{desc}\034GSI\r\n")
          end
          line
        end

        def translate_bold(line)
          line.gsub("</prompt>\r\n", "</prompt>")
              .gsub("<pushBold/>", "\034GSL\r\n")
              .gsub("<popBold/>", "\034GSM\r\n")
        end

        # Preserves the original behavior: report to the client and the log,
        # naming the raw server string alongside the line that failed.
        def report_error(method, line)
          $_CLIENT_.puts "--- Error: #{method}: #{$!}"
          $_CLIENT_.puts "$_SERVERSTRING_: #{$_SERVERSTRING_}"
          Lich.log("--- Error: #{method}: #{$!}\n\t#{$!.backtrace.join("\n\t")}")
          Lich.log("$_SERVERSTRING_: #{$_SERVERSTRING_}")
          Lich.log("Line: #{line}")
        end
      end
    end
  end
end
