# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../support/stream_replay/extract'

# extract.rb turns a ;logxml capture into a committed fixture, so its
# pseudonymization is what keeps real player names out of the repo.
RSpec.describe StreamReplay::Extract do
  # Cleaned line numbers (after the reget marker, date header, timestamps and
  # client echo are dropped) are noted on the right.
  let(:log) do
    <<~LOG
      2026-10-15 15:35:00 EDT: <prompt time="0">&gt;</prompt>
      <!-- Above contents from reget; full logging now active -->
      2026-10-15 3:35pm
      2026-10-15 15:35:01 -04:00: <component id='room players'>Also here: Sir Gareth and Zed.</component>
      2026-10-15 15:35:01 -04:00: <prompt time="1">&gt;</prompt>
      2026-10-15 15:35:02 -04:00: Zed nods. Gareth waves to Hero.
      2026-10-15 15:35:02 -04:00: <!-- CLIENT -->look<!-- ENDCLIENT -->
      2026-10-15 15:35:03 -04:00: <prompt time="2">&gt;</prompt>
      2026-10-15 15:35:03.5 +00:00
    LOG
  end
  # 1: Also here  2: prompt  3: Zed nods...  4: prompt

  def body(fixture)
    fixture.split("### stream-replay:body-below ###\n", 2).last
  end

  def extract(**opts)
    described_class.new(game: 'DR', char: 'Hero', **opts).call(log)
  end

  it 'pseudonymizes the character and every player found, everywhere' do
    out = extract
    expect(out).to include('<app char="Aldric"')
    expect(out).not_to match(/\b(?:Hero|Gareth|Zed)\b/)
  end

  it 'collects the last name of a legacy "Also here:" list, which ends in ".</component>"' do
    lines = ["<component id='room players'>Also here: Xavi, Universalist Yorick and Wendel (hiding).</component>\n",
             "<component id='room players'>Also here: Sir Gareth and Zed.</component>\n"]
    out = described_class.new(game: 'DR', char: 'Hero').call(lines.join)
    expect(out).not_to match(/\b(?:Wendel|Zed)\b/)
  end

  it 'strips timestamps, the reget prefix, logxml headers/trailers and client echoes' do
    lines = body(extract).lines
    expect(lines.length).to eq(4)
    expect(lines.join).not_to include('2026-10-15', 'CLIENT', 'reget')
  end

  it 'pseudonymizes a player whose identifying markup lies outside the window' do
    # The window is line 3..4; Gareth and Zed are only identified by the
    # "Also here:" list on line 1, but are named in plain text on line 3.
    out = body(extract(from: 3, to: 3))
    expect(out).to start_with('Corwin nods. Brenna waves to Aldric.')
    expect(out).not_to match(/\b(?:Gareth|Zed)\b/)
  end

  it 'keeps the pseudonyms of names found inside the window stable' do
    # Out-of-window names are appended after in-window ones, so a fixture whose
    # window already identified everyone gets the same pseudonyms as before.
    # Gareth and Zed are identified before the window (lines 1-2); Yorick is
    # identified inside it (lines 3-4), so he still gets the first pseudonym
    # after the character, ahead of the earlier out-of-window names.
    lines = ["<component id='room players'>Also here: Sir Gareth and Zed.</component>\n",
             "<prompt time=\"1\">&gt;</prompt>\n",
             "You also see <a exist=\"-7\" noun=\"Yorick\">Yorick</a>. Zed nods.\n",
             "<prompt time=\"2\">&gt;</prompt>\n"]
    out = body(described_class.new(game: 'DR', char: 'Hero', from: 3, to: 4).call(lines.join))
    expect(out).to start_with('You also see <a exist="-7" noun="Brenna">Brenna</a>. Delphine nods.')
  end

  it 'leaves names listed in --keep alone' do
    expect(body(extract(keep: ['Gareth']))).to include('Gareth waves')
  end

  it 'always pseudonymizes --scrub-names, even when also listed in --keep' do
    out = body(extract(keep: ['Gareth'], scrub: ['Gareth']))
    expect(out).not_to include('Gareth')
  end

  it 'snaps the window outward to prompt boundaries' do
    expect(body(extract(from: 3, to: 3)).lines.length).to eq(2)
    expect(body(extract(from: 2, to: 2)).lines.length).to eq(2)
  end

  it 'rejects --from 0 instead of writing an empty body' do
    expect { extract(from: 0, to: 2) }.to raise_error(ArgumentError, /--from/)
  end

  it 'rejects --from past the end of the log' do
    expect { extract(from: 99) }.to raise_error(ArgumentError, /--from/)
    # With --to also past the end, the --to/--from order check can't catch it.
    expect { extract(from: 99, to: 120) }.to raise_error(ArgumentError, /--from 99 is outside/)
  end

  it 'rejects --to before --from' do
    expect { extract(from: 3, to: 1) }.to raise_error(ArgumentError, /--to/)
  end
  it 'keeps everything when the log has no reget marker (a login, or a window cut from a longer log)' do
    no_marker = log.lines.reject { |l| l.include?('full logging now active') }.join
    out = body(described_class.new(game: 'DR', char: 'Hero').call(no_marker))
    # The first prompt, which the marker would have dropped, is kept.
    expect(out.lines.length).to eq(5)
    expect(out).to start_with('<prompt time="0">')
  end

  describe 'a window that starts at a real login' do
    let(:login) do
      <<~LOG
        2026-10-16 9:00am
        <mode id="GAME"/><settings client="1.0.1.26" major="1"><presets><p id='roomName'/></presets><vars><v name='x' value='Hero'/></vars></settings>
        <playerID id='614301'/>
        <settingsInfo  client="1.0.1.26" major="9" crc='1' instance='DR'/>
        <app char="Hero" game="DR" title="[DR: Hero] Wrayth"/>
        <streamWindow id="main" title="Story" location="center" target="drop" resident="true"/>
        <prompt time="1">&gt;</prompt>
        Hero waves.
      LOG
    end

    def split(fixture)
      fixture.split("### stream-replay:body-below ###\n", 2)
    end

    # Lich starts --start-scripts (the probe) on the line after the one that
    # names the character, and the driver waits for the probe before it sends
    # the body, so the header must include that next line.
    it 'keeps the login lines and ends the header one line after <app char> instead of adding a synthetic one' do
      header, rest = split(described_class.new(game: 'DR', char: 'Hero', real_login: true).call(login))
      expect(header.lines.length).to eq(5)
      expect(header).to include("<settingsInfo  client=\"1.0.1.26\" major=\"9\" crc='1' instance='DR'/>")
      expect(header.lines.last(2)).to eq([%(<app char="Aldric" game="DR" title="[DR: Aldric] Wrayth"/>\n),
                                          %(<streamWindow id="main" title="Story" location="center" target="drop" resident="true"/>\n)])
      expect(header).not_to include('1.0.1.28', '700001')
      expect(rest).to start_with('<prompt time="1">')
    end

    it 'adds a synthetic <app> line after <settingsInfo> when the login has none (GemStone)' do
      gs = login.lines.reject { |l| l.include?('<app ') }.join.sub("instance='DR'", "instance='GSF'")
      header, rest = split(described_class.new(game: 'GS', char: 'Hero', real_login: true).call(gs))
      expect(header.lines.last(3)).to eq(["<settingsInfo  client=\"1.0.1.26\" major=\"9\" crc='1' instance='GSF'/>\n",
                                          %(<app char="Aldric" game="GS" title="GemStone IV: Aldric"/>\n),
                                          %(<streamWindow id="main" title="Story" location="center" target="drop" resident="true"/>\n)])
      expect(rest).to start_with('<prompt time="1">')
    end

    it 'refuses a window that ends at the <app> line' do
      cut = login.lines.take(5).join
      expect { described_class.new(game: 'DR', char: 'Hero', real_login: true).call(cut) }
        .to raise_error(ArgumentError, /nothing follows/)
    end

    it 'refuses a window with no <settingsInfo>' do
      no_login = login.lines.reject { |l| l.include?('<settingsInfo') }.join
      expect { described_class.new(game: 'DR', char: 'Hero', real_login: true).call(no_login) }
        .to raise_error(ArgumentError, /--real-login/)
    end

    it 'reduces the <settings> blob to its empty element with --drop-settings-body' do
      out = described_class.new(game: 'DR', char: 'Hero', real_login: true, drop_settings_body: true).call(login)
      expect(out).to include(%(<mode id="GAME"/><settings client="1.0.1.26" major="1"></settings>\n))
      expect(out).not_to include('presets', 'vars')
    end

    it 'leaves the <settings> blob alone without --drop-settings-body' do
      expect(described_class.new(game: 'DR', char: 'Hero', real_login: true).call(login)).to include('<presets>')
    end
  end

  describe '--end-prompt' do
    let(:unfinished) { "<prompt time=\"1\">&gt;</prompt>\nYou wave.\n" }

    it 'appends the warm-up prompt when the window ends without one' do
      out = body(described_class.new(game: 'DR', char: 'Hero', end_prompt: true).call(unfinished))
      expect(out.lines.last).to eq("<prompt time=\"0\">&gt;</prompt>\n")
    end

    it 'adds nothing when the window already ends on a prompt' do
      out = body(described_class.new(game: 'DR', char: 'Hero', end_prompt: true).call(log))
      expect(out.lines.length).to eq(4)
    end

    it 'adds nothing without the option' do
      expect(body(described_class.new(game: 'DR', char: 'Hero').call(unfinished)).lines.last).to eq("You wave.\n")
    end
  end
end
