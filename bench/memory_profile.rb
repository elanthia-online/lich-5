# frozen_string_literal: true

# bench/memory_profile.rb -- synthesize a "normal run" against the real Lich
# code paths and measure memory at each phase.
#
# Strategy (chosen for deterministic, attributable accounting):
#   * Drive the server->parse->script->hook pipeline SYNCHRONOUSLY by calling
#     Game.process_server_string in a loop, so the exact number of lines
#     processed before each RSS sample is known. (We deliberately do NOT spawn
#     the live @main_thread orchestrator; see bench/lich_env.rb.)
#   * Exercise the thread-id-keyed leaks (Buffer/SharedBuffer indices, hooks,
#     watchfors) with REAL Script thread churn -- the way they actually
#     accumulate in production.
#
# Phases are sampled separately so the static footprint (e.g. the ~46k-line
# critrank tables loaded by GameLoader) is distinguishable from steady-state
# growth.
#
# Usage:
#   bundle exec ruby bench/memory_profile.rb
#   ITER=5000 NPCS=20000 CHURN=500 CENSUS=1 bundle exec ruby bench/memory_profile.rb
#
# Env knobs:
#   ITER         server-string ticks to feed         (default 2000)
#   SAMPLE_EVERY sample interval within stream phase  (default 500)
#   NPCS         unique NPCs to push at GameObj index (default 5000)
#   CHURN        start/kill Script cycles             (default 200)
#   CENSUS       1 = walk ObjectSpace for class diff  (default 0)

require_relative 'memory_sampler'
require_relative 'lich_env'

sampler = Bench::MemorySampler.new

# These knobs are loop counts and modulo divisors (SAMPLE_EVERY/NPCS/CHURN feed
# the per-phase sample intervals), so a zero or negative value would
# ZeroDivisionError mid-run. Reject it up front with a clear message.
def positive_env_int(name, default)
  value = Integer(ENV.fetch(name, default))
  raise ArgumentError, "#{name} must be > 0 (got #{value})" unless value.positive?
  value
end

ITER         = positive_env_int('ITER', 2000)
SAMPLE_EVERY = positive_env_int('SAMPLE_EVERY', 500)
NPCS         = positive_env_int('NPCS', 5000)
CHURN        = positive_env_int('CHURN', 200)
CENSUS       = ENV['CENSUS'].to_s == '1'

# ---------------------------------------------------------------------------
# Phase 0/1/2 -- boot the real subsystems and pay the static cost
# ---------------------------------------------------------------------------
sampler.sample('0. process start (pre-boot)')

Bench::LichEnv.boot!
XMLData.game = 'GS' if XMLData.respond_to?(:game=)
XMLData.name = 'Benchchar' if XMLData.respond_to?(:name=)
sampler.sample('1. after core require')

Bench::LichEnv.load_gemstone!
sampler.sample('2. after GameLoader (GS trackers)', gc: true)

census_before = sampler.class_census if CENSUS

# ---------------------------------------------------------------------------
# Synthetic GS server stream. One "tick" is a handful of chunks resembling a
# few seconds of play: vitals, room, a creature appearing (unique exist id so
# the GameObj index sees fresh entries), combat, a crit line, prompt/roundtime.
# ---------------------------------------------------------------------------
def stream_tick(i)
  id = 7_000_000 + i
  rt = 1_718_000_000 + i
  [
    "<dialogData id='minivitals'><progressBar id='health' value='100' text='health 100/100'/>" \
      "<progressBar id='mana' value='80' text='mana 80/100'/>" \
      "<progressBar id='stamina' value='90' text='stamina 90/100'/>" \
      "<progressBar id='spirit' value='100' text='spirit 100/100'/></dialogData>\r\n",
    "<streamWindow id='room' title='Room' subtitle=\" - [Town Square, Central]\" location='center' target='drop'/>\r\n",
    "<component id='room desc'>This is a busy intersection of the town.</component>\r\n",
    "<component id='room objs'>You also see <pushBold/><a exist=\"#{id}\" noun=\"kobold\">a snarling kobold</a><popBold/> and a stone bench.</component>\r\n",
    "<pushStream id=\"combat\" /><a exist=\"#{id}\" noun=\"kobold\">a snarling kobold</a> swings a club at you!<popStream id=\"combat\" />\r\n",
    "Hair stands on end.\r\n",
    "<pushBold/>A <a exist=\"#{id}\" noun=\"kobold\">snarling kobold</a><popBold/> crumples to the ground, dead.\r\n",
    "<roundTime value='#{rt}'/>\r\n",
    "<prompt time=\"#{rt}\">&gt;</prompt>\r\n",
  ]
