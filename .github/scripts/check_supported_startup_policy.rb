# frozen_string_literal: true

require 'json'
require_relative '../../lib/startup_policy_compatibility'

# Offline, on the target Ruby/platform: client matrix entries contain an id,
# gemfile path and explicit startup groups. The manifest is never fetched or installed.
if $PROGRAM_NAME == __FILE__
  begin
    raise ArgumentError, 'Usage: check_supported_startup_policy.rb MANIFEST CLIENT_MATRIX' unless ARGV.size == 2
    manifest, matrix = ARGV
    entries = JSON.parse(File.binread(matrix))
    raise ArgumentError, 'client matrix must be a nonempty array of objects' unless entries.is_a?(Array) && !entries.empty? && entries.all? { |client| client.is_a?(Hash) }
    clients = entries.map do |client|
      client.merge('gemfile' => File.binread(File.expand_path(client.fetch('gemfile'), File.dirname(matrix))))
    end
    result = Lich::StartupPolicyCompatibility.verify!(manifest_bytes: File.binread(manifest), clients: clients)
    puts "Startup policy covers supported clients: #{result.keys.join(', ')}"
  rescue Lich::AcceptedGemPolicy::Error, JSON::ParserError, ArgumentError, KeyError, TypeError, SystemCallError => e
    warn "Startup policy rejected: #{e.message}"
    exit 1
  end
end
