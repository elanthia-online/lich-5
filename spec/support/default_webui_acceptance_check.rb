# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require_relative 'default_webui_acceptance_report'

# Subprocess supervisor for the real no-argument entrypoint with a protocol-only
# browser substitute. The probe points the home, data, temp, script, map, log and
# backup roots into one temporary root (only lib stays on the checkout), and the
# verdict fails unless every reported root resolves inside it; an atomic report
# file carries the record without inherited descriptors. On Unix the child runs in
# its own process group and cleanup signals the group; on Windows (no `pgroup:`,
# no TERM) the child PID alone is killed.
# It does not verify a browser cookie jar or native window geometry.
root = File.expand_path('../..', __dir__)
probe = File.join(root, 'spec/support/default_webui_acceptance_probe.rb')
# Windows Ruby rejects `pgroup:` and has no TERM; there the child is spawned
# plainly and stopped by its own PID with KILL. Same choice as the
# bounded_child helper (script_scope_builder_spec.rb).
own_process_group = !RbConfig::CONFIG['host_os'].match?(/mswin|mingw|cygwin/)
acceptance_root = Dir.mktmpdir('lich-default-webui-acceptance')
report_path = File.join(acceptance_root, 'report.json')
output = +''
nil

begin
  env = {
    'RUBYOPT'                      => "-r#{probe}",
    'LICH_WEBUI_BROWSER'           => nil,
    'LICH_CI_DEFAULT_WEBUI_REPORT' => report_path,
    'LICH_CI_DEFAULT_WEBUI_ROOT'   => acceptance_root
  }
  spawn_options = { chdir: root }
  spawn_options[:pgroup] = true if own_process_group
  stdin, combined, wait = Open3.popen2e(env, RbConfig.ruby, File.join(root, 'lich.rbw'), **spawn_options)
  stdin.close
  drain = Thread.new { output << combined.read }
  raw = DefaultWebUIAcceptanceReport.receive(report_path, wait).to_s
  wait.join(10)
  stops = own_process_group ? [['TERM', 2], ['KILL', nil]] : [['KILL', nil]]
  stops.each do |signal, grace|
    break unless wait.alive?

    begin
      Process.kill(signal, own_process_group ? -wait.pid : wait.pid)
    rescue Errno::ESRCH
      # The group exited between the liveness check and the signal; its own
      # exit status, reaped below, is the outcome.
      nil
    end
    wait.join(grace)
  end
  status = wait.value
  drain.join
  result = raw.empty? ? { 'verdict' => 'fail', 'error' => 'acceptance record timeout' } : JSON.parse(raw)
  result['clean_shutdown'] = status.success?
  result['exit_status'] = status.exitstatus
  result['term_signal'] = status.termsig
  result['gtk_family_loaded_features'] ||= []
  isolated = File.realpath(acceptance_root)
  escaped_roots = (result['effective_roots'] || {}).reject do |_name, path|
    resolved = File.exist?(path) ? File.realpath(path) : File.expand_path(path)
    resolved == isolated || resolved.start_with?("#{isolated}/")
  end
  result['escaped_roots'] = escaped_roots
  roots_isolated = result.key?('effective_roots') && escaped_roots.empty?
  result['verdict'] = 'fail' unless result['clean_shutdown'] && result['gtk_family_loaded_features'].empty? && roots_isolated
  result['log'] = output unless result['verdict'] == 'pass'
  artifact = ENV['LICH_CI_DEFAULT_WEBUI_ARTIFACT']
  if artifact
    FileUtils.mkdir_p(File.dirname(artifact))
    File.write(artifact, JSON.pretty_generate(result) + "\n")
  end
  puts JSON.generate(result)
  exit(result['verdict'] == 'pass' ? 0 : 1)
ensure
  FileUtils.remove_entry(acceptance_root) if File.directory?(acceptance_root)
end
