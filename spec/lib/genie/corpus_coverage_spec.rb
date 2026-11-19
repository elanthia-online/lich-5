# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Local coverage guard for the large real-world scripts we were asked to support
# (GenieHunter + Mastercraft are the "95%" corpus; ubercombat is also critical).
#
# The scripts are NOT committed (they were shared privately / are third-party), so
# each example SKIPS unless the file exists locally. On a machine that has them
# (e.g. the maintainer's), this asserts the lexer keeps 100% parse coverage --
# zero unknown-command warnings after includes are resolved.
#
# Roots (override with env vars):
#   GENIE_CORPUS_ROOT (~/repos)                 -> Mastercraft + DR-Genie-Scripts
#   GENIE_LAB (~/genie-port-lab/scripts)        -> ubercombat/
#   GENIE_TESTER_SCRIPTS (unset)                -> a tester's private script dir; with
#   GENIE_TESTER_FILES (comma-separated names)     the files of it to compile
RSpec.describe 'Genie real-world corpus (local, skipped if absent)' do
  repo = ENV['GENIE_CORPUS_ROOT'] || File.expand_path('~/repos')
  lab  = ENV['GENIE_LAB'] || File.expand_path('~/genie-port-lab/scripts')

  tester     = ENV.fetch('GENIE_TESTER_SCRIPTS', nil)
  ubercombat = File.join(lab, 'ubercombat')

  search_dirs = [
    File.join(repo, 'DR-Genie-Scripts'),
    File.join(repo, 'DR-Genie-Scripts', 'GenieHunter'),
    File.join(repo, 'Mastercraft'),
    tester,
    ubercombat
  ].compact

  include_loader = lambda do |name|
    n = name.strip
    search_dirs.each do |dir|
      [n, "#{n}.cmd", "#{n}.inc"].each do |candidate|
        path = File.join(dir, candidate)
        return File.read(path) if File.exist?(path)
      end
    end
    # Absent from the local corpus copy (commonsingleweap.cmd, js_arrays.js): a one-row stub, so
    # the rows we have are still covered (Remix would refuse to load without it).
    "echo stub for #{n}\n"
  end

  tester_files = tester ? ENV.fetch('GENIE_TESTER_FILES', '').split(',').map(&:strip).reject(&:empty?) : []
  tester_cases = tester_files.to_h { |name| ["tester (#{name})", File.join(tester, name)] }

  # label => absolute path
  {
    'Mastercraft (mastercraft.cmd)' => File.join(repo, 'Mastercraft', 'mastercraft.cmd'),
    'Mastercraft (mc_include.cmd)'  => File.join(repo, 'Mastercraft', 'mc_include.cmd'),
    'Mastercraft (MC_Setup.cmd)'    => File.join(repo, 'Mastercraft', 'MC_Setup.cmd'),
    'GenieHunter (hunt.cmd)'        => File.join(repo, 'DR-Genie-Scripts', 'GenieHunter', 'hunt.cmd'),
    'GenieHunter (gh_setup.cmd)'    => File.join(repo, 'DR-Genie-Scripts', 'GenieHunter', 'gh_setup.cmd'),
    'ubercombat (uber.cmd)'         => File.join(ubercombat, 'uber.cmd'),
    'ubercombat (uberwatch.cmd)'    => File.join(ubercombat, 'uberwatch.cmd')
  }.merge(tester_cases).each do |label, path|
    it "compiles #{label} with zero unknown-command warnings" do
      skip "not present locally: #{path}" unless File.exist?(path)

      program = Lich::Genie::Engine.compile(File.read(path), include_loader: include_loader, ignore_warnings: true)
      offenders = program.warnings.map { |w| "L#{w[:file_row]}: #{w[:content][0, 80]}" }
      expect(program.warnings).to be_empty, "unexpected parse warnings:\n#{offenders.join("\n")}"
      expect(program.instructions).not_to be_empty
    end
  end
end
