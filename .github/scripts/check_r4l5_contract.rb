# frozen_string_literal: true

require 'net/http'
require 'optparse'
require_relative '../../lib/r4l5_contract_check'

module Lich
  # Small bounded HTTPS reader: no package installation, redirects to HTTP,
  # credentials, or recovery side effects. Local paths support offline checks.
  module ContractDocument
    LIMIT = 5 * 1024 * 1024

    def self.read(location, redirects: 5)
      return File.binread(location, LIMIT + 1).tap { |bytes| check_size!(bytes) } unless location.start_with?('https://')
      uri = URI(location)
      raise RuntimeGemContract::Error, 'contract URL must use HTTPS without credentials' unless uri.scheme == 'https' && uri.host && !uri.userinfo
      bytes = +''
      result = nil
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30, write_timeout: 30) do |http|
        http.request(Net::HTTP::Get.new(uri)) do |response|
          case response
          when Net::HTTPSuccess
            response.read_body { |chunk| bytes << chunk; check_size!(bytes) }
            result = bytes
          when Net::HTTPRedirection
            raise RuntimeGemContract::Error, 'too many contract redirects' if redirects.zero?
            destination = URI.join(uri, response.fetch('location')).to_s
            raise RuntimeGemContract::Error, 'contract redirect must use HTTPS' unless destination.start_with?('https://')
            result = read(destination, redirects: redirects - 1)
          else raise RuntimeGemContract::Error, "contract acquisition failed: HTTP #{response.code}"
          end
        end
      end
      result
    end

    def self.check_size!(bytes)
      raise RuntimeGemContract::Error, 'contract document exceeds size limit' if bytes.bytesize > LIMIT
    end
  end
end

if $PROGRAM_NAME == __FILE__
  base = 'https://github.com/elanthia-online/Ruby4Lich5/releases'
  options = {
    gemfile: File.expand_path('../../Gemfile', __dir__),
    lockfile: File.expand_path('../../Gemfile.lock', __dir__),
    manifest: "#{base}/download/R4L5-gem-bundle-x64-mingw-ucrt/R4L5-gem-manifest.json",
    provenance: "#{base}/latest/download/installer-provenance.json"
  }
  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: ruby .github/scripts/check_r4l5_contract.rb [options]'
    %i[gemfile lockfile manifest provenance candidate_sha installer].each do |key|
      opts.on("--#{key.to_s.tr('_', '-')} VALUE") { |value| options[key] = value }
    end
  end
  begin
    parser.parse!
    raise Lich::RuntimeGemContract::Error, 'unexpected arguments' unless ARGV.empty?
    if options[:candidate_sha] && !Lich::RuntimeGemContract::COMMIT.match?(options[:candidate_sha])
      raise Lich::RuntimeGemContract::Error, '--candidate-sha requires a full commit SHA'
    end
    result = Lich::R4L5ContractCheck.verify!(
      gemfile: File.binread(options[:gemfile]), lockfile: File.binread(options[:lockfile]),
      manifest_bytes: Lich::ContractDocument.read(options[:manifest]),
      provenance: JSON.parse(Lich::ContractDocument.read(options[:provenance])),
      candidate_sha: options[:candidate_sha], installer_path: options[:installer],
      lich_version: File.read(File.join(File.dirname(options[:gemfile]), 'lib/version.rb'))[/^LICH_VERSION = '([^']+)'/, 1]
    )
    puts "R4L5 contract accepted: #{result.fetch('packages').length} locked Windows packages; matching installer predecessor"
    result.fetch('bundled').each do |name, versions|
      puts "RubyInstaller supplies #{name}: lock=#{versions['locked'] || 'unlisted'}, supplied=#{versions['supplied']}" if versions['locked'] != versions['supplied']
    end
  rescue Lich::RuntimeGemContract::Error, OptionParser::ParseError, JSON::ParserError, IOError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError => e
    warn "R4L5 contract rejected: #{e.message}"
    exit 1
  end
end
