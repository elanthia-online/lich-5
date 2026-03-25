# frozen_string_literal: true

=begin
  Updates individual scripts, libraries, and data files.

  Handles both repo-specific file updates (e.g. dr-scripts:foo.lic) and
  legacy auto-detected updates. Supports SHA-based skip-if-current checks
  for script repository files.
=end

module Lich
  module Util
    module Update
      class FileUpdater
        # @param client [GitHubClient] GitHub API client instance
        # @param resolver [ChannelResolver] channel resolver instance
        def initialize(client, resolver)
          @client = client
          @resolver = resolver
        end

        # Updates a file from a specific repository.
        #
        # @param type [String] 'script' or 'data'
        # @param repo_key [String] repository key from SCRIPT_REPOS
        # @param filename [String] file name to update
        # @return [void]
        def update_file_from_repo(type, repo_key, filename)
          config = SCRIPT_REPOS[repo_key]
          unless config
            respond "[lich5-update: Unknown repository '#{repo_key}'. Known: #{SCRIPT_REPOS.keys.join(', ')}]"
            return
          end

          case type
          when "script"
            location = SCRIPT_DIR
          when "data"
            data_subdir = (config[:subdirs] || {})['data']
            location = data_subdir ? data_subdir[:dest] : File.join(SCRIPT_DIR, 'data')
            FileUtils.mkdir_p(location)
          else
            respond "[lich5-update: repo:filename syntax is only supported for --script= and --data=.]"
            return
          end

          prefix = config[:script_prefix]
          tree_data = @client.fetch_github_json(config[:api_url])
          if tree_data && tree_data['tree']
            raw_path = if type == "data"
                         data_subdir = (config[:subdirs] || {})['data']
                         if data_subdir && data_subdir[:pattern]
                           match = tree_data['tree'].find { |e| e['path'] =~ data_subdir[:pattern] && File.basename(e['path']) == filename }
                           match ? match['path'] : nil
                         else
                           prefix ? "#{prefix}/#{filename}" : filename
                         end
                       elsif prefix
                         "#{prefix}/#{filename}"
                       else
                         filename
                       end
            remote_entry = raw_path ? tree_data['tree'].find { |e| e['path'] == raw_path } : nil
            if remote_entry
              local_path = File.join(location, filename)
              if File.exist?(local_path)
                local_sha = Digest::SHA1.hexdigest("blob #{File.binread(local_path).bytesize}\0#{File.binread(local_path)}")
                if local_sha == remote_entry['sha']
                  StatusReporter.respond_mono("[lich5-update: #{filename} is already up to date.]")
                  return
                end
              end
            else
              name = config[:display_name] || repo_key
              StatusReporter.respond_mono("[lich5-update: #{filename} not found in #{name} repository.]")
              return
            end
          end

          name = config[:display_name] || repo_key
          url = "#{config[:raw_base_url]}/#{raw_path}"
          content = @client.http_get(url, auth: false)
          if content
            FileWriter.safe_write(File.join(location, filename), content)
            StatusReporter.respond_mono("[lich5-update: #{filename} has been updated from #{name}.]")
          else
            StatusReporter.respond_mono("[lich5-update: Failed to download #{filename} from #{name}.]")
          end
        end

        # Updates a file using legacy auto-detection logic.
        #
        # @param type [String] 'script', 'library', or 'data'
        # @param rf [String] requested filename
        # @param version [String] channel ('production' or 'beta')
        # @return [void]
        def update_file(type, rf, version = 'production')
          if version =~ /^(?:staging|master)$/i
            respond 'Requested channel %s mapped to main (stable).' % [version]
            version = 'production'
          end
          requested_file = rf
          case type
          when "script"
            location = SCRIPT_DIR
            if requested_file.downcase == 'dependency.lic'
              remote_repo = "https://raw.githubusercontent.com/elanthia-online/dr-scripts/main"
            else
              remote_repo = "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts"
            end
            requested_file_ext = requested_file =~ /\.lic$/ ? ".lic" : "bad extension"
          when "library"
            location = LIB_DIR
            case version
            when "production"
              remote_repo = "https://raw.githubusercontent.com/#{GITHUB_REPO}/#{@resolver.resolve_channel_ref(:stable)}/lib"
            when "beta"
              ref = @resolver.resolve_channel_ref(:beta)
              if ref.nil?
                respond 'No viable beta found. Aborting beta update.'
                return
              end
              remote_repo = "https://raw.githubusercontent.com/#{GITHUB_REPO}/#{ref}/lib"
            end
            requested_file_ext = requested_file =~ /\.rb$/ ? ".rb" : "bad extension"
          when "data"
            location = DATA_DIR
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts"
            requested_file_ext = requested_file =~ /(\.(?:xml|ui))$/ ? $1&.dup : "bad extension"
          end

          unless requested_file_ext == "bad extension"
            file_path = File.join(location, requested_file)
            tmp_file_path = file_path + ".tmp"
            old_file_path = file_path + ".old"

            File.rename(file_path, old_file_path) if File.exist?(file_path)

            begin
              File.open(tmp_file_path, "wb") do |file|
                file.write URI.parse(File.join(remote_repo, requested_file)).open.read
              end

              File.rename(tmp_file_path, file_path)
              File.delete(old_file_path) if File.exist?(old_file_path)

              respond
              respond "#{requested_file} has been updated."
            rescue StandardError => e
              respond
              respond "Error updating #{requested_file}: #{e.class} - #{e.message}"
              respond "Backtrace: #{e.backtrace.first(3).join(' | ')}" if $debug

              if File.exist?(tmp_file_path)
                begin
                  File.delete(tmp_file_path)
                  respond "Cleaned up incomplete temporary file."
                rescue => cleanup_error
                  respond "Warning: Could not delete temporary file: #{cleanup_error.message}"
                end
              end

              if File.exist?(old_file_path)
                begin
                  File.rename(old_file_path, file_path)
                  respond "Restored original file."
                rescue => restore_error
                  respond "Warning: Could not restore original file: #{restore_error.message}"
                end
              end

              respond
              respond "The filename #{requested_file} is not available via lich5-update."
              respond "Check the spelling of your requested file, or use '#{$clean_lich_char}jinx' to"
              respond "download #{requested_file} from another repository."
            end
          else
            respond
            respond "The requested file #{requested_file} has an incorrect extension."
            respond "Valid extensions are '.lic' for scripts, '.rb' for library files,"
            respond "and '.xml' or '.ui' for data files. Please correct and try again."
          end
        end

        # Updates core data files (effect-list.xml) after version upgrade.
        #
        # @param version [String] version string (default: LICH_VERSION)
        # @return [void]
        def update_core_data_and_scripts(version = LICH_VERSION)
          if XMLData.game !~ /^GS|^DR/
            respond "invalid game type, unsure what scripts to update via Update.update_core_scripts"
            return
          end

          if XMLData.game =~ /^GS/
            ["effect-list.xml"].each do |file|
              transition_filename = "#{file}".sub(".xml", '')
              newfilename = File.join(DATA_DIR, "#{transition_filename}-#{Time.now.to_i}.xml")
              if File.exist?(File.join(DATA_DIR, file))
                File.open(File.join(DATA_DIR, file), 'rb') { |r| File.open(newfilename, 'wb') { |w| w.write(r.read) } }
                respond "The prior version of #{file} was renamed to #{newfilename}."
              end
              update_file('data', file)
            end
          end

          Lich.core_updated_with_lich_version = version
        end
      end
    end
  end
end
