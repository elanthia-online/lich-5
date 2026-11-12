# frozen_string_literal: true

require_relative 'support/example_timeout'
require 'open3'
require 'rbconfig'

# Regression guard (PR #1813 review item 2, v0.26.2): every Genie golden that reads a wall clock
# must hold in ANY process time zone. The goldens were recorded at UTC+13 (the dev machine's
# NZDT), and a spec clock built with Time.local made them pass only there -- CI (UTC) was red.
# A spec cannot set ENV['TZ'] (a process-wide global, shared with every other example), so this
# re-runs the wall-clock cases in rspec SUBPROCESSES, each with its own TZ, chosen to differ
# from +13:00 and from each other: America/New_York (-05:00 in January, has a DST gap) and
# Asia/Kolkata (+05:30, a half-hour offset). A future Time.local (or Time.now / localtime) in
# a spec clock or in an engine path that formats a time fails here whatever zone CI runs in.
RSpec.describe 'Genie wall-clock goldens are time-zone independent', :slow do
  root = File.expand_path('../../..', __dir__)
  files = %w[flow_parity_spec.rb game_state_spec.rb net_date_spec.rb interpreter_errors_spec.rb interpreter_eval_spec.rb
             command_router_spec.rb].map { |f| File.join(root, 'spec/lib/genie', f) }
  # Each filter is a substring of exactly one example's full description.
  filters = ['t45_unixtime_prompt', 't91_date_specials', 't92_spell_specials',
             'leaves every reserved variable where Remix leaves it',
             'checks the roundtime end against the injected clock',
             'returns the naive parsed fields whatever the process zone',
             'measures a setstart date inside a DST gap',
             'reads @timer@ with no timer as the seconds since 0001-01-01',
             'checks the year-9999 bound against the injected wall clock',
             '#log names and heads the daily log from the injected wall clock']

  def run_in_zone(root, files, filters, zone)
    cmd = [RbConfig.ruby, Gem.bin_path('rspec-core', 'rspec'), *files, '--no-color', '--format', 'progress',
           '--order', 'defined', *filters.flat_map { |f| ['-e', f] }]
    Open3.capture2e({ 'TZ' => zone }, *cmd, chdir: root)
  end

  it 'runs the date / unixtime / timer goldens green under TZ=America/New_York and TZ=Asia/Kolkata' do
    results = %w[America/New_York Asia/Kolkata].map { |zone| [zone, Thread.new { run_in_zone(root, files, filters, zone) }] }
    results.each do |zone, worker|
      output, status = worker.value
      summary = output[/^\d+ examples?, \d+ failures?.*$/]
      expect([zone, summary, status.success?]).to eq([zone, "#{filters.length} examples, 0 failures", true]), output
    end
  end
end
