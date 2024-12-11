module Lich
  module DragonRealms

def convert2copper(amt, denomination)
  if denomination =~ /platinum/
    (amt.to_i * 10_000)
  elsif denomination =~ /gold/
    (amt.to_i * 1000)
  elsif denomination =~ /silver/
    (amt.to_i * 100)
  elsif denomination =~ /bronze/
    (amt.to_i * 10)
  else
    amt
  end
end

def check_exp_mods
  Lich::Util.issue_command("exp mods", /The following skills are currently under the influence of a modifier/, /^<output class=""/, quiet: true, include_end: false, usexml: false)
end

def convert2plats(copper)
  denominations = [[10_000, 'platinum'], [1000, 'gold'], [100, 'silver'], [10, 'bronze'], [1, 'copper']]
  denominations.inject([copper, []]) do |result, denomination|
    remaining = result.first
    display = result.last
    if remaining / denomination.first > 0
      display << "#{remaining / denomination.first} #{denomination.last}"
    end
    [remaining % denomination.first, display]
  end.last.join(', ')
end

def clean_and_split(room_objs)
  room_objs.sub(/You also see/, '').sub(/ with a [\w\s]+ sitting astride its back/, '').strip.split(/,|\sand\s/)
end

def find_pcs(room_players)
  room_players.sub(/ and (.*)$/) { ", #{Regexp.last_match(1)}" }
              .split(', ')
              .map { |obj| obj.sub(/ (who|whose body)? ?(has|is|appears|glows) .+/, '').sub(/ \(.+\)/, '') }
              .map { |obj| obj.strip.scan(/\w+$/).first }
end

def find_pcs_prone(room_players)
  room_players.sub(/ and (.*)$/) { ", #{Regexp.last_match(1)}" }
              .split(', ')
              .select { |obj| obj =~ /who is lying down/i }
              .map { |obj| obj.sub(/ who (has|is) .+/, '').sub(/ \(.+\)/, '') }
              .map { |obj| obj.strip.scan(/\w+$/).first }
end

def find_pcs_sitting(room_players)
  room_players.sub(/ and (.*)$/) { ", #{Regexp.last_match(1)}" }
              .split(', ')
              .select { |obj| obj =~ /who is sitting/i }
              .map { |obj| obj.sub(/ who (has|is) .+/, '').sub(/ \(.+\)/, '') }
              .map { |obj| obj.strip.scan(/\w+$/).first }
end

def find_npcs(room_objs)
  room_objs.sub(/You also see/, '').sub(/ with a [\w\s]+ sitting astride its back/, '').strip
           .scan(%r{<pushBold/>[^<>]*<popBold/> which appears dead|<pushBold/>[^<>]*<popBold/> \(dead\)|<pushBold/>[^<>]*<popBold/>})
           .reject { |obj| obj =~ /which appears dead|\(dead\)/ }
           .map { |obj| obj.sub(/.*alfar warrior.*/, 'alfar warrior') }
           .map { |obj| obj.sub(/.*sinewy leopard.*/, 'sinewy leopard') }
           .map { |obj| obj.sub(/.*lesser naga.*/, 'lesser naga') }
           .map { |obj| obj.sub('<pushBold/>', '').sub(%r{<popBold/>.*}, '') }
           .map { |obj| obj.split(/\sand\s/).last.sub(/(?:\sglowing)?\swith\s.*/, '') }
           .map { |obj| obj.strip.scan(/[A-z'-]+$/).first }
end

def find_dead_npcs(room_objs)
  room_objs.sub(/You also see/, '').sub(/ with a [\w\s]+ sitting astride its back/, '')
           .strip.scan(%r{<pushBold/>[^<>]*<popBold/> which appears dead|<pushBold/>[^<>]*<popBold/> \(dead\)|<pushBold/>[^<>]*<popBold/>})
           .select { |obj| obj =~ /which appears dead|\(dead\)/ }
           .map { |obj| obj.sub('<pushBold/>', '').sub(%r{<popBold/>.*}, '') }
           .map { |obj| obj.split(/\sand\s/).last.sub(/(?:\sglowing)?\swith\s.*/, '') }
           .map { |obj| obj.strip.scan(/[A-z'-]+$/).first }
end

def find_objects(room_objs)
  room_objs.sub!("<pushBold/>a domesticated gelapod<popBold/>", 'domesticated gelapod')
  clean_and_split(room_objs)
    .reject { |obj| obj =~ /pushBold/ }
    .map { |obj| obj.sub(/\.$/, '').strip.sub(/^a /, '').strip.sub(/^some /, '') }
end
end
end