end

# ---------------------------------------------------------------------------
# Phase 3 -- steady-state stream
# ---------------------------------------------------------------------------
Game = Lich::GameBase::Game
processed = 0
ITER.times do |i|
  stream_tick(i).each do |chunk|
    Game.process_server_string(chunk.dup)
    processed += 1
  end
  if ((i + 1) % SAMPLE_EVERY).zero?
    sampler.sample("3. stream tick #{i + 1}/#{ITER}")
  end
end
sampler.sample('3z. stream end (post-GC)', gc: true)
puts "fed #{processed} server-string chunks across #{ITER} ticks"

# ---------------------------------------------------------------------------
# Phase 4 -- GameObj identity index growth (the flagged unbounded @@index).
# Calls the same production API the parser uses, with unique ids.
# ---------------------------------------------------------------------------
NPCS.times do |i|
  GameObj.new_npc((9_000_000 + i).to_s, 'wraith', "wraith ##{i}")
  sampler.sample("4. gameobj index #{i + 1}/#{NPCS}") if ((i + 1) % (NPCS / 4.0).ceil).zero?
end
idx = GameObj.class_variable_get(:@@index) rescue nil
sampler.sample('4z. gameobj index end (post-GC)', gc: true)
puts "GameObj @@index size: #{idx ? idx.size : 'n/a'}"

# ---------------------------------------------------------------------------
# Phase 5 -- real Script thread churn (hooks + watchfor + thread-keyed buffers)
# ---------------------------------------------------------------------------
churn_lic = File.join(SCRIPT_DIR, 'memchurn.lic')
File.write(churn_lic, <<~'LIC')
  # throwaway churn script: registers a downstream hook + a watchfor, then
  # falls off the end so the script dies and runs its kill cleanup. Exercises
  # the hook registry, per-script @watchfor, and thread-id-keyed buffer indices.
  # The hook declares persist: false (scoped to this script), so the kill path
  # removes it -- without that it would be retained by default and inflate the
  # phase-5 hook count, masking whether cleanup actually fires.
  DownstreamHook.add("memchurn-#{Time.now.to_f}-#{rand(1_000_000)}", proc { |server_string| server_string }, persist: false)
  Lich::Common::Watchfor.new(/this pattern never matches anything zzzz/) { nil }
LIC

started = 0
CHURN.times do |i|
  ok = Script.start('memchurn', :force => true) rescue nil
  started += 1 if ok
  # let the script run + exit; feed a couple lines so hooks/watchfors execute
  20.times do
    Game.process_server_string("<prompt time=\"1\">&gt;</prompt>\r\n")
    break unless Script.running?('memchurn')
    sleep 0.005
  end
  if ((i + 1) % (CHURN / 4.0).ceil).zero?
    sampler.sample("5. script churn #{i + 1}/#{CHURN}")
  end
end
sampler.sample('5z. script churn end (post-GC)', gc: true)
puts "started #{started}/#{CHURN} churn scripts; downstream hooks now: " \
     "#{Lich::Common::DownstreamHook.class_variable_get(:@@downstream_hooks).size rescue 'n/a'}"

# ---------------------------------------------------------------------------
# Final report
# ---------------------------------------------------------------------------
sampler.sample('6. final (post-GC)', gc: true)
sampler.report

if CENSUS
  census_after = sampler.class_census
  sampler.report_census(census_before, census_after)
end
