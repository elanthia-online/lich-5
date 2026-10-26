# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Subprocess supervisor for the real no-argument entrypoint with a protocol-only
# browser substitute. Temporary data and the inherited report pipe isolate it from
# installed accounts. Process-group cleanup makes this a POSIX acceptance helper;
# it does not verify a browser cookie jar, native window geometry, or Windows cleanup.
root = File.expand_path('../..', __dir__)
probe = File.join(root, 'spec/support/default_webui_acceptance_probe.rb')
acceptance_root = Dir.mktmpdir('lich-r3-default-webui-acceptance')
reader, writer = IO.pipe
output = +''
nil

begin
  env = {
    'RUBYOPT'                    => "-r#{probe}",
    'LICH_CI_DEFAULT_WEBUI_FD'   => writer.fileno.to_s,
    'LICH_CI_DEFAULT_WEBUI_ROOT' => acceptance_root
  }
  stdin, combined, wait = Open3.popen2e(
    env, RbConfig.ruby, File.join(root, 'lich.rbw'), chdir: root, pgroup: true, writer.fileno => writer
  )
  writer.close
  stdin.close
  drain = Thread.new { output << combined.read }
  raw = IO.select([reader], nil, nil, 20) ? reader.gets.to_s : ''
  wait.join(10)
  if wait.alive?
    Process.kill('TERM', -wait.pid)
    wait.join(2)
  end
  if wait.alive?
    Process.kill('KILL', -wait.pid)
    wait.join
  end
  status = wait.value
  drain.join
  result = raw.empty? ? { 'verdict' => 'fail', 'error' => 'acceptance record timeout' } : JSON.parse(raw)
  result['clean_shutdown'] = status.success?
  result['exit_status'] = status.exitstatus
  result['term_signal'] = status.termsig
  result['gtk_family_loaded_features'] ||= []
  result['verdict'] = 'fail' unless result['clean_shutdown'] && result['gtk_family_loaded_features'].empty?
  result['log'] = output unless result['verdict'] == 'pass'
  artifact = ENV['LICH_CI_DEFAULT_WEBUI_ARTIFACT']
  if artifact
    FileUtils.mkdir_p(File.dirname(artifact))
    File.write(artifact, JSON.pretty_generate(result) + "\n")
  end
  puts JSON.generate(result)
  exit(result['verdict'] == 'pass' ? 0 : 1)
ensure
  reader.close unless reader.closed?
  writer.close unless writer.closed?
  FileUtils.remove_entry(acceptance_root) if File.directory?(acceptance_root)
end
